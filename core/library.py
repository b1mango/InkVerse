import shutil
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable, List, Optional
from uuid import uuid4

import ebooklib
import fitz  # PyMuPDF
import mobi
from ebooklib import epub

from .cover import extract_epub_cover, extract_pdf_cover, generate as generate_cover
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


def _mobi_cache_dir() -> Path:
    """Cache directory for extracted MOBI → EPUB files."""
    d = ensure_storage()["cache"] / "mobi_epub"
    d.mkdir(exist_ok=True)
    return d


def _extract_mobi_to_epub(mobi_path: Path, book_id: str) -> Optional[Path]:
    """Extract a MOBI file to an EPUB (or HTML) and cache it. Returns path to extracted file."""
    cache = _mobi_cache_dir() / book_id
    epub_marker = cache / ".extracted"
    # Check if already extracted
    if epub_marker.exists():
        for f in cache.iterdir():
            if f.suffix.lower() in (".epub", ".html"):
                return f
    # Extract
    cache.mkdir(parents=True, exist_ok=True)
    try:
        tempdir, extracted_path = mobi.extract(str(mobi_path))
        extracted = Path(extracted_path)
        dest = cache / extracted.name
        shutil.copy2(extracted, dest)
        # Clean up temp
        shutil.rmtree(tempdir, ignore_errors=True)
        epub_marker.write_text("ok")
        return dest
    except Exception:
        return None


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
    """Import TXT, EPUB, PDF, and MOBI files into the library."""
    imports_dir = ensure_storage()["imports"]
    covers = _covers_dir()
    data = _load_metadata()
    added: List[dict] = []

    for src in paths:
        ext = src.suffix.lower()
        if ext not in (".txt", ".epub", ".pdf", ".mobi"):
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
        elif ext == ".pdf":
            # Extract metadata from PDF
            try:
                doc = fitz.open(str(dest))
                meta = doc.metadata
                if meta.get("title"):
                    title = meta["title"]
                if meta.get("author"):
                    author = meta["author"]
                doc.close()
            except Exception:
                pass
            # Try to extract first page as cover
            if not extract_pdf_cover(dest, cover):
                generate_cover(title, cover)
        elif ext == ".mobi":
            # Extract MOBI to EPUB for reading; also try to get metadata
            epub_path = _extract_mobi_to_epub(dest, bid)
            if epub_path and epub_path.suffix.lower() == ".epub":
                try:
                    book = epub.read_epub(str(epub_path), options={"ignore_ncx": True})
                    dc_title = book.get_metadata("DC", "title")
                    if dc_title:
                        title = dc_title[0][0]
                    dc_author = book.get_metadata("DC", "creator")
                    if dc_author:
                        author = dc_author[0][0]
                except Exception:
                    pass
                if not extract_epub_cover(epub_path, cover):
                    generate_cover(title, cover)
            else:
                generate_cover(title, cover)
        else:
            generate_cover(title, cover)

        entry = {
            "id": bid,
            "title": title,
            "author": author,
            "cover_path": str(cover),
            "status": "",
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
                   "li", "blockquote", "tr", "hr", "section", "article"}

    def __init__(self):
        super().__init__()
        self._parts: list[str] = []
        self._skip = False

    def handle_starttag(self, tag: str, _):
        if tag in ("script", "style"):
            self._skip = True
        elif tag == "br":
            self._parts.append("\n")
        elif tag in self._BLOCK_TAGS:
            self._parts.append("\n\n")

    def handle_endtag(self, tag: str):
        if tag in ("script", "style"):
            self._skip = False
        elif tag in self._BLOCK_TAGS:
            self._parts.append("\n\n")

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
            href_map[name.lower()] = idx
            # Also map without directory prefix
            if "/" in name:
                href_map[name.split("/", 1)[1].lower()] = idx

    def _resolve(href: str) -> int:
        """Resolve a TOC href to a spine index."""
        clean = href.split("#")[0].lower() if href else ""
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

    # Fallback: if TOC is empty / too sparse, or no real chapters, use spine directly
    has_real = any((not c.get("isSection") and c.get("index", -1) >= 0) for c in chapters)
    if len(chapters) < 2 or not has_real:
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
    text = _html_to_text(content.decode("utf-8", errors="replace"))
    return _normalize_paragraphs(text)


