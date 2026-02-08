"""Book cover: algorithmic generation, EPUB extraction & online look-up."""

from __future__ import annotations

import colorsys
import hashlib
import json
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen
from xml.etree import ElementTree as ET

from PIL import Image, ImageDraw, ImageFont
import fitz  # PyMuPDF

W, H = 300, 420  # cover dimensions
_UA = {"User-Agent": "InkVerse/0.1"}


@dataclass
class FetchResult:
    """What an online search found."""
    cover: bool = False
    author: str = ""
    matched: bool = False  # True if title matched a real book


@dataclass
class _Hit:
    img_url: str
    matched_title: str = ""
    author: str = ""
    headers: dict = field(default_factory=lambda: _UA)


# ── Helpers ─────────────────────────────────────────────────────────


def _colors(title: str):
    """Derive two harmonious gradient colours from a title hash."""
    h = int(hashlib.md5(title.encode()).hexdigest(), 16)
    hue1, hue2 = (h % 360) / 360, ((h >> 12) % 360) / 360
    c1 = tuple(int(c * 255) for c in colorsys.hls_to_rgb(hue1, 0.32, 0.55))
    c2 = tuple(int(c * 255) for c in colorsys.hls_to_rgb(hue2, 0.18, 0.45))
    return c1, c2


def _font(size: int = 120):
    """Return a font that supports CJK, with a graceful fallback."""
    for name in ("msyh.ttc", "simhei.ttf", "simsun.ttc", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _titles_match(query: str, candidate: str) -> bool:
    """Check if *query* and *candidate* refer to the same book."""
    q, c = query.strip().lower(), candidate.strip().lower()
    if not q or not c:
        return False
    if q == c:
        return True
    # Short titles (≤4 chars): candidate must START with the query
    # to avoid "test" matching "The Test of …"
    if len(q) <= 4:
        return c.startswith(q)
    # Longer titles: substring in either direction
    return q in c or c in q


# ── Algorithmic generation ──────────────────────────────────────────


def generate(title: str, dest: Path) -> None:
    """Create a unique gradient cover with the title's initial character."""
    c1, c2 = _colors(title)
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)

    # vertical gradient
    for y in range(H):
        t = y / H
        draw.line(
            [(0, y), (W, y)],
            fill=tuple(int(a + (b - a) * t) for a, b in zip(c1, c2)),
        )

    # large initial character
    char = (title[0] if title else "?").upper()
    big = _font(120)
    bb = draw.textbbox((0, 0), char, font=big)
    cx = (W - bb[2] + bb[0]) // 2 - bb[0]
    cy = (H - bb[3] + bb[1]) // 2 - bb[1] - 20
    draw.text((cx + 2, cy + 2), char, fill=(0, 0, 0), font=big)
    draw.text((cx, cy), char, fill=(255, 255, 255), font=big)

    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest, "PNG")


# ── EPUB cover extraction ───────────────────────────────────────────


def extract_epub_cover(epub_path: Path, dest: Path) -> bool:
    """Try to extract the cover image from an EPUB file. Returns True on success."""
    try:
        with zipfile.ZipFile(epub_path) as zf:
            # Strategy 1: look in OPF metadata for a cover image
            cover = _epub_cover_from_opf(zf)
            if cover:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(cover)
                return True

            # Strategy 2: find first image that looks like a cover by name
            for name in zf.namelist():
                low = name.lower()
                if any(k in low for k in ("cover", "frontcover")) and low.endswith(
                    (".jpg", ".jpeg", ".png", ".gif")
                ):
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(zf.read(name))
                    return True
    except Exception:
        pass
    return False


def _epub_cover_from_opf(zf: zipfile.ZipFile) -> bytes | None:
    """Parse container.xml → OPF → find cover image item."""
    try:
        container = ET.fromstring(zf.read("META-INF/container.xml"))
        ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
        opf_path = container.find(".//c:rootfile", ns).attrib["full-path"]
        opf_dir = "/".join(opf_path.split("/")[:-1])
        opf = ET.fromstring(zf.read(opf_path))
        ns_opf = {"opf": "http://www.idpf.org/2007/opf"}

        # Find cover meta → item href
        cover_id = None
        for meta in opf.findall(".//{http://www.idpf.org/2007/opf}meta"):
            if meta.get("name") == "cover":
                cover_id = meta.get("content")
                break

        if not cover_id:
            # Some EPUBs use properties="cover-image" on manifest item
            for item in opf.findall(".//{http://www.idpf.org/2007/opf}item"):
                if "cover-image" in (item.get("properties") or ""):
                    cover_id = item.get("id")
                    break

        if cover_id:
            for item in opf.findall(".//{http://www.idpf.org/2007/opf}item"):
                if item.get("id") == cover_id:
                    href = item.get("href")
                    img_path = f"{opf_dir}/{href}" if opf_dir else href
                    data = zf.read(img_path)
                    if len(data) > 512:
                        return data
    except Exception:
        pass
    return None


