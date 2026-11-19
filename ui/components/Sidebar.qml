import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  Sidebar – 书库导航：搜索、继续阅读、全部 / 想读 / 已读完、按格式、收藏集
    格式分组是墨界相对「图书」的差异点：TXT、EPUB、MOBI、PDF 各有入口与计数。
    收藏集行接受书卡拖放；右键可重命名或删除。  */
Rectangle {
    id: root
    color: Theme.sidebar
    property string lang: "zh"
    property var books: []
    property var collections: []
    property string currentKey: "now"          // now | all | status:<s> | format:<f> | collection:<id> | settings
    property alias searchText: search.text
    signal navigate(string key)
    signal collectionsEdited()

    function zh(a, b) { return lang === "zh" ? a : b }
    function focusSearch() { search.forceActiveFocus(); search.selectAll() }
    function count(pred) { var n = 0; for (var i = 0; i < books.length; i++) if (pred(books[i])) n++; return n }

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 13
        anchors.topMargin: 18
        anchors.bottomMargin: 12
        spacing: 0

        Row {
            Layout.leftMargin: 8
            Layout.bottomMargin: 14
            spacing: 8
            Text { id: mark; text: "墨界"; color: Theme.text; font.family: Theme.brandFont; font.pixelSize: 26; Accessible.name: "墨界 InkVerse" }
            Text {
                anchors.baseline: mark.baseline
                text: "InkVerse"
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontCaption
                font.letterSpacing: 0.5
            }
        }

        SearchBox {
            id: search
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            implicitHeight: 32
            placeholderText: zh("搜索书名或作者", "Search")
            onTextChanged: if (text !== "" && !root.currentKey.match(/^(all|status|format|collection)/)) root.navigate("all")
            Keys.onDownPressed: root.navigate(root.currentKey === "now" ? "all" : root.currentKey)
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: nav.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: nav
                width: parent.width
                spacing: 2

                Section { text: zh("书库", "Library") ; Layout.topMargin: 0 }
                NavRow { key: "now"; text: zh("继续阅读", "Reading Now"); iconName: "book-open" }
                NavRow { key: "all"; text: zh("全部图书", "All Books"); iconName: "library"; badge: root.books.length }
                NavRow { key: "status:to_read"; text: zh("想读", "Want to Read"); iconName: "bookmark"; badge: root.count(function(b) { return b.status === "to_read" }) }
                NavRow { key: "status:read"; text: zh("已读完", "Finished"); iconName: "circle-check"; badge: root.count(function(b) { return b.status === "read" }) }

                Section { text: zh("格式", "Formats") }
                Repeater {
                    model: [
                        { f: "epub", label: "EPUB", icon: "book" },
                        { f: "mobi", label: "MOBI", icon: "book" },
                        { f: "pdf", label: "PDF", icon: "file-text" },
                        { f: "txt", label: "TXT", icon: "type" }
                    ]
                    NavRow {
                        required property var modelData
                        key: "format:" + modelData.f
                        text: modelData.label
                        iconName: modelData.icon
                        badge: root.count(function(b) { return b.format === modelData.f })
                        showZero: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 20
                    Layout.bottomMargin: 4
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        text: zh("收藏集", "Collections")
                        color: Theme.textTertiary
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }
                    IconButton {
                        implicitWidth: 26; implicitHeight: 26; iconSize: 15
                        iconName: "plus"
                        label: zh("新建收藏集", "New collection")
                        onClicked: nameDialog.openFor("", "")
                    }
                }
                Repeater {
                    model: root.collections
                    NavRow {
                        id: collectionRow
                        required property var modelData
                        key: "collection:" + modelData.id
                        text: modelData.name
                        iconName: "layers"
                        badge: (modelData.book_ids || []).length
                        acceptsBooks: true
                        onBookDropped: (bookId) => { backend.addBookToFolder(bookId, modelData.id); root.collectionsEdited() }
                        onMenuRequested: { collectionMenu.target = modelData; collectionMenu.popup() }
                    }
                }
                Text {
                    visible: root.collections.length === 0 && root.books.length > 0
                    Layout.leftMargin: 10
                    Layout.topMargin: 2
                    text: zh("新建收藏集后，把书拖进去", "Create a collection, then drag books in")
                    color: Theme.textTertiary
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 8; implicitHeight: 1; color: Theme.border }
        RowLayout {
            Layout.fillWidth: true
            NavRow { key: "settings"; text: zh("设置", "Settings"); iconName: "settings"; Layout.fillWidth: true }
            Text {
                Layout.rightMargin: 8
                text: typeof appVersion !== "undefined" ? "v" + appVersion : ""
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.features: Theme.tabular
            }
        }
    }

    component Section: Text {
        Layout.topMargin: 20
        Layout.bottomMargin: 4
        Layout.leftMargin: 10
        color: Theme.textTertiary
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
    }

    component NavRow: AbstractButton {
        id: row
        property string key
        property string iconName
        property int badge: -1
        property bool showZero: false
        property bool dimmed: false
        property bool acceptsBooks: false
        readonly property bool selected: root.currentKey === key
        signal bookDropped(string bookId)
        signal menuRequested()

        Layout.fillWidth: true
        implicitHeight: 32
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        Accessible.role: Accessible.PageTab
        Accessible.selected: selected
        onClicked: root.navigate(key)

        background: Rectangle {
            radius: Theme.radiusM
            color: drop.containsDrag ? Theme.accentSoft
                : row.selected ? Theme.surface
                : row.hovered ? Theme.surfaceHover : "transparent"
            border.color: drop.containsDrag ? Theme.accent : (row.selected ? Theme.border : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            FocusRing { shown: row.visualFocus }
        }
        contentItem: RowLayout {
            spacing: 10
            LucideIcon {
                Layout.leftMargin: 10
                name: row.iconName
                size: 17
                color: row.selected ? Theme.accentText : Theme.textSecondary
                opacity: row.dimmed ? 0.5 : 1
            }
            Text {
                Layout.fillWidth: true
                text: row.text
                color: row.selected ? Theme.text : Theme.textSecondary
                opacity: row.dimmed ? 0.6 : 1
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                Layout.rightMargin: 10
                visible: row.badge > 0 || (row.showZero && row.badge === 0)
                text: row.badge
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontCaption
                font.features: Theme.tabular
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            enabled: row.acceptsBooks
            onClicked: row.menuRequested()
        }
        DropArea {
            id: drop
            anchors.fill: parent
            enabled: row.acceptsBooks
            keys: ["bookId"]
            onDropped: (d) => { var id = d.getDataAsString("bookId"); if (id) row.bookDropped(id) }
        }
    }

    AppMenu {
        id: collectionMenu
        property var target: ({})
        AppMenuItem { text: zh("重命名…", "Rename…"); iconName: "pencil"; onTriggered: nameDialog.openFor(collectionMenu.target.id, collectionMenu.target.name) }
        AppMenuItem {
            text: zh("删除收藏集…", "Delete collection…")
            iconName: "trash"
            destructive: true
            onTriggered: {
                deleteDialog.targetId = collectionMenu.target.id
                deleteDialog.title = zh("删除收藏集「" + collectionMenu.target.name + "」", "Delete “" + collectionMenu.target.name + "”")
                deleteDialog.open()
            }
        }
    }

    ConfirmDialog {
        id: deleteDialog
        property string targetId: ""
        message: zh("只删除这个收藏集，里面的书仍留在书库。", "Only the collection is removed; its books stay in the library.")
        confirmText: zh("删除收藏集", "Delete collection")
        onConfirmed: {
            backend.deleteFolder(targetId)
            if (root.currentKey === "collection:" + targetId) root.navigate("all")
            root.collectionsEdited()
        }
    }

    AppModal {
        id: nameDialog
        objectName: "collectionNameDialog"
        property string targetId: ""
        title: targetId === "" ? zh("新建收藏集", "New collection") : zh("重命名收藏集", "Rename collection")
        preferredWidth: 380
        showClose: false
        function openFor(id, name) { targetId = id; nameField.text = name; open() }
        function commit() {
            var name = nameField.text.trim()
            if (name === "") return
            if (targetId === "") backend.createFolder(name)
            else backend.renameFolder(targetId, name)
            root.collectionsEdited()
            close()
        }
        onOpened: { nameField.forceActiveFocus(); nameField.selectAll() }

        TextField {
            id: nameField
            Layout.fillWidth: true
            implicitHeight: Theme.controlHeight
            placeholderText: zh("收藏集名称", "Collection name")
            color: Theme.text
            placeholderTextColor: Theme.textTertiary
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            leftPadding: 12
            Accessible.name: zh("收藏集名称", "Collection name")
            onAccepted: nameDialog.commit()
            background: Rectangle {
                radius: Theme.radiusM
                color: Theme.bg
                border.color: nameField.activeFocus ? Theme.accent : Theme.border
                border.width: nameField.activeFocus ? 1.5 : 1
            }
        }
        footer: [
            AppButton { text: zh("取消", "Cancel"); variant: "ghost"; onClicked: nameDialog.close() },
            AppButton { text: nameDialog.targetId === "" ? zh("创建", "Create") : zh("保存", "Save"); variant: "primary"; enabled: nameField.text.trim() !== ""; onClicked: nameDialog.commit() }
        ]
    }
}