def _normalize_paragraphs(text: str) -> str:
    """Ensure paragraph separators are consistently \\n\\n."""
    import re
    # Strip \r
    text = text.replace("\r", "")
    # Normalize: line with only whitespace → empty line (paragraph separator)
    text = re.sub(r"\n[ \t\u3000]+\n", "\n\n", text)
    # Lines that start with CJK indent (full-width space) after a single newline
    # are likely new paragraphs → ensure double newline before them
    text = re.sub(r"(?<!\n)\n(\u3000|\u2003| {2,})", r"\n\n\1", text)
    # Collapse triple+ newlines
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


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


# ── MOBI helpers (delegate to EPUB after extraction) ─────────────────


def _get_mobi_epub(book_id: str) -> Optional[Path]:
    """Get the extracted EPUB path for a MOBI book."""
    book = get_book(book_id)
    if not book or book.get("format") != "mobi":
        return None
    mobi_path = Path(str(book.get("path", "")))
    if not mobi_path.exists():
        return None
    return _extract_mobi_to_epub(mobi_path, book_id)


def _open_mobi_epub(book_id: str):
    """Open the extracted EPUB for a MOBI book. Returns (book_dict, epub.EpubBook) or (None, None)."""
    epub_path = _get_mobi_epub(book_id)
    if not epub_path or epub_path.suffix.lower() != ".epub":
        return None, None
    try:
        return get_book(book_id), epub.read_epub(str(epub_path), options={"ignore_ncx": True})
    except Exception:
        return None, None


def mobi_chapters(book_id: str) -> List[dict]:
    """Return chapters from MOBI (via extracted EPUB, or HTML page-break parsing)."""
    book_dict, ep = _open_mobi_epub(book_id)
    if not ep:
        # Try HTML-based chapter extraction using <mbp:pagebreak/> markers
        return _mobi_html_chapters(book_id)

    # Reuse the same TOC parsing logic as EPUB
    spine_items: list = []
    href_map: dict[str, int] = {}
    for sid, _ in ep.spine:
        item = ep.get_item_with_id(sid)
        if item:
            idx = len(spine_items)
            spine_items.append(item)
            name = item.get_name()
            href_map[name.lower()] = idx
            if "/" in name:
                href_map[name.split("/", 1)[1].lower()] = idx

    def _resolve(href: str) -> int:
        clean = href.split("#")[0].lower() if href else ""
        return href_map.get(clean, href_map.get(clean.split("/")[-1], -1))

    chapters: list[dict] = []

    def _flatten(entries, depth: int = 0):
        for entry in entries:
            if isinstance(entry, tuple):
                section, children = entry
                sidx = _resolve(section.href) if hasattr(section, "href") else -1
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

    has_real = any((not c.get("isSection") and c.get("index", -1) >= 0) for c in chapters)
    if len(chapters) < 2 or not has_real:
        chapters = []
        for i, item in enumerate(spine_items):
            name = Path(item.get_name()).stem
            title = name.replace("_", " ").replace("-", " ").strip().title()
            chapters.append({"title": title, "index": i, "isSection": False})

    return chapters


# ── MOBI HTML chapter cache ──
_mobi_html_cache: dict[str, list[dict]] = {}  # book_id -> [{title, html, text}]


