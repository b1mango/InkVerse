import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  StepperSlider – 减 / 滑块 / 加，数值以等宽数字显示；方向键微调  */
ColumnLayout {
    id: root
    property string label: ""
    property real from: 0
    property real to: 10
    property real stepSize: 1
    property real value: 0
    property string minusIcon: "minus"
    property string plusIcon: "plus"
    property QtObject tone: Theme.p
    property color textColor: tone.text
    property color mutedColor: tone.textSecondary
    property color trackColor: tone.sunken
    property color fillColor: tone.accent
    property color knobColor: tone.surface
    property color borderColor: tone.borderStrong
    signal moved(real value)

    spacing: 6

    function _set(v) {
        var snapped = Math.round(v / stepSize) * stepSize
        snapped = Math.max(from, Math.min(to, snapped))
        if (snapped !== value) root.moved(snapped)
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.label
            color: root.mutedColor
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            font.weight: Font.Medium
        }
        Text {
            text: Math.round(root.value)
            color: root.textColor
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            font.features: Theme.tabular
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        IconButton {
            iconName: root.minusIcon
            label: root.label + qsTr(" 减小")
            iconSize: 15
            implicitWidth: 30; implicitHeight: 30
            tone: root.tone
            enabled: root.value > root.from
            onClicked: root._set(root.value - root.stepSize)
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: root.from
            to: root.to
            stepSize: root.stepSize
            snapMode: Slider.SnapAlways
            value: root.value
            focusPolicy: Qt.StrongFocus
            Accessible.name: root.label
            onMoved: root._set(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: root.trackColor
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: root.fillColor
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 16; height: 16; radius: 8
                color: root.knobColor
                border.color: slider.visualFocus ? root.fillColor : root.borderColor
                border.width: slider.visualFocus ? 2 : 1
            }
        }

        IconButton {
            iconName: root.plusIcon
            label: root.label + qsTr(" 增大")
            iconSize: 15
            implicitWidth: 30; implicitHeight: 30
            tone: root.tone
            enabled: root.value < root.to
            onClicked: root._set(root.value + root.stepSize)
        }
    }
}
