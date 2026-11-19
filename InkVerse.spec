# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller build for InkVerse (macOS .app on arm64, Windows folder for the Inno Setup installer).

    pyinstaller InkVerse.spec --noconfirm

macOS: dist/InkVerse.app      Windows: dist/InkVerse/InkVerse.exe (packaged by InkVerse_installer.iss)
"""
import re
import sys
from pathlib import Path

ROOT = Path(SPECPATH)
VERSION = re.search(r'__version__ = "([^"]+)"', (ROOT / "app" / "__init__.py").read_text(encoding="utf-8")).group(1)
IS_MAC = sys.platform == "darwin"

a = Analysis(
    [str(ROOT / "app" / "main.py")],
    pathex=[str(ROOT)],
    datas=[
        (str(ROOT / "ui"), "ui"),
        (str(ROOT / "assets" / "fonts"), "assets/fonts"),
        (str(ROOT / "assets" / "icons"), "assets/icons"),
    ],
    hiddenimports=["core.cover", "core.library", "core.reading", "core.settings", "core.storage", "core.text_encoding"],
    excludes=["tkinter", "pytest", "PySide6.QtWebEngineCore", "PySide6.QtWebEngineWidgets", "PySide6.Qt3DCore"],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="InkVerse",
    console=False,
    icon=str(ROOT / "assets" / "icons" / ("app.icns" if IS_MAC else "app.ico")),
    target_arch="arm64" if IS_MAC else None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(exe, a.binaries, a.datas, name="InkVerse")

if IS_MAC:
    app = BUNDLE(
        coll,
        name="InkVerse.app",
        icon=str(ROOT / "assets" / "icons" / "app.icns"),
        bundle_identifier="io.github.b1mango.inkverse",
        version=VERSION,
        info_plist={
            "CFBundleDisplayName": "墨界",
            "CFBundleName": "InkVerse",
            "CFBundleShortVersionString": VERSION,
            "CFBundleVersion": VERSION,
            "LSApplicationCategoryType": "public.app-category.books",
            "LSMinimumSystemVersion": "12.0",
            "NSHighResolutionCapable": True,
            "NSRequiresAquaSystemAppearance": False,
        },
    )