def _mobi_html_split(book_id: str) -> list[dict]:
    """Split an HTML-extracted MOBI into chapters using <mbp:pagebreak/> markers.
    Each entry: {title: str, html: str, text: str}. Cached per book_id."""
    import re

    if book_id in _mobi_html_cache:
        return _mobi_html_cache[book_id]

    epub_path = _get_mobi_epub(book_id)
    if not epub_path or epub_path.suffix.lower() not in (".html", ".htm"):
        _mobi_html_cache[book_id] = []
        return []

    try:
        html = epub_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        _mobi_html_cache[book_id] = []
        return []

    # Split by MOBI page-break markers
    raw_parts = re.split(r'<mbp:pagebreak\s*/?>', html)

    chapters: list[dict] = []
    for part_html in raw_parts:
        text = _html_to_text(part_html)
        text = _normalize_paragraphs(text)
        if len(text.strip()) < 5:
            continue  # skip empty / trivially short parts

        # Extract title: first bold/large centered text
        title = ""
        # Try: <font size="N"><b>...</b></font>
        m = re.search(r'<font[^>]*size="[4-6]"[^>]*><b>(.*?)</b></font>', part_html, re.DOTALL)
        if not m:
            # Try: <font size="N">...</font> (without bold)
            m = re.search(r'<font[^>]*size="[4-6]"[^>]*>(.*?)</font>', part_html, re.DOTALL)
        if not m:
            # Try: centered paragraph
            m = re.search(r'<p[^>]*align="center"[^>]*>(.*?)</p>', part_html, re.DOTALL)
        if m:
            title = re.sub(r'<[^>]+>', '', m.group(1)).strip()

        # Fallback: use first line of text
        if not title:
            first_line = text.strip().split('\n')[0].strip()
            title = first_line[:30] if first_line else f"Chapter {len(chapters) + 1}"

        # Skip TOC page itself
        if title.lower() in ("table of contents", "目录"):
            continue

        chapters.append({"title": title, "html": part_html, "text": text})

    _mobi_html_cache[book_id] = chapters
    return chapters


def _mobi_html_chapters(book_id: str) -> List[dict]:
    """Return chapter metadata for an HTML-extracted MOBI.
    Short parts (< 100 chars) are treated as section headers."""
    parts = _mobi_html_split(book_id)
    chapters: list[dict] = []
    for i, p in enumerate(parts):
        text_len = len(p["text"].strip())
        is_section = text_len < 100
        chapters.append({
            "title": p["title"],
            "index": i,
            "isSection": is_section,
        })
    return chapters


def read_mobi_chapter(book_id: str, chapter_idx: int) -> str:
    """Read a single MOBI chapter by spine index (via extracted EPUB or HTML split)."""
    _, ep = _open_mobi_epub(book_id)
    if not ep:
        # Use HTML chapter split
        parts = _mobi_html_split(book_id)
        if 0 <= chapter_idx < len(parts):
            return parts[chapter_idx]["text"]
        return ""
    spine_items = []
    for sid, _ in ep.spine:
        item = ep.get_item_with_id(sid)
        if item:
            spine_items.append(item)
    if chapter_idx < 0 or chapter_idx >= len(spine_items):
        return ""
    content = spine_items[chapter_idx].get_content()
    text = _html_to_text(content.decode("utf-8", errors="replace"))
    return _normalize_paragraphs(text)


def read_mobi_full(book_id: str) -> str:
    """Read entire MOBI as plain text (via extracted EPUB or HTML split)."""
    _, ep = _open_mobi_epub(book_id)
    if not ep:
        # Use cached HTML split
        parts = _mobi_html_split(book_id)
        if parts:
            return "\n\n".join(p["text"] for p in parts)
        # Final fallback: read raw HTML
        epub_path = _get_mobi_epub(book_id)
        if epub_path and epub_path.suffix.lower() in (".html", ".htm"):
            try:
                html = epub_path.read_text(encoding="utf-8", errors="replace")
                return _html_to_text(html)
            except Exception:
                return ""
        return ""
    parts = []
    for item in ep.get_items_of_type(ebooklib.ITEM_DOCUMENT):
        text = _html_to_text(item.get_content().decode("utf-8", errors="replace"))
        if text.strip():
            parts.append(text)
    return "\n\n".join(parts)


# ── PDF helpers ──────────────────────────────────────────────────────


