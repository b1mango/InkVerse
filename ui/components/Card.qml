import QtQuick
import "../theme"

/*  Card – 平面卡片：表面色 + 1px 描边，不做伪毛玻璃和高光  */
Rectangle {
    color: Theme.surface
    radius: Theme.radiusL
    border.color: Theme.border
    border.width: 1
}
