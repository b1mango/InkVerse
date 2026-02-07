import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root
    
    property string currentLanguage: "zh"
    signal languageChanged(string lang)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 30

        // Header
        Text {
            text: currentLanguage === "zh" ? "设置" : "Settings"
            color: "#ffffff"
            font.pixelSize: 32
            font.weight: Font.Light
        }

        // Language Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: currentLanguage === "zh" ? "语言设置" : "Language"
                color: "#cccccc"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 12

                Rectangle {
                    width: 120; height: 44; radius: 8
                    color: root.currentLanguage === "zh" ? "#30ffffff" : "#15ffffff"
                    border.color: root.currentLanguage === "zh" ? "#50ffffff" : "#25ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "中文"
                        color: "#ffffff"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentLanguage = "zh"
                            root.languageChanged("zh")
                        }
                    }
                }

                Rectangle {
                    width: 120; height: 44; radius: 8
                    color: root.currentLanguage === "en" ? "#30ffffff" : "#15ffffff"
                    border.color: root.currentLanguage === "en" ? "#50ffffff" : "#25ffffff"

                    Text {
                        anchors.centerIn: parent
                        text: "English"
                        color: "#ffffff"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentLanguage = "en"
                            root.languageChanged("en")
                        }
                    }
                }
            }

            Text {
                text: currentLanguage === "zh" 
                    ? "重启应用后生效部分更改" 
                    : "Some changes take effect after restart"
                color: "#666666"
                font.pixelSize: 12
            }
        }

        Item { Layout.fillHeight: true }

        // Version info
        Text {
            text: "InkVerse v0.1.0 Alpha"
            color: "#40ffffff"
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