def read_pdf_text(book_id: str) -> str:
    """Read entire PDF as plain text."""
    book = get_book(book_id)
    if not book or book.get("format") != "pdf":
        return ""
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return ""
    
    try:
        doc = fitz.open(str(path))
        parts = []
        for page in doc:
            text = page.get_text()
            if text.strip():
                parts.append(text)
        doc.close()
        return "\n\n".join(parts)
    except Exception:
        return ""


def pdf_chapters(book_id: str) -> List[dict]:
    """Return chapters from PDF outline (table of contents)."""
    book = get_book(book_id)
    if not book or book.get("format") != "pdf":
        return []
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return []
    
    try:
        doc = fitz.open(str(path))
        toc = doc.get_toc()  # Returns list of [level, title, page]
        chapters = []
        
        if toc:
            for i, (level, title, page) in enumerate(toc):
                # Only mark as section if the next entry is at a deeper level
                has_children = (i + 1 < len(toc) and toc[i + 1][0] > level)
                chapters.append({
                    "title": title,
                    "index": page - 1,  # Convert to 0-based index
                    "isSection": has_children,
                })
        else:
            # Fallback: create chapter for each page
            for i in range(len(doc)):
                chapters.append({
                    "title": f"Page {i + 1}",
                    "index": i,
                    "isSection": False,
                })
        
        doc.close()
        return chapters
    except Exception:
        return []


def read_pdf_chapter(book_id: str, page_num: int) -> str:
    """Read a single page from PDF."""
    book = get_book(book_id)
    if not book or book.get("format") != "pdf":
        return ""
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return ""
    
    try:
        doc = fitz.open(str(path))
        if page_num < 0 or page_num >= len(doc):
            doc.close()
            return ""
        text = doc[page_num].get_text()
        doc.close()
        return text
    except Exception:
        return ""


def pdf_page_count(book_id: str) -> int:
    """Return total page count for a PDF."""
    book = get_book(book_id)
    if not book or book.get("format") != "pdf":
        return 0
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return 0

    try:
        doc = fitz.open(str(path))
        count = len(doc)
        doc.close()
        return count
    except Exception:
        return 0


def render_pdf_page(book_id: str, page_num: int, zoom: float = 2.0) -> str:
    """Render a PDF page as PNG image and return the file path."""
    book = get_book(book_id)
    if not book or book.get("format") != "pdf":
        return ""
    path = Path(str(book.get("path", "")))
    if not path.exists():
        return ""
    
    # Create cache directory for PDF page images
    cache_dir = ensure_storage()["cache"] / "pdf_pages" / book_id
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    # Check if already cached
    img_path = cache_dir / f"page_{page_num}_{int(zoom*10)}.png"
    if img_path.exists():
        return str(img_path).replace("\\", "/")
    
    try:
        doc = fitz.open(str(path))
        if page_num < 0 or page_num >= len(doc):
            doc.close()
            return ""
        
        page = doc[page_num]
        mat = fitz.Matrix(zoom, zoom)
        pix = page.get_pixmap(matrix=mat)
        
        # Save as PNG
        pix.save(str(img_path))
        doc.close()
        
        return str(img_path).replace("\\", "/")
    except Exception:
        return ""


# ── Reading stats / heatmap ──────────────────────────────────────────


def _load_reading_stats() -> dict:
    """Load reading stats from storage."""
    stats_path = ensure_storage()["cache"].parent / "reading_stats.json"
    if not stats_path.exists():
        return {"sessions": []}
    return load_json(stats_path) or {"sessions": []}


def _save_reading_stats(data: dict) -> None:
    stats_path = ensure_storage()["cache"].parent / "reading_stats.json"
    save_json(stats_path, data)


def record_reading_session(book_id: str, minutes: float) -> None:
    """Record a reading session with date and duration."""
    from datetime import date
    stats = _load_reading_stats()
    today = date.today().isoformat()
    stats.setdefault("sessions", []).append({
        "date": today,
        "book_id": book_id,
        "minutes": round(minutes, 1),
    })
    _save_reading_stats(stats)


