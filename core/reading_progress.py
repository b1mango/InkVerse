from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Dict

from .storage import ensure_storage, load_json, save_json


@dataclass
class DailyReading:
    day: str
    minutes: int


def log_reading(minutes: int, day: date | None = None) -> None:
    storage = ensure_storage()
    log_path = storage["reading_logs"]

    day_key = (day or date.today()).isoformat()
    data: Dict[str, int] = load_json(log_path)
    data[day_key] = int(data.get(day_key, 0)) + int(minutes)

    save_json(log_path, data)
