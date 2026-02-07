import json
from pathlib import Path
from typing import Any, Dict

BASE_DIR = Path.home() / ".inkverse"


def ensure_storage() -> Dict[str, Path]:
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    imports = BASE_DIR / "imports"
    cache = BASE_DIR / "cache"
    imports.mkdir(exist_ok=True)
    cache.mkdir(exist_ok=True)
    meta = BASE_DIR / "metadata.json"
    if not meta.exists():
        meta.write_text("{}", encoding="utf-8")
    return {"metadata": meta, "imports": imports, "cache": cache}


def load_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save_json(path: Path, data: Dict[str, Any]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