def get_dashboard_stats() -> dict:
    """Return total reading hours and books finished count."""
    stats = _load_reading_stats()
    total_minutes = sum(s.get("minutes", 0) for s in stats.get("sessions", []))
    books = list_books()
    finished = sum(1 for b in books if b.get("status") == "read")
    total_books = len(books)
    return {
        "total_hours": round(total_minutes / 60, 1),
        "finished_books": finished,
        "total_books": total_books,
    }


def get_recent_books(limit: int = 6) -> List[dict]:
    """Return recently active books (those with reading sessions), most recent first."""
    stats = _load_reading_stats()
    sessions = stats.get("sessions", [])
    
    # Build last-read time and total minutes per book
    book_last: dict[str, str] = {}
    book_mins: dict[str, float] = {}
    for s in sessions:
        bid = s.get("book_id", "")
        if not bid:
            continue
        d = s.get("date", "")
        m = s.get("minutes", 0)
        if bid not in book_last or d > book_last[bid]:
            book_last[bid] = d
        book_mins[bid] = book_mins.get(bid, 0) + m
    
    # Sort by most recently read
    sorted_ids = sorted(book_last.keys(), key=lambda x: book_last[x], reverse=True)
    
    result = []
    for bid in sorted_ids[:limit]:
        book = get_book(bid)
        if not book:
            continue
        result.append({
            "id": book.get("id", ""),
            "title": book.get("title", ""),
            "author": book.get("author", ""),
            "cover_path": book.get("cover_path", "").replace("\\", "/"),
            "format": book.get("format", "txt"),
            "last_read": book_last.get(bid, ""),
            "reading_minutes": round(book_mins.get(bid, 0), 1),
        })
    return result


def get_reading_heatmap(days: int = 182) -> List[dict]:
    """Return daily reading minutes for the past N days (for GitHub-style heatmap)."""
    from datetime import date, timedelta
    stats = _load_reading_stats()

    # Aggregate by date
    daily: dict[str, float] = {}
    for s in stats.get("sessions", []):
        d = s.get("date", "")
        daily[d] = daily.get(d, 0) + s.get("minutes", 0)

    today = date.today()
    result = []
    for i in range(days - 1, -1, -1):
        d = today - timedelta(days=i)
        ds = d.isoformat()
        result.append({
            "date": ds,
            "minutes": round(daily.get(ds, 0), 1),
            "weekday": d.weekday(),  # 0=Mon, 6=Sun
        })
    return result


# ── Folder management ────────────────────────────────────────────────


def list_folders() -> List[dict]:
    """Return all folders."""
    data = _load_metadata()
    return data.get("folders", [])


def create_folder(name: str) -> List[dict]:
    """Create a new folder and return updated folders list."""
    data = _load_metadata()
    if "folders" not in data:
        data["folders"] = []
    data["folders"].append({
        "id": str(uuid4()),
        "name": name,
        "book_ids": [],
    })
    _save_metadata(data)
    return data["folders"]


def delete_folder(folder_id: str) -> List[dict]:
    """Delete a folder (does not delete the books inside)."""
    data = _load_metadata()
    data["folders"] = [f for f in data.get("folders", []) if f.get("id") != folder_id]
    _save_metadata(data)
    return data["folders"]


def rename_folder(folder_id: str, name: str) -> List[dict]:
    """Rename a folder."""
    data = _load_metadata()
    for folder in data.get("folders", []):
        if folder.get("id") == folder_id:
            folder["name"] = name
    _save_metadata(data)
    return data.get("folders", [])


def add_book_to_folder(book_id: str, folder_id: str) -> List[dict]:
    """Add a book to a folder."""
    data = _load_metadata()
    for folder in data.get("folders", []):
        if folder.get("id") == folder_id:
            if book_id not in folder.get("book_ids", []):
                folder.setdefault("book_ids", []).append(book_id)
    _save_metadata(data)
    return data.get("folders", [])


