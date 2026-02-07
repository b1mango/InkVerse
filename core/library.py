from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional
from uuid import uuid4

from .cover import generate as generate_cover
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


def _covers_dir() -> Path:
    return ensure_storage()["cache"] / "covers"


def add_imported_txt(paths: Iterable[Path]) -> List[Dict[str, object]]:
    imported = import_files(paths)
    data = _load_metadata()
    covers = _covers_dir()
    covers.mkdir(exist_ok=True)

    added: List[Dict[str, object]] = []
    for path in imported:
        if path.suffix.lower() != ".txt":
            continue
        bid = str(uuid4())
        cover = covers / f"{bid}.png"
        generate_cover(path.stem, cover)
        book = Book(
            id=bid,
            title=path.stem,
            cover_path=str(cover),
            status="to_read",
        )
        entry = asdict(book)
        entry["path"] = str(path)
        entry["format"] = "txt"
        data["books"].append(entry)
        added.append(entry)

    _save_metadata(data)
    return added


def ensure_all_covers() -> None:
    """Generate algorithmic covers for any books that lack one."""
    covers = _covers_dir()
    covers.mkdir(exist_ok=True)
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


def get_book(book_id: str) -> Optional[Dict[str, object]]:
    for book in list_books():
        if str(book.get("id")) == book_id:
            return book
    return None


def unfetched_books() -> List[Dict[str, object]]:
    """Return books that haven't had online metadata lookup yet."""
    return [b for b in list_books() if not b.get("meta_fetched")]


def update_book(book_id: str, **fields) -> None:
    """Update arbitrary fields of a book in metadata."""
    data = _load_metadata()
    for book in data["books"]:
        if str(book.get("id")) == book_id:
            book.update(fields)
            _save_metadata(data)
            return


def read_txt(book_id: str) -> str:
    book = get_book(book_id)
    if not book:
        return ""
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def parse_chapters(book_id: str) -> List[Dict[str, object]]:
    """Extract chapter headings and their character offsets from a TXT book.

    Recognizes patterns like:
      第X章 / 第X节 / 第X回 / 第X卷 (Chinese)
      Chapter X / CHAPTER X (English)
      ── plain separator lines like “第一章 标题”
    Returns [{"title": str, "offset": int}, ...]
    """
    import re

    text = read_txt(book_id)
    if not text:
        return []

    pattern = re.compile(
        r"^\s*("
        r"第[\u4e00-\u9fa5\d〇零壹贰叁肆伍陆柒捌玖拾佰仟]+[章节回卷部篇集]"
        r"|[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s*\d+"
        r"|[Pp][Aa][Rr][Tt]\s*[．.\s]*\d+"
        r"|卷[\u4e00-\u9fa5\d]+"
        r").*$",
        re.MULTILINE,
    )

    chapters: List[Dict[str, object]] = []
    for m in pattern.finditer(text):
        raw = m.group(0).strip()
        # Skip lines that are too long (likely paragraphs, not headings)
        if len(raw) > 50:
            continue
        title = raw
        chapters.append({"title": title, "offset": m.start()})

    return chapters