# ── PDF cover extraction ────────────────────────────────────────────


def extract_pdf_cover(pdf_path: Path, dest: Path) -> bool:
    """Try to extract the first page as cover from a PDF file. Returns True on success."""
    try:
        doc = fitz.open(str(pdf_path))
        if len(doc) == 0:
            return False
        
        # Render first page as image
        page = doc[0]
        # Render at 2x resolution for better quality, then resize
        mat = fitz.Matrix(2, 2)
        pix = page.get_pixmap(matrix=mat)
        
        # Convert to PIL Image
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        
        # Resize to standard cover dimensions while maintaining aspect ratio
        img.thumbnail((W, H), Image.Resampling.LANCZOS)
        
        # Create a centered image on white background
        final = Image.new("RGB", (W, H), (255, 255, 255))
        x = (W - img.width) // 2
        y = (H - img.height) // 2
        final.paste(img, (x, y))
        
        dest.parent.mkdir(parents=True, exist_ok=True)
        final.save(dest, "PNG")
        doc.close()
        return True
    except Exception:
        return False


# ── Online fetch ────────────────────────────────────────────────────


def fetch_online(title: str, dest: Path, timeout: int = 8) -> FetchResult:
    """Try Douban → Google Books → Open Library. Returns metadata found."""
    result = FetchResult()
    for searcher in (_douban, _google_books, _openlibrary):
        try:
            hit = searcher(title, timeout)
            if not hit:
                continue
            # Validate title similarity to avoid false matches
            if not _titles_match(title, hit.matched_title):
                continue
            result.matched = True
            data = urlopen(
                Request(hit.img_url, headers=hit.headers), timeout=timeout
            ).read()
            if len(data) > 1024:
                dest.write_bytes(data)
                result.cover = True
            if hit.author:
                result.author = hit.author
            if result.cover:
                return result
        except Exception:
            continue
    return result


def _douban(title: str, t: int) -> _Hit | None:
    """Douban subject suggest – best for Chinese books."""
    url = f"https://book.douban.com/j/subject_suggest?q={quote(title)}"
    hdrs = {**_UA, "Referer": "https://book.douban.com/"}
    info = json.loads(urlopen(Request(url, headers=hdrs), timeout=t).read())
    if not info or not isinstance(info, list):
        return None
    for item in info:
        pic = item.get("pic")
        if pic:
            img_url = pic.replace("/spic/", "/l/").replace("/s/", "/l/")
            author = item.get("author_name", "") or ""
            matched = item.get("title", "")
            return _Hit(img_url, matched, author, hdrs)
    return None


def _google_books(title: str, t: int) -> _Hit | None:
    url = f"https://www.googleapis.com/books/v1/volumes?q={quote(title)}&maxResults=1"
    info = json.loads(urlopen(Request(url, headers=_UA), timeout=t).read())
    items = info.get("items", [])
    if not items:
        return None
    vol = items[0].get("volumeInfo", {})
    links = vol.get("imageLinks", {})
    img_url = links.get("thumbnail") or links.get("smallThumbnail")
    if not img_url:
        return None
    authors = vol.get("authors", [])
    matched = vol.get("title", "")
    return _Hit(img_url, matched, ", ".join(authors) if authors else "")


def _openlibrary(title: str, t: int) -> _Hit | None:
    url = f"https://openlibrary.org/search.json?title={quote(title)}&limit=1"
    info = json.loads(urlopen(Request(url, headers=_UA), timeout=t).read())
    docs = info.get("docs", [])
    if not docs or not docs[0].get("cover_i"):
        return None
    doc = docs[0]
    img = f"https://covers.openlibrary.org/b/id/{doc['cover_i']}-M.jpg"
    authors = doc.get("author_name", [])
    matched = doc.get("title", "")
    return _Hit(img, matched, ", ".join(authors) if authors else "")
