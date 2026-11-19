import QtQuick
import QtQuick.Layouts
import "../theme"

/*  FolderCard – 四格封面拼贴；接受书卡拖入  */
Item {
    id: card
    property string folderId: ""
    property string name: ""
    property int bookCount: 0
    property var covers: ["", "", "", ""]
    property string lang: "zh"
    property bool current: false
    signal open()
    signal menuRequested(real x, real y)
    signal bookDropped(string bookId)

    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: width * 4 / 3
            radius: Theme.radiusM
            color: drop.containsDrag ? Theme.accentSoft : Theme.sunken
            border.color: drop.containsDrag || card.current ? Theme.accent : (mouse.containsMouse ? Theme.borderStrong : Theme.border)
            border.width: drop.containsDrag || card.current ? 2 : 1

            Grid {
                anchors.fill: parent
                anchors.margins: 10
                columns: 2
                spacing: 6
                Repeater {
                    model: card.covers
                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: (parent.height - parent.spacing) / 2
                        radius: Theme.radiusS
                        color: Theme.surface
                        border.color: Theme.border
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: card.fileUrl(modelData)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: modelData !== ""
                        }
                    }
                }
            }
            LucideIcon {
                anchors.centerIn: parent
                visible: card.bookCount === 0
                name: "folder"
                size: 28
                color: Theme.textTertiary
            }
            IconButton {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                implicitWidth: 30; implicitHeight: 30
                visible: mouse.containsMouse || card.current
                iconName: "ellipsis"
                label: lang === "zh" ? "文件夹操作" : "Folder actions"
                iconColor: Theme.text
                focusPolicy: Qt.NoFocus
                background: Rectangle { radius: Theme.radiusM; color: Theme.surface; opacity: 0.94; border.color: Theme.border }
                onClicked: { var p = mapToItem(card, width, height + 4); card.menuRequested(p.x, p.y) }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                LucideIcon { name: "folder"; size: 15; color: Theme.textSecondary }
                Text {
                    Layout.fillWidth: true
                    text: card.name
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            Text {
                text: card.bookCount + (lang === "zh" ? " 本书" : (card.bookCount === 1 ? " book" : " books"))
                color: Theme.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontCaption
                font.features: Theme.tabular
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
        onClicked: (m) => m.button === Qt.RightButton ? card.menuRequested(m.x, m.y) : card.open()
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["bookId"]
        onDropped: function(d) {
            var bid = d.getDataAsString("bookId")
            if (bid) card.bookDropped(bid)
        }
    }
}
