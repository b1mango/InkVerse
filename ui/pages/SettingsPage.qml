import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components"
import "../theme"

/*  SettingsPage – 外观、语言、默认阅读字体；每项改动即时生效并保存  */
Item {
    id: root
    property string lang: "zh"
    property string themePreference: "system"
    property string readingFont: "LXGW WenKai"
    signal themeChosen(string value)
    signal languageChosen(string value)
    signal readingFontChosen(string value)

    ScrollView {
        id: scroller
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: Math.min(scroller.availableWidth - 2 * Theme.pagePadding, 680)
            x: Theme.pagePadding
            spacing: 0

            Text {
                Layout.topMargin: 36
                Layout.bottomMargin: 24
                text: lang === "zh" ? "设置" : "Settings"
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH1
                font.weight: Font.DemiBold
                Accessible.role: Accessible.Heading
            }

            SectionLabel { text: lang === "zh" ? "通用" : "General" }
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: generalCol.implicitHeight

                ColumnLayout {
                    id: generalCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    SettingRow {
                        title: lang === "zh" ? "外观" : "Appearance"
                        SegmentedControl {
                            value: root.themePreference
                            options: [
                                { label: lang === "zh" ? "跟随系统" : "System", value: "system", icon: "monitor" },
                                { label: lang === "zh" ? "浅色" : "Light", value: "light", icon: "sun" },
                                { label: lang === "zh" ? "深色" : "Dark", value: "dark", icon: "moon" }
                            ]
                            onActivated: (v) => root.themeChosen(v)
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.leftMargin: 16; implicitHeight: 1; color: Theme.border }
                    SettingRow {
                        title: lang === "zh" ? "语言" : "Language"
                        SegmentedControl {
                            value: root.lang
                            options: [{ label: "中文", value: "zh" }, { label: "English", value: "en" }]
                            onActivated: (v) => root.languageChosen(v)
                        }
                    }
                }
            }

            SectionLabel { text: lang === "zh" ? "默认阅读字体" : "Reading typeface" }
            GridLayout {
                id: fontGrid
                Layout.fillWidth: true
                columns: Math.max(2, Math.floor((width + columnSpacing) / (180 + columnSpacing)))
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: Theme.readingFonts
                    delegate: AbstractButton {
                        id: fontCard
                        readonly property bool selected: root.readingFont === modelData.family
                        Layout.fillWidth: true
                        implicitHeight: 88
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: modelData.label
                        Accessible.role: Accessible.RadioButton
                        Accessible.checked: selected
                        onClicked: root.readingFontChosen(modelData.family)

                        background: Rectangle {
                            radius: Theme.radiusL
                            color: fontCard.hovered && !fontCard.selected ? Theme.surfaceHover : Theme.surface
                            border.color: fontCard.selected ? Theme.accent : Theme.border
                            border.width: fontCard.selected ? 1.5 : 1
                            FocusRing { shown: fontCard.visualFocus }
                        }
                        contentItem: ColumnLayout {
                            spacing: 4
                            Text {
                                Layout.leftMargin: 16
                                text: "墨界水云 Ink"
                                color: Theme.text
                                font.family: modelData.family
                                font.pixelSize: 20
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.rightMargin: 16
                            }
                            RowLayout {
                                Layout.leftMargin: 16
                                Layout.rightMargin: 12
                                Text {
                                    Layout.fillWidth: true
                                    text: lang === "zh" ? modelData.label : modelData.en
                                    color: Theme.textSecondary
                                    font.family: Theme.uiFont
                                    font.pixelSize: Theme.fontCaption
                                }
                                LucideIcon { visible: fontCard.selected; name: "check"; size: 16; color: Theme.accentText }
                            }
                        }
                    }
                }
            }

            SectionLabel { text: lang === "zh" ? "数据" : "Data" }
            Card {
                Layout.fillWidth: true
                Layout.bottomMargin: 40
                Layout.preferredHeight: dataRow.implicitHeight
                SettingRow {
                    id: dataRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    title: lang === "zh" ? "书库与阅读记录" : "Library and reading data"
                    detail: lang === "zh" ? "保存在本机 ~/.inkverse，不上传" : "Stored locally in ~/.inkverse, never uploaded"
                }
            }
        }
    }

    component SectionLabel: Text {
        Layout.topMargin: 20
        Layout.bottomMargin: 8
        Layout.leftMargin: 4
        color: Theme.textTertiary
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
    }

    component SettingRow: Item {
        property string title
        property string detail: ""
        default property alias trailing: trailingSlot.data
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(60, labelCol.implicitHeight + 28)
        implicitHeight: Math.max(60, labelCol.implicitHeight + 28)

        Column {
            id: labelCol
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: trailingSlot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { text: title; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontBody }
            Text { visible: detail !== ""; text: detail; color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption }
        }
        Item {
            id: trailingSlot
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
