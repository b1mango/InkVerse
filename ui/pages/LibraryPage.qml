import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt.labs.platform as Platform
import "../components"
import "../theme"

/*  LibraryPage – 书库视图：按侧栏范围（全部 / 想读 / 已读完 / 格式 / 收藏集）与搜索过滤，
    封面网格与列表两种视图，排序，右键与更多菜单，键盘导航，拖到侧栏收藏集，删除前确认。  */
Item {
    id: root
    signal bookSelected(var book, var sourceItem)
    signal importRequested(var urls)
    signal libraryChanged()
    signal viewModeChosen(string mode)
    signal sortModeChosen(string mode)

    property string lang: "zh"
    property var books: []
    property var collections: []
    property string scopeKey: "all"
    property string searchText: ""
    property string viewMode: "grid"
    property string sortMode: "recent"
    property var _menuBook: ({})
    property string hiddenBookId: ""     // cover currently flying to the reader

    // Book drag (onto a sidebar collection)
    property string _dragBookId: ""
    property bool _dragActive: false
    property string _dragCover: ""
    property real _dragProxyX: 0
    property real _dragProxyY: 0

    function zh(a, b) { return lang === "zh" ? a : b }
    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }
    function openImportDialog() { fileDialog.open() }

    readonly property string scopeKind: scopeKey.split(":")[0]
    readonly property string scopeValue: scopeKey.indexOf(":") > 0 ? scopeKey.substring(scopeKey.indexOf(":") + 1) : ""
    readonly property var scopeCollection: {
        if (scopeKind !== "collection") return null
        for (var i = 0; i < collections.length; i++) if (collections[i].id === scopeValue) return collections[i]
        return null
    }
    readonly property string scopeTitle: scopeKind === "status" ? (scopeValue === "read" ? zh("已读完", "Finished") : zh("想读", "Want to Read"))
        : scopeKind === "format" ? scopeValue.toUpperCase()
        : scopeKind === "collection" ? (scopeCollection ? scopeCollection.name : "")
        : zh("全部图书", "All Books")

    readonly property var visibleBooks: {
        var q = searchText.trim().toLowerCase()
        var ids = scopeCollection ? (scopeCollection.book_ids || []) : null
        var out = []
        for (var i = 0; i < books.length; i++) {
            var b = books[i]
            if (scopeKind === "status" && b.status !== scopeValue) continue
            if (scopeKind === "format" && b.format !== scopeValue) continue
            if (ids && ids.indexOf(b.id) < 0) continue
            if (q && (b.title || "").toLowerCase().indexOf(q) < 0 && (b.author || "").toLowerCase().indexOf(q) < 0) continue
            out.push(b)
        }
        var key = sortMode
        out.sort(function(a, b) {
            if (key === "title") return (a.title || "").localeCompare(b.title || "", "zh")
            if (key === "author") return (a.author || "~").localeCompare(b.author || "~", "zh") || (a.title || "").localeCompare(b.title || "", "zh")
            if (key === "added") return (b.added_at || 0) - (a.added_at || 0)
            return (b.last_opened || 0) - (a.last_opened || 0) || (b.added_at || 0) - (a.added_at || 0)
        })
        return out
    }

    function _setStatus(status) { backend.updateBookStatus(_menuBook.id, status); libraryChanged() }

    function _showMenu(book, sourceItem, x, y) {
        _menuBook = book
        var p = sourceItem.mapToItem(root, x, y)
        bookMenu.popup(root, p.x, p.y)
    }

    function _askDelete(book) {
        _menuBook = book
        deleteDialog.title = zh("删除《" + book.title + "》", "Delete “" + book.title + "”")
        deleteDialog.open()
    }

    function _currentView() { return viewMode === "list" ? list : grid }

    Shortcut { sequence: "Ctrl+1"; enabled: root.visible; onActivated: root.viewModeChosen("grid") }
    Shortcut { sequence: "Ctrl+2"; enabled: root.visible; onActivated: root.viewModeChosen("list") }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Toolbar ──
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.pagePadding
            Layout.rightMargin: Theme.pagePadding - 8
            Layout.topMargin: 28
            Layout.bottomMargin: 12
            spacing: 8

            Text {
                text: root.scopeTitle
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: root.width * 0.4
                Accessible.role: Accessible.Heading
            }
            Text {
                Layout.alignment: Qt.AlignBaseline
                visible: root.visibleBooks.length > 0
                text: root.visibleBooks.length + zh(" 本", root.visibleBooks.length === 1 ? " book" : " books")
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                font.features: Theme.tabular
            }
            Item { Layout.fillWidth: true }

            AppButton {
                id: sortButton
                variant: "ghost"
                compact: true
                iconName: "sort"
                text: root.sortMode === "title" ? zh("书名", "Title") : root.sortMode === "author" ? zh("作者", "Author")
                    : root.sortMode === "added" ? zh("添加时间", "Date added") : zh("最近阅读", "Recent")
                Accessible.name: zh("排序方式", "Sort by")
                onClicked: sortMenu.popup(sortButton, 0, sortButton.height + 4)
            }
            SegmentedControl {
                segmentHeight: 26
                value: root.viewMode
                options: [{ label: "", a11y: zh("封面网格", "Grid"), value: "grid", icon: "layout-grid" }, { label: "", a11y: zh("列表", "List"), value: "list", icon: "rows" }]
                onActivated: (v) => root.viewModeChosen(v)
                Accessible.name: zh("视图", "View")
            }
            AppButton {
                text: zh("导入", "Import")
                iconName: "import"
                variant: "primary"
                compact: true
                onClicked: fileDialog.open()
                ToolTip.visible: hovered
                ToolTip.delay: 400
                ToolTip.text: zh("支持 EPUB、MOBI、PDF、TXT，也可直接拖进窗口", "EPUB, MOBI, PDF and TXT; you can also drag files into the window")
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Cover grid ──
            GridView {
                id: grid
                objectName: "libraryGrid"
                anchors.fill: parent
                anchors.leftMargin: Theme.pagePadding - 12
                anchors.rightMargin: Theme.pagePadding - 12
                visible: root.viewMode === "grid" && root.visibleBooks.length > 0
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
                clip: true
                model: root.visibleBooks
                // Fixed shelf slot like a bookcase: covers are 132 px wide at every window size and
                // columns follow the width (1440 → 7, 1180 → 5, 960 → 4); spare width stays on the right
                cellWidth: 164
                cellHeight: (cellWidth - 32) * 1.45 + 80
                activeFocusOnTab: true
                keyNavigationEnabled: true
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Accessible.name: root.scopeTitle
                Accessible.role: Accessible.List
                onActiveFocusChanged: if (activeFocus && currentIndex < 0 && count > 0) currentIndex = 0
                Keys.onReturnPressed: if (currentItem) root.bookSelected(root.visibleBooks[currentIndex], currentItem.coverItem)
                Keys.onEnterPressed: if (currentItem) root.bookSelected(root.visibleBooks[currentIndex], currentItem.coverItem)
                Keys.onDeletePressed: if (currentIndex >= 0) root._askDelete(root.visibleBooks[currentIndex])
                Keys.onMenuPressed: if (currentItem) root._showMenu(root.visibleBooks[currentIndex], currentItem, 40, 40)

                delegate: BookTile {
                    id: tile
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    book: modelData
                    lang: root.lang
                    current: (GridView.isCurrentItem && grid.activeFocus) || (bookMenu.visible && root._menuBook.id === modelData.id)
                    hidden: root.hiddenBookId === modelData.id
                    dimmed: root._dragActive && root._dragBookId === modelData.id
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.title
                    onOpen: root.bookSelected(modelData, tile.coverItem)
                    onMenuRequested: (x, y) => root._showMenu(modelData, tile, x, y)
                    onDragStarted: { root._dragBookId = modelData.id; root._dragCover = modelData.cover_path || ""; root._dragActive = true }
                    onDragMoved: (x, y) => { var gp = tile.mapToItem(root, x, y); root._dragProxyX = gp.x; root._dragProxyY = gp.y }
                    onDragReleased: { dragProxy.Drag.drop(); dragCleanupTimer.start() }
                }
            }

            // ── List ──
            ListView {
                id: list
                objectName: "libraryList"
                anchors.fill: parent
                anchors.leftMargin: Theme.pagePadding
                anchors.rightMargin: Theme.pagePadding
                visible: root.viewMode === "list" && root.visibleBooks.length > 0
                clip: true
                model: root.visibleBooks
                activeFocusOnTab: true
                keyNavigationEnabled: true
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Accessible.name: root.scopeTitle
                Accessible.role: Accessible.List
                onActiveFocusChanged: if (activeFocus && currentIndex < 0 && count > 0) currentIndex = 0
                Keys.onReturnPressed: if (currentItem) root.bookSelected(root.visibleBooks[currentIndex], currentItem.thumb)
                Keys.onDeletePressed: if (currentIndex >= 0) root._askDelete(root.visibleBooks[currentIndex])
                Keys.onMenuPressed: if (currentItem) root._showMenu(root.visibleBooks[currentIndex], currentItem, 40, 30)

                header: Rectangle {
                    width: ListView.view.width
                    height: 30
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 54          // row padding 12 + thumb 30 + gap 12: header sits on the title
                        anchors.rightMargin: 48         // row padding 8 + more button 28 + gap 12
                        spacing: 12
                        Repeater {
                            model: [{ t: root.zh("书名", "Title"), w: -1 }, { t: root.zh("格式", "Format"), w: 64 }, { t: root.zh("进度", "Progress"), w: 120 }, { t: root.zh("添加时间", "Added"), w: 96 }]
                            Text {
                                Layout.fillWidth: modelData.w < 0
                                Layout.preferredWidth: modelData.w > 0 ? modelData.w : -1
                                text: modelData.t
                                color: Theme.textTertiary
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Medium
                            }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property alias thumb: thumbBox
                    readonly property real percent: modelData.progress && modelData.progress.percent !== undefined ? modelData.progress.percent : -1
                    width: ListView.view.width
                    height: 60
                    radius: Theme.radiusM
                    color: (ListView.isCurrentItem && list.activeFocus) || (bookMenu.visible && root._menuBook.id === modelData.id) ? Theme.accentSoft
                        : rowMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    Rectangle { anchors.bottom: parent.bottom; x: 12; width: parent.width - 24; height: 1; color: Theme.border; opacity: 0.7 }
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    opacity: root._dragActive && root._dragBookId === modelData.id ? 0.35 : 1
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.title

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 12
                        Rectangle {
                            id: thumbBox
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 42
                            radius: 2
                            color: Theme.sunken
                            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
                            clip: true
                            Image { anchors.fill: parent; anchors.margins: 1; source: root.fileUrl(row.modelData.cover_path); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.height: 96 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { Layout.fillWidth: true; text: row.modelData.title || ""; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontBody; font.weight: Font.Medium; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: row.modelData.author || root.zh("作者未知", "Unknown author"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; elide: Text.ElideRight }
                        }
                        Text { Layout.preferredWidth: 64; text: (row.modelData.format || "txt").toUpperCase(); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold; font.letterSpacing: 0.4 }
                        RowLayout {
                            Layout.preferredWidth: 120
                            spacing: 8
                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 4
                                radius: 2
                                color: Theme.sunken
                                visible: row.percent > 0 && row.modelData.status !== "read"
                                Rectangle { width: parent.width * Math.max(0, row.percent); height: parent.height; radius: 2; color: Theme.accent }
                            }
                            Text {
                                text: row.modelData.status === "read" ? root.zh("已读完", "Finished") : row.percent > 0 ? Math.max(1, Math.round(row.percent * 100)) + "%" : root.zh("未读", "New")
                                color: Theme.textSecondary
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontCaption
                                font.features: Theme.tabular
                            }
                        }
                        Text {
                            Layout.preferredWidth: 96
                            text: row.modelData.added_at ? Qt.formatDate(new Date(row.modelData.added_at * 1000), "yyyy-MM-dd") : "—"
                            color: Theme.textTertiary
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontCaption
                            font.features: Theme.tabular
                        }
                        IconButton {
                            id: rowMore
                            implicitWidth: 28; implicitHeight: 28; iconSize: 15
                            iconName: "ellipsis"
                            label: root.zh("更多操作", "More")
                            focusPolicy: Qt.NoFocus
                            opacity: rowMouse.containsMouse || hovered ? 1 : 0
                            onClicked: root._showMenu(row.modelData, rowMore, 0, rowMore.height + 4)
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property real _px: 0
                        property real _py: 0
                        property bool _dragging: false
                        onPressed: (m) => { _px = m.x; _py = m.y; _dragging = false }
                        onPositionChanged: (m) => {
                            if (!pressed || !(pressedButtons & Qt.LeftButton)) return
                            if (!_dragging && Math.abs(m.x - _px) + Math.abs(m.y - _py) > 16) {
                                _dragging = true
                                root._dragBookId = row.modelData.id; root._dragCover = row.modelData.cover_path || ""; root._dragActive = true
                            }
                            if (_dragging) { var gp = mapToItem(root, m.x, m.y); root._dragProxyX = gp.x; root._dragProxyY = gp.y }
                        }
                        onReleased: if (_dragging) { dragProxy.Drag.drop(); dragCleanupTimer.start() }
                        onClicked: (m) => {
                            if (_dragging) return
                            if (m.button === Qt.RightButton) root._showMenu(row.modelData, row, m.x, m.y)
                            else { list.currentIndex = row.index }
                        }
                        onDoubleClicked: root.bookSelected(row.modelData, thumbBox)
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: root.books.length === 0
                iconName: "library"
                title: zh("书库还是空的", "Your library is empty")
                detail: zh("把文件拖进窗口，或点击下方导入\n支持 EPUB · MOBI · PDF · TXT", "Drag files into the window or import them below\nEPUB · MOBI · PDF · TXT")
                actionText: zh("导入书籍", "Import books")
                actionIcon: "import"
                onAction: fileDialog.open()
            }
            EmptyState {
                anchors.centerIn: parent
                visible: root.books.length > 0 && root.visibleBooks.length === 0
                iconName: root.searchText !== "" ? "search" : root.scopeKind === "collection" ? "layers" : root.scopeKind === "format" ? "file-text" : "bookmark"
                title: root.searchText !== "" ? zh("没有找到相关的书", "No matching books")
                    : root.scopeKind === "collection" ? zh("这个收藏集还是空的", "This collection is empty")
                    : root.scopeKind === "format" ? zh("书库里还没有 " + root.scopeValue.toUpperCase() + " 文件", "No " + root.scopeValue.toUpperCase() + " books yet")
                    : root.scopeValue === "read" ? zh("还没有读完的书", "Nothing finished yet") : zh("还没有想读的书", "Nothing marked to read")
                detail: root.searchText !== "" ? zh("换个书名或作者试试", "Try another title or author")
                    : root.scopeKind === "collection" ? zh("在全部图书里把封面拖到左侧的收藏集上", "Drag covers onto the collection in the sidebar")
                    : root.scopeKind === "status" ? zh("在书的右键菜单里标记", "Use the book’s context menu to mark it") : ""
            }
        }
    }

    // ── Drag proxy ──
    Rectangle {
        id: dragProxy
        x: root._dragProxyX - width / 2
        y: root._dragProxyY - height / 2
        width: 72; height: 100
        visible: root._dragActive
        z: 500
        radius: 3
        color: Theme.sunken
        border.color: Theme.accent
        border.width: 2
        rotation: -3
        Drag.active: root._dragActive
        Drag.keys: ["bookId"]
        Drag.mimeData: ({ "bookId": root._dragBookId })
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Image { anchors.fill: parent; anchors.margins: 2; source: root.fileUrl(root._dragCover); fillMode: Image.PreserveAspectCrop }
    }
    Timer { id: dragCleanupTimer; interval: 50; onTriggered: { root._dragActive = false; root._dragBookId = ""; root._dragCover = "" } }

    // ── Menus ──
    AppMenu {
        id: sortMenu
        Repeater {
            model: [{ v: "recent", t: root.zh("最近阅读", "Recent") }, { v: "title", t: root.zh("书名", "Title") }, { v: "author", t: root.zh("作者", "Author") }, { v: "added", t: root.zh("添加时间", "Date added") }]
            AppMenuItem { text: modelData.t; iconName: root.sortMode === modelData.v ? "check" : ""; onTriggered: root.sortModeChosen(modelData.v) }
        }
    }

    AppMenu {
        id: bookMenu
        objectName: "bookMenu"
        AppMenuItem { text: zh("打开", "Open"); iconName: "book-open"; onTriggered: root.bookSelected(root._menuBook, null) }
        MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
        AppMenuItem { text: root._menuBook.status === "to_read" ? zh("移出想读", "Remove from Want to Read") : zh("加入想读", "Add to Want to Read"); iconName: "bookmark"; onTriggered: root._setStatus(root._menuBook.status === "to_read" ? "" : "to_read") }
        AppMenuItem { text: root._menuBook.status === "read" ? zh("标为未读完", "Mark as unfinished") : zh("标为已读完", "Mark as finished"); iconName: "circle-check"; onTriggered: root._setStatus(root._menuBook.status === "read" ? "" : "read") }
        AppMenu {
            id: collectionSubMenu
            title: zh("加入收藏集", "Add to collection")
            AppMenuItem { text: zh("还没有收藏集", "No collections yet"); enabled: false; visible: root.collections.length === 0; height: visible ? implicitHeight : 0 }
            Instantiator {
                model: root.collections
                delegate: AppMenuItem {
                    text: modelData.name
                    iconName: "layers"
                    onTriggered: { backend.addBookToFolder(root._menuBook.id, modelData.id); root.libraryChanged() }
                }
                onObjectAdded: (index, object) => collectionSubMenu.insertItem(index + 1, object)
                onObjectRemoved: (index, object) => collectionSubMenu.removeItem(object)
            }
        }
        AppMenuItem {
            text: zh("从此收藏集移除", "Remove from collection")
            iconName: "folder-minus"
            visible: root.scopeKind === "collection"
            height: visible ? implicitHeight : 0
            onTriggered: { backend.removeBookFromFolder(root._menuBook.id, root.scopeValue); root.libraryChanged() }
        }
        AppMenuItem { text: Qt.platform.os === "osx" ? zh("在访达中显示", "Show in Finder") : zh("在文件夹中显示", "Show in folder"); iconName: "folder-open"; onTriggered: backend.revealBookFile(root._menuBook.id) }
        MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
        AppMenuItem { text: zh("删除…", "Delete…"); iconName: "trash"; destructive: true; onTriggered: root._askDelete(root._menuBook) }
    }

    ConfirmDialog {
        id: deleteDialog
        objectName: "deleteDialog"
        message: zh("将从书库移除这本书，并删除导入副本、封面缓存、书签和全部划线笔记。原始文件不受影响，此操作无法撤销。",
                    "Removes the book with its imported copy, cover, bookmarks and highlights. Your original file is untouched. This cannot be undone.")
        confirmText: zh("删除", "Delete")
        onConfirmed: { backend.deleteBook(root._menuBook.id); root.libraryChanged(); root._currentView().forceActiveFocus() }
    }

    Platform.FileDialog {
        id: fileDialog
        title: zh("导入书籍", "Import books")
        fileMode: Platform.FileDialog.OpenFiles
        nameFilters: [zh("电子书", "Books") + " (*.epub *.mobi *.pdf *.txt)"]
        onAccepted: {
            var urls = []
            for (var k = 0; k < fileDialog.files.length; k++) urls.push(fileDialog.files[k].toString())
            if (urls.length > 0) root.importRequested(urls)
        }
    }
}
