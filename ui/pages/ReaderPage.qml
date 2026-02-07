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
    property int currentChapter: -1
    signal backRequested()

    // ── Reading settings ────────────────────────────────────────
    property string bgColor: "#fdfbf7"
    property string textColor: "#1a1a1a"
    property int fontSize: 18
    property int pageMargin: 40
    property bool dualPage: false
    property string readingMode: "scroll"  // "scroll" or "paginated"
    property int paragraphSpacing: 0       // 0-4 extra blank lines

    function _spacedText(raw, spacing) {
        if (!raw) return ""
        // spacing 0 = no blank line (tight), 1 = 1 blank line, 2+ = more
        var join = "\n"
        for (var i = 0; i < spacing; i++) join += "\n"
        // Use regex to catch any run of 2+ newlines (robust paragraph detection)
        return raw.replace(/\n{2,}/g, join)
    }
    property string displayText: _spacedText(bookText, paragraphSpacing)

    // ── Paginated state ─────────────────────────────────────────
    property int _pageIndex: 0
    property int _displayPage: 0   // decoupled for slide animation
    property int _totalPages: 1
    property real _slideOffset: 0  // horizontal offset during animation

    readonly property var bgPresets: [
        { name: "白色",   bg: "#ffffff", fg: "#1a1a1a" },
        { name: "羊皮纸", bg: "#fdfbf7", fg: "#1a1a1a" },
        { name: "暖褐",   bg: "#f4ecd8", fg: "#3d3429" },
        { name: "护眼绿", bg: "#e8f5e9", fg: "#2e3830" },
        { name: "夜间",   bg: "#1e1e2e", fg: "#d4d4d8" }
    ]

    // Derived dark-mode helpers
    property bool _isDark: bgColor === "#1e1e2e"
    property string _panelBg:     _isDark ? "#2a2a3e" : "#f5f3ef"
    property string _panelBorder: _isDark ? "#3a3a4e" : "#e0ddd8"
    property string _activeBg:    _isDark ? "#4a4a6e" : "#e0ddd8"
    property string _hoverBg:     _isDark ? "#333350" : "#f0ece6"
    property string _dimText:     _isDark ? "#b0b0cc" : "#666"

    ListModel { id: chapterModel }

    function loadChapters() {
        chapterModel.clear()
        currentChapter = -1
        if (bookFormat === "epub" && backend) {
            var chs = backend.getChapters(bookId)
            for (var i = 0; i < chs.length; i++) {
                chapterModel.append({
                    "title":     chs[i].title || ("Chapter " + (i + 1)),
                    "index":     chs[i].index,
                    "isSection": chs[i].isSection || false
                })
            }
            for (var j = 0; j < chapterModel.count; j++) {
                if (!chapterModel.get(j).isSection || chapterModel.get(j).index >= 0) {
                    loadChapterByIndex(j)
                    break
                }
            }
        }
    }

    function loadChapterByIndex(idx) {
        if (!backend || bookFormat !== "epub") return
        var ch = chapterModel.get(idx)
        if (!ch || ch.index < 0) return
        currentChapter = idx
        root.bookText = backend.readChapter(bookId, ch.index)
        jumpToPage(0)
    }

    // ── Navigation helpers ──────────────────────────────────────
    function gotoPrevChapter() {
        for (var i = currentChapter - 1; i >= 0; i--) {
            var ch = chapterModel.get(i)
            if (ch && ch.index >= 0) { loadChapterByIndex(i); return }
        }
    }
    function gotoNextChapter() {
        for (var i = currentChapter + 1; i < chapterModel.count; i++) {
            var ch = chapterModel.get(i)
            if (ch && ch.index >= 0) { loadChapterByIndex(i); return }
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
    Keys.onLeftPressed:  { if (readingMode === "paginated") pagePrev(); else gotoPrevChapter() }
    Keys.onRightPressed: { if (readingMode === "paginated") pageNext(); else gotoNextChapter() }

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
                Text { anchors.centerIn: parent; text: "← 返回"; color: root.textColor; opacity: 0.6; font.pixelSize: 14 }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.backRequested() }
            }

            Rectangle {
                width: 50; height: 30; radius: 6
                visible: bookFormat === "epub" && chapterModel.count > 1
                color: tocMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "目录"; color: root.textColor; opacity: 0.5; font.pixelSize: 13 }
                MouseArea { id: tocMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tocPanel.visible = !tocPanel.visible }
            }

            Rectangle {
                width: 30; height: 30; radius: 6
                visible: bookFormat === "epub" && chapterModel.count > 1
                color: prevMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "◀"; color: currentChapter > 0 ? root.textColor : "#ccc"; opacity: 0.6; font.pixelSize: 14 }
                MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gotoPrevChapter() }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: {
                    if (bookFormat === "epub" && currentChapter >= 0 && currentChapter < chapterModel.count)
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
                visible: bookFormat === "epub" && chapterModel.count > 1
                color: nextMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "▶"; color: currentChapter < chapterModel.count - 1 ? root.textColor : "#ccc"; opacity: 0.6; font.pixelSize: 14 }
                MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gotoNextChapter() }
            }

            Rectangle {
                width: 50; height: 30; radius: 6
                color: settingsMa.containsMouse ? "#15000000" : "transparent"
                Text { anchors.centerIn: parent; text: "设置"; color: root.textColor; opacity: 0.5; font.pixelSize: 13 }
                MouseArea { id: settingsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsPanel.visible = !settingsPanel.visible }
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

        ListView {
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
                    cursorShape: (model.index >= 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { if (model.index >= 0) { loadChapterByIndex(index); tocPanel.visible = false } }
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
            Text { text: "阅读背景"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
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

            // ── Font size (custom stepper slider) ──
            Text { text: "字体大小"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
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
            Text { text: "页面边距"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
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
            Text { text: "段间距"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
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
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; height: 3; width: root.paragraphSpacing / 4 * (parent.width - 16); radius: 1.5; color: _isDark ? "#8888bb" : "#a09888" }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8 + root.paragraphSpacing / 4 * (parent.width - 16) - 10
                        width: 20; height: 20; radius: 10
                        color: _isDark ? "#aaaadd" : "#7a7060"
                        Text { anchors.centerIn: parent; text: root.paragraphSpacing; color: "#fff"; font.pixelSize: 9; font.weight: Font.Bold }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.paragraphSpacing = Math.round(r * 4) }
                        onPositionChanged: function(mouse) { if (pressed) { var r = Math.max(0, Math.min(1, (mouse.x - 8) / (parent.width - 16))); root.paragraphSpacing = Math.round(r * 4) } }
                    }
                }
                Rectangle {
                    width: 36; height: 32; radius: 6; color: psPlus.containsMouse ? _hoverBg : "transparent"
                    Text { anchors.centerIn: parent; text: "+"; color: root.textColor; opacity: 0.6; font.pixelSize: 16 }
                    MouseArea { id: psPlus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.paragraphSpacing < 4) root.paragraphSpacing++ } }
                }
            }

            // ── Reading mode ──
            Text { text: "阅读方式"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 10
                Repeater {
                    model: [{ label: "下拉", val: "scroll" }, { label: "翻页", val: "paginated" }]
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
            Text { text: "页面布局"; color: root.textColor; opacity: 0.7; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 10
                Repeater {
                    model: [{ label: "单页", val: false }, { label: "双页", val: true }]
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
        visible: tocPanel.visible || settingsPanel.visible
        onClicked: { tocPanel.visible = false; settingsPanel.visible = false }
    }

    // ── Reading Area ────────────────────────────────────────────
    Item {
        id: readingArea
        anchors.top: topBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right

        // ═══════════════ SCROLL MODE ═══════════════
        Flickable {
            id: scrollFlickable
            visible: root.readingMode === "scroll"
            anchors.fill: parent; clip: true
            contentWidth: width
            contentHeight: scrollText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Text {
                id: scrollText
                width: scrollFlickable.width
                text: root.displayText
                wrapMode: Text.WordWrap
                color: root.textColor
                font.pixelSize: root.fontSize; font.family: "Georgia"
                lineHeight: 1.6
                leftPadding:  root.pageMargin
                rightPadding: root.pageMargin
                topPadding: 30; bottomPadding: 60
            }
        }

        // ═══════════════ PAGINATED MODE ═══════════════
        Item {
            id: paginatedContainer
            visible: root.readingMode === "paginated"
            anchors.fill: parent; clip: true

            property int _topMargin: 30
            property int _linesPerCol: 1
            property real _lineH: layoutHelper.lineCount > 0
                ? layoutHelper.contentHeight / layoutHelper.lineCount
                : root.fontSize * 1.6

            // Hidden Text for layout measurement (identical properties to visible Text)
            Text {
                id: layoutHelper
                visible: false
                width: root.dualPage ? paginatedContainer.width / 2 - 2 * root.pageMargin
                                     : paginatedContainer.width - 2 * root.pageMargin
                text: root.displayText
                wrapMode: Text.WordWrap
                font.pixelSize: root.fontSize; font.family: "Georgia"
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
                                    wrapMode: Text.WordWrap
                                    color: root.textColor
                                    font.pixelSize: root.fontSize; font.family: "Georgia"
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
    }
}
