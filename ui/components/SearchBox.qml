import QtQuick
import QtQuick.Controls.Basic
import "../theme"

/*  SearchBox – 常驻搜索框，Esc 清空，带清除按钮  */
TextField {
    id: field
    property string accessibleName: placeholderText
    implicitHeight: Theme.controlHeight
    leftPadding: 34
    rightPadding: text !== "" ? 34 : 12
    color: Theme.text
    placeholderTextColor: Theme.textTertiary
    selectionColor: Theme.accentSoft
    selectedTextColor: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.fontBody
    selectByMouse: true
    Accessible.name: accessibleName
    Keys.onEscapePressed: (event) => {
        if (text !== "") { text = ""; event.accepted = true }
        else event.accepted = false
    }

    background: Rectangle {
        radius: Theme.radiusM
        color: Theme.surface
        border.color: field.activeFocus ? Theme.accent : Theme.border
        border.width: field.activeFocus ? 1.5 : 1
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }

        LucideIcon {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 16
            color: Theme.textTertiary
        }
    }

    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 30; implicitHeight: 30
        iconSize: 14
        visible: field.text !== ""
        iconName: "x"
        label: qsTr("清空搜索")
        focusPolicy: Qt.NoFocus
        onClicked: { field.text = ""; field.forceActiveFocus() }
    }
}
