import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"

Item {
    id: root
    signal bookSelected(var book)
    
    // Model should be exposed from main context or passed in.
    property var model

    property string _menuBookId: ""
    property real _menuX: 0
    property real _menuY: 0
    property string _filterStatus: ""      // "" = all, "to_read", "reading", "read"
    property string _searchText: ""
    property bool _searchActive: false
    property bool _filterOpen: false
    property var _allBooks: []              // cached full book list
    property real _filterBtnX: 0
    property real _filterBtnY: 0
    property string lang: "zh"  // Language property

    function refresh(books) {
        if (books) {
            // Deep-copy QVariantList into pure JS array so property access is reliable
            var arr = []
            for (var i = 0; i < books.length; i++) {
                var b = books[i]
                arr.push({
                    id:              b.id              || "",
                    title:           b.title           || "Untitled",
                    author:          b.author          || "",
                    cover_path:      b.cover_path      || "",
                    status:          b.status          || "to_read",
                    reading_minutes: b.reading_minutes  || 0,
                    path:            b.path            || "",
                    format:          b.format          || "txt"
                })
            }
            root._allBooks = arr
        }
        _applyFilter()
    }

    function _applyFilter() {
        if (!model) return
        model.clear()
        var fs = root._filterStatus
        var q = root._searchText.toLowerCase()
        for (var i = 0; i < root._allBooks.length; i++) {
            var b = root._allBooks[i]
            if (fs !== "" && b.status !== fs) continue
            if (q !== "") {
                if (b.title.toLowerCase().indexOf(q) < 0
                 && b.author.toLowerCase().indexOf(q) < 0) continue
            }
            model.append(b)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Text {
                text: lang === "zh" ? "书库" : "Library"
                color: "#ffffff"
                font.pixelSize: 32
                font.weight: Font.Light
            }

            // Search box
            Rectangle {
                Layout.preferredWidth: root._searchActive ? 260 : 36
                Layout.preferredHeight: 36
                radius: 18
                color: "#15ffffff"
                border.color: root._searchActive ? "#50ffffff" : "#25ffffff"
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8

                    // Search icon
                    Text {
                        text: "\uD83D\uDD0D"
                        color: "#80ffffff"
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
                        color: "#ffffff"
                        font.pixelSize: 14
                        clip: true
                        selectByMouse: true
                        onTextChanged: {
                            root._searchText = text
                            root._applyFilter()
                        }
                    }

                    // Placeholder
                    Text {
                        visible: root._searchActive && searchInput.text === ""
                        text: lang === "zh" ? "搜索书名或作者..." : "Search title or author..."
                        color: "#40ffffff"
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Clear button
                    Text {
                        visible: root._searchActive && searchInput.text !== ""
                        text: "✕"
                        color: "#60ffffff"
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
                width: filterRow.implicitWidth + 24
                height: 36; radius: 18
                color: root._filterStatus !== "" ? "#30ffffff" : "#20ffffff"
                border.color: root._filterStatus !== "" ? "#50ffffff" : "#30ffffff"

                RowLayout {
                    id: filterRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "▾"; color: "#90ffffff"; font.pixelSize: 12 }
                    Text {
                        text: root._filterStatus === "to_read" ? (lang === "zh" ? "待看" : "To Read")
                            : root._filterStatus === "reading" ? (lang === "zh" ? "在看" : "Reading")
                            : root._filterStatus === "read" ? (lang === "zh" ? "已看" : "Finished")
                            : (lang === "zh" ? "筛选" : "Filter")
                        color: "#ffffff"; font.pixelSize: 14
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var gp = filterBtn.mapToItem(root, 0, 0)
                        root._filterBtnX = gp.x
                        root._filterBtnY = gp.y
                        root._filterOpen = !root._filterOpen
                    }
                }
            }

            Rectangle {
                width: 100
                height: 36
                radius: 18
                color: "#20ffffff"
                border.color: "#30ffffff"
                
                Text {
                    anchors.centerIn: parent
                    text: lang === "zh" ? "+ 导入" : "+ Import"
                    color: "#ffffff"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: importOverlay.visible = true
                }
            }
        }

        // Grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 220
            cellHeight: 280
            model: root.model
            
            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight
                
                GlassPanel {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#cc1a1f26" // Darker card
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // Cover
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 12
                            Layout.bottomMargin: 0
                            radius: 8
                            clip: true
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: cover_path ? "file:///" + cover_path : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                            }
                        }
                        
                        // Meta
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 16
                            Layout.topMargin: 12
                            Layout.bottomMargin: 16
                            spacing: 4
                            
                            Text {
                                text: title
                                color: "#eeeeee"
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: author ? author : "Unknown Author"
                                color: "#80ffffff"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bookSelected(model)
                        onEntered: parent.border.color = "#60ffffff"
                        onExited: parent.border.color = "#30ffffff"
                    }

                    // Three-dot menu button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 14
                        anchors.bottomMargin: 12
                        width: 30; height: 30; radius: 15
                        color: dotMa.containsMouse ? "#50ffffff" : "#20ffffff"
                        z: 10

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 3.5; height: 3.5; radius: 1.75
                                    color: "#ccffffff"
                                }
                            }
                        }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._menuBookId = model.id
                                var gp = parent.mapToItem(root, 0, 0)
                                root._menuX = Math.min(gp.x - 130, root.width - 170)
                                root._menuY = Math.min(gp.y + parent.height + 4, root.height - 200)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ── Filter close overlay ──────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: root._filterOpen
        z: 40
        onClicked: root._filterOpen = false
    }

    // ── Filter dropdown (root level, above close overlay) ─────
    Rectangle {
        id: filterDropdown
        visible: root._filterOpen
        z: 200
        width: 140
        height: filterCol.implicitHeight + 12
        radius: 10
        color: "#2a2f3e"
        border.color: "#3a3f50"

        // Position below the filter button, right-aligned
        x: root._filterBtnX + (filterBtn ? filterBtn.width : 0) - width
        y: root._filterBtnY + (filterBtn ? filterBtn.height : 36) + 6

        Column {
            id: filterCol
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 6
            spacing: 2

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
                    width: filterCol.width; height: 34; radius: 4
                    color: {
                        if (root._filterStatus === modelData.value) return "#3a4055"
                        if (filterItemMa.containsMouse) return "#333850"
                        return "transparent"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 14
                        text: modelData.label
                        color: root._filterStatus === modelData.value ? "#ffffff" : "#cccccc"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: filterItemMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._filterStatus = modelData.value
                            root._filterOpen = false
                            root._applyFilter()
                        }
                    }
                }
            }
        }
    }

    // ── Book context menu overlay ─────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: root._menuBookId !== ""
        z: 150
        onClicked: root._menuBookId = ""
    }

    Rectangle {
        id: bookMenu
        visible: root._menuBookId !== ""
        z: 200
        x: root._menuX
        y: root._menuY
        width: 160
        height: menuCol.implicitHeight + 16
        radius: 8
        color: "#2a2f3e"
        border.color: "#3a3f50"

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: [
                    { text: "\u6DFB\u52A0\u5230\u5F85\u770B", status: "to_read" },
                    { text: "\u6DFB\u52A0\u5230\u5728\u770B", status: "reading" },
                    { text: "\u6DFB\u52A0\u5230\u5DF2\u770B", status: "read" }
                ]

                Rectangle {
                    width: menuCol.width
                    height: 36; radius: 4
                    color: statusMa.containsMouse ? "#3a4055" : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        text: modelData.text
                        color: "#dddddd"; font.pixelSize: 13
                    }

                    MouseArea {
                        id: statusMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var books = backend.updateBookStatus(root._menuBookId, modelData.status)
                            root.refresh(books)
                            root._menuBookId = ""
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width: menuCol.width - 16; height: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#3a3f50"
            }

            // Delete option
            Rectangle {
                width: menuCol.width
                height: 36; radius: 4
                color: delMa.containsMouse ? "#3a2020" : "transparent"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    text: lang === "zh" ? "删除" : "Delete"
                    color: "#ff6b6b"; font.pixelSize: 13
                }

                MouseArea {
                    id: delMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var books = backend.deleteBook(root._menuBookId)
                        root.refresh(books)
                        root._menuBookId = ""
                    }
                }
            }
        }
    }

    // ── Import overlay (drag-drop + browse) ────────────────────
    Rectangle {
        id: importOverlay
        visible: false; z: 100
        anchors.fill: parent
        color: "#cc000000"

        MouseArea { anchors.fill: parent; onClicked: importOverlay.visible = false }

        Rectangle {
            id: importCard
            anchors.centerIn: parent
            width: 460; height: 340; radius: 16
            color: "#1e2330"; border.color: "#30ffffff"

            MouseArea { anchors.fill: parent }  // block click-through

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 30
                spacing: 20

                Text {
                    text: "导入书籍"
                    color: "#ffffff"; font.pixelSize: 20; font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignHCenter
                }

                // Drop zone
                Rectangle {
                    id: dropZone
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 12
                    color: dropArea.containsDrag ? "#30ffffff" : "#10ffffff"
                    border.color: dropArea.containsDrag ? "#80ffffff" : "#25ffffff"
                    border.width: 2

                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 12

                        Text {
                            text: "⬆"
                            color: "#60ffffff"; font.pixelSize: 48
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "拖放文件到此处"
                            color: "#90ffffff"; font.pixelSize: 15
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "支持 .txt .epub 格式"
                            color: "#50ffffff"; font.pixelSize: 12
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: function(drop) {
                            if (!backend) return
                            var urls = []
                            if (drop.hasUrls) {
                                for (var i = 0; i < drop.urls.length; i++) {
                                    var u = drop.urls[i].toString()
                                    if (u.toLowerCase().endsWith(".txt") || u.toLowerCase().endsWith(".epub"))
                                        urls.push(u)
                                }
                            }
                            if (urls.length > 0) {
                                var books = backend.importFiles(urls)
                                root.refresh(books)
                                importOverlay.visible = false
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fileDialog.open()
                    }
                }

                // Browse button
                Rectangle {
                    Layout.fillWidth: true; height: 42; radius: 8
                    color: browseMa.containsMouse ? "#40ffffff" : "#25ffffff"
                    Text {
                        anchors.centerIn: parent
                        text: "📁  浏览文件"; color: "#ffffff"; font.pixelSize: 14
                    }
                    MouseArea {
                        id: browseMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: fileDialog.open()
                    }
                }
            }

            // Close button
            Text {
                anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 16
                text: "✕"; color: "#80ffffff"; font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: importOverlay.visible = false
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Import Books"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Books (*.txt *.epub)", "Text files (*.txt)", "EPUB files (*.epub)"]
        onAccepted: {
             if (!backend) { console.warn("[LibraryPage] backend not available"); return }
             var picked = []
             if (fileDialog.files && fileDialog.files.length > 0)
                 picked = fileDialog.files
             else if (fileDialog.currentFiles && fileDialog.currentFiles.length > 0)
                 picked = fileDialog.currentFiles
             else if (fileDialog.file && fileDialog.file.toString() !== "")
                 picked = [fileDialog.file]
             else if (fileDialog.currentFile && fileDialog.currentFile.toString() !== "")
                 picked = [fileDialog.currentFile]

             if (picked.length > 0) {
                 var urls = []
                 for (var k = 0; k < picked.length; k++)
                     urls.push(picked[k].toString())
                 var books = backend.importFiles(urls)
                 root.refresh(books)
                 importOverlay.visible = false
             }
        }
    }
    
    Component.onCompleted: {
        if (backend) {
            backend.ensureCovers()
            root.refresh(backend.listBooks())
        }
    }

    Connections {
        target: backend || null
        function onCoversUpdated() {
            root.refresh(backend.listBooks())
        }
    }
}
