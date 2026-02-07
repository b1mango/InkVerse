import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#Fdfbf7" // Rice paper color
    
    property string bookTitle: ""
    property string bookText: ""
    signal backRequested()

    // Top Bar (Auto hide/show could be added later, for now static but minimal)
    Rectangle {
        id: topBar
        width: parent.width
        height: 50
        color: "transparent"
        z: 10
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            
            Text {
                text: "← Back"
                color: "#5c5c5c"
                font.pixelSize: 14
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: root.bookTitle
                color: "#333333"
                font.pixelSize: 14
                font.family: "KaiTi" // Try a serif/Kai font if available, fallback system serif
                font.weight: Font.Medium
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: "Aa" // Placeholder for settings
                color: "#5c5c5c"
                font.pixelSize: 16
            }
        }
    }

    Flickable {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Math.max(20, (parent.width - 800) / 2) // Max width constraint
        anchors.rightMargin: Math.max(20, (parent.width - 800) / 2)
        clip: true
        contentWidth: width
        contentHeight: textContent.implicitHeight

        ScrollBar.vertical: ScrollBar { }

        Text {
            id: textContent
            width: parent.width
            text: root.bookText
            wrapMode: Text.WordWrap
            color: "#1a1a1a" // Ink black
            font.pixelSize: 18
            font.family: "Georgia" // Good serif for reading
            
            padding: 40
            lineHeight: 1.6
        }
    }
}
