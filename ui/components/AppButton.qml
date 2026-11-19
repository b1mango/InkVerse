import QtQuick
import QtQuick.Controls.Basic
import "../theme"

/*  AppButton – 主要 / 次要 / 幽灵 / 危险 四种按钮，键盘可达  */
Button {
    id: control
    property string variant: "secondary"   // primary | secondary | ghost | danger | dangerSoft
    property string iconName: ""
    property bool compact: false

    implicitHeight: compact ? 30 : Theme.controlHeight
    leftPadding: compact ? 10 : 14
    rightPadding: compact ? 10 : 14
    font.family: Theme.uiFont
    font.pixelSize: compact ? Theme.fontSmall : Theme.fontBody
    font.weight: variant === "primary" ? Font.DemiBold : Font.Medium
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text

    readonly property color _fg: {
        if (!enabled) return Theme.textTertiary
        if (variant === "primary") return Theme.textOnAccent
        if (variant === "danger") return Theme.textOnAccent
        if (variant === "dangerSoft") return Theme.danger
        if (variant === "ghost") return hovered ? Theme.text : Theme.textSecondary
        return Theme.text
    }

    contentItem: Row {
        spacing: 6
        LucideIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: control.iconName !== ""
            name: control.iconName
            size: control.compact ? 14 : 16
            color: control._fg
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: control.text !== ""
            text: control.text
            font: control.font
            color: control._fg
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: Theme.radiusM
        color: {
            if (!control.enabled) return control.variant === "ghost" ? "transparent" : Theme.sunken
            if (control.variant === "primary") return control.down ? Theme.accentHover : (control.hovered ? Theme.accentHover : Theme.accent)
            if (control.variant === "danger") return control.hovered || control.down ? Qt.darker(Theme.danger, 1.08) : Theme.danger
            if (control.variant === "dangerSoft") return control.hovered || control.down ? Theme.dangerSoft : "transparent"
            if (control.variant === "ghost") return control.down ? Theme.sunken : (control.hovered ? Theme.surfaceHover : "transparent")
            return control.down ? Theme.sunken : (control.hovered ? Theme.surfaceHover : Theme.surface)
        }
        border.width: control.variant === "secondary" ? 1 : 0
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        FocusRing { shown: control.visualFocus }
    }
}
