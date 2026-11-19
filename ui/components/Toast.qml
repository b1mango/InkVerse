import QtQuick
import "../theme"

/*  Toast – 底部短提示，3 秒后淡出  */
Rectangle {
    id: toast
    property alias text: label.text
    function show(message) { label.text = message; opacity = 1; hideTimer.restart() }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 32
    width: label.implicitWidth + 32
    height: 38
    radius: 19
    color: Theme.inverse
    opacity: 0
    visible: opacity > 0
    z: 900
    Behavior on opacity { NumberAnimation { duration: Theme.base } }
    Accessible.role: Accessible.AlertMessage
    Accessible.name: label.text

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.textOnInverse
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
    }
    Timer { id: hideTimer; interval: 3000; onTriggered: toast.opacity = 0 }
}
