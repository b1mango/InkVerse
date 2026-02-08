import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

/*  Sidebar – 水墨玻璃态侧边栏  */
Rectangle {
    id: root
    width: 240
    color: "transparent"
    property int currentPage: 0
    property string lang: "zh"
    property string theme: "ink"  // "ink" or "cream"
    property string appFont: "Long Cang"
    property int appFontBoldW: Font.Bold
    property int appFontNormW: Font.Normal
    signal pageSelected(int index)

    FontLoader {
        id: iconFont
        source: "../../assets/fonts/MaterialSymbolsOutlined.ttf"
    }

    // ── Ink-wash background image ──
    Image {
        anchors.fill: parent
        source: "../../assets/images/bg_sidebar.svg"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.9
    }

    // ── Glass overlay ──
    Rectangle {
        anchors.fill: parent
        color: root.theme === "ink" ? "#98e0e2e5" : "#98ece4d8"
        border.color: "#28b8b4b0"
        border.width: 0.5

        // Inner highlight (top-to-bottom)
        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#18ffffff" }
                GradientStop { position: 0.4; color: "#08ffffff" }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
        }
    }

    // ── Right edge separator (ink brushstroke feel) ──
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 1
        color: "#30a09888"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // ── Logo / Title ──
        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Text {
                text: "墨界"
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#2a2828"
                font.pixelSize: 36
                font.weight: root.appFontBoldW
                font.family: root.appFont
            }
            Text {
                text: "InkVerse"
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#555050"
                font.pixelSize: 12
                font.weight: Font.Normal
                font.letterSpacing: root.theme === "ink" ? 5 : 3
                font.family: "LXGW WenKai"
            }
        }

        // ── Brushstroke divider ──
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 160
            Layout.preferredHeight: 16
            source: "../../assets/images/brushstroke.svg"
            fillMode: Image.PreserveAspectFit
            opacity: 0.5
        }

        // ── Navigation ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            NavButton {
                text: lang === "zh" ? "首页" : "Dashboard"
                iconText: "space_dashboard"
                selected: root.currentPage === 0
                onClicked: root.pageSelected(0)
            }

            NavButton {
                text: lang === "zh" ? "书库" : "Library"
                iconText: "local_library"
                selected: root.currentPage === 1
                onClicked: root.pageSelected(1)
            }
        }

        Item { Layout.fillHeight: true }

        // ── Bottom area ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            NavButton {
                text: lang === "zh" ? "设置" : "Settings"
                iconText: "settings"
                selected: root.currentPage === 3
                onClicked: root.pageSelected(3)
            }

            // Brushstroke decoration (bottom)
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 140
                Layout.preferredHeight: 16
                source: "../../assets/images/brushstroke.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.35
            }

            // Ink swirl accent
            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 60
                Layout.preferredHeight: 30
                source: "../../assets/images/ink_swirl.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.2
            }

            Text {
                text: "v0.1.0"
                color: "#80756858"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── NavButton inline component ──
    component NavButton: Rectangle {
        id: navBtn
        property string text
        property string iconText
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        height: 44
        radius: 12
        clip: true

        // ── Cream theme: glass background with icon ──
        color: root.theme === "cream"
            ? (selected ? "#30a09888" : (navMa.containsMouse ? "#18a09888" : "transparent"))
            : "transparent"
        border.color: root.theme === "cream"
            ? (selected ? "#40a09888" : "transparent")
            : "transparent"

        Behavior on color { ColorAnimation { duration: 150 } }

        // ── Ink theme: brush stroke background ──
        Image {
            anchors.fill: parent
            source: "../../assets/images/dashboard.svg"
            fillMode: Image.PreserveAspectCrop
            visible: root.theme === "ink"
            opacity: navBtn.selected ? 0.55 : (navMa.containsMouse ? 0.30 : 0.0)
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ── Cream theme: icon + text row ──
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            spacing: 12
            visible: root.theme === "cream"

            Text {
                text: navBtn.iconText
                color: navBtn.selected ? "#3a3228" : "#7a7060"
                font.pixelSize: 20
                font.family: iconFont.name
            }
            Text {
                text: navBtn.text
                color: navBtn.selected ? "#2a2420" : "#6a6050"
                font.pixelSize: 15
                font.weight: navBtn.selected ? Font.DemiBold : root.appFontNormW
                font.family: root.appFont
                Layout.fillWidth: true
            }
        }

        // ── Ink theme: calligraphic text only ──
        Text {
            anchors.centerIn: parent
            visible: root.theme === "ink"
            text: navBtn.text
            color: navBtn.selected ? "#2a2420" : "#5a5040"
            font.pixelSize: 17
            font.weight: root.appFontBoldW
            font.family: root.appFont
        }

        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.clicked()
        }
    }
}
