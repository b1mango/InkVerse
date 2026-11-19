import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components"
import "../theme"

/*  ReaderPage – 阅读页：TXT/EPUB/MOBI 分页或滚动，PDF 整页渲染
    阅读参数写回全局偏好；每本书的章节与页内位置随翻页保存，重新打开时恢复。  */
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
    signal preferencesChanged(var patch)

    function zh(a, b) { return lang === "zh" ? a : b }

    // ── Reading session tracking ────────────────────────────────
    property string _storageError: ""
    property string _textError: ""
    property string _textEncoding: "auto"
    readonly property var _textEncodings: ["auto", "utf-8-sig", "gb18030", "big5", "utf-16", "utf-16-le", "utf-16-be"]

    function _startSession() {
        _storageError = ""
        backend.startReadingSession(bookId)
    }

    function _endSession() {
        return backend.endReadingSession()
    }

    function loadTextBook() {
        var result = backend.readTextBook(bookId)
        _textEncoding = result.encoding || "auto"
        _textError = result.error || ""
        bookText = result.text || ""
        jumpToPage(0)
    }

    function changeTextEncoding(encoding) {
        var result = backend.changeTextEncoding(bookId, encoding)
        _textError = result.error || ""
        if (!_textError) {
            _textEncoding = result.encoding
            bookText = result.text
            jumpToPage(0)
        }
        _textEncodingChanged()
    }

    Connections {
        target: backend
        function onStorageError(message) { root._storageError = message }
    }

    // ── Opening a book and remembering the place ────────────────
    property var _pendingRestore: null

    function open(book) {
        bookFormat = book.format || "txt"   // before the id, so no view renders the new id as the old format
        bookId = book.id || ""
        bookTitle = book.title || "Untitled"
        _annotationMode = false
        _notesVisible = false
        tocPanel.visible = false
        settingsPanel.visible = false
        _clearSelection()
        _pendingRestore = backend.getReadingProgress(bookId) || null
        if (bookFormat === "txt") {
            loadTextBook()
            loadChapters()
        } else {
            bookText = ""
            loadChapters()
        }
        _restoreChapter()
        _startSession()
        root.forceActiveFocus()
    }

    function _restoreChapter() {
        var pr = _pendingRestore
        if (!pr || pr.chapter === undefined) { _pendingRestore = null; return }
        if (bookFormat === "pdf") {
            setPdfPage(pr.chapter)
            _pendingRestore = null
            return
        }
        if (_isChapterFormat && pr.chapter >= 0 && pr.chapter < chapterModel.count && pr.chapter !== currentChapter)
            loadChapterByIndex(pr.chapter)
        restoreTimer.restart()   // the page count settles after layout
    }

    Timer {
        id: restoreTimer
        interval: 60
        onTriggered: {
            var pr = root._pendingRestore
            root._pendingRestore = null
            if (!pr) return
            var r = Math.max(0, Math.min(1, pr.ratio || 0))
            if (root.readingMode === "paginated") root.jumpToPage(Math.round(r * Math.max(0, root._totalPages - 1)))
            else scrollFlickable.contentY = r * Math.max(0, scrollFlickable.contentHeight - scrollFlickable.height)
        }
    }

    function _positionRatio() {
        if (readingMode === "paginated") return _totalPages > 1 ? _pageIndex / (_totalPages - 1) : 0
        var maxY = scrollFlickable.contentHeight - scrollFlickable.height
        return maxY > 0 ? scrollFlickable.contentY / maxY : 0
    }

    function saveProgress() {
        if (!bookId || _pendingRestore || !backend) return
        if (bookFormat === "pdf") backend.saveReadingProgress(bookId, pdfFlickable.currentPdfPage, 0)
        else backend.saveReadingProgress(bookId, currentChapter, _positionRatio())
    }

    Timer { id: progressSaveTimer; interval: 800; onTriggered: root.saveProgress() }
    on_PageIndexChanged: progressSaveTimer.restart()
    onCurrentChapterChanged: progressSaveTimer.restart()

    function goBack() {
        progressSaveTimer.stop()
        saveProgress()
        if (_endSession()) backRequested()
    }

    // ── Reading preferences (shared by every book) ──────────────
    property string bgKey: "paper"
    property int fontSize: 18
    property string fontFamily: "LXGW WenKai"
    property int pageMargin: 96
    property bool dualPage: false
    property string readingMode: "paginated"  // "scroll" or "paginated"
    property int paragraphSpacing: 0
    property string pdfFitMode: "fit_page"
    property real pdfZoom: 1.0
    property bool _progressBarVisible: false

    readonly property var bgPresets: [
        { key: "paper",  name: zh("素纸", "Paper"), bg: "#FAFAF7", fg: "#1F2322" },
        { key: "sepia",  name: zh("暖褐", "Sepia"), bg: "#F3EBDA", fg: "#3B3125" },
        { key: "mist",   name: zh("烟灰", "Mist"),  bg: "#ECEFED", fg: "#222826" },
        { key: "bamboo", name: zh("竹青", "Bamboo"), bg: "#E3EDE8", fg: "#1F2E29" },
        { key: "night",  name: zh("夜间", "Night"), bg: "#121414", fg: "#C8D0CC" }
    ]
    function _preset(key) {
        for (var i = 0; i < bgPresets.length; i++) if (bgPresets[i].key === key) return bgPresets[i]
        return bgPresets[0]
    }
    readonly property string bgColor: _preset(bgKey).bg
    readonly property string textColor: _preset(bgKey).fg
    readonly property bool _isDark: bgKey === "night"
    readonly property QtObject _palette: _isDark ? Theme.night : Theme.light

    function applyPreferences(r) {
        if (!r) return
        if (r.background) bgKey = r.background
        if (r.font_family) fontFamily = r.font_family
        if (r.font_size) fontSize = r.font_size
        if (r.page_margin) pageMargin = r.page_margin
        if (r.paragraph_spacing !== undefined) paragraphSpacing = r.paragraph_spacing
        if (r.reading_mode) readingMode = r.reading_mode
        if (r.dual_page !== undefined) dualPage = r.dual_page
        if (r.pdf_fit_mode) pdfFitMode = r.pdf_fit_mode
    }

    function setPreference(key, value) {
        var ratio = _positionRatio()
        _captureAnchor()
        if (key === "background") bgKey = value
        else if (key === "font_family") fontFamily = value
        else if (key === "font_size") fontSize = value
        else if (key === "page_margin") pageMargin = value
        else if (key === "paragraph_spacing") paragraphSpacing = value
        else if (key === "reading_mode") readingMode = value
        else if (key === "dual_page") dualPage = value
        else if (key === "pdf_fit_mode") { pdfFitMode = value; pdfZoom = 1.0 }
        var patch = {}
        patch[key] = value
        root.preferencesChanged(patch)
        // Keep the reader on the same passage when the layout changes
        if (bookFormat === "pdf" || key === "background" || key === "pdf_fit_mode") return
        if (key === "paragraph_spacing") {
            // Spacing rewrites the text, so character offsets move; fall back to the relative position
            _pendingRestore = { chapter: currentChapter, ratio: ratio }
            restoreTimer.restart()
        } else {
            _reflow()
        }
    }

    // ── Keeping the passage in place across re-layout ───────────
    // The first character on screen is tracked while reading; when the text column changes width
    // (panels docking, window resize, font or mode change) the view returns to the page holding it.
    property int _anchorChar: 0
    property bool _reflowing: false

    function _captureAnchor() {
        if (_reflowing || bookFormat === "pdf" || _pendingRestore) return
        if (readingMode === "paginated")
            _anchorChar = paginatedContainer.posAt(_displayPage * paginatedContainer._colsPerPage, 0, 0)
        else
            _anchorChar = scrollTextEdit.positionAt(pageMargin + 1, scrollFlickable.contentY + scrollTextEdit.topPadding + 2)
    }

    function _reflow() {
        if (bookFormat === "pdf" || _pendingRestore) return
        _reflowing = true
        reflowTimer.restart()
    }

    Timer {
        id: reflowTimer
        interval: 60
        onTriggered: {
            if (root.readingMode === "paginated") {
                root.jumpToPage(paginatedContainer.pageOf(root._anchorChar))
            } else {
                var r = scrollTextEdit.positionToRectangle(root._anchorChar)
                var maxY = Math.max(0, scrollFlickable.contentHeight - scrollFlickable.height)
                scrollFlickable.contentY = Math.max(0, Math.min(maxY, r.y - scrollTextEdit.topPadding))
            }
            root._reflowing = false
            root._refreshHighlightRects()
        }
    }
    on_DisplayPageChanged: Qt.callLater(_captureAnchor)

    // ── Annotations / Highlights ────────────────────────────────
    property bool _annotationMode: false
    property var _annotations: []            // all for current book
    property var _chapterAnnotations: []     // filtered for current chapter
    property bool _notesVisible: false
    property int _selStart: -1
    property int _selEnd: -1
    property string _selText: ""
    property string _commentTargetId: ""
    property string _flashAnnotationId: ""
    property int _highlightRevision: 0   // bumps whenever highlights or the selection need repainting

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
            bookId, root._commentTargetId, commentField.text.trim()
        ) || []
        _updateChapterAnnotations()
        root._commentTargetId = ""
        commentDialog.close()
    }

    function editComment(ann) {
        if (!ann) return
        root._commentTargetId = ann.id
        commentField.text = ann.comment || ""
        commentDialog.open()
    }

    function _clearSelection() {
        _selStart = -1; _selEnd = -1; _selText = ""
        annotationToolbar.visible = false
        if (scrollTextEdit.selectedText) scrollTextEdit.deselect()
        _refreshHighlightRects()
    }

    function _copySelection() {
        if (!_selText) return
        if (readingMode === "scroll") scrollTextEdit.copy()
        else paginatedContainer.copyRange(_selStart, _selEnd)
    }

    // Show the colour toolbar next to a point given in root coordinates
    function _showAnnotationToolbar(px, py) {
        annotationToolbar.x = Math.max(20, Math.min(px - annotationToolbar.width / 2, root.width - annotationToolbar.width - 20))
        var y = py - annotationToolbar.height - 14
        annotationToolbar.y = y < readingArea.y + 8 ? py + 24 : y
        annotationToolbar.visible = true
    }

    function _openHighlightMenu(ann) {
        highlightMenu.annId = ann.id
        highlightMenu.annComment = ann.comment || ""
        highlightMenu.popup()
    }

    function _deleteAnnotation(annId) {
        root._annotations = backend.deleteAnnotation(bookId, annId) || []
        _updateChapterAnnotations()
    }

    function _refreshHighlightRects() {
        _highlightRevision++
        Qt.callLater(function() {
            if (scrollHighlightCanvas.available) scrollHighlightCanvas.requestPaint()
        })
    }

    function _annotationOffset(ann) {
        var dt = root.displayText
        if (!ann || !ann.text || !dt) return -1
        var idx = dt.indexOf(ann.text, Math.max(0, (ann.start || 0) - 20))
        return idx >= 0 ? idx : dt.indexOf(ann.text)
    }

    // Find annotation at a given text position (for right-click context menu)
    function _findAnnotationAt(pos) {
        for (var i = 0; i < root._chapterAnnotations.length; i++) {
            var ann = root._chapterAnnotations[i]
            var idx = _annotationOffset(ann)
            if (idx >= 0 && pos >= idx && pos < idx + ann.text.length) return ann
        }
        return null
    }

    // Highlighting works in both page and scroll mode (not on PDF page images)
    function toggleAnnotationMode() {
        if (bookFormat === "pdf") return
        _annotationMode = !_annotationMode
        if (!_annotationMode) _clearSelection()
    }

    // Open the note's chapter and bring its passage into view
    function jumpToAnnotation(ann) {
        if (!ann) return
        if (_isChapterFormat && ann.chapter_index >= 0 && ann.chapter_index !== currentChapter)
            loadChapterByIndex(ann.chapter_index)
        _flashAnnotationId = ann.id
        Qt.callLater(function() { annotationJumpTimer.ann = ann; annotationJumpTimer.restart() })
    }

    Timer {
        id: annotationJumpTimer
        property var ann: null
        interval: 60
        onTriggered: {
            var idx = root._annotationOffset(ann)
            if (idx < 0) return
            if (root.readingMode === "scroll") {
                var r = scrollTextEdit.positionToRectangle(idx)
                var maxY = Math.max(0, scrollFlickable.contentHeight - scrollFlickable.height)
                scrollFlickable.contentY = Math.max(0, Math.min(maxY, r.y - scrollFlickable.height * 0.3))
            } else {
                root.jumpToPage(paginatedContainer.pageOf(idx))
            }
            root._refreshHighlightRects()
            flashTimer.restart()
        }
    }
    Timer { id: flashTimer; interval: 1600; onTriggered: { root._flashAnnotationId = ""; root._refreshHighlightRects() } }

    function chapterTitle(index) {
        if (index >= 0 && index < chapterModel.count) return chapterModel.get(index).title
        return ""
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
    Keys.onSpacePressed: {
        if (bookFormat === "pdf") pdfPageNext()
        else if (readingMode === "paginated") pageNext()
        else scrollFlickable.contentY = Math.min(Math.max(0, scrollFlickable.contentHeight - scrollFlickable.height),
                                                 scrollFlickable.contentY + scrollFlickable.height * 0.9)
    }
    // Esc closes the innermost layer first, then leaves the book
    Keys.onEscapePressed: {
        if (tocPanel.visible || settingsPanel.visible || root._notesVisible) {
            tocPanel.visible = false; settingsPanel.visible = false; root._notesVisible = false
        } else if (annotationToolbar.visible) {
            root._clearSelection()
        } else {
            root.goBack()
        }
    }

    // ── Top Bar ─────────────────────────────────────────────────
    Rectangle {
        id: topBar
        width: parent.width
        height: 52
        color: root.bgColor
        z: 10

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root._palette.border; opacity: 0.6 }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 2

            AppButton {
                text: zh("书库", "Library")
                iconName: "arrow-left"
                variant: "ghost"
                compact: true
                onClicked: root.goBack()
                Accessible.name: zh("返回书库", "Back to library")
            }
            ReaderIcon {
                visible: _isChapterFormat && chapterModel.count > 1
                iconName: "list"
                label: zh("目录", "Contents")
                active: tocPanel.visible
                onClicked: { settingsPanel.visible = false; root._notesVisible = false; tocPanel.visible = !tocPanel.visible }
            }

            Item { Layout.fillWidth: true }

            ReaderIcon {
                visible: _isChapterFormat && chapterModel.count > 1
                iconName: "chevron-left"
                label: zh("上一章", "Previous chapter")
                enabled: currentChapter > 0
                onClicked: gotoPrevChapter()
            }
            Text {
                Layout.maximumWidth: Math.max(160, root.width - 560)
                text: {
                    if (_isChapterFormat && currentChapter >= 0 && currentChapter < chapterModel.count)
                        return chapterModel.get(currentChapter).title
                    return root.bookTitle
                }
                color: root.textColor
                opacity: 0.75
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.weight: Font.Medium
                elide: Text.ElideMiddle
            }
            ReaderIcon {
                visible: _isChapterFormat && chapterModel.count > 1
                iconName: "chevron-right"
                label: zh("下一章", "Next chapter")
                enabled: currentChapter < chapterModel.count - 1
                onClicked: gotoNextChapter()
            }

            Item { Layout.fillWidth: true }

            ReaderIcon {
                visible: root.bookFormat !== "pdf"
                iconName: "highlighter"
                label: root._annotationMode ? zh("结束划线", "Stop highlighting") : zh("划线", "Highlight")
                active: root._annotationMode
                onClicked: root.toggleAnnotationMode()
            }
            ReaderIcon {
                id: notesButton
                iconName: "notebook"
                label: zh("笔记", "Notes")
                active: root._notesVisible
                onClicked: { tocPanel.visible = false; settingsPanel.visible = false; root._notesVisible = !root._notesVisible }
                Rectangle {
                    visible: root._annotations.length > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: -2
                    anchors.topMargin: -1
                    width: Math.max(15, countText.implicitWidth + 7)
                    height: 15
                    radius: 7.5
                    border.color: root.bgColor
                    border.width: 1.5
                    color: root._palette.accent
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root._annotations.length > 99 ? "99+" : root._annotations.length
                        color: root._palette.textOnAccent
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.features: Theme.tabular
                    }
                }
            }
            ReaderIcon {
                iconName: "type"
                label: zh("阅读设置", "Reading settings")
                active: settingsPanel.visible
                onClicked: { tocPanel.visible = false; root._notesVisible = false; settingsPanel.visible = !settingsPanel.visible }
            }
        }
    }

    component ReaderIcon: IconButton {
        tone: root._palette
        iconColor: active ? root._palette.accentText : root.textColor
        opacity: enabled ? (active || hovered ? 1 : 0.7) : 0.3
    }

    // ── TOC Panel (left side) ───────────────────────────────────
    Rectangle {
        id: tocPanel
        objectName: "readerToc"
        visible: false; z: 20
        anchors.top: topBar.bottom
        anchors.topMargin: 8
        anchors.left: parent.left; anchors.leftMargin: 12
        width: 300
        height: Math.min(chapterModel.count * 36 + 20, root.height * 0.75)
        radius: Theme.radiusL
        color: root._palette.surface
        border.color: root._palette.border
        onVisibleChanged: if (visible) { tocList.positionViewAtIndex(Math.max(0, currentChapter), ListView.Center); tocList.forceActiveFocus() }

        MouseArea { anchors.fill: parent }

        ListView {
            id: tocList
            anchors.fill: parent
            anchors.margins: 8
            model: chapterModel
            clip: true
            currentIndex: currentChapter
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            Accessible.name: zh("目录", "Contents")
            Keys.onReturnPressed: tocActivate(currentIndex)
            Keys.onEnterPressed: tocActivate(currentIndex)

            function tocActivate(i) {
                var ch = chapterModel.get(i)
                if (!ch) return
                if (ch.isSection && loadFirstChildFromSection(i)) { tocPanel.visible = false; root.forceActiveFocus(); return }
                if (ch.pageIndex >= 0) { loadChapterByIndex(i); tocPanel.visible = false; root.forceActiveFocus() }
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: model.isSection ? 38 : 34
                radius: Theme.radiusS
                readonly property bool selected: index === currentChapter
                color: model.isSection ? "transparent"
                    : selected ? root._palette.accentSoft
                    : (tocItemMa.containsMouse || (tocList.activeFocus && ListView.isCurrentItem)) ? root._palette.surfaceHover : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: model.isSection ? 10 : 22; anchors.rightMargin: 12
                    text: model.title
                    color: model.isSection ? root._palette.textTertiary : (parent.selected ? root._palette.accentText : root._palette.text)
                    font.family: Theme.uiFont
                    font.pixelSize: model.isSection ? Theme.fontCaption : Theme.fontSmall
                    font.weight: model.isSection || parent.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: tocItemMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: (model.pageIndex >= 0 || model.isSection) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: tocList.tocActivate(index)
                }
            }
        }
    }

    // ── Settings Panel (right side) ─────────────────────────────
    ReaderSettingsPanel {
        id: settingsPanel
        objectName: "readerSettings"
        reader: root
        visible: false; z: 20
        anchors.top: topBar.bottom
        anchors.topMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 12
        height: Math.min(contentHeight, root.height - topBar.height - 24)
    }

    // ── Notes Panel (right side) ────────────────────────────────
    NotesPanel {
        id: notesPanel
        reader: root
        visible: root._notesVisible; z: 20
        anchors.top: topBar.bottom
        anchors.topMargin: 8
        anchors.right: parent.right; anchors.rightMargin: 12
        height: Math.min(root._annotations.length === 0 ? 260 : root._annotations.length * 110 + 80, root.height - topBar.height - 24)
    }

    // Panels dock beside the text (the reading area makes room for them), so no click-away overlay

    // ── Reading Area ────────────────────────────────────────────
    Text {
        id: readError
        anchors.top: topBar.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - 40)
        text: root._storageError || (root.bookFormat === "txt" ? root._textError : "")
        visible: text !== ""
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: root._palette.danger
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
        z: 12
    }
    Item {
        id: readingArea
        objectName: "readingArea"
        anchors.top: topBar.bottom; anchors.topMargin: readError.visible ? readError.height + 12 : 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        // Open panels take their width from the text instead of covering it
        anchors.leftMargin: tocPanel.visible ? tocPanel.width + 20 : 0
        anchors.rightMargin: settingsPanel.visible ? settingsPanel.width + 20 : (root._notesVisible ? notesPanel.width + 20 : 0)
        onWidthChanged: root._reflow()
        onHeightChanged: root._reflow()

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
                    border.color: root._palette.border
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
                            var rendered = backend.renderPdfPage(root.bookId, pdfFlickable.currentPdfPage, 2.0)
                            return rendered ? "file:///" + rendered : ""
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
            onCurrentPdfPageChanged: { syncPdfChapterFromPage(currentPdfPage); progressSaveTimer.restart() }

            // Page indicator
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 20
                width: pageText.implicitWidth + 20; height: 30
                radius: 15; color: root._palette.inverse; opacity: 0.85
                Text {
                    id: pageText
                    anchors.centerIn: parent
                    text: (pdfFlickable.currentPdfPage + 1) + " / " + pdfFlickable.totalPdfPages
                    color: root._palette.textOnInverse; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
                }
            }

            // Navigation buttons
            Rectangle {
                anchors.left: parent.left; anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: prevPdfMa.containsMouse ? "#80000000" : "#60000000"
                visible: pdfFlickable.currentPdfPage > 0
                LucideIcon { anchors.centerIn: parent; name: "chevron-left"; size: 20; color: "#ffffff" }
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
                LucideIcon { anchors.centerIn: parent; name: "chevron-right"; size: 20; color: "#ffffff" }
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
            onContentYChanged: { progressSaveTimer.restart(); Qt.callLater(root._captureAnchor) }

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
                        ctx.globalAlpha = ann.id === root._flashAnnotationId ? 0.6 : 0.28

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
                selectionColor: Qt.rgba(root._palette.accent.r, root._palette.accent.g, root._palette.accent.b, 0.28)
                z: 1

                onSelectedTextChanged: {
                    if (selectedText.length > 0 && root._annotationMode) {
                        root._selStart = selectionStart
                        root._selEnd = selectionEnd
                        root._selText = selectedText
                        var rect = positionToRectangle(selectionStart)
                        var p = mapToItem(root, rect.x, rect.y)
                        root._showAnnotationToolbar(p.x, p.y)
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
                    if (hitAnn) root._openHighlightMenu(hitAnn)
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
            objectName: "pageView"
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

            // Unspaced mirror of the page text. Text breaks lines exactly like TextEdit but has no
            // character geometry, so this answers "which line and x is character n" (and back) for
            // highlights, selection, note jumps and keeping the place across re-layout.
            TextEdit {
                id: measureEdit
                visible: false
                readOnly: true
                width: layoutHelper.width
                text: root.displayText
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WordWrap
                font.pixelSize: root.fontSize; font.family: root.fontFamily
            }

            readonly property int _colsPerPage: root.dualPage ? 2 : 1
            readonly property real _naturalLineH: measureEdit.lineCount > 0
                ? measureEdit.contentHeight / measureEdit.lineCount : root.fontSize * 1.3
            readonly property real _columnWidth: root.dualPage ? width / 2 : width

            function lineOf(pos) {
                var r = measureEdit.positionToRectangle(Math.max(0, pos))
                return Math.max(0, Math.floor((r.y + r.height / 2) / _naturalLineH))
            }
            function pageOf(pos) {
                return Math.floor(Math.floor(lineOf(pos) / Math.max(1, _linesPerCol)) / _colsPerPage)
            }
            // Character under (x, y) inside global column `col`; x and y are relative to its text box
            function posAt(col, x, y) {
                var inCol = Math.max(0, Math.min(_linesPerCol - 1, Math.floor(y / _lineH)))
                var line = col * _linesPerCol + inCol
                return measureEdit.positionAt(Math.max(0, x), line * _naturalLineH + _naturalLineH / 2)
            }
            // Highlight boxes for [start, end) that fall in global column `col`, in its text-box coordinates
            function rectsFor(start, end, col) {
                var out = []
                if (end <= start) return out
                var first = lineOf(start), last = lineOf(end - 1)
                var c0 = col * _linesPerCol, c1 = c0 + _linesPerCol - 1
                var endRect = measureEdit.positionToRectangle(end)
                var endOnLast = lineOf(end) === last
                for (var line = Math.max(first, c0); line <= Math.min(last, c1); line++) {
                    var x0 = line === first ? measureEdit.positionToRectangle(start).x : 0
                    var x1 = (line === last && endOnLast) ? endRect.x : measureEdit.width
                    if (x1 > x0) out.push({ x: x0, y: (line - c0) * _lineH, w: x1 - x0, h: _naturalLineH })
                }
                return out
            }
            function copyRange(start, end) {
                measureEdit.select(start, end)
                measureEdit.copy()
                measureEdit.deselect()
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
                                width: 1; color: root._palette.border
                            }

                            // Inner clip: exactly fits whole lines, no partial cut
                            Item {
                                id: pageColumn
                                readonly property int globalCol: root._displayPage * paginatedContainer._colsPerPage + index
                                width: parent.width
                                y: paginatedContainer._topMargin
                                height: paginatedContainer._linesPerCol * paginatedContainer._lineH
                                clip: true

                                // Highlights and the live selection, painted under the glyphs
                                Canvas {
                                    id: pageHighlights
                                    objectName: "pageHighlights"
                                    x: root.pageMargin
                                    width: measureEdit.width
                                    height: parent.height
                                    readonly property string revision: [root._highlightRevision, pageColumn.globalCol, paginatedContainer._linesPerCol,
                                        width, root._selStart, root._selEnd, root._flashAnnotationId].join(":")
                                    onRevisionChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        var anns = root._chapterAnnotations
                                        for (var i = 0; i < anns.length; i++) {
                                            var start = root._annotationOffset(anns[i])
                                            if (start < 0) continue
                                            ctx.fillStyle = anns[i].color
                                            ctx.globalAlpha = anns[i].id === root._flashAnnotationId ? 0.6 : 0.28
                                            var boxes = paginatedContainer.rectsFor(start, start + anns[i].text.length, pageColumn.globalCol)
                                            for (var b = 0; b < boxes.length; b++) ctx.fillRect(boxes[b].x, boxes[b].y, boxes[b].w, boxes[b].h)
                                        }
                                        if (root._selEnd > root._selStart && root.readingMode === "paginated") {
                                            ctx.fillStyle = root._palette.accent
                                            ctx.globalAlpha = 0.28
                                            var sel = paginatedContainer.rectsFor(root._selStart, root._selEnd, pageColumn.globalCol)
                                            for (var k = 0; k < sel.length; k++) ctx.fillRect(sel[k].x, sel[k].y, sel[k].w, sel[k].h)
                                        }
                                    }
                                }

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
                color: root.textColor; opacity: 0.4; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
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

            // Highlighting on pages: drag to select, right-click a highlight for its menu.
            // A plain click still turns the page from the outer thirds.
            MouseArea {
                id: pageSelect
                objectName: "pageSelect"
                anchors.fill: parent
                z: 6
                enabled: root._annotationMode
                cursorShape: Qt.IBeamCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property int anchorPos: -1
                property bool dragged: false

                function charAt(mx, my) {
                    var colIndex = root.dualPage && mx >= paginatedContainer._columnWidth ? 1 : 0
                    var x = mx - colIndex * paginatedContainer._columnWidth - root.pageMargin
                    var y = my - paginatedContainer._topMargin
                    return paginatedContainer.posAt(root._displayPage * paginatedContainer._colsPerPage + colIndex, x, y)
                }

                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        var hit = root._findAnnotationAt(charAt(mouse.x, mouse.y))
                        if (hit) root._openHighlightMenu(hit)
                        return
                    }
                    root._clearSelection()
                    anchorPos = charAt(mouse.x, mouse.y)
                    dragged = false
                }
                onPositionChanged: (mouse) => {
                    if (!(pressedButtons & Qt.LeftButton) || anchorPos < 0) return
                    var here = charAt(mouse.x, mouse.y)
                    if (here === anchorPos) return
                    dragged = true
                    root._selStart = Math.min(anchorPos, here)
                    root._selEnd = Math.max(anchorPos, here)
                }
                onReleased: (mouse) => {
                    if (mouse.button !== Qt.LeftButton) return
                    if (dragged && root._selEnd > root._selStart) {
                        root._selText = root.displayText.substring(root._selStart, root._selEnd)
                        var p = mapToItem(root, mouse.x, mouse.y)
                        root._showAnnotationToolbar(p.x, p.y)
                    } else if (!dragged) {
                        if (mouse.x < width * 0.3) root.pagePrev()
                        else if (mouse.x > width * 0.7) root.pageNext()
                    }
                    anchorPos = -1
                }
            }
        }

        // ═══════════════ CENTER TAP ZONE (toggle progress bar) ═══════════════
        Item {
            id: centerTapZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.bottom: parent.bottom
            width: parent.width * 0.4
            z: 10
            enabled: !root._annotationMode   // leave presses to text selection while highlighting
            TapHandler {
                onTapped: root._progressBarVisible = !root._progressBarVisible
            }
        }
    }

    // ── Annotation Toolbar (floating, appears on text selection) ──
    Rectangle {
        id: annotationToolbar
        visible: false; z: 100
        width: annToolRow.implicitWidth + 16
        height: 44
        radius: 22
        color: root._palette.surface
        border.color: root._palette.border

        RowLayout {
            id: annToolRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: [
                    { color: "#E8C547", name: zh("黄色", "Yellow") },
                    { color: "#7FB069", name: zh("绿色", "Green") },
                    { color: "#5B9BD5", name: zh("蓝色", "Blue") },
                    { color: "#E07A5F", name: zh("红色", "Red") }
                ]
                AbstractButton {
                    id: swatch
                    implicitWidth: 28; implicitHeight: 28
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: zh("用", "Highlight ") + modelData.name + zh("划线", "")
                    onClicked: root._createHighlight(modelData.color)
                    background: Rectangle {
                        radius: 14
                        color: modelData.color
                        border.color: swatch.hovered ? root.textColor : "transparent"
                        border.width: 1.5
                        FocusRing { shown: swatch.visualFocus }
                    }
                }
            }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: root._palette.border }
            IconButton {
                implicitWidth: 30; implicitHeight: 30; iconSize: 16
                tone: root._palette
                iconName: "copy"
                label: zh("复制", "Copy")
                onClicked: { root._copySelection(); root._clearSelection() }
            }
        }
    }

    // ── Highlight context menu (right-click on a highlight) ──
    AppMenu {
        id: highlightMenu
        property string annId: ""
        property string annComment: ""
        AppMenuItem {
            text: highlightMenu.annComment ? zh("编辑评论", "Edit comment") : zh("添加评论", "Add comment")
            iconName: "message"
            onTriggered: root.editComment({ id: highlightMenu.annId, comment: highlightMenu.annComment })
        }
        AppMenuItem {
            text: zh("删除划线", "Delete highlight")
            iconName: "trash"
            destructive: true
            onTriggered: root._deleteAnnotation(highlightMenu.annId)
        }
    }

    // ── Comment dialog ──
    AppModal {
        id: commentDialog
        title: zh("评论", "Comment")
        preferredWidth: 420
        showClose: false
        onOpened: commentField.forceActiveFocus()
        onClosed: root.forceActiveFocus()

        TextArea {
            id: commentField
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            placeholderText: zh("写下你的想法", "Write your thoughts")
            wrapMode: TextArea.Wrap
            color: Theme.text
            placeholderTextColor: Theme.textTertiary
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            Accessible.name: zh("评论内容", "Comment")
            Keys.onReturnPressed: (event) => {
                if (event.modifiers & Qt.ShiftModifier) event.accepted = false
                else root._commitComment()
            }
            background: Rectangle {
                radius: Theme.radiusM
                color: Theme.bg
                border.color: commentField.activeFocus ? Theme.accent : Theme.border
                border.width: commentField.activeFocus ? 1.5 : 1
            }
        }
        footer: [
            AppButton { text: zh("取消", "Cancel"); variant: "ghost"; onClicked: commentDialog.close() },
            AppButton { text: zh("保存", "Save"); variant: "primary"; onClicked: root._commitComment() }
        ]
    }

    Toast { id: toast }

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

        // Main pill
        Rectangle {
            id: progressPill
            anchors.fill: parent
            radius: 26
            color: root._palette.surface
            border.color: root._palette.border
            border.width: 1

            opacity: root._progressBarVisible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic } }

            transform: Translate {
                y: root._progressBarVisible ? 0 : 8
                Behavior on y { NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 14

                Text {
                    text: Math.round(progressBar.progress * 100) + "%"
                    color: root.textColor; opacity: 0.7
                    font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold; font.features: Theme.tabular
                    Layout.preferredWidth: 36
                }

                Item {
                    id: trackArea
                    Layout.fillWidth: true; height: 32

                    // Track background
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: root._palette.sunken

                        // Filled track
                        Rectangle {
                            width: parent.width * progressBar.progress
                            height: parent.height; radius: 2
                            color: root._palette.accent
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
                            color: root._palette.borderStrong

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
                        color: root._palette.surface
                        border.color: root._palette.border

                        property alias text: tooltipText.text

                        Text {
                            id: tooltipText
                            anchors.centerIn: parent
                            color: root._palette.text
                            font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Handle
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * progressBar.progress - 7
                        width: 14; height: 14; radius: 7
                        color: root._palette.surface
                        border.color: root._palette.accent
                        border.width: 2
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
                    color: root.textColor; opacity: 0.6
                    font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
