"""Offline regression tests; optional format and cover dependencies are stubbed.

Run with: python3 -B -m unittest discover -s tests -v
All writes use TemporaryDirectory; the real library is never opened.
"""

import importlib
import sys
import tempfile
import threading
import types
import unittest
from pathlib import Path
from unittest.mock import patch

from core import storage
from core.reading import ReadingSession
from core.text_encoding import decode_text


class StorageTests(unittest.TestCase):
    def test_failed_replace_preserves_previous_json(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "data.json"
            storage.save_json(path, {"old": "中文"})
            original = path.read_bytes()
            with patch.object(storage.os, "replace", side_effect=OSError("disk failure")):
                with self.assertRaises(OSError):
                    storage.save_json(path, {"new": 2})
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(list(Path(folder).iterdir()), [path])

    def test_failed_sync_preserves_previous_json(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "data.json"
            storage.save_json(path, {"old": 1})
            with patch.object(storage.os, "fsync", side_effect=OSError("disk full")):
                with self.assertRaises(OSError):
                    storage.save_json(path, {"new": 2})
            self.assertEqual(storage.load_json(path), {"old": 1})


class LibraryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cover = types.ModuleType("core.cover")
        cover.generate = lambda title, dest: dest.write_bytes(b"test cover")
        cover.extract_epub_cover = lambda *args: False
        cover.extract_pdf_cover = lambda *args: False
        ebooklib = types.ModuleType("ebooklib")
        ebooklib.epub = types.ModuleType("ebooklib.epub")
        # These tests exercise TXT/storage only, without installing optional readers.
        with patch.dict(sys.modules, {
            "core.cover": cover, "ebooklib": ebooklib,
            "fitz": types.ModuleType("fitz"), "mobi": types.ModuleType("mobi"),
        }):
            cls.library = importlib.import_module("core.library")

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base_patch = patch.object(storage, "BASE_DIR", self.root / "data")
        self.base_patch.start()
        self.addCleanup(self.base_patch.stop)

    def import_text(self, name="book.txt", text="中文书籍", encoding="utf-8"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode(encoding))
        return self.library.add_imported_files([path])[0]

    def test_same_name_import_and_delete_are_independent(self):
        first = self.import_text("a/book.txt", "first")
        second = self.import_text("b/book.txt", "second")
        self.assertNotEqual(first["path"], second["path"])
        self.assertEqual(first["title"], "book")
        self.assertEqual(self.library.read_txt(first["id"]), "first")
        self.library.delete_book(first["id"])
        self.assertEqual(self.library.read_txt(second["id"]), "second")

    def test_old_shared_paths_remain_readable_after_one_record_deleted(self):
        book = self.import_text()
        legacy_path = storage.ensure_storage()["imports"] / "book.txt"
        Path(book["path"]).rename(legacy_path)
        book["path"] = str(legacy_path)
        duplicate = {**book, "id": "legacy-second"}
        self.library._save_metadata({"books": [book, duplicate]})
        self.library.delete_book(book["id"])
        self.assertEqual(self.library.read_txt(duplicate["id"]), "中文书籍")
        self.assertTrue(Path(duplicate["cover_path"]).exists())

    def test_metadata_update_keeps_concurrent_user_change(self):
        book = self.import_text()
        loaded = threading.Event()
        release = threading.Event()
        second_entered = threading.Event()
        original_load = self.library._load_metadata
        failures = []

        def delayed_load():
            data = original_load()
            if threading.current_thread().name == "cover-worker":
                loaded.set()
                if not release.wait(3):
                    raise AssertionError("worker was not released")
            else:
                second_entered.set()
            return data

        def update(**fields):
            try:
                self.library.update_book(book["id"], **fields)
            except Exception as exc:
                failures.append(exc)

        with patch.object(self.library, "_load_metadata", delayed_load):
            first = threading.Thread(target=lambda: update(author="author"), name="cover-worker")
            second = threading.Thread(target=lambda: update(status="read"), name="user-change")
            first.start()
            self.assertTrue(loaded.wait(3))
            second.start()
            try:
                self.assertFalse(second_entered.wait(0.1))
            finally:
                release.set()
                first.join(3)
                second.join(3)
        self.assertFalse(first.is_alive() or second.is_alive())
        self.assertEqual(failures, [])
        saved = self.library.get_book(book["id"])
        self.assertEqual((saved["author"], saved["status"]), ("author", "read"))

    def test_gbk_import_auto_and_manual_encoding_persist(self):
        book = self.import_text(encoding="gbk")
        self.assertEqual(self.library.read_txt(book["id"]), "中文书籍")
        self.assertEqual(self.library.set_text_encoding(book["id"], "gb18030"), "中文书籍")
        self.assertEqual(self.library.get_book(book["id"])["text_encoding"], "gb18030")
        with self.assertRaises(UnicodeDecodeError):
            self.library.set_text_encoding(book["id"], "utf-8-sig")
        self.assertEqual(self.library.get_book(book["id"])["text_encoding"], "gb18030")
        self.assertEqual(self.library.read_txt(book["id"]), "中文书籍")

    def test_manual_big5_and_utf16_without_bom(self):
        for index, encoding in enumerate(("big5", "utf-16-le", "utf-16-be")):
            with self.subTest(encoding=encoding):
                book = self.import_text(f"{index}.txt", "繁體中文", encoding)
                self.assertEqual(self.library.set_text_encoding(book["id"], encoding), "繁體中文")
                self.assertEqual(self.library.read_txt(book["id"]), "繁體中文")

    def test_session_checkpoints_reach_disk_without_rounding_loss(self):
        current = [0.0]
        session = ReadingSession(self.library.record_reading_session, lambda: current[0])
        session.start("book")
        current[0] = 60
        session.flush()
        current[0] = 62
        session.end()
        session.end()
        sessions = self.library._load_reading_stats()["sessions"]
        self.assertAlmostEqual(sum(s["minutes"] for s in sessions), 62 / 60)


class EncodingTests(unittest.TestCase):
    def test_bom_and_common_encodings(self):
        for encoding in ("utf-8", "utf-8-sig", "utf-16", "utf-32", "gb18030"):
            with self.subTest(encoding=encoding):
                text, _ = decode_text("这是中文书籍".encode(encoding))
                self.assertEqual(text, "这是中文书籍")

    def test_invalid_bytes_do_not_turn_into_replacement_characters(self):
        with self.assertRaises(ValueError):
            decode_text(b"\xff")
        with self.assertRaises(ValueError):
            decode_text(b"abc", "unknown")


class ReadingTests(unittest.TestCase):
    def test_switch_and_repeated_end_do_not_double_count(self):
        now = [0.0]
        saved = []
        session = ReadingSession(lambda book, minutes: saved.append((book, minutes)), lambda: now[0])
        session.start("a")
        now[0] = 60
        session.flush()
        now[0] = 90
        session.start("a")  # Starting the same session must not discard its remainder.
        now[0] = 120
        session.start("b")
        now[0] = 150
        session.end()
        session.end()
        self.assertEqual(saved, [("a", 1), ("a", 1), ("b", 0.5)])

    def test_save_failure_retains_uncommitted_time_for_retry(self):
        now = [0.0]
        saved = []
        fail = [True]

        def record(book, minutes):
            if fail[0]:
                raise OSError("disk full")
            saved.append((book, minutes))

        session = ReadingSession(record, lambda: now[0])
        session.start("a")
        now[0] = 60
        with self.assertRaises(OSError):
            session.end()
        fail[0] = False
        now[0] = 90
        session.end()
        session.end()
        self.assertEqual(saved, [("a", 1.5)])


if __name__ == "__main__":
    unittest.main()
