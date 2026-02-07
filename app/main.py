import sys
from pathlib import Path

from PySide6.QtCore import QObject, QThread, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from core.library import (
    add_imported_files,
    delete_book,
    ensure_all_covers,
    epub_chapters,
    get_book,
    list_books,
    read_epub_chapter,
    read_epub_full,
    read_txt,
    unfetched_books,
    update_book,
)
from core.storage import ensure_storage


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

    def __init__(self):
        super().__init__()
        self._worker: CoverWorker | None = None

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
        return read_txt(bookId)

    @Slot(str, result="QVariantList")
    def getChapters(self, bookId: str):
        return epub_chapters(bookId)

    @Slot(str, int, result=str)
    def readChapter(self, bookId: str, chapterIdx: int) -> str:
        return read_epub_chapter(bookId, chapterIdx)

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


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    ensure_storage()

    # Keep a Python reference so GC doesn't collect the QObject
    backend = LibraryBackend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_path = ROOT_DIR / "ui" / "main.qml"
    engine.load(str(qml_path))

    if not engine.rootObjects():
        return 1

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
