import os
import sys
import traceback
from pathlib import Path

from PySide6.QtCore import QObject, QThread, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QFontDatabase, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

_bundle_root = getattr(sys, "_MEIPASS", None)
ROOT_DIR = Path(_bundle_root) if _bundle_root else Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from core.library import (
    add_book_to_folder,
    add_imported_files,
    create_folder,
    delete_annotation,
    delete_book,
    delete_folder,
    ensure_all_covers,
    epub_chapters,
    generate_weekly_report,
    get_book,
    get_book_reading_detail,
    get_dashboard_stats,
    get_reading_heatmap,
    get_reading_stats_by_period,
    get_recent_books,
    list_books,
    list_folders,
    load_annotations,
    mobi_chapters,
    pdf_page_count,
    pdf_chapters,
    read_epub_chapter,
    read_epub_full,
    read_mobi_chapter,
    read_mobi_full,
    read_pdf_chapter,
    read_pdf_text,
    read_txt,
    record_reading_session,
    remove_book_from_folder,
    rename_folder,
    render_pdf_page,
    save_annotation,
    set_text_encoding,
    unfetched_books,
    update_annotation,
    update_book,
)
from core.storage import ensure_storage
from core.reading import ReadingSession
from core.text_encoding import decode_text


# ── Background cover & metadata fetcher ────────────────────────────


class CoverWorker(QThread):
    """Fetch real covers + author info from online APIs in background."""

    done = Signal()

    def __init__(self, books: list):
        super().__init__()
        self._books = books

    def run(self):
        from core.cover import fetch_online

        for b in self._books:
            title = b.get("title", "")
            cp = b.get("cover_path", "")
            bid = b.get("id", "")
            if not (title and cp and bid):
                continue

            result = fetch_online(title, Path(cp))
            updates: dict = {"meta_fetched": True}

            if result.matched:
                updates["doc_type"] = "book"
                if result.author and not b.get("author"):
                    updates["author"] = result.author
            else:
                updates["doc_type"] = "document"

            update_book(bid, **updates)

        self.done.emit()


# ── QML backend ─────────────────────────────────────────────────────


