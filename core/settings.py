"""Persistent app and reading preferences in ~/.inkverse/settings.json."""

from __future__ import annotations

import copy
from typing import Any, Dict

from core.storage import ensure_storage, load_json, save_json, serialized

DEFAULTS: Dict[str, Any] = {
    "theme": "system",
    "language": "zh",
    "library_view": "grid",
    "library_sort": "recent",
    "reading": {
        "font_family": "LXGW WenKai",
        "font_size": 18,
        "page_margin": 96,
        "paragraph_spacing": 0,
        "reading_mode": "paginated",
        "dual_page": False,
        "background": "auto",
        "pdf_fit_mode": "fit_page",
    },
}

_CHOICES = {
    "theme": {"system", "light", "dark"},
    "language": {"zh", "en"},
    "library_view": {"grid", "list"},
    "library_sort": {"recent", "title", "author", "added"},
    "reading_mode": {"paginated", "scroll"},
    "background": {"auto", "paper", "sepia", "mist", "bamboo", "night"},
    "pdf_fit_mode": {"fit_page", "fit_width", "original"},
}
_RANGES = {"font_size": (14, 28), "page_margin": (10, 120), "paragraph_spacing": (0, 10)}


def _settings_path():
    return ensure_storage()["metadata"].parent / "settings.json"


def _clean_reading(raw: Any) -> Dict[str, Any]:
    clean = copy.deepcopy(DEFAULTS["reading"])
    if not isinstance(raw, dict):
        return clean
    for key, value in raw.items():
        if key not in clean:
            continue
        if key in _RANGES:
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                low, high = _RANGES[key]
                clean[key] = int(min(high, max(low, round(value))))
        elif key == "dual_page":
            if isinstance(value, bool):
                clean[key] = value
        elif key in _CHOICES:
            if value in _CHOICES[key]:
                clean[key] = value
        elif isinstance(value, str) and value.strip():
            clean[key] = value.strip()
    return clean


def _clean(raw: Any) -> Dict[str, Any]:
    clean = copy.deepcopy(DEFAULTS)
    if not isinstance(raw, dict):
        return clean
    for key in ("theme", "language", "library_view", "library_sort"):
        if raw.get(key) in _CHOICES[key]:
            clean[key] = raw[key]
    clean["reading"] = _clean_reading(raw.get("reading"))
    return clean


@serialized
def load_settings() -> Dict[str, Any]:
    """Saved preferences merged over defaults; unknown or invalid values fall back."""
    try:
        return _clean(load_json(_settings_path()))
    except (OSError, ValueError):
        return copy.deepcopy(DEFAULTS)


@serialized
def save_settings(patch: Dict[str, Any]) -> Dict[str, Any]:
    """Merge a partial update (top level and ``reading``), validate, and write atomically."""
    current = load_settings()
    merged = copy.deepcopy(current)
    if isinstance(patch, dict):
        for key, value in patch.items():
            if key == "reading" and isinstance(value, dict):
                merged["reading"].update(value)
            elif key in ("theme", "language", "library_view", "library_sort"):
                merged[key] = value
    clean = _clean(merged)
    save_json(_settings_path(), clean)
    return clean
