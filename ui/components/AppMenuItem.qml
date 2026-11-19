import QtQuick
import QtQuick.Controls.Basic
import "../theme"

/*  AppMenuItem – 菜单项：可选图标、危险态、子菜单箭头  */
MenuItem {
    id: item
    property string iconName: ""
    property bool destructive: false

    implicitHeight: 34
    leftPadding: 10
    rightPadding: 10
    font.family: Theme.uiFont
    font.pixelSize: Theme.fontSmall

    arrow: LucideIcon {
        x: item.width - width - 10
        y: (item.height - height) / 2
        visible: item.subMenu
        name: "chevron-right"
        size: 14
        color: Theme.textTertiary
    }
    indicator: Item {}

    contentItem: Row {
        spacing: 10
        leftPadding: 0
        LucideIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: item.iconName           // empty name keeps the slot so labels line up
            size: 16
            color: item.destructive ? Theme.danger : Theme.textSecondary
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: item.text
            font: item.font
            color: !item.enabled ? Theme.textTertiary : item.destructive ? Theme.danger : Theme.text
        }
    }

    background: Rectangle {
        radius: Theme.radiusS
        color: item.highlighted ? (item.destructive ? Theme.dangerSoft : Theme.surfaceHover) : "transparent"
    }
}
