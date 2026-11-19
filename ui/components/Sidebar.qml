import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  Sidebar – 安静的侧栏：字标、三项导航、版本号  */
Rectangle {
    id: root
    color: Theme.sidebar
    property int currentPage: 0
    property string lang: "zh"
    signal pageSelected(int index)

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 13
        anchors.topMargin: 22
        anchors.bottomMargin: 16
        spacing: 2

        // Wordmark: the one place the calligraphy face appears
        Row {
            Layout.leftMargin: 10
            Layout.bottomMargin: 22
            spacing: 8
            Text {
                text: "墨界"
                color: Theme.text
                font.family: Theme.brandFont
                font.pixelSize: 28
                Accessible.name: "墨界 InkVerse"
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: "InkVerse"
                color: Theme.textTertiary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontCaption
                font.letterSpacing: 1
            }
        }

        NavButton { text: lang === "zh" ? "首页" : "Home"; iconName: "layout-dashboard"; selected: root.currentPage === 0; onClicked: root.pageSelected(0) }
        NavButton { text: lang === "zh" ? "书库" : "Library"; iconName: "library"; selected: root.currentPage === 1; onClicked: root.pageSelected(1) }

        Item { Layout.fillHeight: true }

        NavButton { text: lang === "zh" ? "设置" : "Settings"; iconName: "settings"; selected: root.currentPage === 3; onClicked: root.pageSelected(3) }

        Text {
            Layout.leftMargin: 12
            Layout.topMargin: 10
            text: "v0.2.0"
            color: Theme.textTertiary
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontCaption
            font.features: Theme.tabular
        }
    }

    component NavButton: AbstractButton {
        id: nav
        property string iconName
        property bool selected: false

        Layout.fillWidth: true
        implicitHeight: 38
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        Accessible.role: Accessible.PageTab
        Accessible.selected: selected

        background: Rectangle {
            radius: Theme.radiusM
            color: nav.selected ? Theme.surface : (nav.hovered ? Theme.surfaceHover : "transparent")
            border.color: nav.selected ? Theme.border : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            FocusRing { shown: nav.visualFocus }
        }

        contentItem: Row {
            leftPadding: 10
            spacing: 10
            LucideIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: nav.iconName
                size: 18
                color: nav.selected ? Theme.accentText : Theme.textSecondary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: nav.text
                color: nav.selected ? Theme.text : Theme.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.weight: nav.selected ? Font.DemiBold : Font.Normal
            }
        }
    }
}
