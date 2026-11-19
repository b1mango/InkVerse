import QtQuick
import QtQuick.Controls.Basic
import "../theme"

/*  IconButton – 方形图标按钮，必须给出可访问名称（同时用作提示）  */
AbstractButton {
    id: control
    property string iconName: ""
    property string label: ""
    property real iconSize: 18
    property bool active: false
    property QtObject tone: Theme.p
    property color iconColor: active ? tone.accentText : (hovered ? tone.text : tone.textSecondary)
    property color hoverColor: tone.surfaceHover
    property color activeColor: tone.accentSoft

    implicitWidth: 36
    implicitHeight: 36
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: label
    Accessible.role: Accessible.Button

    ToolTip.visible: hovered && label !== ""
    ToolTip.delay: 500
    ToolTip.text: label

    contentItem: Item {
        LucideIcon {
            anchors.centerIn: parent
            name: control.iconName
            size: control.iconSize
            color: control.enabled ? control.iconColor : control.tone.textTertiary
        }
    }

    background: Rectangle {
        radius: Theme.radiusM
        color: control.active ? control.activeColor
            : control.down ? control.tone.sunken
            : control.hovered ? control.hoverColor : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        FocusRing { shown: control.visualFocus }
    }
}
