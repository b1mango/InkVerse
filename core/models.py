from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Book:
    id: str
    title: str
    author: str | None = None
    cover_path: str | None = None
    status: str = "to_read"
    reading_minutes: int = 0
