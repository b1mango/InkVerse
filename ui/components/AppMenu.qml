import QtQuick
import QtQuick.Controls.Basic
import "../theme"

/*  AppMenu – 右键与“更多”菜单，方向键与 Esc 由 Menu 原生处理  */
Menu {
    id: menu
    padding: 6
    implicitWidth: 200

    delegate: AppMenuItem {}

    background: Rectangle {
        implicitWidth: 200
        radius: Theme.radiusL
        color: Theme.surface
        border.color: Theme.border
    }
}
