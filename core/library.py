from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional
from uuid import uuid4

from .import_manager import import_files
from .models import Book
from .storage import ensure_storage, load_json, save_json


def _load_metadata() -> Dict[str, List[Dict[str, object]]]:
    storage = ensure_storage()
    data = load_json(storage["metadata"])
    if "books" not in data or not isinstance(data["books"], list):
        data["books"] = []
    return data


def _save_metadata(data: Dict[str, List[Dict[str, object]]]) -> None:
    storage = ensure_storage()
    save_json(storage["metadata"], data)


def list_books() -> List[Dict[str, object]]:
    data = _load_metadata()
    return list(data.get("books", []))


def add_imported_txt(paths: Iterable[Path]) -> List[Dict[str, object]]:
    imported = import_files(paths)
    data = _load_metadata()

    added: List[Dict[str, object]] = []
    for path in imported:
        if path.suffix.lower() != ".txt":
            continue
        book = Book(
            id=str(uuid4()),
            title=path.stem,
            author=None,
            cover_path=None,
            status="to_read",
            reading_minutes=0,
        )
        entry = asdict(book)
        entry["path"] = str(path)
        entry["format"] = "txt"
        data["books"].append(entry)
        added.append(entry)

    _save_metadata(data)
    return added


def get_book(book_id: str) -> Optional[Dict[str, object]]:
    for book in list_books():
        if str(book.get("id")) == book_id:
            return book
    return None


def read_txt(book_id: str) -> str:
    book = get_book(book_id)
    if not book:
        return ""
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")
