import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

GlassPanel {
    id: root
    width: 240
    color: "#E611151a" // Slightly more opaque for sidebar
    property int currentPage: 0
    property string lang: "zh"  // Language property
    signal pageSelected(int index)

    FontLoader {
        id: iconFont
        source: "../../assets/fonts/MaterialSymbolsOutlined.ttf"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24

        // Logo / Title area
        Text {
            text: lang === "zh" ? "墨界 InkVerse" : "InkVerse"
            color: "#ffffff"
            font.pixelSize: 28
            font.weight: Font.Light
            font.family: "Segoe UI" 
            opacity: 0.9
            Layout.alignment: Qt.AlignHCenter
        }

        // Navigation
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

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

        Item { Layout.fillHeight: true } // Spacer

        // Bottom area
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            NavButton {
                text: lang === "zh" ? "设置" : "Settings"
                iconText: "settings"
                selected: root.currentPage === 3
                onClicked: root.pageSelected(3)
            }
            
            Text {
                text: "v0.1.0 Alpha"
                color: "#50ffffff"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component NavButton: Rectangle {
        id: navBtn
        property string text
        property string iconText
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        height: 44
        radius: 12
        color: selected ? "#20ffffff" : "transparent"
        border.color: selected ? "#30ffffff" : "transparent"
        
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            spacing: 12
            
            Text {
                text: navBtn.iconText
                color: navBtn.selected ? "#ffffff" : "#80ffffff"
                font.pixelSize: 20
                font.family: iconFont.name
            }
            
            Text {
                text: navBtn.text
                color: navBtn.selected ? "#ffffff" : "#a0ffffff"
                font.pixelSize: 15
                font.weight: navBtn.selected ? Font.Medium : Font.Normal
                Layout.fillWidth: true
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: if (!navBtn.selected) navBtn.color = "#10ffffff"
            onExited: if (!navBtn.selected) navBtn.color = "transparent"
            onClicked: navBtn.clicked()
        }
    }
}
