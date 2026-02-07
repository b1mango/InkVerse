import shutil
from pathlib import Path
from typing import Iterable, List, Optional
from uuid import uuid4

from .cover import generate as generate_cover
from .storage import ensure_storage, load_json, save_json


def _load_metadata() -> dict:
    data = load_json(ensure_storage()["metadata"])
    if not isinstance(data.get("books"), list):
        data["books"] = []
    return data


def _save_metadata(data: dict) -> None:
    save_json(ensure_storage()["metadata"], data)


def _covers_dir() -> Path:
    d = ensure_storage()["cache"] / "covers"
    d.mkdir(exist_ok=True)
    return d


def list_books() -> List[dict]:
    return list(_load_metadata().get("books", []))


def get_book(book_id: str) -> Optional[dict]:
    return next((b for b in list_books() if b.get("id") == book_id), None)


def unfetched_books() -> List[dict]:
    return [b for b in list_books() if not b.get("meta_fetched")]


def update_book(book_id: str, **fields) -> None:
    data = _load_metadata()
    for book in data["books"]:
        if book.get("id") == book_id:
            book.update(fields)
            _save_metadata(data)
            return


def add_imported_txt(paths: Iterable[Path]) -> List[dict]:
    imports_dir = ensure_storage()["imports"]
    covers = _covers_dir()
    data = _load_metadata()
    added: List[dict] = []

    for src in paths:
        if src.suffix.lower() != ".txt":
            continue
        dest = imports_dir / src.name
        shutil.copy2(src, dest)

        bid = str(uuid4())
        cover = covers / f"{bid}.png"
        generate_cover(dest.stem, cover)
        entry = {
            "id": bid,
            "title": dest.stem,
            "author": "",
            "cover_path": str(cover),
            "status": "to_read",
            "path": str(dest),
            "format": "txt",
        }
        data["books"].append(entry)
        added.append(entry)

    _save_metadata(data)
    return added


def ensure_all_covers() -> None:
    covers = _covers_dir()
    data = _load_metadata()
    changed = False
    for book in data["books"]:
        cp = book.get("cover_path", "")
        if not cp or not Path(cp).exists():
            dest = covers / f"{book['id']}.png"
            generate_cover(book.get("title", "?"), dest)
            book["cover_path"] = str(dest)
            changed = True
    if changed:
        _save_metadata(data)


def read_txt(book_id: str) -> str:
    book = get_book(book_id)
    if not book:
        return ""
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")
