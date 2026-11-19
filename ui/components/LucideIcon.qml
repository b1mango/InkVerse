import QtQuick
import QtQuick.Shapes
import "../theme"
import "Icons.js" as Icons

/*  LucideIcon – 24×24 Lucide 描边图标，任意尺寸下线宽保持 1.5 px  */
Item {
    id: root
    property string name: ""
    property color color: Theme.textSecondary
    property real size: 18
    property real strokeWidth: 1.5

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        visible: root.name !== ""

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth * 24 / Math.max(1, root.size)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.paths[root.name] || "" }
        }
    }
}
