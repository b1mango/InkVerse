import sys
from pathlib import Path
from typing import Iterable, List

from PySide6.QtCore import QObject, QUrl, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from core.library import add_imported_txt, list_books, read_txt
from core.storage import ensure_storage


class LibraryBackend(QObject):
    def _coerce_path(self, item: object) -> Path | None:
        if isinstance(item, QUrl):
            local = item.toLocalFile()
        else:
            text = str(item)
            if text.startswith("file:"):
                local = QUrl(text).toLocalFile()
            else:
                local = text
        if not local:
            return None
        path = Path(local)
        if not path.exists():
            return None
        return path

    @Slot(result=list)
    def listBooks(self) -> List[dict]:
        books = list_books()
        print(f"[InkVerse] listBooks -> {len(books)}")
        return books

    @Slot(list, result=list)
    def importFiles(self, urls: Iterable[object]) -> List[dict]:
        paths: List[Path] = []
        for url in urls:
            path = self._coerce_path(url)
            if path:
                paths.append(path)
        print(f"[InkVerse] importFiles -> {len(paths)} path(s)")
        for path in paths:
            print(f"[InkVerse] import: {path}")
        add_imported_txt(paths)
        return list_books()

    @Slot(str, result=str)
    def readBookText(self, bookId: str) -> str:
        return read_txt(bookId)


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    ensure_storage()

    engine.rootContext().setContextProperty("backend", LibraryBackend())

    qml_path = ROOT_DIR / "ui" / "main.qml"
    engine.load(str(qml_path))

    if not engine.rootObjects():
        return 1

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
