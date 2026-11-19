import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  ReaderSettingsPanel – 阅读参数：背景、字体、字号、边距、段距、方式、版式、PDF 缩放、TXT 编码
    每项改动立即作用于阅读页，并通过 reader.setPreference 写回全局阅读偏好。  */
Rectangle {
    id: panel
    property Item reader
    readonly property QtObject p: reader._palette
    readonly property string lang: reader.lang
    function zh(a, b) { return lang === "zh" ? a : b }

    readonly property real contentHeight: scroller.contentHeight + 32
    width: 320
    radius: Theme.radiusL
    color: p.surface
    border.color: p.border

    MouseArea { anchors.fill: parent }   // keep clicks inside the panel

    ScrollView {
        id: scroller
        anchors.fill: parent
        anchors.margins: 16
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: scroller.availableWidth
            spacing: 16

            // ── TXT encoding ──
            ColumnLayout {
                Layout.fillWidth: true
                visible: reader.bookFormat === "txt"
                spacing: 6
                Label { text: zh("文字编码", "Text encoding") }
                ComboBox {
                    id: encodingChoice
                    objectName: "encodingChoice"
                    Layout.fillWidth: true
                    implicitHeight: 34
                    model: [zh("自动识别", "Automatic"), "UTF-8", "GB18030 / GBK", "Big5", "UTF-16 (BOM)", "UTF-16 LE", "UTF-16 BE"]
                    currentIndex: reader._textEncodings.indexOf(reader._textEncoding)
                    onActivated: reader.changeTextEncoding(reader._textEncodings[currentIndex])
                    Accessible.name: zh("文字编码", "Text encoding")
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                    Connections {
                        target: panel.reader
                        function on_TextEncodingChanged() { encodingChoice.currentIndex = panel.reader._textEncodings.indexOf(panel.reader._textEncoding) }
                    }
                    background: Rectangle {
                        radius: Theme.radiusM
                        color: panel.p.bg
                        border.color: encodingChoice.visualFocus ? panel.p.accent : panel.p.border
                        border.width: encodingChoice.visualFocus ? 2 : 1
                    }
                    contentItem: Text {
                        leftPadding: 12
                        text: encodingChoice.displayText
                        color: panel.p.text
                        font: encodingChoice.font
                        verticalAlignment: Text.AlignVCenter
                    }
                    indicator: LucideIcon {
                        x: encodingChoice.width - width - 10
                        y: (encodingChoice.height - height) / 2
                        name: "chevron-down"; size: 15; color: panel.p.textSecondary
                    }
                    delegate: ItemDelegate {
                        width: encodingChoice.width
                        height: 32
                        highlighted: encodingChoice.highlightedIndex === index
                        contentItem: Text { text: modelData; color: panel.p.text; font: encodingChoice.font; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: highlighted ? panel.p.surfaceHover : "transparent"; radius: Theme.radiusS }
                    }
                    popup.background: Rectangle { color: panel.p.surface; border.color: panel.p.border; radius: Theme.radiusM }
                }
            }

            // ── Background ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: zh("阅读背景", "Background") }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: reader.bgPresets
                        delegate: AbstractButton {
                            id: swatch
                            readonly property bool selected: reader.bgKey === modelData.key
                            Layout.fillWidth: true
                            implicitHeight: 52
                            focusPolicy: Qt.StrongFocus
                            hoverEnabled: true
                            Accessible.name: modelData.name
                            Accessible.role: Accessible.RadioButton
                            Accessible.checked: selected
                            onClicked: reader.setPreference("background", modelData.key)
                            background: Rectangle {
                                radius: Theme.radiusM
                                color: modelData.bg
                                border.color: swatch.selected ? panel.p.accent : panel.p.border
                                border.width: swatch.selected ? 2 : 1
                                FocusRing { shown: swatch.visualFocus }
                            }
                            contentItem: Column {
                                spacing: 2
                                topPadding: 8
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "文"; color: modelData.fg; font.family: reader.fontFamily; font.pixelSize: 15 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: modelData.fg; opacity: 0.75; font.family: Theme.uiFont; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }

            // ── Font family ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: zh("正文字体", "Typeface") }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 6
                    Repeater {
                        model: Theme.readingFonts
                        delegate: AbstractButton {
                            id: fontButton
                            readonly property bool selected: reader.fontFamily === modelData.family
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 34
                            focusPolicy: Qt.StrongFocus
                            hoverEnabled: true
                            Accessible.name: modelData.label
                            Accessible.role: Accessible.RadioButton
                            Accessible.checked: selected
                            onClicked: reader.setPreference("font_family", modelData.family)
                            background: Rectangle {
                                radius: Theme.radiusM
                                color: fontButton.selected ? panel.p.accentSoft : (fontButton.hovered ? panel.p.surfaceHover : "transparent")
                                border.color: fontButton.selected ? panel.p.accent : panel.p.border
                                FocusRing { shown: fontButton.visualFocus }
                            }
                            contentItem: Text {
                                text: lang === "zh" ? modelData.label : modelData.en
                                color: panel.p.text
                                font.family: modelData.family
                                font.pixelSize: Theme.fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            StepperSlider {
                Layout.fillWidth: true
                label: zh("字号", "Size")
                from: 14; to: 28; stepSize: 1
                value: reader.fontSize
                minusIcon: "minus"; plusIcon: "plus"
                tone: panel.p
                onMoved: (v) => reader.setPreference("font_size", v)
            }
            StepperSlider {
                Layout.fillWidth: true
                label: zh("页边距", "Margin")
                from: 10; to: 120; stepSize: 5
                value: reader.pageMargin
                tone: panel.p
                onMoved: (v) => reader.setPreference("page_margin", v)
            }
            StepperSlider {
                Layout.fillWidth: true
                visible: reader.bookFormat !== "pdf"
                label: zh("段间距", "Paragraph spacing")
                from: 0; to: 10; stepSize: 1
                value: reader.paragraphSpacing
                tone: panel.p
                onMoved: (v) => reader.setPreference("paragraph_spacing", v)
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: reader.bookFormat !== "pdf"
                Label { text: zh("阅读方式", "Mode") }
                Segments {
                    value: reader.readingMode
                    options: [{ label: zh("翻页", "Pages"), value: "paginated" }, { label: zh("滚动", "Scroll"), value: "scroll" }]
                    onActivated: (v) => reader.setPreference("reading_mode", v)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: reader.bookFormat !== "pdf" && reader.readingMode === "paginated"
                Label { text: zh("版式", "Layout") }
                Segments {
                    value: reader.dualPage
                    options: [{ label: zh("单页", "Single"), value: false }, { label: zh("双页", "Spread"), value: true }]
                    onActivated: (v) => reader.setPreference("dual_page", v)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: reader.bookFormat === "pdf"
                Label { text: zh("页面大小", "Page size") }
                Segments {
                    value: reader.pdfFitMode
                    options: [
                        { label: zh("整页", "Fit page"), value: "fit_page" },
                        { label: zh("适应宽度", "Fit width"), value: "fit_width" },
                        { label: zh("原始", "Actual"), value: "original" }
                    ]
                    onActivated: (v) => reader.setPreference("pdf_fit_mode", v)
                }
            }
        }
    }

    component Label: Text {
        color: panel.p.textSecondary
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
        font.weight: Font.Medium
    }

    // SegmentedControl recoloured for the reader's own palette
    component Segments: SegmentedControl {
        Layout.fillWidth: true
        fill: true
        tone: panel.p
    }
}
