import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#fdfbf7"

    property string bookId: ""
    property string bookTitle: ""
    property string bookText: ""
    signal backRequested()

    // Placeholder for future EPUB/PDF TOC
    ListModel { id: chapterModel }
    function loadChapters() { chapterModel.clear() }

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
                Text { anchors.centerIn: parent; text: "← 返回"; color: "#5c5c5c"; font.pixelSize: 14 }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.backRequested() }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.bookTitle; color: "#333"
                font.pixelSize: 14; font.weight: Font.Medium
                elide: Text.ElideMiddle; Layout.maximumWidth: 400
            }

            Item { Layout.fillWidth: true }
            Item { width: 70 } // balance spacer
        }
    }

    // ── Reading Area ────────────────────────────────────────────
    Flickable {
        id: flickable
        anchors.top: topBar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        clip: true
        contentWidth: width
        contentHeight: textContent.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Text {
            id: textContent
            width: flickable.width
            text: root.bookText
            wrapMode: Text.WordWrap
            color: "#1a1a1a"
            font.pixelSize: 18; font.family: "Georgia"
            lineHeight: 1.6
            leftPadding:  Math.max(40, (flickable.width - 760) / 2)
            rightPadding: Math.max(40, (flickable.width - 760) / 2)
            topPadding: 30; bottomPadding: 60
        }
    }
}
