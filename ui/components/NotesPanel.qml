import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  NotesPanel – 全书划线按章节与位置排序；点卡片跳到原文位置  */
Rectangle {
    id: panel
    property Item reader
    readonly property QtObject p: reader._palette
    readonly property string lang: reader.lang
    function zh(a, b) { return lang === "zh" ? a : b }

    width: 340
    radius: Theme.radiusL
    color: p.surface
    border.color: p.border

    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: zh("笔记", "Notes")
                color: panel.p.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }
            Text {
                text: reader._annotations.length
                color: panel.p.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                font.features: Theme.tabular
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: reader._annotations.length > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            model: {
                var sorted = reader._annotations.slice()
                sorted.sort(function(a, b) {
                    var ca = a.chapter_index || 0, cb = b.chapter_index || 0
                    return ca !== cb ? ca - cb : (a.start || 0) - (b.start || 0)
                })
                return sorted
            }

            delegate: AbstractButton {
                id: note
                property var ann: modelData
                width: ListView.view.width
                implicitHeight: noteCol.implicitHeight + 4
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                Accessible.name: ann ? ann.text : ""
                onClicked: reader.jumpToAnnotation(ann)

                background: Rectangle {
                    radius: Theme.radiusM
                    color: note.hovered ? panel.p.surfaceHover : panel.p.bg
                    border.color: panel.p.border
                    FocusRing { shown: note.visualFocus }
                }

                contentItem: ColumnLayout {
                    id: noteCol
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 10
                        spacing: 8
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 3
                            Layout.preferredHeight: Math.max(noteText.implicitHeight, 18)
                            radius: 1.5
                            color: note.ann ? note.ann.color : panel.p.accent
                        }
                        Text {
                            id: noteText
                            Layout.fillWidth: true
                            text: note.ann ? note.ann.text : ""
                            color: panel.p.text
                            font.family: reader.fontFamily
                            font.pixelSize: Theme.fontSmall
                            lineHeight: 1.3
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 21
                        Layout.rightMargin: 10
                        visible: !!(note.ann && note.ann.comment)
                        text: note.ann ? (note.ann.comment || "") : ""
                        color: panel.p.textSecondary
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontCaption
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 21
                        Layout.rightMargin: 4
                        Layout.bottomMargin: 4
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: reader.chapterTitle(note.ann ? note.ann.chapter_index : -1)
                            color: panel.p.textTertiary
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        IconButton {
                            implicitWidth: 28; implicitHeight: 28; iconSize: 14
                            tone: panel.p
                            iconName: "pen-line"
                            label: zh("编辑评论", "Edit comment")
                            onClicked: reader.editComment(note.ann)
                        }
                        IconButton {
                            implicitWidth: 28; implicitHeight: 28; iconSize: 14
                            tone: panel.p
                            iconName: "trash"
                            label: zh("删除划线", "Delete highlight")
                            onClicked: reader._deleteAnnotation(note.ann.id)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: reader._annotations.length === 0
            spacing: 8
            Item { Layout.fillHeight: true }
            LucideIcon { Layout.alignment: Qt.AlignHCenter; name: "highlighter"; size: 26; color: panel.p.textTertiary }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: zh("还没有划线", "No highlights yet")
                color: panel.p.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 260
                text: zh("点顶栏的划线按钮，再选中文字即可标记", "Turn on highlighting in the top bar, then select text")
                color: panel.p.textSecondary
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontCaption
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            Item { Layout.fillHeight: true }
        }
    }
}
