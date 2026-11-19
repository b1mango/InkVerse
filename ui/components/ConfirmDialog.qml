import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  ConfirmDialog – 不可逆操作的二次确认；默认焦点落在“取消”  */
AppModal {
    id: dialog
    property string message: ""
    property string confirmText: qsTr("删除")
    property string cancelText: qsTr("取消")
    property bool destructive: true
    signal confirmed()

    preferredWidth: 400
    showClose: false

    Text {
        Layout.fillWidth: true
        text: dialog.message
        color: Theme.textSecondary
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        lineHeight: 1.35
        wrapMode: Text.Wrap
    }

    footer: [
        AppButton {
            id: cancelButton
            text: dialog.cancelText
            variant: "ghost"
            onClicked: dialog.close()
        },
        AppButton {
            text: dialog.confirmText
            variant: dialog.destructive ? "danger" : "primary"
            onClicked: { dialog.close(); dialog.confirmed() }
        }
    ]

    onOpened: cancelButton.forceActiveFocus()
}
