import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  AppModal – 居中模态框：Esc 与点击遮罩关闭，打开时焦点留在框内  */
Popup {
    id: modal
    property string title: ""
    property int preferredWidth: 420
    default property alias content: body.data
    property alias footer: footerRow.data
    property bool showClose: true

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(preferredWidth, (parent ? parent.width : preferredWidth) - 48)
    height: Math.min(implicitHeight, (parent ? parent.height : implicitHeight) - 48)
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Theme.scrim }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.base; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.fast } }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusL
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 12
            Layout.topMargin: 16
            spacing: 8
            visible: modal.title !== "" || modal.showClose

            Text {
                Layout.fillWidth: true
                text: modal.title
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH3
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Accessible.role: Accessible.Heading
            }
            IconButton {
                visible: modal.showClose
                iconName: "x"
                label: qsTr("关闭")
                onClicked: modal.close()
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 12
            Layout.bottomMargin: footerRow.children.length > 0 ? 8 : 24
            spacing: 12
        }

        RowLayout {
            id: footerRow
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 24
            Layout.bottomMargin: 20
            Layout.topMargin: 8
            spacing: 8
            visible: children.length > 0
        }
    }
}
