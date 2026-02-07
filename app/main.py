import sys
from pathlib import Path
from typing import Iterable, List

from PySide6.QtCore import QObject, QThread, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from core.library import (
    add_imported_txt,
    ensure_all_covers,
    list_books,
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
                if result.cover:
                    print(f"[InkVerse] fetched cover: {title}")
                if result.author and not b.get("author"):
                    updates["author"] = result.author
                    print(f"[InkVerse] found author: {title} -> {result.author}")
            else:
                updates["doc_type"] = "document"
                print(f"[InkVerse] no match online, treating as document: {title}")

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
    def _sanitize(books: List[dict]) -> List[dict]:
        """None → empty string, back-slashes → forward slashes for QML."""
        out: List[dict] = []
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
    def listBooks(self) -> List[dict]:
        books = self._sanitize(list_books())
        print(f"[InkVerse] listBooks -> {len(books)} book(s)")
        return books

    @Slot("QVariantList", result="QVariantList")
    def importFiles(self, urls: Iterable[object]) -> List[dict]:
        paths = [p for u in urls if (p := self._coerce_path(u))]
        print(f"[InkVerse] importFiles -> {len(paths)} path(s)")
        added = add_imported_txt(paths)
        print(f"[InkVerse] added {len(added)} book(s)")
        self._fetch_covers_async(added)
        return self._sanitize(list_books())

    @Slot(str, result=str)
    def readBookText(self, bookId: str) -> str:
        return read_txt(bookId)

    @Slot()
    def ensureCovers(self):
        """Generate missing algorithmic covers, then fetch online for new books only."""
        ensure_all_covers()
        pending = unfetched_books()
        if pending:
            print(f"[InkVerse] {len(pending)} book(s) need online lookup")
            self._fetch_covers_async(pending)
        else:
            print("[InkVerse] all books already fetched, skipping online lookup")


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
