import json
import os
import tempfile
import threading
from functools import wraps
from pathlib import Path
from typing import Any, Dict

BASE_DIR = Path.home() / ".inkverse"
_storage_lock = threading.RLock()


def serialized(func):
    """Keep a complete read-modify-write operation inside one process lock."""
    @wraps(func)
    def locked(*args, **kwargs):
        with _storage_lock:
            return func(*args, **kwargs)
    return locked


@serialized
def ensure_storage() -> Dict[str, Path]:
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    imports = BASE_DIR / "imports"
    cache = BASE_DIR / "cache"
    imports.mkdir(exist_ok=True)
    cache.mkdir(exist_ok=True)
    meta = BASE_DIR / "metadata.json"
    if not meta.exists():
        save_json(meta, {})
    return {"metadata": meta, "imports": imports, "cache": cache}


@serialized
def load_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


@serialized
def save_json(path: Path, data: Dict[str, Any]) -> None:
    payload = json.dumps(data, ensure_ascii=False, indent=2)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=f".{path.name}.", suffix=".tmp", delete=False,
        ) as handle:
            temporary = Path(handle.name)
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
