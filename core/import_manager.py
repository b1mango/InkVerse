from pathlib import Path
import shutil
from typing import Iterable, List

from .storage import ensure_storage


def import_files(paths: Iterable[Path]) -> List[Path]:
    storage = ensure_storage()
    imports_dir = storage["imports"]

    imported: List[Path] = []
    for path in paths:
        target = imports_dir / path.name
        shutil.copy2(path, target)
        imported.append(target)

    return imported
