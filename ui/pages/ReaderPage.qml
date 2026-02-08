import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: bgColor
    focus: true

    property string bookId: ""
    property string bookTitle: ""
    property string bookFormat: "txt"
    property string bookText: ""
    property string lang: "zh"
    property int currentChapter: -1
    signal backRequested()

    // ── Reading session tracking ────────────────────────────────
    property real _sessionStartTime: 0

    function _startSession() {
        _sessionStartTime = Date.now()
    }

    function _endSession() {
        if (_sessionStartTime > 0 && bookId && backend) {
            var elapsed = (Date.now() - _sessionStartTime) / 60000  // minutes
            if (elapsed >= 0.1) {
                backend.recordReadingSession(bookId, elapsed)
            }
            _sessionStartTime = 0
        }
    }

    // ── Reading settings ────────────────────────────────────────
    property string bgColor: "#eae8e5"
    property string textColor: "#2a2828"
    property int fontSize: 18
    property string fontFamily: "LXGW WenKai"
    property int pageMargin: 120
    property bool dualPage: false
    property string readingMode: "paginated"  // "scroll" or "paginated"
    property int paragraphSpacing: 0       // 0-10 extra spacing
    property string pdfFitMode: "fit_page" // fit_page, fit_width, original
    property real pdfZoom: 1.0
    property bool _progressBarVisible: false

    // ── Annotations / Highlights ────────────────────────────────
    property bool _annotationMode: false
    property var _annotations: []            // all for current book
    property var _chapterAnnotations: []     // filtered for current chapter
    property bool _notesVisible: false
    property int _selStart: -1
    property int _selEnd: -1
    property string _selText: ""
    // For right-click comment on existing highlight
    property string _commentTargetId: ""

    function _loadAnnotations() {
        if (backend && bookId) {
            root._annotations = backend.loadAnnotations(bookId, -1) || []
            _updateChapterAnnotations()
        }
    }

    function _updateChapterAnnotations() {
        var result = []
        for (var i = 0; i < root._annotations.length; i++) {
            var a = root._annotations[i]
            if (currentChapter < 0 || a.chapter_index === currentChapter)
                result.push(a)
        }
        root._chapterAnnotations = result
        _refreshHighlightRects()
    }

    function _createHighlight(color) {
        if (_selStart < 0 || _selEnd <= _selStart || !_selText) return
        var ci = currentChapter >= 0 ? currentChapter : -1
        root._annotations = backend.saveAnnotation(
            bookId, ci, _selStart, _selEnd, _selText, color, ""
        ) || []
        _updateChapterAnnotations()
        _clearSelection()
    }

    function _commitComment() {
        if (!root._commentTargetId) return
        root._annotations = backend.updateAnnotationComment(
            bookId, root._commentTargetId, commentTextInput.text.trim()
        ) || []
        _updateChapterAnnotations()
        root._commentTargetId = ""
        commentInputOverlay.visible = false
    }

    function _clearSelection() {
        _selStart = -1; _selEnd = -1; _selText = ""
        annotationToolbar.visible = false
        if (scrollTextEdit.selectedText) scrollTextEdit.deselect()
    }

    function _deleteAnnotation(annId) {
        root._annotations = backend.deleteAnnotation(bookId, annId) || []
        _updateChapterAnnotations()
    }

    function _refreshHighlightRects() {
        // Trigger Canvas repaint on next frame
        Qt.callLater(function() {
            if (scrollHighlightCanvas.available) scrollHighlightCanvas.requestPaint()
        })
    }

    // Find annotation at a given text position (for right-click context menu)
    function _findAnnotationAt(pos) {
        var dt = root.displayText
        for (var i = 0; i < root._chapterAnnotations.length; i++) {
            var ann = root._chapterAnnotations[i]
            if (!ann.text || !dt) continue
            var idx = dt.indexOf(ann.text, Math.max(0, ann.start - 20))
            if (idx < 0) idx = dt.indexOf(ann.text)
            if (idx < 0) continue
            if (pos >= idx && pos < idx + ann.text.length) return ann
        }
        return null
    }

    // Helper: does this format support chapters?
    readonly property bool _isChapterFormat: bookFormat === "epub" || bookFormat === "pdf" || bookFormat === "mobi"
    // Helper: epub-like text formats with chapters (not PDF)
    readonly property bool _isEpubLike: bookFormat === "epub" || bookFormat === "mobi"

    // ── EPUB global progress helpers ─────────────────────────────
    property int _epubTotalContentChapters: 0
    property int _epubCurrentContentOrdinal: 0  // 0-based among content chapters

    function _countContentChapters() {
        var count = 0
        for (var i = 0; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (!ch.isSection && ch.pageIndex >= 0) count++
        }
        _epubTotalContentChapters = count
    }

    function _updateContentOrdinal() {
        if (currentChapter < 0) { _epubCurrentContentOrdinal = 0; return }
        var ord = 0
        for (var i = 0; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (!ch.isSection && ch.pageIndex >= 0) {
                if (i === currentChapter) { _epubCurrentContentOrdinal = ord; return }
                ord++
            }
        }
    }

    function _epubSeekToGlobalRatio(ratio) {
        if (_epubTotalContentChapters <= 0) return
        var targetF = ratio * _epubTotalContentChapters
        var targetChapter = Math.floor(targetF)
        if (targetChapter >= _epubTotalContentChapters) targetChapter = _epubTotalContentChapters - 1
        var intraRatio = targetF - targetChapter
        // Find the Nth content chapter
        var ord = 0
        for (var i = 0; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (!ch.isSection && ch.pageIndex >= 0) {
                if (ord === targetChapter) {
                    loadChapterByIndex(i)
                    // After loading, jump to intra-chapter position
                    Qt.callLater(function() {
                        if (readingMode === "paginated") {
                            var p = Math.round(intraRatio * (root._totalPages - 1))
                            root.jumpToPage(Math.max(0, p))
                        } else {
                            scrollFlickable.contentY = intraRatio * Math.max(0, scrollFlickable.contentHeight - scrollFlickable.height)
                        }
                    })
                    return
                }
                ord++
            }
        }
    }

    // Auto-hide progress bar after 4s
    Timer {
        id: progressAutoHide
        interval: 4000; repeat: false
        onTriggered: root._progressBarVisible = false
    }
    on_ProgressBarVisibleChanged: {
        if (_progressBarVisible) progressAutoHide.restart()
        else progressAutoHide.stop()
    }

    // ── Chapter markers for progress bar ────────────────────────
    property var _chapterMarkers: {
        var markers = []
        if (!root._isChapterFormat || chapterModel.count <= 1) return markers

        if (root._isEpubLike && root._epubTotalContentChapters > 0) {
            var ord = 0
            for (var i = 0; i < chapterModel.count; i++) {
                var ch = chapterModel.get(i)
                if (!ch.isSection && ch.pageIndex >= 0) {
                    markers.push({
                        ratio: ord / root._epubTotalContentChapters,
                        title: ch.title
                    })
                    ord++
                }
            }
        } else if (root.bookFormat === "pdf" && pdfFlickable.totalPdfPages > 0) {
            for (var j = 0; j < chapterModel.count; j++) {
                var pch = chapterModel.get(j)
                if (!pch.isSection && pch.pageIndex >= 0) {
                    markers.push({
                        ratio: pch.pageIndex / pdfFlickable.totalPdfPages,
                        title: pch.title
                    })
                }
            }
        }
        return markers
    }

    function _spacedText(raw, spacing) {
        if (!raw) return ""
        // spacing 0 = tight (2 newlines), each step adds 1 newline, 10 = 12 newlines
        var nlCount = 2 + spacing  // 0→2, 1→3, 2→4, ... 10→12
        var join = ""
        for (var i = 0; i < nlCount; i++) join += "\n"
        return raw.replace(/\n{2,}/g, join)
    }
    property string displayText: _spacedText(bookText, paragraphSpacing)

    // ── Paginated state ─────────────────────────────────────────
    property int _pageIndex: 0
    property int _displayPage: 0   // decoupled for slide animation
    property int _totalPages: 1
    property real _slideOffset: 0  // horizontal offset during animation

    readonly property var bgPresets: [
        { name: lang === "zh" ? "素纸" : "Paper",   bg: "#fdfbf7", fg: "#2a2420" },
        { name: lang === "zh" ? "暖褐" : "Sepia",   bg: "#f4ecd8", fg: "#3d3429" },
        { name: lang === "zh" ? "水墨" : "Ink",     bg: "#eae8e5", fg: "#2a2828" },
        { name: lang === "zh" ? "竹青" : "Green",   bg: "#e8f0e6", fg: "#2e3828" },
        { name: lang === "zh" ? "夜间" : "Night",   bg: "#1e1e2e", fg: "#d4d4d8" }
    ]

    // Derived dark-mode helpers
    property bool _isDark: bgColor === "#1e1e2e"
    property string _panelBg:     _isDark ? "#2a2a3e" : "#eeecea"
    property string _panelBorder: _isDark ? "#3a3a4e" : "#d5d3d0"
    property string _activeBg:    _isDark ? "#4a4a6e" : "#d5d3d0"
    property string _hoverBg:     _isDark ? "#333350" : "#e5e3e0"
    property string _dimText:     _isDark ? "#b0b0cc" : "#8a8580"

    ListModel { id: chapterModel }

    function loadChapters() {
        chapterModel.clear()
        currentChapter = -1
        _loadAnnotations()
        if (_isChapterFormat && backend) {
            var chs = backend.getChapters(bookId)
            for (var i = 0; i < chs.length; i++) {
                chapterModel.append({
                    "title":     chs[i].title || ("Chapter " + (i + 1)),
                    "pageIndex": chs[i].index,
                    "isSection": chs[i].isSection || false
                })
            }
            // Set PDF total pages here (after bookFormat is already set)
            if (bookFormat === "pdf") {
                pdfFlickable.totalPdfPages = backend.getPdfPageCount(root.bookId)
            }
            _countContentChapters()

            if (chapterModel.count === 0 && _isEpubLike) {
                // Fallback: load full text if no chapters at all
                root.bookText = backend.readBookText(bookId)
                jumpToPage(0)
                return
            }

            for (var j = 0; j < chapterModel.count; j++) {
                var item = chapterModel.get(j)
                if (!item.isSection && item.pageIndex >= 0) {
                    if (bookFormat === "pdf") {
                        currentChapter = j
                        setPdfPage(item.pageIndex)
                    } else {
                        loadChapterByIndex(j)
                    }
                    break
                }
            }
        }
    }

    function loadChapterByIndex(idx) {
        if (!backend || !_isChapterFormat) return
        var ch = chapterModel.get(idx)
        if (!ch || ch.pageIndex < 0) return
        currentChapter = idx
        _updateContentOrdinal()
        _updateChapterAnnotations()
        if (bookFormat === "pdf") {
            setPdfPage(ch.pageIndex)
            return
        }
        root.bookText = backend.readChapter(bookId, ch.pageIndex)
        jumpToPage(0)
    }

    function loadFirstChildFromSection(sectionIdx) {
        for (var i = sectionIdx + 1; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (!ch.isSection && ch.pageIndex >= 0) {
                loadChapterByIndex(i)
                return true
            }
            if (ch.isSection && i > sectionIdx + 1) break
        }
        return false
    }

    function setPdfPage(pageIdx) {
        if (bookFormat !== "pdf") return
        if (!pdfFlickable) return
        var total = pdfFlickable.totalPdfPages
        var next = pageIdx
        if (next < 0) next = 0
        if (total > 0 && next >= total) next = total - 1
        pdfFlickable.currentPdfPage = next
        pdfFlickable.contentX = 0
        pdfFlickable.contentY = 0
    }

    function pdfPagePrev() {
        if (bookFormat !== "pdf") return
        setPdfPage(pdfFlickable.currentPdfPage - 1)
    }

    function pdfPageNext() {
        if (bookFormat !== "pdf") return
        setPdfPage(pdfFlickable.currentPdfPage + 1)
    }

    function syncPdfChapterFromPage(pageIdx) {
        if (bookFormat !== "pdf") return
        for (var i = 0; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (!ch.isSection && ch.pageIndex === pageIdx) {
                currentChapter = i
                _updateContentOrdinal()
                return
            }
        }
    }

    // ── Navigation helpers ──────────────────────────────────────
    function gotoPrevChapter() {
        for (var i = currentChapter - 1; i >= 0; i--) {
            var ch = chapterModel.get(i)
            if (ch && ch.pageIndex >= 0) { loadChapterByIndex(i); return }
        }
    }
    function gotoNextChapter() {
        for (var i = currentChapter + 1; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (ch && ch.pageIndex >= 0) { loadChapterByIndex(i); return }
        }
    }

    // ── Paginated navigation with horizontal slide ──────────────
    function goToPage(newPage) {
        if (newPage < 0 || newPage >= _totalPages || newPage === _pageIndex) return
        var dir = newPage > _pageIndex ? -1 : 1
        _pageIndex = newPage
        slideAnim.direction = dir
        slideAnim.start()
    }
    function jumpToPage(p) {
        _pageIndex = p; _displayPage = p; _slideOffset = 0
        scrollFlickable.contentY = 0
    }
    function pagePrev() {
        if (_pageIndex > 0) goToPage(_pageIndex - 1)
        else gotoPrevChapter()
    }
    function pageNext() {
        if (_pageIndex < _totalPages - 1) goToPage(_pageIndex + 1)
        else gotoNextChapter()
    }

    SequentialAnimation {
        id: slideAnim
        property int direction: -1  // -1 = slide left (next), 1 = slide right (prev)
        NumberAnimation { target: root; property: "_slideOffset"; from: 0; to: slideAnim.direction * readingArea.width; duration: 150; easing.type: Easing.InQuad }
        ScriptAction { script: { root._displayPage = root._pageIndex } }
        NumberAnimation { target: root; property: "_slideOffset"; from: -slideAnim.direction * readingArea.width; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }

    // ── Keyboard handling ───────────────────────────────────────
    Keys.onLeftPressed:  {
        if (bookFormat === "pdf") pdfPagePrev()
        else if (readingMode === "paginated") pagePrev()
        else gotoPrevChapter()
    }
    Keys.onRightPressed: {
        if (bookFormat === "pdf") pdfPageNext()
        else if (readingMode === "paginated") pageNext()
        else gotoNextChapter()
    }

    // ── Top Bar ─────────────────────────────────────────────────
    Rectangle {
        id: topBar
        width: parent.width; height: 50
        color: "transparent"; z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20; anchors.rightMargin: 20

            Rectangle {
                width: 70; height: 30; radius: 6
                color: backMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "← " + (lang === "zh" ? "返回" : "Back"); color: root.textColor; opacity: 0.6; font.pixelSize: 14 }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root._endSession(); root.backRequested() } }
            }

            Rectangle {
                width: 50; height: 30; radius: 6
                visible: _isChapterFormat && chapterModel.count > 1
                color: tocMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: lang === "zh" ? "目录" : "TOC"; color: root.textColor; opacity: 0.5; font.pixelSize: 13 }
                MouseArea { id: tocMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tocPanel.visible = !tocPanel.visible }
            }

            Rectangle {
                width: 30; height: 30; radius: 6
                visible: _isChapterFormat && chapterModel.count > 1
                color: prevMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "◀"; color: currentChapter > 0 ? root.textColor : "#ccc"; opacity: 0.6; font.pixelSize: 14 }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gotoPrevChapter() }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: {
                    if (_isChapterFormat && currentChapter >= 0 && currentChapter < chapterModel.count)
                        return chapterModel.get(currentChapter).title
                    return root.bookTitle
                }
                color: root.textColor; opacity: 0.7
                font.pixelSize: 14; font.weight: Font.Medium
                elide: Text.ElideMiddle; Layout.maximumWidth: 400
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 30; height: 30; radius: 6
                visible: _isChapterFormat && chapterModel.count > 1
                color: nextMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "▶"; color: currentChapter < chapterModel.count - 1 ? root.textColor : "#ccc"; opacity: 0.6; font.pixelSize: 14 }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gotoNextChapter() }
            }

            Rectangle {
                width: 50; height: 30; radius: 6
                color: settingsMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: lang === "zh" ? "设置" : "Settings"; color: root.textColor; opacity: 0.5; font.pixelSize: 13 }
                MouseArea { id: settingsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsPanel.visible = !settingsPanel.visible }
            }

            // Annotation mode toggle
            Rectangle {
                width: 50; height: 30; radius: 6
                color: root._annotationMode ? (root._isDark ? "#4a4a6e" : "#d5d0c8") : (annModeMa.containsMouse ? "#15000000" : "transparent")
                border.color: root._annotationMode ? (root._isDark ? "#6666aa" : "#a09888") : "transparent"
                border.width: root._annotationMode ? 1.5 : 0
                Text {
                    anchors.centerIn: parent
                    text: lang === "zh" ? "划线" : "Mark"
                    color: root.textColor; opacity: root._annotationMode ? 0.9 : 0.5
                    font.pixelSize: 13
                }
                MouseArea {
                    id: annModeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root._annotationMode = !root._annotationMode
                }
            }

            // Notes button
            Rectangle {
                width: 50; height: 30; radius: 6
                color: notesMa.containsMouse ? "#15000000" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: lang === "zh" ? "笔记" : "Notes"
                    color: root.textColor; opacity: 0.5; font.pixelSize: 13
                }
                Rectangle {
                    visible: root._annotations.length > 0
                    anchors.top: parent.top; anchors.right: parent.right
                    anchors.topMargin: 2; anchors.rightMargin: 2
                    width: 14; height: 14; radius: 7
                    color: _isDark ? "#6666aa" : "#a09888"
                    Text {
                        anchors.centerIn: parent
                        text: root._annotations.length > 99 ? "99" : root._annotations.length.toString()
                        color: "#fff"; font.pixelSize: 7; font.weight: Font.Bold
                    }
                }
                MouseArea {
                    id: notesMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root._notesVisible = !root._notesVisible
                }
            }
        }
    }

    // ── TOC Panel (left side) ───────────────────────────────────
    Rectangle {
        id: tocPanel
        visible: false; z: 20
        anchors.top: topBar.bottom
        anchors.left: parent.left; anchors.leftMargin: 20
        width: 300; height: Math.min(chapterModel.count * 38 + 20, root.height * 0.7)
        radius: 10; color: _panelBg; border.color: _panelBorder

        // Background blocker: prevents clicks from bleeding through to the click-outside overlay
        MouseArea { anchors.fill: parent; z: 0 }

        ListView {
            z: 1
            anchors.fill: parent; anchors.margins: 10
            model: chapterModel; clip: true
            delegate: Rectangle {
                width: ListView.view.width
                height: model.isSection ? 40 : 34; radius: 6
                color: {
                    if (model.isSection) return "transparent"
                    if (index === currentChapter) return _isDark ? "#3a3a5e" : "#e8e4de"
                    if (tocItemMa.containsMouse) return _hoverBg
                    return "transparent"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: model.isSection ? 8 : 20; anchors.rightMargin: 12
                    text: model.title
                    color: {
                        if (model.isSection) return _isDark ? "#a0a0c0" : "#999"
                        if (index === currentChapter) return _isDark ? "#e0e0ff" : "#333"
                        return _dimText
                    }
                    font.pixelSize: model.isSection ? 14 : 13
                    font.weight: model.isSection ? Font.Bold : (index === currentChapter ? Font.DemiBold : Font.Normal)
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: tocItemMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: (model.pageIndex >= 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (model.isSection) {
                            if (loadFirstChildFromSection(index)) {
                                tocPanel.visible = false
                                return
                            }
                            // Section without children – fall through to treat as regular chapter
                        }
                        if (model.pageIndex >= 0) {
                            loadChapterByIndex(index)
                            tocPanel.visible = false
                        }
                    }
                }
            }
        }
    }

    // ── Settings Panel (right side) ─────────────────────────────
    Rectangle {
        id: settingsPanel
        visible: false; z: 20
        anchors.top: topBar.bottom
        anchors.right: parent.right; anchors.rightMargin: 20
        width: 300; height: settingsCol.implicitHeight + 40
        radius: 10; color: _panelBg; border.color: _panelBorder

        Column {
            id: settingsCol
            anchors.fill: parent; anchors.margins: 20
            spacing: 20

            // ── Background ──
            Text { text: lang === "zh" ? "阅读背景" : "Background"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 10
                Repeater {
                    model: root.bgPresets.length
                    Rectangle {
                        width: 44; height: 30; radius: 6
                        color: root.bgPresets[index].bg
                        border.color: root.bgColor === root.bgPresets[index].bg ? root.textColor : "#ccc"
                        border.width: root.bgColor === root.bgPresets[index].bg ? 2 : 1
                        Text { anchors.centerIn: parent; text: root.bgPresets[index].name; font.pixelSize: 9; color: root.bgPresets[index].fg }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.bgColor = root.bgPresets[index].bg; root.textColor = root.bgPresets[index].fg } }
                    }
                }
            }

            // ── Font family ──
            Text { text: lang === "zh" ? "阅读字体" : "Font"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Grid {
                columns: 3; spacing: 8; width: parent.width
                Repeater {
                    model: [
                        { label: "Georgia",  val: "Georgia" },
                        { label: "宋体",     val: "SimSun" },
                        { label: "楷体",     val: "KaiTi" },
                        { label: "微软雅黑", val: "Microsoft YaHei" },
                        { label: "仿宋",     val: "FangSong" },
                        { label: "霞鹜文楷", val: "LXGW WenKai" },
                        { label: "朱雀仿宋", val: "Zhuque Fangsong (technical preview)" },
                        { label: "小赖字体", val: "Xiaolai" }
                    ]
                    Rectangle {
                        width: 84; height: 30; radius: 6
                        color: root.fontFamily === modelData.val ? _activeBg : "transparent"
                        border.color: _panelBorder
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.textColor; opacity: root.fontFamily === modelData.val ? 1.0 : 0.6
                            font.pixelSize: 11
                            font.family: modelData.val
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.fontFamily = modelData.val
                        }
                    }
                }
            }

            // ── Font size (custom stepper slider) ──
            Text { text: lang === "zh" ? "字体大小" : "Font Size"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 0; width: parent.width
                Rectangle {
                    width: 36; height: 32; radius: 6; color: fsMinus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "A"; color: root.textColor; opacity: 0.6; font.pixelSize: 12 }
                    MouseArea { id: fsMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.fontSize > 14) root.fontSize-- } }
                }
                Item {
                    width: parent.width - 72; height: 32
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 16; height: 3; x: 8; radius: 1.5; color: _isDark ? "#444466" : "#d8d4ce" }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; height: 3; width: (root.fontSize - 14) / 14 * (parent.width - 16); radius: 1.5; color: _isDark ? "#8888bb" : "#a09888" }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8 + (root.fontSize - 14) / 14 * (parent.width - 16) - 10
                        width: 20; height: 20; radius: 10
                        color: _isDark ? "#aaaadd" : "#7a7060"
                        Text { anchors.centerIn: parent; text: root.fontSize; color: "#fff"; font.pixelSize: 9; font.weight: Font.Bold }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.fontSize = Math.round(14 + r * 14) }
                        onPositionChanged: function(mouse) { if (pressed) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.fontSize = Math.round(14 + r * 14) } }
                    }
                }
                Rectangle {
                    width: 36; height: 32; radius: 6; color: fsPlus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "A"; color: root.textColor; opacity: 0.6; font.pixelSize: 16; font.weight: Font.DemiBold }
                    MouseArea { id: fsPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.fontSize < 28) root.fontSize++ } }
                }
            }

            // ── Page margin (custom stepper slider) ──
            Text { text: lang === "zh" ? "页面边距" : "Margin"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 0; width: parent.width
                Rectangle {
                    width: 36; height: 32; radius: 6; color: mgMinus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "−"; color: root.textColor; opacity: 0.6; font.pixelSize: 16 }
                    MouseArea { id: mgMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.pageMargin > 10) root.pageMargin -= 5 } }
                }
                Item {
                    width: parent.width - 72; height: 32
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 16; height: 3; x: 8; radius: 1.5; color: _isDark ? "#444466" : "#d8d4ce" }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; height: 3; width: (root.pageMargin - 10) / 110 * (parent.width - 16); radius: 1.5; color: _isDark ? "#8888bb" : "#a09888" }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8 + (root.pageMargin - 10) / 110 * (parent.width - 16) - 10
                        width: 20; height: 20; radius: 10
                        color: _isDark ? "#aaaadd" : "#7a7060"
                        Text { anchors.centerIn: parent; text: root.pageMargin; color: "#fff"; font.pixelSize: 9; font.weight: Font.Bold }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.pageMargin = Math.round((10 + r * 110) / 5) * 5 }
                        onPositionChanged: function(mouse) { if (pressed) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.pageMargin = Math.round((10 + r * 110) / 5) * 5 } }
                    }
                }
                Rectangle {
                    width: 36; height: 32; radius: 6; color: mgPlus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "+"; color: root.textColor; opacity: 0.6; font.pixelSize: 16 }
                    MouseArea { id: mgPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.pageMargin < 120) root.pageMargin += 5 } }
                }
            }

            // ── Paragraph spacing (custom stepper slider) ──
            Text { text: lang === "zh" ? "段间距" : "Spacing"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 0; width: parent.width
                Rectangle {
                    width: 36; height: 32; radius: 6; color: psMinus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "−"; color: root.textColor; opacity: 0.6; font.pixelSize: 16 }
                    MouseArea { id: psMinus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.paragraphSpacing > 0) root.paragraphSpacing-- } }
                }
                Item {
                    width: parent.width - 72; height: 32
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 16; height: 3; x: 8; radius: 1.5; color: _isDark ? "#444466" : "#d8d4ce" }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; height: 3; width: root.paragraphSpacing / 10 * (parent.width - 16); radius: 1.5; color: _isDark ? "#8888bb" : "#a09888" }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8 + root.paragraphSpacing / 10 * (parent.width - 16) - 10
                        width: 20; height: 20; radius: 10
                        color: _isDark ? "#aaaadd" : "#7a7060"
                        Text { anchors.centerIn: parent; text: root.paragraphSpacing; color: "#fff"; font.pixelSize: 9; font.weight: Font.Bold }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.paragraphSpacing = Math.round(r * 10) }
                        onPositionChanged: function(mouse) { if (pressed) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.paragraphSpacing = Math.round(r * 10) } }
                    }
                }
                Rectangle {
                    width: 36; height: 32; radius: 6; color: psPlus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "+"; color: root.textColor; opacity: 0.6; font.pixelSize: 16 }
                    MouseArea { id: psPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.paragraphSpacing < 10) root.paragraphSpacing++ } }
                }
            }

            // ── PDF Page Size ──
            Text {
                text: lang === "zh" ? "页面大小" : "Page Size"
                visible: root.bookFormat === "pdf"
                color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold
            }
            Row {
                visible: root.bookFormat === "pdf"
                spacing: 10
                Repeater {
                    model: [
                        { label: lang === "zh" ? "原始大小" : "Original", val: "original" },
                        { label: lang === "zh" ? "适应宽度" : "Fit Width", val: "fit_width" },
                        { label: lang === "zh" ? "自动缩放" : "Fit Page", val: "fit_page" }
                    ]
                    Rectangle {
                        width: 80; height: 30; radius: 6
                        color: root.pdfFitMode === modelData.val ? _activeBg : "transparent"
                        border.color: _panelBorder
                        Text { anchors.centerIn: parent; text: modelData.label; color: root.textColor; opacity: 0.7; font.pixelSize: 11 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pdfFitMode = modelData.val
                                root.pdfZoom = 1.0
                            }
                        }
                    }
                }
            }

            // ── Reading mode ──
            Text { text: lang === "zh" ? "阅读方式" : "Mode"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 10
                Repeater {
                    model: [{ label: lang === "zh" ? "下拉" : "Scroll", val: "scroll" }, { label: lang === "zh" ? "翻页" : "Paged", val: "paginated" }]
                    Rectangle {
                        width: 70; height: 30; radius: 6
                        color: root.readingMode === modelData.val ? _activeBg : "transparent"
                        border.color: _panelBorder
                        Text { anchors.centerIn: parent; text: modelData.label; color: root.textColor; opacity: 0.7; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.readingMode = modelData.val; jumpToPage(0) } }
                    }
                }
            }

            // ── Layout ──
            Text { text: lang === "zh" ? "页面布局" : "Layout"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 10
                Repeater {
                    model: [{ label: lang === "zh" ? "单页" : "Single", val: false }, { label: lang === "zh" ? "双页" : "Dual", val: true }]
                    Rectangle {
                        width: 70; height: 30; radius: 6
                        color: root.dualPage === modelData.val ? _activeBg : "transparent"
                        border.color: _panelBorder
                        Text { anchors.centerIn: parent; text: modelData.label; color: root.textColor; opacity: 0.7; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.dualPage = modelData.val; jumpToPage(0) } }
                    }
                }
            }
        }
    }

    // Click outside to close panels
    MouseArea {
        anchors.fill: parent; z: 15
        visible: tocPanel.visible || settingsPanel.visible || root._notesVisible
        onClicked: { tocPanel.visible = false; settingsPanel.visible = false; root._notesVisible = false }
    }

    // ── Reading Area ────────────────────────────────────────────
    Item {
        id: readingArea
        anchors.top: topBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right

        // ═══════════════ PDF IMAGE MODE ═══════════════
        Flickable {
            id: pdfFlickable
            visible: root.bookFormat === "pdf"
            anchors.fill: parent
            clip: true
            contentWidth: pdfCanvas.width
            contentHeight: pdfCanvas.height
            boundsBehavior: Flickable.StopAtBounds

            property int currentPdfPage: 0
            property int totalPdfPages: 1
            property real displayW: 100
            property real displayH: 100

            function updateScale() {
                var iw = pdfImage.sourceSize.width
                var ih = pdfImage.sourceSize.height
                if (iw <= 0 || ih <= 0) return

                var pad = 40
                var availW = Math.max(200, pdfFlickable.width - pad * 2)
                var availH = Math.max(200, pdfFlickable.height - pad * 2)

                var s = 1.0
                if (root.pdfFitMode === "fit_width") s = availW / iw
                else if (root.pdfFitMode === "original") s = 1.0
                else s = Math.min(availW / iw, availH / ih)
                s = s * root.pdfZoom

                displayW = Math.round(iw * s)
                displayH = Math.round(ih * s)
            }

            Item {
                id: pdfCanvas
                width: Math.max(pdfFlickable.width, pdfFlickable.displayW + 64)
                height: Math.max(pdfFlickable.height, pdfFlickable.displayH + 64)

                Rectangle {
                    id: pageFrame
                    width: pdfFlickable.displayW + 24
                    height: pdfFlickable.displayH + 24
                    x: (pdfCanvas.width - width) / 2
                    y: (pdfCanvas.height - height) / 2
                    radius: 8
                    color: "#ffffff"
                    border.color: "#e0ddd8"
                }

                Image {
                    id: pdfImage
                    width: pdfFlickable.displayW
                    height: pdfFlickable.displayH
                    x: pageFrame.x + 12
                    y: pageFrame.y + 12
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    smooth: true

                    source: {
                        if (root.bookFormat === "pdf" && backend && root.bookId && pdfFlickable.currentPdfPage >= 0) {
                            return "file:///" + backend.renderPdfPage(root.bookId, pdfFlickable.currentPdfPage, 2.0)
                        }
                        return ""
                    }

                    onStatusChanged: {
                        if (status === Image.Ready) pdfFlickable.updateScale()
                    }
                    onSourceSizeChanged: pdfFlickable.updateScale()
                }

                // Zoom controls
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        if (wheel.modifiers & Qt.ControlModifier) {
                            var delta = wheel.angleDelta.y / 120
                            root.pdfZoom = Math.max(0.5, Math.min(3.0, root.pdfZoom + delta * 0.1))
                            pdfFlickable.updateScale()
                            wheel.accepted = true
                        } else {
                            wheel.accepted = false
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {}
            ScrollBar.horizontal: ScrollBar {}

            onWidthChanged: updateScale()
            onHeightChanged: updateScale()
            onCurrentPdfPageChanged: syncPdfChapterFromPage(currentPdfPage)

            // Page indicator
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 20
                width: pageText.implicitWidth + 20; height: 30
                radius: 15; color: "#80000000"
                Text {
                    id: pageText
                    anchors.centerIn: parent
                    text: (pdfFlickable.currentPdfPage + 1) + " / " + pdfFlickable.totalPdfPages
                    color: "#ffffff"; font.pixelSize: 12
                }
            }

            // Navigation buttons
            Rectangle {
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: prevPdfMa.containsMouse ? "#80000000" : "#60000000"
                visible: pdfFlickable.currentPdfPage > 0
                Text { anchors.centerIn: parent; text: "◀"; color: "#ffffff"; font.pixelSize: 16 }
                MouseArea {
                    id: prevPdfMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pdfFlickable.currentPdfPage > 0) {
                            pdfFlickable.currentPdfPage--
                            pdfFlickable.contentX = 0
                            pdfFlickable.contentY = 0
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: nextPdfMa.containsMouse ? "#80000000" : "#60000000"
                visible: pdfFlickable.currentPdfPage < pdfFlickable.totalPdfPages - 1
                Text { anchors.centerIn: parent; text: "▶"; color: "#ffffff"; font.pixelSize: 16 }
                MouseArea {
                    id: nextPdfMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (pdfFlickable.currentPdfPage < pdfFlickable.totalPdfPages - 1) {
                            pdfFlickable.currentPdfPage++
                            pdfFlickable.contentX = 0
                            pdfFlickable.contentY = 0
                        }
                    }
                }
            }

            // Click zones for page turning
            MouseArea {
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                width: parent.width * 0.25; z: 2
                cursorShape: Qt.PointingHandCursor
                onClicked: pdfPagePrev()
            }
            MouseArea {
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                width: parent.width * 0.25; z: 2
                cursorShape: Qt.PointingHandCursor
                onClicked: pdfPageNext()
            }

            Component.onCompleted: {
                if (root.bookFormat === "pdf" && backend && root.bookId) {
                    totalPdfPages = backend.getPdfPageCount(root.bookId)
                    updateScale()
                }
            }

            Connections {
                target: root
                function onBookIdChanged() {
                    if (root.bookFormat === "pdf" && backend && root.bookId) {
                        pdfFlickable.totalPdfPages = backend.getPdfPageCount(root.bookId)
                        pdfFlickable.currentPdfPage = 0
                        pdfFlickable.updateScale()
                    }
                }
                function onPdfFitModeChanged() {
                    pdfFlickable.updateScale()
                }
                function onPdfZoomChanged() {
                    pdfFlickable.updateScale()
                }
            }
        }

        // ═══════════════ SCROLL MODE (TXT/EPUB) ═══════════════
        Flickable {
            id: scrollFlickable
            visible: root.readingMode === "scroll" && root.bookFormat !== "pdf"
            anchors.fill: parent; clip: true
            contentWidth: width
            contentHeight: scrollTextEdit.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            // Highlight underlay canvas
            Canvas {
                id: scrollHighlightCanvas
                width: scrollTextEdit.width
                height: scrollTextEdit.implicitHeight
                z: 0

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    var anns = root._chapterAnnotations
                    for (var i = 0; i < anns.length; i++) {
                        var ann = anns[i]
                        var needle = ann.text
                        var dt = root.displayText
                        if (!needle || !dt) continue
                        // Find text position
                        var idx = dt.indexOf(needle, Math.max(0, ann.start - 20))
                        if (idx < 0) idx = dt.indexOf(needle)
                        if (idx < 0) continue

                        ctx.fillStyle = ann.color
                        ctx.globalAlpha = 0.28

                        var endPos = idx + needle.length
                        var startRect = scrollTextEdit.positionToRectangle(idx)
                        var endRect = scrollTextEdit.positionToRectangle(endPos)

                        if (Math.abs(startRect.y - endRect.y) < 2) {
                            // Single line
                            ctx.fillRect(startRect.x, startRect.y, endRect.x + endRect.width - startRect.x, startRect.height)
                        } else {
                            // First line
                            ctx.fillRect(startRect.x, startRect.y, scrollTextEdit.width - startRect.x - root.pageMargin, startRect.height)
                            // Middle lines
                            var lineH = startRect.height
                            for (var ly = startRect.y + lineH; ly < endRect.y - 1; ly += lineH) {
                                ctx.fillRect(root.pageMargin, ly, scrollTextEdit.width - 2 * root.pageMargin, lineH)
                            }
                            // Last line
                            ctx.fillRect(root.pageMargin, endRect.y, endRect.x + endRect.width - root.pageMargin, endRect.height)
                        }
                    }
                }
            }

            TextEdit {
                id: scrollTextEdit
                width: scrollFlickable.width
                text: root.displayText
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WordWrap
                color: root.textColor
                font.pixelSize: root.fontSize; font.family: root.fontFamily
                leftPadding:  root.pageMargin
                rightPadding: root.pageMargin
                topPadding: 30; bottomPadding: 60
                readOnly: true
                selectByMouse: root._annotationMode
                selectedTextColor: root.textColor
                selectionColor: "#50FFEB3B"
                z: 1

                onSelectedTextChanged: {
                    if (selectedText.length > 0 && root._annotationMode) {
                        root._selStart = selectionStart
                        root._selEnd = selectionEnd
                        root._selText = selectedText
                        // Position toolbar above selection
                        var rect = positionToRectangle(selectionStart)
                        var yPos = rect.y - scrollFlickable.contentY - 50
                        if (yPos < 10) yPos = rect.y - scrollFlickable.contentY + rect.height + 10
                        annotationToolbar.x = Math.max(20, Math.min(
                            rect.x - annotationToolbar.width / 2,
                            root.width - annotationToolbar.width - 20
                        ))
                        annotationToolbar.y = readingArea.y + Math.max(10, yPos)
                        annotationToolbar.visible = true
                    }
                }

                // Repaint highlights when text changes
                onTextChanged: root._refreshHighlightRects()
                onContentHeightChanged: root._refreshHighlightRects()
            }

            // Right-click context menu for adding comments to highlights
            MouseArea {
                anchors.fill: scrollTextEdit
                z: 2
                acceptedButtons: Qt.RightButton
                enabled: root._annotationMode
                onClicked: (mouse) => {
                    var textPos = scrollTextEdit.positionAt(mouse.x, mouse.y)
                    var hitAnn = root._findAnnotationAt(textPos)
                    if (hitAnn) {
                        root._commentTargetId = hitAnn.id
                        highlightContextMenu.x = mouse.x
                        highlightContextMenu.y = readingArea.y + mouse.y - scrollFlickable.contentY
                        highlightContextMenu._annId = hitAnn.id
                        highlightContextMenu._annText = hitAnn.text || ""
                        highlightContextMenu._annComment = hitAnn.comment || ""
                        highlightContextMenu.visible = true
                    }
                }
            }

            // Click to deselect
            MouseArea {
                anchors.fill: parent
                z: -1
                visible: root._annotationMode && annotationToolbar.visible
                onClicked: root._clearSelection()
            }
        }

        // ═══════════════ PAGINATED MODE (TXT/EPUB) ═══════════════
        Item {
            id: paginatedContainer
            visible: root.readingMode === "paginated" && root.bookFormat !== "pdf"
            anchors.fill: parent; clip: true

            property int _topMargin: 30
            property int _linesPerCol: 1
            property real _lineH: layoutHelper.lineCount > 0
                ? layoutHelper.contentHeight / layoutHelper.lineCount
                : root.fontSize * 1.6

            // Debounced margin for layout: avoids re-layout on every 5px drag tick
            property int _effectiveMargin: root.pageMargin
            Timer {
                id: marginDebounce
                interval: 80; repeat: false
                onTriggered: paginatedContainer._effectiveMargin = root.pageMargin
            }
            Connections {
                target: root
                function onPageMarginChanged() { marginDebounce.restart() }
            }

            // Hidden Text for layout measurement (identical properties to visible Text)
            Text {
                id: layoutHelper
                visible: false
                width: root.dualPage ? paginatedContainer.width / 2 - 2 * paginatedContainer._effectiveMargin
                                     : paginatedContainer.width - 2 * paginatedContainer._effectiveMargin
                text: root.displayText
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize; font.family: root.fontFamily
                lineHeight: 1.6
                onLineCountChanged: paginatedContainer._recalcPages()
                onContentHeightChanged: paginatedContainer._recalcPages()
            }

            function _recalcPages() {
                var lc = layoutHelper.lineCount
                if (lc <= 0) { root._totalPages = 1; return }
                var lineH = layoutHelper.contentHeight / lc
                var viewH = paginatedContainer.height - _topMargin - 30
                if (viewH <= 0 || lineH <= 0) { root._totalPages = 1; return }
                var lpc = Math.max(1, Math.floor(viewH / lineH))
                _linesPerCol = lpc
                var totalCols = Math.ceil(lc / lpc)
                var colsPerPage = root.dualPage ? 2 : 1
                root._totalPages = Math.max(1, Math.ceil(totalCols / colsPerPage))
                if (root._pageIndex >= root._totalPages) root._pageIndex = root._totalPages - 1
                if (root._displayPage >= root._totalPages) root._displayPage = root._totalPages - 1
            }

            onWidthChanged: _recalcPages()
            onHeightChanged: _recalcPages()
            Component.onCompleted: _recalcPages()

            // Slideable content wrapper
            Item {
                id: slideWrapper
                anchors.fill: parent
                x: root._slideOffset

                Row {
                    anchors.fill: parent; spacing: 0

                    Repeater {
                        model: root.dualPage ? 2 : 1

                        Item {
                            width: root.dualPage ? paginatedContainer.width / 2 : paginatedContainer.width
                            height: paginatedContainer.height

                            // Separator line between dual pages
                            Rectangle {
                                visible: root.dualPage && index === 1
                                anchors.left: parent.left; anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1; color: _panelBorder
                            }

                            // Inner clip: exactly fits whole lines, no partial cut
                            Item {
                                width: parent.width
                                y: paginatedContainer._topMargin
                                height: paginatedContainer._linesPerCol * paginatedContainer._lineH
                                clip: true

                                Text {
                                    width: parent.width
                                    text: root.displayText
                                    textFormat: Text.PlainText
                                    wrapMode: Text.WordWrap
                                    color: root.textColor
                                    font.pixelSize: root.fontSize; font.family: root.fontFamily
                                    lineHeight: 1.6
                                    leftPadding: root.pageMargin
                                    rightPadding: root.pageMargin
                                    y: {
                                        var globalCol = root._displayPage * (root.dualPage ? 2 : 1) + index
                                        return -globalCol * paginatedContainer._linesPerCol * paginatedContainer._lineH
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Page indicator
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                text: (root._pageIndex + 1) + " / " + root._totalPages
                color: root.textColor; opacity: 0.35; font.pixelSize: 12
            }

            // Click zones for page turning
            MouseArea {
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                width: parent.width * 0.3; z: 5; cursorShape: Qt.PointingHandCursor
                onClicked: root.pagePrev()
            }
            MouseArea {
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                width: parent.width * 0.3; z: 5; cursorShape: Qt.PointingHandCursor
                onClicked: root.pageNext()
            }
        }

        // ═══════════════ CENTER TAP ZONE (toggle progress bar) ═══════════════
        Item {
            id: centerTapZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.bottom: parent.bottom
            width: parent.width * 0.4
            z: 10
            TapHandler {
                onTapped: root._progressBarVisible = !root._progressBarVisible
            }
        }
    }

    // ── Annotation Toolbar (floating, appears on text selection) ──
    Rectangle {
        id: annotationToolbar
        visible: false; z: 100
        width: annToolRow.implicitWidth + 20; height: 42; radius: 21
        color: _isDark ? "#e62a2a3e" : "#e8eeecea"
        border.color: _isDark ? "#3a3a4e" : "#c8c5c0"

        // Shadow
        Rectangle {
            anchors.fill: parent; anchors.margins: -2
            radius: parent.radius + 2; z: -1
            color: "transparent"; border.color: "#18000000"; border.width: 3
        }

        RowLayout {
            id: annToolRow
            anchors.centerIn: parent; spacing: 6

            // Highlight color buttons
            Repeater {
                model: [
                    { color: "#FFEB3B", name: "黄" },
                    { color: "#8BC34A", name: "绿" },
                    { color: "#42A5F5", name: "蓝" },
                    { color: "#FF7043", name: "红" }
                ]

                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: modelData.color; opacity: 0.85
                    border.color: annColorMa.containsMouse ? root.textColor : "transparent"
                    border.width: 1.5

                    MouseArea {
                        id: annColorMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root._createHighlight(modelData.color)
                    }
                }
            }

            // Divider
            Rectangle { width: 1; height: 20; color: _panelBorder }

            // Copy button
            Rectangle {
                width: 28; height: 28; radius: 14
                color: annCopyMa.containsMouse ? _hoverBg : "transparent"
                Text { anchors.centerIn: parent; text: "📋"; font.pixelSize: 14 }
                MouseArea {
                    id: annCopyMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root._selText) {
                            scrollTextEdit.copy()
                        }
                        root._clearSelection()
                    }
                }
            }
        }
    }

    // ── Highlight Right-Click Context Menu ──
    MouseArea {
        anchors.fill: parent
        visible: highlightContextMenu.visible; z: 95
        onClicked: highlightContextMenu.visible = false
    }

    Rectangle {
        id: highlightContextMenu
        visible: false; z: 100
        width: 140; height: hCtxCol.implicitHeight + 12
        radius: 10; color: _panelBg; border.color: _panelBorder

        property string _annId: ""
        property string _annText: ""
        property string _annComment: ""

        Column {
            id: hCtxCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 6; spacing: 2

            Rectangle {
                width: hCtxCol.width; height: 34; radius: 6
                color: addComMa.containsMouse ? _hoverBg : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: lang === "zh" ? (highlightContextMenu._annComment ? "编辑评论" : "添加评论") : (highlightContextMenu._annComment ? "Edit Comment" : "Add Comment")
                    color: root.textColor; opacity: 0.7; font.pixelSize: 13
                }
                MouseArea {
                    id: addComMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root._commentTargetId = highlightContextMenu._annId
                        commentTextInput.text = highlightContextMenu._annComment
                        commentInputOverlay.visible = true
                        commentTextInput.forceActiveFocus()
                        highlightContextMenu.visible = false
                    }
                }
            }

            Rectangle {
                width: hCtxCol.width - 12; height: 1
                anchors.horizontalCenter: parent.horizontalCenter; color: _panelBorder
            }

            Rectangle {
                width: hCtxCol.width; height: 34; radius: 6
                color: delHighMa.containsMouse ? "#30c05050" : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: lang === "zh" ? "删除划线" : "Delete Highlight"
                    color: "#c05050"; font.pixelSize: 13
                }
                MouseArea {
                    id: delHighMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root._deleteAnnotation(highlightContextMenu._annId)
                        highlightContextMenu.visible = false
                    }
                }
            }
        }
    }

    // ── Comment Input Overlay ──
    Rectangle {
        id: commentInputOverlay
        visible: false; z: 200
        anchors.fill: parent
        color: "#66282828"

        MouseArea { anchors.fill: parent; onClicked: commentInputOverlay.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: 380; height: 160; radius: 16
            color: _isDark ? "#2a2a3e" : "#eeecea"
            border.color: _isDark ? "#3a3a4e" : "#c8c5c0"

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24; spacing: 14

                Text {
                    text: lang === "zh" ? "添加评论" : "Add Comment"
                    color: root.textColor; font.pixelSize: 16; font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 10
                    color: _isDark ? "#333350" : "#15a09888"
                    border.color: _isDark ? "#4a4a6e" : "#30a09888"

                    TextInput {
                        id: commentTextInput
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        color: root.textColor; font.pixelSize: 14
                        clip: true; selectByMouse: true
                        onAccepted: root._commitComment()

                        Text {
                            visible: !commentTextInput.text
                            anchors.verticalCenter: parent.verticalCenter
                            text: lang === "zh" ? "写下你的想法..." : "Write your thoughts..."
                            color: _dimText; font.pixelSize: 13
                        }
                    }
                }

                RowLayout {
                    spacing: 12; Layout.alignment: Qt.AlignRight

                    Rectangle {
                        width: 60; height: 32; radius: 8
                        color: cancelCommentMa.containsMouse ? _hoverBg : "transparent"
                        border.color: _panelBorder
                        Text { anchors.centerIn: parent; text: lang === "zh" ? "取消" : "Cancel"; color: _dimText; font.pixelSize: 13 }
                        MouseArea {
                            id: cancelCommentMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: commentInputOverlay.visible = false
                        }
                    }

                    Rectangle {
                        width: 60; height: 32; radius: 8
                        color: confirmCommentMa.containsMouse ? (_isDark ? "#4a4a6e" : "#d0ccc4") : (_isDark ? "#3a3a5e" : "#e0dcd4")
                        Text { anchors.centerIn: parent; text: lang === "zh" ? "保存" : "Save"; color: root.textColor; font.pixelSize: 13 }
                        MouseArea {
                            id: confirmCommentMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root._commitComment()
                        }
                    }
                }
            }
        }
    }

    // ── Notes Panel (right side) ──
    // Sorted by position (start index), each highlight in a rounded card
    Rectangle {
        id: notesPanel
        visible: root._notesVisible; z: 20
        anchors.top: topBar.bottom
        anchors.right: parent.right; anchors.rightMargin: 20
        width: 340; height: Math.min(root._annotations.length * 100 + 70, root.height * 0.8)
        radius: 12; color: _panelBg; border.color: _panelBorder

        MouseArea { anchors.fill: parent; z: 0 }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 14; spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Layout.bottomMargin: 10

                Text {
                    text: lang === "zh" ? "笔记 · " + root._annotations.length : "Notes · " + root._annotations.length
                    color: root.textColor; opacity: 0.8
                    font.pixelSize: 15; font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Text {
                    text: "✕"; color: _dimText; font.pixelSize: 14
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._notesVisible = false
                    }
                }
            }

            // Sorted annotations list
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 8
                model: {
                    // Sort annotations by start position
                    var sorted = root._annotations.slice()
                    sorted.sort(function(a, b) {
                        var ca = a.chapter_index || 0
                        var cb = b.chapter_index || 0
                        if (ca !== cb) return ca - cb
                        return (a.start || 0) - (b.start || 0)
                    })
                    return sorted
                }

                delegate: Rectangle {
                    width: ListView.view ? ListView.view.width : 300
                    height: noteCardCol.implicitHeight + 20
                    radius: 10
                    color: _isDark ? "#22ffffff" : "#10908880"
                    border.color: _isDark ? "#28ffffff" : "#18908880"
                    border.width: 0.5

                    property var ann: modelData

                    ColumnLayout {
                        id: noteCardCol
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 6

                        // Highlighted text with color bar
                        RowLayout {
                            spacing: 8; Layout.fillWidth: true

                            Rectangle {
                                width: 3; height: Math.max(noteTextLabel.implicitHeight, 20); radius: 1.5
                                color: ann ? ann.color : "#FFEB3B"
                                Layout.alignment: Qt.AlignTop
                            }

                            Text {
                                id: noteTextLabel
                                text: ann ? ann.text : ""
                                color: root.textColor; opacity: 0.85
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Comment (if any) - small light text below
                        Text {
                            visible: ann && ann.comment && ann.comment.length > 0
                            text: ann ? (ann.comment || "") : ""
                            color: root.textColor; opacity: 0.45
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: 11
                        }

                        // Bottom row: chapter info + actions
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Layout.leftMargin: 11

                            Text {
                                text: {
                                    if (!ann) return ""
                                    if (ann.chapter_index >= 0 && ann.chapter_index < chapterModel.count)
                                        return chapterModel.get(ann.chapter_index).title
                                    return ""
                                }
                                color: _dimText; font.pixelSize: 9
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }

                            // Edit comment icon
                            Text {
                                text: "✎"; font.pixelSize: 11; color: _dimText; opacity: 0.6
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (ann) {
                                            root._commentTargetId = ann.id
                                            commentTextInput.text = ann.comment || ""
                                            commentInputOverlay.visible = true
                                            commentTextInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }

                            // Delete icon
                            Text {
                                text: "✕"; font.pixelSize: 10; color: _dimText; opacity: 0.5
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (ann) root._deleteAnnotation(ann.id)
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: noteItemMa; anchors.fill: parent; z: -1
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Navigate to the annotation's chapter
                            if (ann && ann.chapter_index >= 0 && ann.chapter_index !== currentChapter) {
                                loadChapterByIndex(ann.chapter_index)
                            }
                            root._notesVisible = false
                        }
                    }
                }
            }

            // Empty state
            Text {
                visible: root._annotations.length === 0
                text: lang === "zh" ? "暂无笔记\n开启「划线」模式后选择文字即可标记" : "No notes yet\nEnable \"Mark\" mode and select text"
                color: _dimText; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
            }
        }
    }

    // ── Reading Progress Bar (floating pill) ───────────────────
    Item {
        id: progressBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width * 0.65, 600)
        height: 52; z: 25

        visible: progressPill.opacity > 0

        property real progress: {
            if (root.bookFormat === "pdf") {
                if (pdfFlickable.totalPdfPages <= 0) return 0.0
                return (pdfFlickable.currentPdfPage + 1) / pdfFlickable.totalPdfPages
            }
            if (root._isEpubLike && root._epubTotalContentChapters > 0) {
                var intra = 0.0
                if (root.readingMode === "paginated") {
                    intra = root._totalPages > 1 ? root._pageIndex / (root._totalPages - 1) : 1.0
                } else {
                    var maxY = scrollFlickable.contentHeight - scrollFlickable.height
                    intra = maxY > 0 ? scrollFlickable.contentY / maxY : 1.0
                }
                return (root._epubCurrentContentOrdinal + intra) / root._epubTotalContentChapters
            }
            if (root.readingMode === "paginated") {
                if (root._totalPages <= 1) return 1.0
                return (root._pageIndex + 1) / root._totalPages
            }
            if (scrollFlickable.contentHeight <= scrollFlickable.height) return 1.0
            return (scrollFlickable.contentY + scrollFlickable.height) / scrollFlickable.contentHeight
        }

        // Shadow
        Rectangle {
            anchors.fill: progressPill
            anchors.margins: -2
            radius: progressPill.radius + 2
            color: "#00000000"
            border.color: "#18000000"
            border.width: 4
            opacity: progressPill.opacity
        }

        // Main pill
        Rectangle {
            id: progressPill
            anchors.fill: parent
            radius: 26
            color: _isDark ? "#e62a2a3e" : "#e0eeecea"
            border.color: _isDark ? "#3a3a4e" : "#40c8c0b0"
            border.width: 0.5

            opacity: root._progressBarVisible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }

            scale: root._progressBarVisible ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            transform: Translate {
                y: root._progressBarVisible ? 0 : 20
                Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }

            // Inner highlight
            Rectangle {
                anchors.fill: parent; anchors.margins: 1
                radius: parent.radius - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#15ffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 14

                Text {
                    text: Math.round(progressBar.progress * 100) + "%"
                    color: root.textColor; opacity: 0.6
                    font.pixelSize: 12; font.weight: Font.DemiBold
                    Layout.preferredWidth: 36
                }

                Item {
                    id: trackArea
                    Layout.fillWidth: true; height: 32

                    // Track background
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: _isDark ? "#444466" : "#d8d4ce"

                        // Filled track
                        Rectangle {
                            width: parent.width * progressBar.progress
                            height: parent.height; radius: 2
                            color: _isDark ? "#8888bb" : "#a09888"
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                    }

                    // Chapter tick marks
                    Repeater {
                        model: root._chapterMarkers.length

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: root._chapterMarkers[index].ratio * trackArea.width - 1
                            width: 2; height: 10; radius: 1
                            color: _isDark ? "#6666aa" : "#b0a890"
                            opacity: 0.7

                            // Hover area for tooltip
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    chapterTooltip.text = root._chapterMarkers[index].title
                                    chapterTooltip.x = parent.x + parent.width / 2 - chapterTooltip.width / 2
                                    chapterTooltip.visible = true
                                    progressAutoHide.restart()
                                }
                                onExited: chapterTooltip.visible = false
                                onClicked: {
                                    trackSeekMa._seekWithSnap(parent.x + 1)
                                }
                            }
                        }
                    }

                    // Chapter tooltip
                    Rectangle {
                        id: chapterTooltip
                        visible: false; z: 10
                        y: -height - 8
                        width: tooltipText.implicitWidth + 16
                        height: 26; radius: 6
                        color: _isDark ? "#dd2a2a3e" : "#ddeeecea"
                        border.color: _isDark ? "#3a3a4e" : "#c8c5c0"

                        property alias text: tooltipText.text

                        Text {
                            id: tooltipText
                            anchors.centerIn: parent
                            color: root.textColor; opacity: 0.8
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Handle
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * progressBar.progress - 7
                        width: 14; height: 14; radius: 7
                        color: _isDark ? "#aaaadd" : "#7a7060"
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    // Seek mouse area with magnetic snap
                    MouseArea {
                        id: trackSeekMa
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor

                        property string _hoveredChapter: ""

                        function _seekWithSnap(mx) {
                            var r = Math.max(0, Math.min(1, mx / trackArea.width))
                            // Magnetic snap to nearby chapter markers
                            var snapThresholdPx = 12
                            var snapThreshold = trackArea.width > 0 ? snapThresholdPx / trackArea.width : 0
                            var markers = root._chapterMarkers
                            var snapped = false
                            for (var i = 0; i < markers.length; i++) {
                                if (Math.abs(r - markers[i].ratio) < snapThreshold) {
                                    r = markers[i].ratio
                                    chapterTooltip.text = markers[i].title
                                    chapterTooltip.x = markers[i].ratio * trackArea.width - chapterTooltip.width / 2
                                    chapterTooltip.visible = true
                                    snapped = true
                                    break
                                }
                            }
                            if (!snapped) chapterTooltip.visible = false
                            progressAutoHide.restart()

                            if (root.bookFormat === "pdf") {
                                var pg = Math.round(r * (pdfFlickable.totalPdfPages - 1))
                                root.setPdfPage(pg)
                            } else if (root._isEpubLike && root._epubTotalContentChapters > 0) {
                                root._epubSeekToGlobalRatio(r)
                            } else if (root.readingMode === "paginated") {
                                var p = Math.round(r * (root._totalPages - 1))
                                root.jumpToPage(p)
                            } else {
                                scrollFlickable.contentY = r * (scrollFlickable.contentHeight - scrollFlickable.height)
                            }
                        }
                        onClicked: function(mouse) { _seekWithSnap(mouse.x) }
                        onPositionChanged: function(mouse) {
                            if (pressed) _seekWithSnap(mouse.x)
                        }
                        onReleased: chapterTooltip.visible = false
                    }
                }

                Text {
                    text: {
                        if (root.bookFormat === "pdf")
                            return (pdfFlickable.currentPdfPage + 1) + "/" + pdfFlickable.totalPdfPages
                        if (root._isEpubLike && root._epubTotalContentChapters > 0) {
                            // Show "chapter ordinal / total chapters" for epub/mobi
                            return (root._epubCurrentContentOrdinal + 1) + "/" + root._epubTotalContentChapters
                        }
                        if (root.readingMode === "paginated")
                            return (root._pageIndex + 1) + "/" + root._totalPages
                        return ""
                    }
                    visible: text !== ""
                    color: root.textColor; opacity: 0.5
                    font.pixelSize: 11
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
