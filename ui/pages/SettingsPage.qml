import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

/*  SettingsPage – 水墨风设置页  */
Item {
    id: root

    property string currentLanguage: "zh"
    property string currentTheme: "ink"
    signal languageChanged(string lang)
    signal themeChanged(string theme)
    property string currentFont: "Long Cang"
    signal fontChanged(string font)

    // Ink palette
    readonly property string _ink:      "#2a2420"
    readonly property string _inkLight: "#5a5040"
    readonly property string _inkDim:   "#8a7e70"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 50
        anchors.topMargin: 40
        spacing: 30

        Text {
            text: currentLanguage === "zh" ? "设置" : "Settings"
            color: _ink
            font.pixelSize: 32
            font.weight: root.currentFont === "HYXinHaiXingKaiW" ? Font.Medium : Font.Bold
            font.family: root.currentFont
        }

        // ── Theme Section ──
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: themeCol.implicitHeight + 50

            ColumnLayout {
                id: themeCol
                anchors.fill: parent; anchors.margins: 25
                spacing: 16

                Text {
                    text: currentLanguage === "zh" ? "主题风格" : "Theme"
                    color: _inkLight
                    font.pixelSize: 16; font.weight: Font.DemiBold
                }

                Row {
                    spacing: 16

                    // ── Ink Wash theme ──
                    Rectangle {
                        width: 160; height: 100; radius: 12
                        color: root.currentTheme === "ink" ? "#25a09888" : "#10a09888"
                        border.color: root.currentTheme === "ink" ? "#70a09888" : "#30a09888"
                        border.width: root.currentTheme === "ink" ? 2 : 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 60; height: 36; radius: 6
                                color: "#e0dcd8"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: "../../assets/images/background.png"
                                    fillMode: Image.PreserveAspectCrop
                                    opacity: 0.4
                                }
                            }

                            Text {
                                text: currentLanguage === "zh" ? "水墨" : "Ink Wash"
                                color: _ink
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.family: root.currentFont
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentTheme = "ink"; root.themeChanged("ink") }
                        }
                    }

                    // ── Cream theme ──
                    Rectangle {
                        width: 160; height: 100; radius: 12
                        color: root.currentTheme === "cream" ? "#25a09888" : "#10a09888"
                        border.color: root.currentTheme === "cream" ? "#70a09888" : "#30a09888"
                        border.width: root.currentTheme === "cream" ? 2 : 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 60; height: 36; radius: 6
                                color: "#eeecea"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: "../../assets/images/bg_landscape.svg"
                                    fillMode: Image.PreserveAspectCrop
                                    opacity: 0.6
                                }
                            }

                            Text {
                                text: currentLanguage === "zh" ? "素笺" : "Parchment"
                                color: _ink
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.family: root.currentFont
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentTheme = "cream"; root.themeChanged("cream") }
                        }
                    }
                }

                Text {
                    text: currentLanguage === "zh"
                        ? "切换应用整体视觉风格"
                        : "Switch the overall visual style"
                    color: _inkDim; font.pixelSize: 12
                }
            }
        }

        // ── Font Section ──
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: fontCol.implicitHeight + 50

            ColumnLayout {
                id: fontCol
                anchors.fill: parent; anchors.margins: 25
                spacing: 16

                Text {
                    text: currentLanguage === "zh" ? "字体设置" : "Font"
                    color: _inkLight
                    font.pixelSize: 16; font.weight: Font.DemiBold
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: [
                            { name: "Long Cang", label: "龙藏体", desc: "行书" },
                            { name: "汉仪行楷简", label: "汉仪行楷简", desc: "行楷" },
                            { name: "HYXinHaiXingKaiW", label: "心海行楷", desc: "行楷" },
                            { name: "Ma Shan Zheng", label: "马善政楷", desc: "楷书" },
                            { name: "LXGW WenKai", label: "霞鹜文楷", desc: "楷体" }
                        ]

                        Rectangle {
                            width: 140; height: 64; radius: 10
                            color: root.currentFont === modelData.name ? "#25a09888" : "#10a09888"
                            border.color: root.currentFont === modelData.name ? "#70a09888" : "#30a09888"
                            border.width: root.currentFont === modelData.name ? 2 : 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    text: "墨界水云"
                                    color: _ink
                                    font.pixelSize: 18
                                    font.family: modelData.name
                                    font.weight: modelData.name === "HYXinHaiXingKaiW" ? Font.Light : Font.Normal
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.label + " · " + modelData.desc
                                    color: _inkDim
                                    font.pixelSize: 9
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.currentFont = modelData.name; root.fontChanged(modelData.name) }
                            }
                        }
                    }
                }

                Text {
                    text: currentLanguage === "zh"
                        ? "切换界面显示字体"
                        : "Switch UI display font"
                    color: _inkDim; font.pixelSize: 12
                }
            }
        }

        // ── Language Section ──
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: langCol.implicitHeight + 50

            ColumnLayout {
                id: langCol
                anchors.fill: parent; anchors.margins: 25
                spacing: 16

                Text {
                    text: currentLanguage === "zh" ? "语言设置" : "Language"
                    color: _inkLight
                    font.pixelSize: 16; font.weight: Font.DemiBold
                }

                Row {
                    spacing: 12

                    Rectangle {
                        width: 120; height: 44; radius: 10
                        color: root.currentLanguage === "zh" ? "#35a09888" : "#18a09888"
                        border.color: root.currentLanguage === "zh" ? "#60a09888" : "#30a09888"

                        Text { anchors.centerIn: parent; text: "中文"; color: _ink; font.pixelSize: 15 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentLanguage = "zh"; root.languageChanged("zh") }
                        }
                    }

                    Rectangle {
                        width: 120; height: 44; radius: 10
                        color: root.currentLanguage === "en" ? "#35a09888" : "#18a09888"
                        border.color: root.currentLanguage === "en" ? "#60a09888" : "#30a09888"

                        Text { anchors.centerIn: parent; text: "English"; color: _ink; font.pixelSize: 15 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentLanguage = "en"; root.languageChanged("en") }
                        }
                    }
                }

                Text {
                    text: currentLanguage === "zh"
                        ? "重启应用后生效部分更改"
                        : "Some changes take effect after restart"
                    color: _inkDim; font.pixelSize: 12
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Version info
        Text {
            text: "InkVerse v0.1.0"
            color: _inkDim; opacity: 0.5
            font.pixelSize: 12
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
