"""Reader QML behaviour on real Qt Quick (offscreen); skipped when PySide6 is not installed.

Covers highlights in page mode, mapping between characters and page geometry, note jumps,
and keeping the passage in place when a side panel takes width from the text.
"""

import os
import time
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtCore import QMetaObject, QObject, Q_ARG, QCoreApplication, QUrl, Signal, Slot
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuickControls2 import QQuickStyle
except ImportError:  # pragma: no cover - optional dependency
    QObject = object
    Slot = lambda *a, **k: (lambda f: f)  # noqa: E731
    Signal = lambda *a: None  # noqa: E731
    QGuiApplication = None

UI = Path(__file__).resolve().parent.parent / "ui"
PARAGRAPH = "　　竹影在纸上摇晃，雨后的苔痕比昨日更绿，山中无事，晨起煮茶，松风入窗，案上墨迹未干。"
TEXT = "\n\n".join(PARAGRAPH + str(i) for i in range(120))
NEEDLE = "松风入窗，案上墨迹未干。87"


class FakeBackend(QObject):
    storageError = Signal(str)

    def __init__(self):
        super().__init__()
        start = TEXT.index(NEEDLE)
        self.annotations = [{"id": "a1", "chapter_index": -1, "start": start, "end": start + len(NEEDLE),
                             "text": NEEDLE, "color": "#E8C547", "comment": ""}]

    @Slot(str, result="QVariant")
    def readTextBook(self, book_id):
        return {"text": TEXT, "encoding": "auto", "error": ""}

    @Slot(str, int, result="QVariantList")
    def loadAnnotations(self, book_id, chapter):
        return self.annotations

    @Slot(str, result="QVariant")
    def getReadingProgress(self, book_id):
        return {}

    @Slot(str, int, float, result=bool)
    def saveReadingProgress(self, book_id, chapter, ratio):
        return True

    @Slot(str, result=bool)
    def startReadingSession(self, book_id):
        return True

    @Slot(result=bool)
    def endReadingSession(self):
        return True


def pump(ms=150):
    end = time.monotonic() + ms / 1000
    while time.monotonic() < end:
        QCoreApplication.processEvents()
        time.sleep(0.005)


@unittest.skipIf(QGuiApplication is None, "PySide6 not installed")
class ReaderQmlTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        QQuickStyle.setStyle("Basic")
        cls.app = QGuiApplication.instance() or QGuiApplication([])

    def setUp(self):
        self.engine = QQmlApplicationEngine()
        self.backend = FakeBackend()
        self.engine.rootContext().setContextProperty("backend", self.backend)
        source = b'import QtQuick\nimport "pages"\nWindow { width: 1200; height: 760; visible: true\n' \
                 b'  ReaderPage { objectName: "reader"; anchors.fill: parent } }\n'
        self.engine.loadData(source, QUrl.fromLocalFile(str(UI / "reader_test.qml")))
        self.assertTrue(self.engine.rootObjects(), "ReaderPage failed to load")
        self.window = self.engine.rootObjects()[0]
        self.reader = self.window.findChild(QObject, "reader")
        self.pages = self.reader.findChild(QObject, "pageView")
        QMetaObject.invokeMethod(self.reader, "open", Q_ARG("QVariant", {"id": "b1", "title": "t", "format": "txt"}))
        pump(300)

    def tearDown(self):
        self.window.close()
        self.engine.deleteLater()
        pump(50)

    def js(self, expr):
        """Evaluate an expression inside ReaderPage.qml: its ids and the reader's properties are in scope."""
        from PySide6.QtQml import QQmlExpression
        ctx = self.engine.contextForObject(self.pages)
        e = QQmlExpression(ctx, self.reader, expr)
        result = e.evaluate()
        self.assertFalse(e.hasError(), e.error().toString())
        value = result[0] if isinstance(result, tuple) else result
        return value.toVariant() if hasattr(value, "toVariant") else value

    def test_page_mode_draws_existing_highlight_on_its_page(self):
        self.assertEqual(self.js("readingMode"), "paginated")
        start = TEXT.index(NEEDLE)
        page = self.js(f"paginatedContainer.pageOf({start})")
        self.assertGreater(page, 0)
        col = page * self.js("paginatedContainer._colsPerPage")
        boxes = self.js(f"paginatedContainer.rectsFor({start}, {start + len(NEEDLE)}, {col})")
        self.assertTrue(boxes)
        self.assertEqual(self.js(f"paginatedContainer.rectsFor({start}, {start + len(NEEDLE)}, 0).length"), 0)
        # the box maps back to the first highlighted character
        hit = self.js(f"paginatedContainer.posAt({col}, {boxes[0]['x'] + 1}, {boxes[0]['y'] + 2})")
        self.assertEqual(hit, start)

    def test_note_jump_opens_the_page_holding_the_passage(self):
        start = TEXT.index(NEEDLE)
        self.js("jumpToAnnotation(_annotations[0])")
        pump(300)
        self.assertEqual(self.js("_pageIndex"), self.js(f"paginatedContainer.pageOf({start})"))
        self.assertEqual(self.js("_findAnnotationAt(%d).id" % (start + 2)), "a1")

    def test_highlighting_stays_in_page_mode(self):
        self.js("toggleAnnotationMode()")
        pump(100)
        self.assertTrue(self.js("_annotationMode"))
        self.assertEqual(self.js("readingMode"), "paginated")

    def test_drag_selects_text_in_page_mode(self):
        from PySide6.QtCore import QPoint, Qt
        from PySide6.QtTest import QTest
        self.js("toggleAnnotationMode()")
        pump(100)
        top = int(self.js("readingArea.y + paginatedContainer._topMargin + paginatedContainer._lineH * 2.5"))
        x0 = int(self.js("pageMargin")) + 40
        QTest.mousePress(self.window, Qt.LeftButton, Qt.NoModifier, QPoint(x0, top))
        for k in range(1, 9):
            QTest.mouseMove(self.window, QPoint(x0 + 30 * k, top), 5)
        QTest.mouseRelease(self.window, Qt.LeftButton, Qt.NoModifier, QPoint(x0 + 240, top))
        pump(100)
        start, end = self.js("_selStart"), self.js("_selEnd")
        self.assertGreater(end, start)
        self.assertEqual(self.js("_selText"), TEXT[start:end])
        self.assertTrue(self.js("annotationToolbar.visible"))

    def test_docked_panel_reflows_and_keeps_the_passage(self):
        self.js("jumpToPage(6)")
        pump(200)
        first_char = self.js("_anchorChar")
        width_before = self.js("readingArea.width")
        self.js("_notesVisible = true")
        pump(400)
        self.assertLess(self.js("readingArea.width"), width_before)
        self.assertEqual(self.js("_pageIndex"), self.js(f"paginatedContainer.pageOf({first_char})"))
        self.assertGreater(self.js("_pageIndex"), 6)


if __name__ == "__main__":
    unittest.main()
