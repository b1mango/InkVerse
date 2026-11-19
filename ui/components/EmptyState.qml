import QtQuick
import QtQuick.Layouts
import "../theme"

/*  EmptyState – 图标 + 一句结论 + 可选动作，不写教学长文  */
ColumnLayout {
    id: root
    property string iconName: "book-open"
    property string title: ""
    property string detail: ""
    property string actionText: ""
    property string actionIcon: ""
    signal action()

    spacing: 10

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        width: 56; height: 56; radius: 28
        color: Theme.sunken
        LucideIcon { anchors.centerIn: parent; name: root.iconName; size: 26; color: Theme.textTertiary }
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 4
        text: root.title
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontTitle
        font.weight: Font.DemiBold
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 360
        visible: root.detail !== ""
        text: root.detail
        color: Theme.textSecondary
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }
    AppButton {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        visible: root.actionText !== ""
        text: root.actionText
        iconName: root.actionIcon
        variant: "primary"
        onClicked: root.action()
    }
}
