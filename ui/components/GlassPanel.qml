import QtQuick 2.15

/*  GlassPanel  –  毛玻璃态面板
    Frosted-glass card with ink-wash warmth.
    More transparent, with shadow depth and bright edge highlight.
*/
Rectangle {
    id: root
    color: "#a8eeecea"          // cool paper-white, ~66 % opaque
    radius: 16
    border.color: "#30b8b4b0"   // soft cool edge
    border.width: 0.5

    // Outer soft shadow (simulated)
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.color: "#10000000"
        border.width: 6
    }
    Rectangle {
        z: -2
        anchors.fill: parent
        anchors.margins: -4
        radius: parent.radius + 4
        color: "transparent"
        border.color: "#08000000"
        border.width: 8
    }

    // Top edge bright highlight (glass reflection)
    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
        height: parent.height * 0.45
        radius: parent.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#22ffffff" }
            GradientStop { position: 0.6; color: "#08ffffff" }
            GradientStop { position: 1.0; color: "#00ffffff" }
        }
    }

    // Bottom vignette (subtle depth)
    Rectangle {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.bottomMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
        height: parent.height * 0.3
        radius: parent.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#06000000" }
        }
    }

    property alias contentItem: container.data
    Item {
        id: container
        anchors.fill: parent
        anchors.margins: 1
    }
}
