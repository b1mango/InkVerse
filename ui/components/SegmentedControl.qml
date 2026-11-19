import QtQuick
import QtQuick.Controls.Basic
import "../theme"

/*  SegmentedControl – 互斥选项；左右方向键切换  */
Rectangle {
    id: root
    property var options: []          // [{ label, value, icon? }]
    property var value
    property bool fill: false
    property int segmentHeight: 30
    property QtObject tone: Theme.p          // palette; the reader passes its own
    signal activated(var value)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: segmentHeight + 6
    radius: Theme.radiusM
    color: tone.sunken

    function _select(i) {
        if (i < 0 || i >= options.length) return
        root.activated(options[i].value)
    }

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2

        Repeater {
            model: root.options
            delegate: AbstractButton {
                id: seg
                readonly property bool selected: root.value === modelData.value
                width: root.fill ? (row.width - (root.options.length - 1) * row.spacing) / root.options.length
                                 : implicitWidth
                implicitWidth: (modelData.label ? segLabel.implicitWidth + 24 : 16) + (modelData.icon ? 22 : 0)
                height: root.segmentHeight
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                checkable: false
                Accessible.name: modelData.a11y || modelData.label
                Accessible.role: Accessible.RadioButton
                Accessible.checked: selected
                onClicked: root.activated(modelData.value)
                Keys.onLeftPressed: root._select(index - 1)
                Keys.onRightPressed: root._select(index + 1)

                background: Rectangle {
                    radius: Theme.radiusS
                    color: seg.selected ? root.tone.surface : (seg.hovered ? root.tone.surfaceHover : "transparent")
                    border.color: seg.selected ? root.tone.border : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    FocusRing { shown: seg.visualFocus }
                }
                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        LucideIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!modelData.icon
                            name: modelData.icon || ""
                            size: 15
                            color: seg.selected ? root.tone.text : root.tone.textSecondary
                        }
                        Text {
                            id: segLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: seg.selected ? root.tone.text : root.tone.textSecondary
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                            font.weight: seg.selected ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}
