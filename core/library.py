import shutil
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable, List, Optional
from uuid import uuid4

import ebooklib
from ebooklib import epub

from .cover import extract_epub_cover, generate as generate_cover
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


def delete_book(book_id: str) -> None:
    """Remove a book from the library and delete its files."""
    data = _load_metadata()
    book = next((b for b in data["books"] if b.get("id") == book_id), None)
    if not book:
        return
    for key in ("path", "cover_path"):
        p = book.get(key, "")
        if p and Path(p).exists():
            Path(p).unlink(missing_ok=True)
    data["books"] = [b for b in data["books"] if b.get("id") != book_id]
    _save_metadata(data)


def add_imported_files(paths: Iterable[Path]) -> List[dict]:
    """Import TXT and EPUB files into the library."""
    imports_dir = ensure_storage()["imports"]
    covers = _covers_dir()
    data = _load_metadata()
    added: List[dict] = []

    for src in paths:
        ext = src.suffix.lower()
        if ext not in (".txt", ".epub"):
            continue
        dest = imports_dir / src.name
        shutil.copy2(src, dest)

        bid = str(uuid4())
        cover = covers / f"{bid}.png"
        fmt = ext.lstrip(".")

        title = dest.stem
        author = ""

        if ext == ".epub":
            # Extract metadata from EPUB
            try:
                book = epub.read_epub(str(dest), options={"ignore_ncx": True})
                dc_title = book.get_metadata("DC", "title")
                if dc_title:
                    title = dc_title[0][0]
                dc_author = book.get_metadata("DC", "creator")
                if dc_author:
                    author = dc_author[0][0]
            except Exception:
                pass
            # Try to extract embedded cover first
            if not extract_epub_cover(dest, cover):
                generate_cover(title, cover)
        else:
            generate_cover(title, cover)

        entry = {
            "id": bid,
            "title": title,
            "author": author,
            "cover_path": str(cover),
            "status": "to_read",
            "path": str(dest),
            "format": fmt,
        }
        data["books"].append(entry)
        added.append(entry)

    _save_metadata(data)
    return added


# Keep backward-compatible alias
add_imported_txt = add_imported_files


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


# ── EPUB helpers ─────────────────────────────────────────────────────


class _HTMLToText(HTMLParser):
    """Lightweight HTML→plain text converter preserving paragraph breaks."""

    _BLOCK_TAGS = {"p", "div", "h1", "h2", "h3", "h4", "h5", "h6",
                   "li", "blockquote", "tr", "br", "hr", "section", "article"}

    def __init__(self):
        super().__init__()
        self._parts: list[str] = []
        self._skip = False

    def handle_starttag(self, tag: str, _):
        if tag in ("script", "style"):
            self._skip = True
        elif tag in self._BLOCK_TAGS:
            self._parts.append("\n")
        elif tag == "br":
            self._parts.append("\n")

    def handle_endtag(self, tag: str):
        if tag in ("script", "style"):
            self._skip = False
        elif tag in self._BLOCK_TAGS:
            self._parts.append("\n")

    def handle_data(self, data: str):
        if not self._skip:
            self._parts.append(data)

    def get_text(self) -> str:
        import re
        raw = "".join(self._parts)
        # Collapse runs of blank lines to max two newlines
        return re.sub(r"\n{3,}", "\n\n", raw).strip()


def _html_to_text(html: str) -> str:
    parser = _HTMLToText()
    parser.feed(html)
    return parser.get_text()


def _open_epub(book_id: str):
    """Return (book_dict, epub.EpubBook) or (None, None)."""
    book = get_book(book_id)
    if not book or book.get("format") != "epub":
        return None, None
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return None, None
    try:
        return book, epub.read_epub(str(path), options={"ignore_ncx": True})
    except Exception:
        return None, None


def epub_chapters(book_id: str) -> List[dict]:
    """Return a flat list of {title, index, isSection} from the EPUB TOC."""
    _, ep = _open_epub(book_id)
    if not ep:
        return []

    # Build spine-ordered items and href → spine-index map
    spine_items: list = []
    href_map: dict[str, int] = {}
    for sid, _ in ep.spine:
        item = ep.get_item_with_id(sid)
        if item:
            idx = len(spine_items)
            spine_items.append(item)
            name = item.get_name()
            href_map[name] = idx
            # Also map without directory prefix
            if "/" in name:
                href_map[name.split("/", 1)[1]] = idx

    def _resolve(href: str) -> int:
        """Resolve a TOC href to a spine index."""
        clean = href.split("#")[0] if href else ""
        return href_map.get(clean, href_map.get(clean.split("/")[-1], -1))

    # Flatten the TOC tree
    chapters: list[dict] = []

    def _flatten(entries, depth: int = 0):
        for entry in entries:
            if isinstance(entry, tuple):
                section, children = entry
                sidx = _resolve(section.href) if hasattr(section, "href") else -1
                # Volume / section header
                chapters.append({
                    "title": getattr(section, "title", "") or "",
                    "index": sidx,
                    "isSection": True,
                })
                _flatten(children, depth + 1)
            elif hasattr(entry, "href"):
                cidx = _resolve(entry.href)
                if cidx >= 0:
                    chapters.append({
                        "title": entry.title or "",
                        "index": cidx,
                        "isSection": False,
                    })

    _flatten(ep.toc)

    # Fallback: if TOC is empty / too sparse, use spine directly
    if len(chapters) < 2:
        chapters = []
        for i, item in enumerate(spine_items):
            name = Path(item.get_name()).stem
            title = name.replace("_", " ").replace("-", " ").strip().title()
            chapters.append({"title": title, "index": i, "isSection": False})

    return chapters


def read_epub_chapter(book_id: str, chapter_idx: int) -> str:
    """Read a single EPUB chapter by spine index as plain text."""
    _, ep = _open_epub(book_id)
    if not ep:
        return ""
    spine_items = []
    for sid, _ in ep.spine:
        item = ep.get_item_with_id(sid)
        if item:
            spine_items.append(item)
    if chapter_idx < 0 or chapter_idx >= len(spine_items):
        return ""
    content = spine_items[chapter_idx].get_content()
    return _html_to_text(content.decode("utf-8", errors="replace"))


def read_epub_full(book_id: str) -> str:
    """Read entire EPUB as plain text (all chapters concatenated)."""
    _, ep = _open_epub(book_id)
    if not ep:
        return ""
    parts = []
    for item in ep.get_items_of_type(ebooklib.ITEM_DOCUMENT):
        text = _html_to_text(item.get_content().decode("utf-8", errors="replace"))
        if text.strip():
            parts.append(text)
    return "\n\n".join(parts)