def remove_book_from_folder(book_id: str, folder_id: str) -> List[dict]:
    """Remove a book from a folder."""
    data = _load_metadata()
    for folder in data.get("folders", []):
        if folder.get("id") == folder_id:
            ids = folder.get("book_ids", [])
            if book_id in ids:
                ids.remove(book_id)
    _save_metadata(data)
    return data.get("folders", [])


# ── Multi-dimensional reading stats ─────────────────────────────────


def get_reading_stats_by_period() -> dict:
    """Return reading minutes for today, this week, this month, this year, plus previous period comparisons."""
    from datetime import date, timedelta

    stats = _load_reading_stats()
    sessions = stats.get("sessions", [])

    today = date.today()
    today_iso = today.isoformat()
    week_start = today - timedelta(days=today.weekday())
    week_start_iso = week_start.isoformat()
    month_start_iso = today.replace(day=1).isoformat()
    year_start_iso = today.replace(month=1, day=1).isoformat()

    # Previous week
    prev_week_start = week_start - timedelta(days=7)
    prev_week_end = week_start - timedelta(days=1)

    # Previous month
    prev_month_end = today.replace(day=1) - timedelta(days=1)
    prev_month_start = prev_month_end.replace(day=1)

    today_mins = 0.0
    week_mins = 0.0
    month_mins = 0.0
    year_mins = 0.0
    prev_week_mins = 0.0
    prev_month_mins = 0.0

    for s in sessions:
        d = s.get("date", "")
        m = s.get("minutes", 0)
        if d == today_iso:
            today_mins += m
        if d >= week_start_iso:
            week_mins += m
        if d >= month_start_iso:
            month_mins += m
        if d >= year_start_iso:
            year_mins += m
        if prev_week_start.isoformat() <= d <= prev_week_end.isoformat():
            prev_week_mins += m
        if prev_month_start.isoformat() <= d <= prev_month_end.isoformat():
            prev_month_mins += m

    return {
        "today_minutes": round(today_mins, 1),
        "week_minutes": round(week_mins, 1),
        "month_minutes": round(month_mins, 1),
        "year_minutes": round(year_mins, 1),
        "prev_week_minutes": round(prev_week_mins, 1),
        "prev_month_minutes": round(prev_month_mins, 1),
    }


def get_book_reading_detail(book_id: str) -> dict:
    """Return detailed reading statistics for a specific book."""
    from datetime import date, timedelta

    book = get_book(book_id)
    if not book:
        return {}

    stats = _load_reading_stats()
    sessions = stats.get("sessions", [])
    book_sessions = [s for s in sessions if s.get("book_id") == book_id]
    total_minutes = sum(s.get("minutes", 0) for s in book_sessions)

    # Daily reading for the past 30 days
    today = date.today()
    daily_map: dict[str, float] = {}
    for s in book_sessions:
        d = s.get("date", "")
        daily_map[d] = daily_map.get(d, 0) + s.get("minutes", 0)

    daily_data = []
    for i in range(29, -1, -1):
        d = today - timedelta(days=i)
        ds = d.isoformat()
        daily_data.append({"date": ds, "minutes": round(daily_map.get(ds, 0), 1)})

    reading_days = len(set(s.get("date") for s in book_sessions if s.get("date")))
    avg_per_day = round(total_minutes / max(reading_days, 1), 1)
    dates = sorted(s.get("date", "") for s in book_sessions if s.get("date"))

    return {
        "book_id": book_id,
        "title": book.get("title", ""),
        "author": book.get("author", ""),
        "format": book.get("format", "txt"),
        "total_minutes": round(total_minutes, 1),
        "reading_days": reading_days,
        "avg_per_day": avg_per_day,
        "first_read": dates[0] if dates else "",
        "last_read": dates[-1] if dates else "",
        "daily_data": daily_data,
    }


