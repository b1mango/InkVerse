import QtQuick
import "../theme"

/*  FocusRing – 键盘焦点环，只在 Tab 聚焦时出现  */
Rectangle {
    property Item target: parent
    property bool shown: false
    property real radiusExtra: 2
    anchors.fill: target
    anchors.margins: -3
    radius: (target && target.radius !== undefined ? target.radius : Theme.radiusM) + radiusExtra
    color: "transparent"
    border.color: Theme.accent
    border.width: 2
    visible: shown
}
