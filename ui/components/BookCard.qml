import QtQuick
import QtQuick.Layouts
import "../theme"

/*  BookCard – 封面 3:4 + 书名 + 作者/格式；按下拖动可放进文件夹  */
Item {
    id: card
    property string bookId: ""
    property string title: ""
    property string author: ""
    property string coverPath: ""
    property string format: "txt"
    property string status: ""
    property string lang: "zh"
    property bool current: false
    property bool dimmed: false
    signal open()
    signal menuRequested(real x, real y)
    signal dragStarted()
    signal dragMoved(real x, real y)
    signal dragReleased()

    opacity: dimmed ? 0.4 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }

    readonly property string statusLabel: status === "reading" ? (lang === "zh" ? "在看" : "Reading")
        : status === "to_read" ? (lang === "zh" ? "待看" : "To read")
        : status === "read" ? (lang === "zh" ? "已看" : "Finished") : ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            id: cover
            Layout.fillWidth: true
            Layout.preferredHeight: width * 4 / 3
            radius: Theme.radiusM
            color: Theme.sunken
            border.color: card.current ? Theme.accent : (mouse.containsMouse ? Theme.borderStrong : Theme.border)
            border.width: card.current ? 2 : 1
            clip: true

            Image {
                id: coverImage
                anchors.fill: parent
                anchors.margins: 1
                source: card.fileUrl(card.coverPath)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: coverImage.status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: !card.coverPath
                text: card.title ? card.title.charAt(0) : "?"
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: 40
            }
            Rectangle {
                visible: card.statusLabel !== ""
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 8
                width: statusText.implicitWidth + 12
                height: 22
                radius: 11
                color: card.status === "reading" ? Theme.accent : Theme.inverse
                opacity: 0.92
                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: card.statusLabel
                    color: card.status === "reading" ? Theme.textOnAccent : Theme.textOnInverse
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Medium
                }
            }
            IconButton {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                implicitWidth: 30; implicitHeight: 30
                visible: mouse.containsMouse || card.current
                iconName: "ellipsis"
                label: lang === "zh" ? "更多操作" : "More actions"
                iconColor: Theme.text
                focusPolicy: Qt.NoFocus
                background: Rectangle { radius: Theme.radiusM; color: Theme.surface; opacity: 0.94; border.color: Theme.border }
                onClicked: { var p = mapToItem(card, width, height + 4); card.menuRequested(p.x, p.y) }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: card.title
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: card.author || (lang === "zh" ? "作者未知" : "Unknown author")
                    color: Theme.textSecondary
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
                Text {
                    text: (card.format || "txt").toUpperCase()
                    color: Theme.textTertiary
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                }
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
            if (!_dragging && dx * dx + dy * dy > 400) { _dragging = true; card.dragStarted() }
            if (_dragging) card.dragMoved(m.x, m.y)
        }
        onReleased: { _wasDragging = _dragging; if (_dragging) card.dragReleased(); _dragging = false }
        onClicked: (m) => {
            if (m.button === Qt.RightButton) card.menuRequested(m.x, m.y)
            else if (!_wasDragging) card.open()
        }
    }
}
