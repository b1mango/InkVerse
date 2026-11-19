import QtQuick
import QtQuick.Layouts
import "../theme"

/*  BookTile – 封面网格单元：封面按原比例底对齐并带柔和投影，悬停微微抬起；
    下方是书名、阅读状态（未读 / 百分比 / 已读完）与格式标签。按下拖动可放进收藏集。  */
Item {
    id: tile
    property var book: ({})
    property string lang: "zh"
    property bool current: false
    property bool dimmed: false
    property bool hidden: false          // the cover is flying to the reader
    readonly property alias coverItem: coverFrame
    signal open()
    signal menuRequested(real x, real y)
    signal dragStarted()
    signal dragMoved(real x, real y)
    signal dragReleased()

    function zh(a, b) { return lang === "zh" ? a : b }
    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }
    readonly property real percent: book.progress && book.progress.percent !== undefined ? book.progress.percent : -1
    readonly property string stateText: book.status === "read" ? zh("已读完", "Finished")
        : percent > 0.995 ? zh("已读完", "Finished")
        : percent > 0 ? Math.max(1, Math.round(percent * 100)) + "%"
        : zh("未读", "New")

    opacity: hidden ? 0 : dimmed ? 0.35 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

    // Cover slot: covers sit on a shared baseline like books on a shelf
    Item {
        id: slot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: width * 1.45

        Item {
            id: coverFrame
            readonly property real coverW: image.status === Image.Ready && image.implicitHeight > 0
                ? Math.min(slot.width, slot.height * image.implicitWidth / image.implicitHeight) : slot.width
            readonly property real coverH: image.status === Image.Ready && image.implicitWidth > 0
                ? coverW * image.implicitHeight / image.implicitWidth : slot.width * 4 / 3
            width: coverW
            height: Math.min(coverH, slot.height)
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            transformOrigin: Item.Bottom
            opacity: tile.hidden ? 0 : 1
            scale: mouse.pressed ? 0.98 : (mouse.containsMouse || tile.current ? 1.03 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

            Image {
                id: image
                anchors.fill: parent
                source: tile.fileUrl(tile.book.cover_path)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.height: 480
                visible: false
            }
            // Soft contact shadow from a pre-blurred 9-slice image: no shader, same look on every backend
            BorderImage {
                anchors.fill: parent
                anchors.margins: -32
                anchors.leftMargin: -26
                anchors.rightMargin: -26
                anchors.topMargin: -32 + (mouse.containsMouse ? 8 : 4)
                anchors.bottomMargin: -32 - (mouse.containsMouse ? 8 : 4)
                source: "../../assets/images/cover-shadow.png"
                border { left: 40; right: 40; top: 40; bottom: 40 }
                opacity: Theme.dark ? 0.7 : (mouse.containsMouse ? 0.3 : 0.18)
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.sunken; visible: image.status !== Image.Ready }
            Image {
                anchors.fill: parent
                source: image.source
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.height: 480
                visible: image.status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                text: tile.book.title ? tile.book.title.charAt(0) : "?"
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: 36
            }
            // 1px inner stroke keeps light covers from melting into the page
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 3
                border.width: 1
                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 6
                color: "transparent"
                border.color: Theme.accent
                border.width: 2
                visible: tile.current
            }
        }
    }

    ColumnLayout {
        anchors.top: slot.bottom
        anchors.topMargin: 10
        x: slot.x + coverFrame.x
        width: coverFrame.width
        spacing: 3

        Text {
            Layout.fillWidth: true
            text: tile.book.title || ""
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: tile.stateText
                color: tile.percent > 0 && tile.book.status !== "read" ? Theme.accentText : Theme.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontCaption
                font.weight: tile.percent > 0 ? Font.Medium : Font.Normal
                font.features: Theme.tabular
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                implicitWidth: fmt.implicitWidth + 10
                implicitHeight: 18
                radius: 4
                color: "transparent"
                border.color: Theme.border
                Text {
                    id: fmt
                    anchors.centerIn: parent
                    text: (tile.book.format || "txt").toUpperCase()
                    color: Theme.textSecondary
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                }
            }
            IconButton {
                implicitWidth: 24; implicitHeight: 24; iconSize: 15
                iconName: "ellipsis"
                label: zh("更多操作", "More")
                focusPolicy: Qt.NoFocus
                opacity: mouse.containsMouse || hovered || tile.current ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                onClicked: { var p = mapToItem(tile, 0, height + 4); tile.menuRequested(p.x, p.y) }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property real _pressX: 0
        property real _pressY: 0
        property bool _dragging: false
        property bool _wasDragging: false
        onPressed: (m) => { _pressX = m.x; _pressY = m.y; _dragging = false; _wasDragging = false }
        onPositionChanged: (m) => {
            if (!pressed || !(pressedButtons & Qt.LeftButton)) return
            var dx = m.x - _pressX, dy = m.y - _pressY
            if (!_dragging && dx * dx + dy * dy > 400) { _dragging = true; tile.dragStarted() }
            if (_dragging) tile.dragMoved(m.x, m.y)
        }
        onReleased: { _wasDragging = _dragging; if (_dragging) tile.dragReleased(); _dragging = false }
        onClicked: (m) => {
            if (m.button === Qt.RightButton) tile.menuRequested(m.x, m.y)
            else if (!_wasDragging) tile.open()
        }
        onDoubleClicked: {}
    }
}
