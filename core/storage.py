import json
from pathlib import Path
from typing import Any, Dict

DEFAULT_APP_DIR = Path.home() / ".inkverse"

FILES = {
    "metadata": "metadata.json",
    "reading_logs": "reading_logs.json",
    "settings": "settings.json",
}


def ensure_storage(base_dir: Path | None = None) -> Dict[str, Path]:
    base = base_dir or DEFAULT_APP_DIR
    base.mkdir(parents=True, exist_ok=True)

    imports_dir = base / "imports"
    cache_dir = base / "cache"
    imports_dir.mkdir(exist_ok=True)
    cache_dir.mkdir(exist_ok=True)

    paths = {name: base / filename for name, filename in FILES.items()}
    for path in paths.values():
        if not path.exists():
            path.write_text("{}", encoding="utf-8")

    paths["imports"] = imports_dir
    paths["cache"] = cache_dir
    return paths


def load_json(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: Dict[str, Any]) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