def generate_weekly_report() -> dict:
    """Generate weekly report data for the current week."""
    from datetime import date, timedelta

    today = date.today()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)

    stats = _load_reading_stats()
    sessions = stats.get("sessions", [])

    week_start_iso = week_start.isoformat()
    week_end_iso = week_end.isoformat()
    week_sessions = [s for s in sessions if week_start_iso <= s.get("date", "") <= week_end_iso]
    total_minutes = sum(s.get("minutes", 0) for s in week_sessions)

    # Books read this week with time
    book_time: dict[str, float] = {}
    for s in week_sessions:
        bid = s.get("book_id", "")
        book_time[bid] = book_time.get(bid, 0) + s.get("minutes", 0)

    top_books = []
    for bid, mins in sorted(book_time.items(), key=lambda x: x[1], reverse=True):
        b = get_book(bid)
        if b:
            top_books.append({"title": b.get("title", ""), "minutes": round(mins, 1)})

    # Daily breakdown
    daily = []
    for i in range(7):
        d = week_start + timedelta(days=i)
        ds = d.isoformat()
        day_mins = sum(s.get("minutes", 0) for s in week_sessions if s.get("date") == ds)
        daily.append({"date": ds, "weekday": d.weekday(), "minutes": round(day_mins, 1)})

    # Previous week comparison
    prev_week_start = week_start - timedelta(days=7)
    prev_week_end = week_start - timedelta(days=1)
    prev_sessions = [s for s in sessions
                     if prev_week_start.isoformat() <= s.get("date", "") <= prev_week_end.isoformat()]
    prev_total = sum(s.get("minutes", 0) for s in prev_sessions)

    return {
        "week_start": week_start_iso,
        "week_end": week_end_iso,
        "total_minutes": round(total_minutes, 1),
        "prev_week_minutes": round(prev_total, 1),
        "reading_days": len(set(s.get("date") for s in week_sessions)),
        "top_books": top_books[:5],
        "daily": daily,
    }


# ── Annotations / Highlights ────────────────────────────────────────


def _annotations_dir() -> Path:
    d = ensure_storage()["cache"] / "annotations"
    d.mkdir(exist_ok=True)
    return d


def _ann_path(book_id: str) -> Path:
    return _annotations_dir() / f"{book_id}.json"


def load_annotations(book_id: str, chapter_index: int = -1) -> List[dict]:
    """Load annotations for a book.  -1 = all chapters."""
    path = _ann_path(book_id)
    data = load_json(path) if path.exists() else {}
    annotations = data.get("annotations", [])
    if chapter_index >= 0:
        return [a for a in annotations if a.get("chapter_index") == chapter_index]
    return annotations


def save_annotation(
    book_id: str,
    chapter_index: int,
    start: int,
    end: int,
    text: str,
    color: str,
    comment: str = "",
) -> List[dict]:
    """Create a new annotation and return updated list."""
    from datetime import datetime

    path = _ann_path(book_id)
    data = load_json(path) if path.exists() else {}
    if "annotations" not in data:
        data["annotations"] = []
    data["annotations"].append(
        {
            "id": str(uuid4()),
            "chapter_index": chapter_index,
            "start": start,
            "end": end,
            "text": text,
            "color": color,
            "comment": comment,
            "created_at": datetime.now().isoformat(),
        }
    )
    save_json(path, data)
    return data["annotations"]


def update_annotation(book_id: str, annotation_id: str, **fields) -> List[dict]:
    """Update an annotation (comment, color, etc.)."""
    path = _ann_path(book_id)
    data = load_json(path) if path.exists() else {}
    for ann in data.get("annotations", []):
        if ann.get("id") == annotation_id:
            ann.update(fields)
    save_json(path, data)
    return data.get("annotations", [])


def delete_annotation(book_id: str, annotation_id: str) -> List[dict]:
    """Delete an annotation."""
    path = _ann_path(book_id)
    data = load_json(path) if path.exists() else {}
    data["annotations"] = [
        a for a in data.get("annotations", []) if a.get("id") != annotation_id
    ]
    save_json(path, data)
    return data.get("annotations", [])


