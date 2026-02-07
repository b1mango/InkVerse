import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: "InkVerse"

    Rectangle {
        anchors.fill: parent
        color: "#0f1418"

        Row {
            anchors.fill: parent

            Rectangle {
                width: 240
                color: "#1a2127"

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Label { text: "InkVerse"; color: "#e5e7eb"; font.pixelSize: 20 }
                    Label { text: "Dashboard"; color: "#cbd5e1" }
                    Label { text: "Library"; color: "#cbd5e1" }

                    Item { height: 16; width: 1 }

                    Label { text: "User"; color: "#94a3b8" }
                    Label { text: "Settings"; color: "#94a3b8" }
                }
            }

            Rectangle {
                color: "#0f1418"
                anchors.fill: parent

                Label {
                    text: "Dashboard"
                    anchors.centerIn: parent
                    color: "#e5e7eb"
                    font.pixelSize: 28
                }
            }
        }
    }
}
