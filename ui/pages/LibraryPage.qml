import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt.labs.platform as Platform
import "../components"
import "../theme"

/*  LibraryPage – 书库：常驻搜索、状态分段筛选、文件夹、拖入导入、右键菜单  */
Item {
    id: root
    signal bookSelected(var book)
    signal importRequested(var urls)

    property var model
    property string lang: "zh"
    property string _filterStatus: ""
    property string _searchText: ""
    property var _allBooks: []

    // Folder state
    property var _folders: []
    property string _currentFolderId: ""   // "" = all books
    readonly property string _currentFolderName: {
        for (var i = 0; i < _folders.length; i++)
            if (_folders[i].id === _currentFolderId) return _folders[i].name
        return ""
    }

    // Book drag (into a folder card)
    property string _dragBookId: ""
    property bool _dragActive: false
    property string _dragCover: ""
    property string _dragTitle: ""
    property real _dragProxyX: 0
    property real _dragProxyY: 0

    // Target of the open context menu
    property var _menuItem: ({})

    function zh(a, b) { return lang === "zh" ? a : b }
    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }

    function focusSearch() { searchField.forceActiveFocus(); searchField.selectAll() }
    function openImportDialog() { fileDialog.open() }

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
                    status:          b.status          || "",
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

        var folderBookIdSet = {}
        for (var fi0 = 0; fi0 < root._folders.length; fi0++) {
            var fids0 = root._folders[fi0].book_ids || []
            for (var fj0 = 0; fj0 < fids0.length; fj0++) folderBookIdSet[fids0[fj0]] = true
        }

        // Top level without a status filter shows folders first
        if (root._currentFolderId === "" && fs === "") {
            for (var fi = 0; fi < root._folders.length; fi++) {
                var folder = root._folders[fi]
                if (q !== "" && folder.name.toLowerCase().indexOf(q) < 0) continue
                var fBookIds = folder.book_ids || []
                var covers = ["", "", "", ""]
                for (var ci = 0; ci < Math.min(4, fBookIds.length); ci++) {
                    for (var bi = 0; bi < root._allBooks.length; bi++) {
                        if (root._allBooks[bi].id === fBookIds[ci]) { covers[ci] = root._allBooks[bi].cover_path || ""; break }
                    }
                }
                model.append({
                    _type: "folder", id: folder.id, title: folder.name, author: "", cover_path: "",
                    status: "", reading_minutes: 0, path: "", format: "", _bookCount: fBookIds.length,
                    _cover1: covers[0], _cover2: covers[1], _cover3: covers[2], _cover4: covers[3]
                })
            }
        }

        var folderBookIds = null
        if (root._currentFolderId !== "") {
            for (var fi2 = 0; fi2 < root._folders.length; fi2++) {
                if (root._folders[fi2].id === root._currentFolderId) { folderBookIds = root._folders[fi2].book_ids || []; break }
            }
        }

        for (var i = 0; i < root._allBooks.length; i++) {
            var b = root._allBooks[i]
            if (folderBookIds !== null && folderBookIds.indexOf(b.id) < 0) continue
            // Searching or filtering reaches into folders; the plain top level hides filed books
            if (root._currentFolderId === "" && folderBookIdSet[b.id] && q === "" && fs === "") continue
            if (fs !== "" && b.status !== fs) continue
            if (q !== "" && b.title.toLowerCase().indexOf(q) < 0 && b.author.toLowerCase().indexOf(q) < 0) continue
            model.append({
                _type: "book", id: b.id, title: b.title, author: b.author, cover_path: b.cover_path,
                status: b.status, reading_minutes: b.reading_minutes, path: b.path, format: b.format,
                _bookCount: 0, _cover1: "", _cover2: "", _cover3: "", _cover4: ""
            })
        }
        if (grid.currentIndex >= model.count) grid.currentIndex = model.count - 1
    }

    function _enterFolder(id) { root._currentFolderId = id; grid.currentIndex = 0; _applyFilter() }
    function _leaveFolder() { root._currentFolderId = ""; grid.currentIndex = 0; _applyFilter() }

    function _openItem(item) {
        if (!item) return
        if (item._type === "folder") _enterFolder(item.id)
        else root.bookSelected(item)
    }

    function _showMenu(item, sourceItem, x, y) {
        root._menuItem = {
            _type: item._type, id: item.id, title: item.title, status: item.status
        }
        var p = sourceItem.mapToItem(root, x, y)
        var menu = item._type === "folder" ? folderMenu : bookMenu
        menu.popup(root, p.x, p.y)
    }

    function _setStatus(status) {
        root.refresh(backend.updateBookStatus(root._menuItem.id, status))
    }

    function _askDelete(item) {
        root._menuItem = { _type: item._type, id: item.id, title: item.title, status: item.status }
        if (item._type === "folder") {
            deleteDialog.title = zh("删除文件夹「" + item.title + "」", "Delete folder “" + item.title + "”")
            deleteDialog.message = zh("文件夹里的书会回到书库，不会被删除。", "Books inside go back to the library and are kept.")
            deleteDialog.confirmText = zh("删除文件夹", "Delete folder")
        } else {
            deleteDialog.title = zh("删除《" + item.title + "》", "Delete “" + item.title + "”")
            deleteDialog.message = zh("将从书库移除这本书，并删除导入副本、封面缓存和它的全部划线笔记。原始文件不受影响。此操作无法撤销。",
                                      "Removes the book with its imported copy, cover and all highlights. Your original file is untouched. This cannot be undone.")
            deleteDialog.confirmText = zh("删除", "Delete")
        }
        deleteDialog.open()
    }

    function _confirmDelete() {
        var item = root._menuItem
        if (item._type === "folder") {
            backend.deleteFolder(item.id)
            if (root._currentFolderId === item.id) root._currentFolderId = ""
            root._loadFolders()
            root._applyFilter()
        } else {
            root.refresh(backend.deleteBook(item.id))
        }
        grid.forceActiveFocus()
    }

    // ── Layout ──
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pagePadding
        anchors.rightMargin: Theme.pagePadding
        anchors.topMargin: 32
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: zh("书库", "Library")
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH1
                font.weight: Font.DemiBold
                Accessible.role: Accessible.Heading
            }
            Text {
                Layout.alignment: Qt.AlignBaseline
                Layout.leftMargin: 2
                visible: root._allBooks.length > 0
                text: root._allBooks.length + zh(" 本", root._allBooks.length === 1 ? " book" : " books")
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                font.features: Theme.tabular
            }

            Item { Layout.fillWidth: true }

            SearchField {
                id: searchField
                Layout.preferredWidth: Math.min(280, root.width * 0.28)
                placeholderText: zh("搜索书名或作者", "Search title or author")
                onTextChanged: { root._searchText = text; root._applyFilter() }
                Keys.onDownPressed: grid.forceActiveFocus()
            }
            AppButton {
                text: zh("新建文件夹", "New folder")
                iconName: "folder-plus"
                visible: root._currentFolderId === ""
                onClicked: { folderNameDialog.folderId = ""; folderNameDialog.openWith("") }
            }
            AppButton {
                text: zh("导入", "Import")
                iconName: "import"
                variant: "primary"
                onClicked: fileDialog.open()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root._allBooks.length > 0

            // Breadcrumb when inside a folder
            IconButton {
                visible: root._currentFolderId !== ""
                iconName: "arrow-left"
                label: zh("返回书库", "Back to library")
                onClicked: root._leaveFolder()
            }
            Text {
                visible: root._currentFolderId !== ""
                text: root._currentFolderName
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
                Layout.rightMargin: 8
            }

            SegmentedControl {
                value: root._filterStatus
                options: [
                    { label: zh("全部", "All"), value: "" },
                    { label: zh("待看", "To read"), value: "to_read" },
                    { label: zh("在看", "Reading"), value: "reading" },
                    { label: zh("已看", "Finished"), value: "read" }
                ]
                onActivated: (v) => { root._filterStatus = v; root._applyFilter() }
            }
            Item { Layout.fillWidth: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.leftMargin: -8
                anchors.rightMargin: -8
                clip: true
                visible: root.model && root.model.count > 0
                model: root.model
                readonly property int columns: Math.max(2, Math.floor(width / 188))
                cellWidth: Math.floor(width / columns)
                cellHeight: (cellWidth - 16) * 4 / 3 + 68
                activeFocusOnTab: true
                keyNavigationEnabled: true
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Accessible.name: zh("书库内容", "Library items")
                Accessible.role: Accessible.List

                onActiveFocusChanged: if (activeFocus && currentIndex < 0 && count > 0) currentIndex = 0
                Keys.onReturnPressed: root._openItem(root.model.get(currentIndex))
                Keys.onEnterPressed: root._openItem(root.model.get(currentIndex))
                Keys.onDeletePressed: if (currentIndex >= 0) root._askDelete(root.model.get(currentIndex))
                Keys.onBackPressed: if (root._currentFolderId !== "") root._leaveFolder()
                Keys.onMenuPressed: if (currentItem) root._showMenu(root.model.get(currentIndex), currentItem, 40, 40)
                Keys.onEscapePressed: (event) => {
                    if (root._currentFolderId !== "") { root._leaveFolder(); event.accepted = true }
                    else event.accepted = false
                }

                delegate: Item {
                    id: cell
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isFolder: model._type === "folder"
                    readonly property bool isCurrent: GridView.isCurrentItem && grid.activeFocus
                    Accessible.role: Accessible.ListItem
                    Accessible.name: model.title

                    FolderCard {
                        id: folderCard
                        anchors.fill: parent
                        visible: cell.isFolder
                        folderId: model.id
                        name: model.title
                        bookCount: model._bookCount
                        covers: [model._cover1, model._cover2, model._cover3, model._cover4]
                        lang: root.lang
                        current: cell.isCurrent
                        onOpen: root._enterFolder(model.id)
                        onMenuRequested: (x, y) => root._showMenu(model, folderCard, x, y)
                        onBookDropped: (bookId) => {
                            var fid = model.id
                            Qt.callLater(function() {
                                backend.addBookToFolder(bookId, fid)
                                root._loadFolders()
                                root._applyFilter()
                            })
                        }
                    }

                    BookCard {
                        id: bookCard
                        anchors.fill: parent
                        visible: !cell.isFolder
                        bookId: model.id
                        title: model.title
                        author: model.author
                        coverPath: model.cover_path
                        format: model.format
                        status: model.status
                        lang: root.lang
                        current: cell.isCurrent
                        dimmed: root._dragActive && root._dragBookId === model.id
                        onOpen: root.bookSelected(model)
                        onMenuRequested: (x, y) => root._showMenu(model, bookCard, x, y)
                        onDragStarted: {
                            root._dragBookId = model.id
                            root._dragCover = model.cover_path || ""
                            root._dragTitle = model.title || ""
                            root._dragActive = true
                        }
                        onDragMoved: (x, y) => {
                            var gp = bookCard.mapToItem(root, x, y)
                            root._dragProxyX = gp.x
                            root._dragProxyY = gp.y
                        }
                        onDragReleased: { dragProxy.Drag.drop(); dragCleanupTimer.start() }
                    }
                }
            }

            // Empty library: one clear way in
            EmptyState {
                anchors.centerIn: parent
                visible: root._allBooks.length === 0
                iconName: "library"
                title: zh("书库还是空的", "Your library is empty")
                detail: zh("把 TXT、EPUB、PDF 或 MOBI 文件拖进窗口，或从磁盘选择", "Drag TXT, EPUB, PDF or MOBI files into the window, or pick them from disk")
                actionText: zh("导入书籍", "Import books")
                actionIcon: "import"
                onAction: fileDialog.open()
            }

            // Nothing matches the search or filter
            EmptyState {
                anchors.centerIn: parent
                visible: root._allBooks.length > 0 && root.model && root.model.count === 0
                iconName: root._currentFolderId !== "" && root._searchText === "" && root._filterStatus === "" ? "folder" : "search"
                title: root._currentFolderId !== "" && root._searchText === "" && root._filterStatus === ""
                    ? zh("这个文件夹还没有书", "This folder is empty")
                    : zh("没有符合条件的书", "No matching books")
                detail: root._currentFolderId !== "" && root._searchText === "" && root._filterStatus === ""
                    ? zh("在书库里把书卡拖到文件夹上即可归入", "Drag a book onto the folder in the library to file it")
                    : ""
                actionText: root._searchText !== "" || root._filterStatus !== "" ? zh("清除筛选", "Clear filters") : ""
                onAction: { searchField.text = ""; root._filterStatus = ""; root._applyFilter() }
            }
        }
    }

    // ── Drag proxy (follows the cursor while a book is dragged) ──
    Rectangle {
        id: dragProxy
        x: root._dragProxyX - width / 2
        y: root._dragProxyY - height / 2
        width: 120; height: 160
        visible: root._dragActive
        z: 500
        radius: Theme.radiusM
        color: Theme.sunken
        border.color: Theme.accent
        border.width: 2
        clip: true

        Drag.active: root._dragActive
        Drag.keys: ["bookId"]
        Drag.mimeData: ({ "bookId": root._dragBookId })
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: root.fileUrl(root._dragCover)
            fillMode: Image.PreserveAspectCrop
            visible: root._dragCover !== ""
        }
        Text {
            anchors.centerIn: parent
            visible: root._dragCover === ""
            text: root._dragTitle.length > 0 ? root._dragTitle.charAt(0) : "?"
            color: Theme.textTertiary
            font.pixelSize: 32
        }
    }

    Timer {
        id: dragCleanupTimer
        interval: 50
        onTriggered: { root._dragActive = false; root._dragBookId = ""; root._dragCover = ""; root._dragTitle = "" }
    }

    // ── Menus ──
    AppMenu {
        id: bookMenu
        objectName: "bookMenu"
        AppMenuItem { text: zh("标为待看", "Mark as to read"); iconName: "bookmark"; enabled: root._menuItem.status !== "to_read"; onTriggered: root._setStatus("to_read") }
        AppMenuItem { text: zh("标为在看", "Mark as reading"); iconName: "book-open"; enabled: root._menuItem.status !== "reading"; onTriggered: root._setStatus("reading") }
        AppMenuItem { text: zh("标为已看", "Mark as finished"); iconName: "check"; enabled: root._menuItem.status !== "read"; onTriggered: root._setStatus("read") }
        MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
        AppMenu {
            id: folderSubMenu
            title: zh("移到文件夹", "Move to folder")
            AppMenuItem {
                text: zh("暂无文件夹", "No folders yet")
                enabled: false
                visible: root._folders.length === 0
                height: visible ? implicitHeight : 0
            }
            Instantiator {
                model: root._folders
                delegate: AppMenuItem {
                    text: modelData.name
                    iconName: "folder"
                    onTriggered: {
                        backend.addBookToFolder(root._menuItem.id, modelData.id)
                        root._loadFolders()
                        root._applyFilter()
                    }
                }
                onObjectAdded: (index, object) => folderSubMenu.insertItem(index + 1, object)
                onObjectRemoved: (index, object) => folderSubMenu.removeItem(object)
            }
        }
        AppMenuItem {
            text: zh("移出文件夹", "Remove from folder")
            iconName: "folder-minus"
            visible: root._currentFolderId !== ""
            height: visible ? implicitHeight : 0
            onTriggered: {
                backend.removeBookFromFolder(root._menuItem.id, root._currentFolderId)
                root._loadFolders()
                root._applyFilter()
            }
        }
        MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
        AppMenuItem { text: zh("删除…", "Delete…"); iconName: "trash"; destructive: true; onTriggered: root._askDelete(root._menuItem) }
    }

    AppMenu {
        id: folderMenu
        AppMenuItem { text: zh("打开", "Open"); iconName: "folder"; onTriggered: root._enterFolder(root._menuItem.id) }
        AppMenuItem {
            text: zh("重命名…", "Rename…")
            iconName: "pencil"
            onTriggered: { folderNameDialog.folderId = root._menuItem.id; folderNameDialog.openWith(root._menuItem.title) }
        }
        MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Theme.border } }
        AppMenuItem { text: zh("删除文件夹…", "Delete folder…"); iconName: "trash"; destructive: true; onTriggered: root._askDelete(root._menuItem) }
    }

    // ── Dialogs ──
    ConfirmDialog {
        id: deleteDialog
        objectName: "deleteDialog"
        onConfirmed: root._confirmDelete()
    }

    AppModal {
        id: folderNameDialog
        objectName: "folderNameDialog"
        property string folderId: ""   // "" = create
        title: folderId === "" ? zh("新建文件夹", "New folder") : zh("重命名文件夹", "Rename folder")
        preferredWidth: 380
        showClose: false

        function openWith(name) { nameField.text = name; open() }
        function commit() {
            var name = nameField.text.trim()
            if (name === "") return
            if (folderId === "") backend.createFolder(name)
            else backend.renameFolder(folderId, name)
            root._loadFolders()
            root._applyFilter()
            close()
        }
        onOpened: { nameField.forceActiveFocus(); nameField.selectAll() }

        TextField {
            id: nameField
            Layout.fillWidth: true
            implicitHeight: Theme.controlHeight
            placeholderText: zh("文件夹名称", "Folder name")
            color: Theme.text
            placeholderTextColor: Theme.textTertiary
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            leftPadding: 12
            Accessible.name: zh("文件夹名称", "Folder name")
            onAccepted: folderNameDialog.commit()
            background: Rectangle {
                radius: Theme.radiusM
                color: Theme.bg
                border.color: nameField.activeFocus ? Theme.accent : Theme.border
                border.width: nameField.activeFocus ? 1.5 : 1
            }
        }

        footer: [
            AppButton { text: zh("取消", "Cancel"); variant: "ghost"; onClicked: folderNameDialog.close() },
            AppButton {
                text: folderNameDialog.folderId === "" ? zh("创建", "Create") : zh("保存", "Save")
                variant: "primary"
                enabled: nameField.text.trim() !== ""
                onClicked: folderNameDialog.commit()
            }
        ]
    }

    Platform.FileDialog {
        id: fileDialog
        title: zh("导入书籍", "Import books")
        fileMode: Platform.FileDialog.OpenFiles
        nameFilters: [zh("电子书", "Books") + " (*.txt *.epub *.pdf *.mobi)"]
        onAccepted: {
            var urls = []
            for (var k = 0; k < fileDialog.files.length; k++) urls.push(fileDialog.files[k].toString())
            if (urls.length > 0) root.importRequested(urls)
        }
    }

    Component.onCompleted: { if (backend) { backend.ensureCovers(); root.refresh(backend.listBooks()) } }
    Connections { target: backend || null; function onCoversUpdated() { root.refresh(backend.listBooks()) } }
}
