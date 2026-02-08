import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"

/*  LibraryPage – 水墨风书库 + 文件夹管理  */
Item {
    id: root
    signal bookSelected(var book)

    property var model
    property string _menuBookId: ""
    property real _menuX: 0
    property real _menuY: 0
    property string _filterStatus: ""
    property string _searchText: ""
    property bool _searchActive: false
    property bool _filterOpen: false
    property var _allBooks: []
    property real _filterBtnX: 0
    property real _filterBtnY: 0
    property string lang: "zh"
    property string appFont: "Long Cang"
    property int appFontBoldW: Font.Bold
    property int appFontNormW: Font.Normal

    // Folder state
    property var _folders: []
    property string _currentFolderId: ""   // "" = all books
    property bool _createFolderOpen: false
    property bool _folderSelectOpen: false  // for context menu "add to folder"
    property string _folderMenuBookId: ""
    property string _dragBookId: ""
    property bool _dragActive: false
    property string _dragCover: ""
    property string _dragTitle: ""
    property real _dragProxyX: 0
    property real _dragProxyY: 0

    // ── Ink-wash palette ──
    readonly property string _ink:      "#2a2828"
    readonly property string _inkLight: "#555050"
    readonly property string _inkDim:   "#8a8580"
    readonly property string _paper:    "#eeecea"
    readonly property string _paperDim: "#e0dedc"

    function refresh(books) {
        if (books) {
            var arr = []
            for (var i = 0; i < books.length; i++) {
                var b = books[i]
                arr.push({
                    id:              b.id              || "",
                    title:           b.title           || "Untitled",
                    author:          b.author          || "",
                    cover_path:      b.cover_path      || "",
                    status:          (b.status !== undefined && b.status !== null && b.status !== "") ? b.status : "",
                    reading_minutes: b.reading_minutes  || 0,
                    path:            b.path            || "",
                    format:          b.format          || "txt"
                })
            }
            root._allBooks = arr
        }
        _loadFolders()
        _applyFilter()
    }

    function _loadFolders() {
        if (!backend) return
        root._folders = backend.listFolders() || []
    }

    function _applyFilter() {
        if (!model) return
        model.clear()
        var fs = root._filterStatus
        var q = root._searchText.toLowerCase()

        // Collect all book IDs that belong to any folder
        var folderBookIdSet = {}
        for (var fi0 = 0; fi0 < root._folders.length; fi0++) {
            var fids0 = root._folders[fi0].book_ids || []
            for (var fj0 = 0; fj0 < fids0.length; fj0++) {
                folderBookIdSet[fids0[fj0]] = true
            }
        }

        // When viewing top level and NO filter active, show folders first
        if (root._currentFolderId === "" && fs === "") {
            for (var fi = 0; fi < root._folders.length; fi++) {
                var folder = root._folders[fi]
                if (q !== "" && folder.name.toLowerCase().indexOf(q) < 0) continue
                // Get first 4 book covers for folder thumbnail
                var fBookIds = folder.book_ids || []
                var covers = ["", "", "", ""]
                for (var ci = 0; ci < Math.min(4, fBookIds.length); ci++) {
                    for (var bi = 0; bi < root._allBooks.length; bi++) {
                        if (root._allBooks[bi].id === fBookIds[ci]) {
                            covers[ci] = root._allBooks[bi].cover_path || ""
                            break
                        }
                    }
                }
                model.append({
                    _type: "folder",
                    id: folder.id,
                    title: folder.name,
                    author: "",
                    cover_path: "",
                    status: "",
                    reading_minutes: 0,
                    path: "",
                    format: "",
                    _bookCount: fBookIds.length,
                    _cover1: covers[0],
                    _cover2: covers[1],
                    _cover3: covers[2],
                    _cover4: covers[3]
                })
            }
        }

        // Get book IDs in current folder (if viewing a folder)
        var folderBookIds = null
        if (root._currentFolderId !== "") {
            for (var fi2 = 0; fi2 < root._folders.length; fi2++) {
                if (root._folders[fi2].id === root._currentFolderId) {
                    folderBookIds = root._folders[fi2].book_ids || []
                    break
                }
            }
        }

        for (var i = 0; i < root._allBooks.length; i++) {
            var b = root._allBooks[i]
            // If in a folder view, only show books in that folder
            if (folderBookIds !== null && folderBookIds.indexOf(b.id) < 0) continue
            // If in top-level view, hide books that are in any folder
            if (root._currentFolderId === "" && folderBookIdSet[b.id]) continue
            if (fs !== "" && b.status !== fs) continue
            if (q !== "") {
                if (b.title.toLowerCase().indexOf(q) < 0
                 && b.author.toLowerCase().indexOf(q) < 0) continue
            }
            model.append({
                _type: "book",
                id: b.id,
                title: b.title,
                author: b.author,
                cover_path: b.cover_path,
                status: b.status,
                reading_minutes: b.reading_minutes,
                path: b.path,
                format: b.format,
                _bookCount: 0,
                _cover1: "",
                _cover2: "",
                _cover3: "",
                _cover4: ""
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        anchors.topMargin: 30
        spacing: 20

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Text {
                text: lang === "zh" ? "书库" : "Library"
                color: _ink
                font.pixelSize: 32
                font.weight: root.appFontBoldW
                font.family: root.appFont
            }

            // Search box
            Rectangle {
                Layout.preferredWidth: root._searchActive ? 260 : 36
                Layout.preferredHeight: 36
                radius: 18
                color: "#20c8c0b0"
                border.color: root._searchActive ? "#60a09888" : "#30a09888"
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "\uD83D\uDD0D"
                        color: _inkDim
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._searchActive = !root._searchActive
                                if (root._searchActive) searchInput.forceActiveFocus()
                                else { root._searchText = ""; searchInput.text = ""; root._applyFilter() }
                            }
                        }
                    }

                    TextInput {
                        id: searchInput
                        visible: root._searchActive
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: _ink
                        font.pixelSize: 14
                        clip: true
                        selectByMouse: true
                        onTextChanged: { root._searchText = text; root._applyFilter() }
                    }

                    Text {
                        visible: root._searchActive && searchInput.text === ""
                        text: lang === "zh" ? "搜索书名或作者..." : "Search title or author..."
                        color: _inkDim
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        visible: root._searchActive && searchInput.text !== ""
                        text: "✕"
                        color: _inkDim
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Filter button
            Rectangle {
                id: filterBtn
                Layout.preferredWidth: filterRow.implicitWidth + 24
                Layout.minimumWidth: 80
                height: 36; radius: 18
                color: root._filterStatus !== "" ? "#35c8c0b0" : "#20c8c0b0"
                border.color: root._filterStatus !== "" ? "#60a09888" : "#30a09888"

                RowLayout {
                    id: filterRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "▾"; color: _inkDim; font.pixelSize: 12 }
                    Text {
                        text: root._filterStatus === "to_read" ? (lang === "zh" ? "待看" : "To Read")
                            : root._filterStatus === "reading" ? (lang === "zh" ? "在看" : "Reading")
                            : root._filterStatus === "read" ? (lang === "zh" ? "已看" : "Finished")
                            : (lang === "zh" ? "筛选" : "Filter")
                        color: _inkLight; font.pixelSize: 14
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var gp = filterBtn.mapToItem(root, 0, 0)
                        root._filterBtnX = gp.x; root._filterBtnY = gp.y
                        root._filterOpen = !root._filterOpen
                    }
                }
            }

            // New Folder button (in header)
            Rectangle {
                Layout.preferredWidth: newFolderHdrRow.implicitWidth + 24
                Layout.minimumWidth: 80
                height: 36; radius: 18
                color: newFolderHdrMa.containsMouse ? "#35c8c0b0" : "#20c8c0b0"
                border.color: "#30a09888"
                visible: root._currentFolderId === ""

                RowLayout {
                    id: newFolderHdrRow; anchors.centerIn: parent; spacing: 6
                    Text { text: "+"; color: _inkLight; font.pixelSize: 14 }
                    Text {
                        text: lang === "zh" ? "新建文件夹" : "New Folder"
                        color: _inkLight; font.pixelSize: 14
                    }
                }
                MouseArea {
                    id: newFolderHdrMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        newFolderInput.text = ""
                        root._createFolderOpen = true
                        newFolderInput.forceActiveFocus()
                    }
                }
            }

            // Import button
            Rectangle {
                Layout.preferredWidth: importRow.implicitWidth + 24
                Layout.minimumWidth: 80
                height: 36; radius: 18
                color: importMa.containsMouse ? "#35c8c0b0" : "#20c8c0b0"
                border.color: "#30a09888"

                Text {
                    id: importRow
                    anchors.centerIn: parent
                    text: lang === "zh" ? "+ 导入" : "+ Import"
                    color: _inkLight; font.pixelSize: 14
                }

                MouseArea {
                    id: importMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: importOverlay.visible = true
                }
            }
        }

        // ── Folder Breadcrumb (visible when inside a folder) ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root._currentFolderId !== ""

            Rectangle {
                width: backRow.implicitWidth + 20; height: 32; radius: 16
                color: backFolderMa.containsMouse ? "#30a09888" : "#15a09888"
                border.color: "#30a09888"

                RowLayout {
                    id: backRow; anchors.centerIn: parent; spacing: 6
                    Text { text: "←"; color: _inkLight; font.pixelSize: 14 }
                    Text {
                        text: lang === "zh" ? "返回书库" : "Back to Library"
                        color: _inkLight; font.pixelSize: 13
                    }
                }
                MouseArea {
                    id: backFolderMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root._currentFolderId = ""; root._applyFilter() }
                }
            }

            Text {
                text: {
                    for (var i = 0; i < root._folders.length; i++)
                        if (root._folders[i].id === root._currentFolderId)
                            return root._folders[i].name
                    return ""
                }
                color: _ink; font.pixelSize: 18; font.weight: Font.DemiBold
                font.family: root.appFont
            }
        }

        // ── Inline folder creation overlay ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: root._createFolderOpen
            color: "transparent"

            Rectangle {
                width: 280; height: 36; radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: "#eeecea"
                border.color: "#60a09888"

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 10
                    spacing: 8

                    TextInput {
                        id: newFolderInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: _ink; font.pixelSize: 14
                        clip: true; selectByMouse: true
                        onAccepted: {
                            if (text.trim() !== "") {
                                backend.createFolder(text.trim())
                                root._loadFolders()
                                root._applyFilter()
                            }
                            root._createFolderOpen = false
                        }
                        Keys.onEscapePressed: root._createFolderOpen = false
                    }

                    Text {
                        text: "✓"; color: "#5a8a6a"; font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                            onClicked: newFolderInput.accepted()
                        }
                    }
                    Text {
                        text: "✕"; color: _inkDim; font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                            onClicked: root._createFolderOpen = false
                        }
                    }
                }
            }
        }

        // ── Grid ──
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 220
            cellHeight: 290
            model: root.model

            delegate: Item {
                id: gridItem
                width: grid.cellWidth
                height: grid.cellHeight

                property string itemType: model._type || "book"
                property string folderCover1: model._cover1 || ""
                property string folderCover2: model._cover2 || ""
                property string folderCover3: model._cover3 || ""
                property string folderCover4: model._cover4 || ""

                // ════════════ FOLDER CARD ════════════
                GlassPanel {
                    id: folderCard
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: gridItem.itemType === "folder"
                    color: folderDropArea.containsDrag ? "#c0dbd8d0" : "#a8eeecea"
                    border.color: folderDropArea.containsDrag ? "#70a09888" : "#30b0aaa0"
                    border.width: folderDropArea.containsDrag ? 2 : 0.5

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 0; spacing: 0

                        // Book covers 2x2 grid
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 10
                            Layout.bottomMargin: 0

                            Rectangle {
                                anchors.fill: parent; radius: 12
                                color: "#12908880"
                                clip: true

                                Grid {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    columns: 2; rows: 2
                                    spacing: 4

                                    Repeater {
                                        model: [gridItem.folderCover1, gridItem.folderCover2, gridItem.folderCover3, gridItem.folderCover4]

                                        Rectangle {
                                            width: (parent.width - parent.spacing) / 2
                                            height: (parent.height - parent.spacing) / 2
                                            radius: 6
                                            color: modelData !== "" ? "transparent" : "#0c908880"
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: modelData ? "file:///" + modelData : ""
                                                fillMode: Image.PreserveAspectCrop
                                                visible: modelData !== ""
                                            }

                                            // Empty slot subtle icon
                                            Text {
                                                anchors.centerIn: parent
                                                visible: modelData === ""
                                                text: "\uD83D\uDCDC"
                                                font.pixelSize: 16
                                                opacity: 0.15
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Folder name + count
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 14
                            Layout.topMargin: 10
                            Layout.bottomMargin: 14
                            spacing: 4

                            Text {
                                text: model.title
                                color: _ink
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6; Layout.fillWidth: true
                                Text {
                                    text: model._bookCount + (lang === "zh" ? " 本书" : " books")
                                    color: _inkDim
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                }

                                // Three-dot menu for folder
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    color: folderDotMa.containsMouse ? "#30908880" : "transparent"
                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Repeater { model: 3; Rectangle { width: 3; height: 3; radius: 1.5; color: _inkDim } }
                                    }
                                    MouseArea {
                                        id: folderDotMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            folderContextMenu.folderId = model.id
                                            folderContextMenu.folderName = model.title
                                            var gp = parent.mapToItem(root, 0, 0)
                                            folderContextMenu.x = Math.min(gp.x, root.width - 160)
                                            folderContextMenu.y = gp.y + parent.height + 4
                                            folderContextMenu.visible = true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Click to enter folder
                    MouseArea {
                        anchors.fill: parent; z: -1
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._currentFolderId = model.id
                            root._applyFilter()
                        }
                        onEntered: folderCard.border.color = "#50908880"
                        onExited: folderCard.border.color = "#30b0aaa0"
                    }

                    // Drop area: drag books into folder
                    DropArea {
                        id: folderDropArea
                        anchors.fill: parent
                        keys: ["bookId"]
                        onDropped: function(drop) {
                            var bid = drop.getDataAsString("bookId")
                            if (bid && model.id) {
                                // Defer model refresh to avoid conflict with drag cleanup
                                var fid = model.id
                                Qt.callLater(function() {
                                    backend.addBookToFolder(bid, fid)
                                    root._loadFolders()
                                    root._applyFilter()
                                })
                            }
                        }
                    }
                }

                // ════════════ BOOK CARD ════════════
                GlassPanel {
                    id: bookCard
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: gridItem.itemType === "book"
                    opacity: (root._dragActive && root._dragBookId === model.id) ? 0.4 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 0; spacing: 0

                        // Cover
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 10
                            Layout.bottomMargin: 0

                            Rectangle {
                                id: coverMask
                                anchors.fill: parent
                                radius: 12
                                color: "#18908880"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: cover_path ? "file:///" + cover_path : ""
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                }
                            }

                            // No cover placeholder
                            Text {
                                anchors.centerIn: coverMask
                                visible: !cover_path
                                text: title ? title.charAt(0) : "?"
                                color: _inkDim
                                font.pixelSize: 36
                                font.family: root.appFont
                                opacity: 0.4
                            }
                        }

                        // Meta + controls row
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 14
                            Layout.topMargin: 10
                            Layout.bottomMargin: 14
                            spacing: 4

                            Text {
                                text: title
                                color: _ink
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6
                                Layout.fillWidth: true

                                Text {
                                    text: author ? author : "Unknown"
                                    color: _inkDim
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Format badge
                                Rectangle {
                                    width: fmtLabel.implicitWidth + 10
                                    height: 18; radius: 9
                                    color: "#18908880"
                                    border.color: "#30908880"
                                    border.width: 0.5
                                    Text {
                                        id: fmtLabel
                                        anchors.centerIn: parent
                                        text: format ? format.toUpperCase() : "TXT"
                                        color: _inkDim
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.5
                                    }
                                }

                                // Three-dot menu
                                Rectangle {
                                    width: 24; height: 24; radius: 12
                                    color: dotMa.containsMouse ? "#30908880" : "transparent"

                                    Column {
                                        anchors.centerIn: parent; spacing: 2
                                        Repeater {
                                            model: 3
                                            Rectangle { width: 3; height: 3; radius: 1.5; color: _inkDim }
                                        }
                                    }

                                    MouseArea {
                                        id: dotMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root._menuBookId = model.id
                                            var gp = parent.mapToItem(root, 0, 0)
                                            root._menuX = Math.min(gp.x - 130, root.width - 190)
                                            root._menuY = Math.min(gp.y + parent.height + 4, root.height - 300)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: bookDragMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: -1

                        property real _pressX: 0
                        property real _pressY: 0
                        property bool _dragging: false
                        property bool _wasDragging: false

                        onPressed: (mouse) => {
                            _pressX = mouse.x
                            _pressY = mouse.y
                            _dragging = false
                            _wasDragging = false
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed) return
                            var dx = mouse.x - _pressX
                            var dy = mouse.y - _pressY
                            if (!_dragging && (dx*dx + dy*dy > 400)) {
                                _dragging = true
                                root._dragBookId = model.id
                                root._dragCover = model.cover_path || ""
                                root._dragTitle = model.title || ""
                                root._dragActive = true
                            }
                            if (_dragging) {
                                var gp = mapToItem(root, mouse.x, mouse.y)
                                root._dragProxyX = gp.x
                                root._dragProxyY = gp.y
                            }
                        }
                        onReleased: {
                            _wasDragging = _dragging
                            if (_dragging) {
                                // drop() while Drag.active is still true, then defer cleanup
                                dragProxy.Drag.drop()
                                dragCleanupTimer.start()
                            }
                            _dragging = false
                        }
                        onClicked: {
                            if (!_wasDragging) root.bookSelected(model)
                        }
                        onEntered: bookCard.border.color = "#50908880"
                        onExited: bookCard.border.color = "#30b0aaa0"
                    }
                }
            }
        }
    }

    // ── Drag proxy (follows cursor during book drag) ──
    Rectangle {
        id: dragProxy
        x: root._dragProxyX - width / 2
        y: root._dragProxyY - height / 2
        width: 160; height: 220
        visible: root._dragActive
        z: 500
        opacity: 0.85
        color: "transparent"

        Drag.active: root._dragActive
        Drag.keys: ["bookId"]
        Drag.mimeData: ({ "bookId": root._dragBookId })
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        GlassPanel {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                radius: 10
                color: "#20908880"
                clip: true

                Image {
                    anchors.fill: parent
                    source: root._dragCover ? "file:///" + root._dragCover : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: root._dragCover !== ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: root._dragCover === ""
                    text: root._dragTitle.length > 0 ? root._dragTitle.charAt(0) : "?"
                    color: _inkDim
                    font.pixelSize: 28
                    opacity: 0.5
                }
            }
        }
    }

    Timer {
        id: dragCleanupTimer
        interval: 50; repeat: false
        onTriggered: {
            root._dragActive = false
            root._dragBookId = ""
            root._dragCover = ""
            root._dragTitle = ""
        }
    }

    // ── Filter close overlay ──
    MouseArea {
        anchors.fill: parent; visible: root._filterOpen; z: 40
        onClicked: root._filterOpen = false
    }

    // ── Filter dropdown ──
    Rectangle {
        id: filterDropdown
        visible: root._filterOpen; z: 200
        width: 140; height: filterCol.implicitHeight + 12
        radius: 12
        color: "#eeecea"
        border.color: "#c8c5c0"
        x: root._filterBtnX + (filterBtn ? filterBtn.width : 0) - width
        y: root._filterBtnY + (filterBtn ? filterBtn.height : 36) + 6

        Rectangle {
            anchors.fill: parent; anchors.margins: 1; radius: 11
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#18ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        Column {
            id: filterCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 6; spacing: 2

            Repeater {
                model: lang === "zh" ? [
                    { label: "全部", value: "" },
                    { label: "待看", value: "to_read" },
                    { label: "在看", value: "reading" },
                    { label: "已看", value: "read" }
                ] : [
                    { label: "All", value: "" },
                    { label: "To Read", value: "to_read" },
                    { label: "Reading", value: "reading" },
                    { label: "Finished", value: "read" }
                ]

                Rectangle {
                    width: filterCol.width; height: 34; radius: 6
                    color: {
                        if (root._filterStatus === modelData.value) return "#30a09888"
                        if (filterItemMa.containsMouse) return "#18a09888"
                        return "transparent"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 14
                        text: modelData.label
                        color: root._filterStatus === modelData.value ? _ink : _inkLight
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: filterItemMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._filterStatus = modelData.value
                            root._filterOpen = false; root._applyFilter()
                        }
                    }
                }
            }
        }
    }

    // ── Book context menu overlay ──
    MouseArea {
        anchors.fill: parent; visible: root._menuBookId !== ""; z: 150
        onClicked: { root._menuBookId = ""; root._folderSelectOpen = false }
    }

    Rectangle {
        id: bookMenu
        visible: root._menuBookId !== ""; z: 200
        x: root._menuX; y: root._menuY
        width: 180; height: menuCol.implicitHeight + 16
        radius: 12; color: "#eeecea"; border.color: "#c8c5c0"

        Rectangle {
            anchors.fill: parent; anchors.margins: 1; radius: 11
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#18ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        Column {
            id: menuCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 8; spacing: 2

            // Status options
            Repeater {
                model: lang === "zh" ? [
                    { text: "添加到待看", status: "to_read" },
                    { text: "添加到在看", status: "reading" },
                    { text: "添加到已看", status: "read" }
                ] : [
                    { text: "Mark as To Read", status: "to_read" },
                    { text: "Mark as Reading", status: "reading" },
                    { text: "Mark as Finished", status: "read" }
                ]

                Rectangle {
                    width: menuCol.width; height: 36; radius: 6
                    color: statusMa.containsMouse ? "#25a09888" : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        text: modelData.text; color: _inkLight; font.pixelSize: 13
                    }

                    MouseArea {
                        id: statusMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var books = backend.updateBookStatus(root._menuBookId, modelData.status)
                            root.refresh(books); root._menuBookId = ""
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width: menuCol.width - 16; height: 1
                anchors.horizontalCenter: parent.horizontalCenter; color: "#c5c2be"
            }

            // Add to folder
            Rectangle {
                width: menuCol.width; height: 36; radius: 6
                color: folderAddMa.containsMouse ? "#25a09888" : "transparent"

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    spacing: 6
                    // Ink-wash folder icon
                    Item {
                        width: 16; height: 14; Layout.alignment: Qt.AlignVCenter
                        Rectangle { x: 0; y: 3; width: 14; height: 10; radius: 2; color: "#c8c0b0"; border.color: "#a89880"; border.width: 0.5 }
                        Rectangle { x: 0; y: 1; width: 7; height: 4; radius: 1.5; color: "#b8b0a0" }
                    }
                    Text {
                        text: lang === "zh" ? "添加到文件夹" : "Add to Folder"
                        color: _inkLight; font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                    Text { text: "▸"; color: _inkDim; font.pixelSize: 12 }
                }

                MouseArea {
                    id: folderAddMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root._folderMenuBookId = root._menuBookId
                        root._folderSelectOpen = !root._folderSelectOpen
                    }
                }
            }

            // Remove from current folder (if in a folder view)
            Rectangle {
                width: menuCol.width; height: 36; radius: 6
                visible: root._currentFolderId !== ""
                color: removeFolderMa.containsMouse ? "#25a09888" : "transparent"

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    spacing: 6
                    // Ink-wash export/remove icon
                    Item {
                        width: 16; height: 14; Layout.alignment: Qt.AlignVCenter
                        Rectangle { x: 0; y: 3; width: 14; height: 10; radius: 2; color: "#c8c0b0"; border.color: "#a89880"; border.width: 0.5 }
                        Rectangle { x: 0; y: 1; width: 7; height: 4; radius: 1.5; color: "#b8b0a0" }
                        Rectangle { x: 5; y: 0; width: 2; height: 7; radius: 1; color: "#8a8580" }
                        Rectangle { x: 3; y: 0; width: 6; height: 2; radius: 1; color: "#8a8580" }
                    }
                    Text {
                        text: lang === "zh" ? "从文件夹移除" : "Remove from Folder"
                        color: _inkLight; font.pixelSize: 13
                    }
                }

                MouseArea {
                    id: removeFolderMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.removeBookFromFolder(root._menuBookId, root._currentFolderId)
                        root._loadFolders()
                        root._applyFilter()
                        root._menuBookId = ""
                    }
                }
            }

            // Separator
            Rectangle {
                width: menuCol.width - 16; height: 1
                anchors.horizontalCenter: parent.horizontalCenter; color: "#c5c2be"
            }

            // Delete
            Rectangle {
                width: menuCol.width; height: 36; radius: 6
                color: delMa.containsMouse ? "#30c05050" : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: lang === "zh" ? "删除" : "Delete"; color: "#c05050"; font.pixelSize: 13
                }
                MouseArea {
                    id: delMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var books = backend.deleteBook(root._menuBookId)
                        root.refresh(books); root._menuBookId = ""
                    }
                }
            }
        }
    }

    // ── Folder Select Submenu (appears next to main menu) ──
    Rectangle {
        id: folderSelectMenu
        visible: root._folderSelectOpen && root._menuBookId !== ""; z: 210
        x: bookMenu.x + bookMenu.width + 4
        y: bookMenu.y
        width: 160; height: folderSelectCol.implicitHeight + 12
        radius: 12; color: "#eeecea"; border.color: "#c8c5c0"

        Rectangle {
            anchors.fill: parent; anchors.margins: 1; radius: 11
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#18ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        Column {
            id: folderSelectCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 6; spacing: 2

            // No folders hint
            Text {
                visible: root._folders.length === 0
                text: lang === "zh" ? "  暂无文件夹" : "  No folders"
                color: _inkDim; font.pixelSize: 12
                padding: 8
            }

            Repeater {
                model: root._folders

                Rectangle {
                    width: folderSelectCol.width; height: 34; radius: 6
                    color: folderSelMa.containsMouse ? "#25a09888" : "transparent"

                    RowLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        spacing: 6
                        // Ink-wash folder icon
                        Item {
                            width: 14; height: 12; Layout.alignment: Qt.AlignVCenter
                            Rectangle { x: 0; y: 3; width: 12; height: 8; radius: 1.5; color: "#c8c0b0"; border.color: "#a89880"; border.width: 0.5 }
                            Rectangle { x: 0; y: 1; width: 6; height: 3.5; radius: 1; color: "#b8b0a0" }
                        }
                        Text {
                            text: modelData.name || ""
                            color: _inkLight; font.pixelSize: 13
                        }
                    }

                    MouseArea {
                        id: folderSelMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            backend.addBookToFolder(root._folderMenuBookId, modelData.id)
                            root._loadFolders()
                            root._applyFilter()
                            root._folderSelectOpen = false
                            root._menuBookId = ""
                        }
                    }
                }
            }
        }
    }

    // ── Folder Context Menu (right-click on folder chip) ──
    MouseArea {
        anchors.fill: parent
        visible: folderContextMenu.visible; z: 290
        onClicked: folderContextMenu.visible = false
    }

    Rectangle {
        id: folderContextMenu
        visible: false; z: 300
        width: 140; height: folderCtxCol.implicitHeight + 12
        radius: 12; color: "#eeecea"; border.color: "#c8c5c0"

        property string folderId: ""
        property string folderName: ""

        Rectangle {
            anchors.fill: parent; anchors.margins: 1; radius: 11
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#18ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }

        Column {
            id: folderCtxCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 6; spacing: 2

            Rectangle {
                width: folderCtxCol.width; height: 34; radius: 6
                color: renFolderMa.containsMouse ? "#25a09888" : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: lang === "zh" ? "重命名" : "Rename"; color: _inkLight; font.pixelSize: 13
                }
                MouseArea {
                    id: renFolderMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        renameFolderInput.text = folderContextMenu.folderName
                        renameFolderOverlay.folderId = folderContextMenu.folderId
                        renameFolderOverlay.visible = true
                        folderContextMenu.visible = false
                        renameFolderInput.forceActiveFocus()
                    }
                }
            }

            Rectangle {
                width: folderCtxCol.width - 16; height: 1
                anchors.horizontalCenter: parent.horizontalCenter; color: "#c5c2be"
            }

            Rectangle {
                width: folderCtxCol.width; height: 34; radius: 6
                color: delFolderMa.containsMouse ? "#30c05050" : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: lang === "zh" ? "删除文件夹" : "Delete Folder"; color: "#c05050"; font.pixelSize: 13
                }
                MouseArea {
                    id: delFolderMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        backend.deleteFolder(folderContextMenu.folderId)
                        if (root._currentFolderId === folderContextMenu.folderId)
                            root._currentFolderId = ""
                        root._loadFolders()
                        root._applyFilter()
                        folderContextMenu.visible = false
                    }
                }
            }
        }
    }

    // ── Rename Folder Overlay ──
    Rectangle {
        id: renameFolderOverlay
        visible: false; z: 400
        anchors.fill: parent
        color: "#66282828"

        property string folderId: ""

        MouseArea { anchors.fill: parent; onClicked: renameFolderOverlay.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: 320; height: 120; radius: 16
            color: "#eeecea"; border.color: "#c8c5c0"

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24; spacing: 16

                Text {
                    text: lang === "zh" ? "重命名文件夹" : "Rename Folder"
                    color: _ink; font.pixelSize: 16; font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: 10; Layout.fillWidth: true

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: "#15a09888"; border.color: "#30a09888"

                        TextInput {
                            id: renameFolderInput
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            color: _ink; font.pixelSize: 14
                            clip: true; selectByMouse: true
                            onAccepted: {
                                if (text.trim() !== "") {
                                    backend.renameFolder(renameFolderOverlay.folderId, text.trim())
                                    root._loadFolders()
                                }
                                renameFolderOverlay.visible = false
                            }
                        }
                    }

                    Rectangle {
                        width: 60; height: 36; radius: 10
                        color: confirmRenameMa.containsMouse ? "#35a09888" : "#20a09888"
                        Text { anchors.centerIn: parent; text: "OK"; color: _inkLight; font.pixelSize: 14 }
                        MouseArea {
                            id: confirmRenameMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: renameFolderInput.accepted()
                        }
                    }
                }
            }
        }
    }

    // ── Import overlay ──
    Rectangle {
        id: importOverlay
        visible: false; z: 100; anchors.fill: parent
        color: "#aa2a2828"

        MouseArea { anchors.fill: parent; onClicked: importOverlay.visible = false }

        GlassPanel {
            anchors.centerIn: parent
            width: 460; height: 340
            color: "#eaeeecea"

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 30; spacing: 20

                Text {
                    text: lang === "zh" ? "导入书籍" : "Import Books"
                    color: _ink; font.pixelSize: 20; font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    id: dropZone
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 12
                    color: dropArea.containsDrag ? "#30a09888" : "#15a09888"
                    border.color: dropArea.containsDrag ? "#70a09888" : "#35a09888"
                    border.width: 2

                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 12
                        Text { text: "⬆"; color: _inkDim; font.pixelSize: 48; Layout.alignment: Qt.AlignHCenter }
                        Text { text: lang === "zh" ? "拖放文件到此处" : "Drag files here"; color: _inkLight; font.pixelSize: 15; Layout.alignment: Qt.AlignHCenter }
                        Text { text: lang === "zh" ? "支持 .txt .epub .pdf .mobi 格式" : "Supports .txt .epub .pdf .mobi"; color: _inkDim; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
                    }

                    DropArea {
                        id: dropArea; anchors.fill: parent; keys: ["text/uri-list"]
                        onDropped: function(drop) {
                            if (!backend) return
                            var urls = []
                            if (drop.hasUrls) {
                                for (var i = 0; i < drop.urls.length; i++) {
                                    var u = drop.urls[i].toString().toLowerCase()
                                    if (u.endsWith(".txt") || u.endsWith(".epub") || u.endsWith(".pdf") || u.endsWith(".mobi"))
                                        urls.push(drop.urls[i].toString())
                                }
                            }
                            if (urls.length > 0) {
                                var books = backend.importFiles(urls)
                                root.refresh(books); importOverlay.visible = false
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fileDialog.open() }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 42; radius: 10
                    color: browseMa.containsMouse ? "#35a09888" : "#20a09888"
                    border.color: "#30a09888"
                    Text { anchors.centerIn: parent; text: lang === "zh" ? "📁  浏览文件" : "📁  Browse Files"; color: _inkLight; font.pixelSize: 14 }
                    MouseArea { id: browseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fileDialog.open() }
                }
            }

            Text {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
                text: "✕"; color: _inkDim; font.pixelSize: 18
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: importOverlay.visible = false }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Import Books"; fileMode: FileDialog.OpenFiles
        nameFilters: ["Books (*.txt *.epub *.pdf *.mobi)", "Text files (*.txt)", "EPUB files (*.epub)", "PDF files (*.pdf)", "MOBI files (*.mobi)"]
        onAccepted: {
            if (!backend) return
            var picked = []
            if (fileDialog.files && fileDialog.files.length > 0) picked = fileDialog.files
            else if (fileDialog.currentFiles && fileDialog.currentFiles.length > 0) picked = fileDialog.currentFiles
            else if (fileDialog.file && fileDialog.file.toString() !== "") picked = [fileDialog.file]
            else if (fileDialog.currentFile && fileDialog.currentFile.toString() !== "") picked = [fileDialog.currentFile]
            if (picked.length > 0) {
                var urls = []
                for (var k = 0; k < picked.length; k++) urls.push(picked[k].toString())
                var books = backend.importFiles(urls)
                root.refresh(books); importOverlay.visible = false
            }
        }
    }

    Component.onCompleted: { if (backend) { backend.ensureCovers(); root.refresh(backend.listBooks()) } }
    Connections { target: backend || null; function onCoversUpdated() { root.refresh(backend.listBooks()) } }
}
