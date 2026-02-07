import QtQuick 2.15

Rectangle {
    id: root
    color: "#cc1a1f26" // Semi-transparent dark
    radius: 16
    border.color: "#30ffffff" // Subtle white border for glass edge
    border.width: 1

    property alias contentItem: container.data

    Item {
        id: container
        anchors.fill: parent
        anchors.margins: 1
    }
}