class LibraryBackend(QObject):
    coversUpdated = Signal()
    storageError = Signal(str)

    def __init__(self):
        super().__init__()
        self._worker: CoverWorker | None = None
        self._reading = ReadingSession(record_reading_session)
        self._reading_timer = QTimer(self)
        self._reading_timer.setInterval(60000)
        self._reading_timer.timeout.connect(self.checkpointReadingSession)

    @Slot(str, result=bool)
    def startReadingSession(self, bookId: str) -> bool:
        try:
            self._reading.start(bookId)
            self._reading_timer.start()
            return True
        except (OSError, ValueError):
            self.storageError.emit("阅读时长保存失败，请检查磁盘空间和写入权限后重试。")
            return False

    @Slot(result=bool)
    def checkpointReadingSession(self) -> bool:
        try:
            self._reading.flush()
            self.storageError.emit("")
            return True
        except (OSError, ValueError):
            self.storageError.emit("阅读时长保存失败，请检查磁盘空间和写入权限后重试。")
            return False

    @Slot(result=bool)
    def endReadingSession(self) -> bool:
        try:
            self._reading.end()
            self._reading_timer.stop()
            self.storageError.emit("")
            return True
        except (OSError, ValueError):
            self.storageError.emit("阅读时长保存失败，请检查磁盘空间和写入权限后重试。")
            return False

    @Slot(str, result="QVariant")
    def readTextBook(self, bookId: str):
        book = get_book(bookId)
        if not book:
            return {"error": "书籍不存在。"}
        encoding = book.get("text_encoding", "auto")
        try:
            text, detected = decode_text(Path(book["path"]).read_bytes(), encoding)
            return {"text": text, "encoding": encoding, "detected": detected, "error": ""}
        except UnicodeError:
            return {"error": "无法用当前编码读取，请在阅读设置中选择其他编码。", "encoding": encoding}
        except ValueError:
            return {"error": "无法识别文字编码，请在阅读设置中选择编码。", "encoding": encoding}
        except OSError:
            return {"error": "无法读取书籍文件，请检查文件是否存在及读取权限。", "encoding": encoding}

    @Slot(str, str, result="QVariant")
    def changeTextEncoding(self, bookId: str, encoding: str):
        try:
            text = set_text_encoding(bookId, encoding)
            return {"text": text, "encoding": encoding, "error": ""}
        except (UnicodeError, ValueError):
            return {"error": "无法用此编码读取，已保留原来的正文与编码。"}
        except OSError:
            return {"error": "读取或保存编码失败，请检查文件和写入权限后重试。"}

    # ── helpers ──────────────────────────────────────────────────

    @staticmethod
    def _sanitize(books):
        out = []
        for b in books:
            e = {k: ("" if v is None else v) for k, v in b.items()}
            for key in ("cover_path", "path"):
                if e.get(key):
                    e[key] = e[key].replace("\\", "/")
            out.append(e)
        return out

    def _coerce_path(self, item: object) -> Path | None:
        if isinstance(item, QUrl):
            local = item.toLocalFile()
        else:
            text = str(item)
            local = QUrl(text).toLocalFile() if text.startswith("file:") else text
        return Path(local) if local and Path(local).exists() else None

    def _fetch_covers_async(self, books: list):
        if self._worker and self._worker.isRunning():
            return
        self._worker = CoverWorker(books)
        self._worker.done.connect(self.coversUpdated)
        self._worker.start()

    # ── slots for QML ────────────────────────────────────────────

    @Slot(result="QVariantList")
    def listBooks(self):
        books = self._sanitize(list_books())
        return books

    @Slot("QVariantList", result="QVariantList")
    def importFiles(self, urls):
        paths = [p for u in urls if (p := self._coerce_path(u))]
        added = add_imported_files(paths)
        self._fetch_covers_async(added)
        return self._sanitize(list_books())

    @Slot(str, result=str)
    def readBookText(self, bookId: str) -> str:
        book = get_book(bookId)
        if not book:
            return ""
        fmt = book.get("format", "txt")
        if fmt == "epub":
            return read_epub_full(bookId)
        elif fmt == "pdf":
            return read_pdf_text(bookId)
        elif fmt == "mobi":
            return read_mobi_full(bookId)
        return read_txt(bookId)

    @Slot(str, result="QVariantList")
    def getChapters(self, bookId: str):
        book = get_book(bookId)
        if not book:
            return []
        fmt = book.get("format", "txt")
        if fmt == "epub":
            return epub_chapters(bookId)
        elif fmt == "pdf":
            return pdf_chapters(bookId)
        elif fmt == "mobi":
            return mobi_chapters(bookId)
        return []

    @Slot(str, int, result=str)
    def readChapter(self, bookId: str, chapterIdx: int) -> str:
        book = get_book(bookId)
        if not book:
            return ""
        fmt = book.get("format", "txt")
        if fmt == "epub":
            return read_epub_chapter(bookId, chapterIdx)
        elif fmt == "pdf":
            return read_pdf_chapter(bookId, chapterIdx)
        elif fmt == "mobi":
            return read_mobi_chapter(bookId, chapterIdx)
        return ""

    @Slot(str, int, float, result=str)
    def renderPdfPage(self, bookId: str, pageNum: int, zoom: float = 2.0) -> str:
        """Render a PDF page as an image and return the file path."""
        return render_pdf_page(bookId, pageNum, zoom)

    @Slot(str, result=int)
    def getPdfPageCount(self, bookId: str) -> int:
        return pdf_page_count(bookId)

    @Slot()
    def ensureCovers(self):
        ensure_all_covers()
        pending = unfetched_books()
        if pending:
            self._fetch_covers_async(pending)

    @Slot(str, result="QVariantList")
    def deleteBook(self, bookId: str):
        delete_book(bookId)
        return self._sanitize(list_books())

    @Slot(str, str, result="QVariantList")
    def updateBookStatus(self, bookId: str, status: str):
        update_book(bookId, status=status)
        return self._sanitize(list_books())

    # ── Dashboard / reading stats ────────────────────────────────

    @Slot(result="QVariant")
    def getDashboardStats(self):
        return get_dashboard_stats()

    @Slot(result="QVariantList")
    def getReadingHeatmap(self):
        return get_reading_heatmap(182)  # ~6 months

    @Slot(str, float)
    def recordReadingSession(self, bookId: str, minutes: float):
        record_reading_session(bookId, minutes)

    @Slot(result="QVariantList")
    def getRecentBooks(self):
        return get_recent_books(6)

    # ── Folder management ────────────────────────────────────────

    @Slot(result="QVariantList")
    def listFolders(self):
        return list_folders()

    @Slot(str, result="QVariantList")
    def createFolder(self, name: str):
        return create_folder(name)

    @Slot(str, result="QVariantList")
    def deleteFolder(self, folderId: str):
        return delete_folder(folderId)

    @Slot(str, str, result="QVariantList")
    def renameFolder(self, folderId: str, name: str):
        return rename_folder(folderId, name)

    @Slot(str, str, result="QVariantList")
    def addBookToFolder(self, bookId: str, folderId: str):
        return add_book_to_folder(bookId, folderId)

    @Slot(str, str, result="QVariantList")
    def removeBookFromFolder(self, bookId: str, folderId: str):
        return remove_book_from_folder(bookId, folderId)

    # ── Multi-dimensional stats / Weekly report ──────────────────

    @Slot(result="QVariant")
    def getReadingStatsByPeriod(self):
        return get_reading_stats_by_period()

    @Slot(str, result="QVariant")
    def getBookReadingDetail(self, bookId: str):
        return get_book_reading_detail(bookId)

    @Slot(result="QVariant")
    def generateWeeklyReport(self):
        return generate_weekly_report()

    # ── Annotations / Highlights ───────────────────────────────────

    @Slot(str, int, result="QVariantList")
    def loadAnnotations(self, bookId: str, chapterIndex: int = -1):
        return load_annotations(bookId, chapterIndex)

    @Slot(str, int, int, int, str, str, str, result="QVariantList")
    def saveAnnotation(self, bookId: str, chapterIndex: int, start: int,
                       end: int, text: str, color: str, comment: str):
        return save_annotation(bookId, chapterIndex, start, end, text, color, comment)

    @Slot(str, str, str, result="QVariantList")
    def updateAnnotationComment(self, bookId: str, annotationId: str, comment: str):
        return update_annotation(bookId, annotationId, comment=comment)

    @Slot(str, str, str, result="QVariantList")
    def updateAnnotationColor(self, bookId: str, annotationId: str, color: str):
        return update_annotation(bookId, annotationId, color=color)

    @Slot(str, str, result="QVariantList")
    def deleteAnnotation(self, bookId: str, annotationId: str):
        return delete_annotation(bookId, annotationId)


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    ensure_storage()
    log_path = ensure_storage()["cache"].parent / "inkverse.log"

    def _log(msg: str) -> None:
        try:
            log_path.parent.mkdir(parents=True, exist_ok=True)
            with log_path.open("a", encoding="utf-8") as fh:
                fh.write(msg + "\n")
        except Exception:
            pass

    def _log_warnings(warnings):
        for w in warnings:
            _log(f"QML warning: {w.toString()}")

    engine.warnings.connect(_log_warnings)

    # Ensure QML import path when bundled
    qml_import_path = ROOT_DIR / "PySide6" / "qml"
    if qml_import_path.exists():
        os.environ.setdefault("QML2_IMPORT_PATH", str(qml_import_path))
        engine.addImportPath(str(qml_import_path))

    # Load custom fonts from assets/fonts
    fonts_dir = ROOT_DIR / "assets" / "fonts"
    if fonts_dir.exists():
        for font_file in fonts_dir.glob("*.ttf"):
            QFontDatabase.addApplicationFont(str(font_file))
        for font_file in fonts_dir.glob("*.otf"):
            QFontDatabase.addApplicationFont(str(font_file))

    # Keep a Python reference so GC doesn't collect the QObject
    backend = LibraryBackend()
    app.aboutToQuit.connect(backend.endReadingSession)
    engine.rootContext().setContextProperty("backend", backend)

    qml_path = ROOT_DIR / "ui" / "main.qml"
    try:
        engine.load(QUrl.fromLocalFile(str(qml_path)))
    except Exception:
        _log("Failed to load QML: " + str(qml_path))
        _log(traceback.format_exc())

    if not engine.rootObjects():
        _log("No root objects loaded. QML failed to initialize.")
        return 1

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
