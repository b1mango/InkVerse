import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme"

/*  ReaderSidebar – 阅读页左侧停靠栏：目录 / 书签 / 笔记三个分页，跟随阅读背景的色板  */
Rectangle {
    id: panel
    property Item reader
    readonly property QtObject p: reader._palette
    readonly property string lang: reader.lang
    function zh(a, b) { return lang === "zh" ? a : b }

    width: 304
    color: p.surface
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: panel.p.border }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.rightMargin: 13
        spacing: 10

        SegmentedControl {
            Layout.fillWidth: true
            fill: true
            tone: panel.p
            value: reader._sidebarTab
            options: [
                { label: zh("目录", "Contents"), value: "toc" },
                { label: zh("书签", "Bookmarks"), value: "bookmarks" },
                { label: zh("笔记", "Notes"), value: "notes" }
            ]
            onActivated: (v) => reader._sidebarTab = v
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: reader._sidebarTab === "bookmarks" ? 1 : reader._sidebarTab === "notes" ? 2 : 0

            // ── Contents ──
            Item {
                ListView {
                    id: tocList
                    objectName: "tocList"
                    anchors.fill: parent
                    visible: reader.chapters.count > 0
                    model: reader.chapters
                    clip: true
                    currentIndex: reader.currentChapter
                    keyNavigationEnabled: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    Accessible.name: zh("目录", "Contents")
                    Keys.onReturnPressed: activate(currentIndex)
                    Keys.onEnterPressed: activate(currentIndex)
                    Component.onCompleted: positionViewAtIndex(Math.max(0, reader.currentChapter), ListView.Center)

                    function activate(i) {
                        var ch = reader.chapters.get(i)
                        if (!ch) return
                        if (ch.isSection && reader.loadFirstChildFromSection(i)) { reader.forceActiveFocus(); return }
                        if (ch.pageIndex >= 0) { reader.loadChapterByIndex(i); reader.forceActiveFocus() }
                    }

                    delegate: Rectangle {
                        required property int index
                        required property string title
                        required property int pageIndex
                        required property bool isSection
                        readonly property bool selected: index === reader.currentChapter
                        width: ListView.view.width
                        height: isSection ? 34 : 34
                        radius: Theme.radiusS
                        color: isSection ? "transparent"
                            : selected ? panel.p.accentSoft
                            : (itemMouse.containsMouse || (tocList.activeFocus && ListView.isCurrentItem)) ? panel.p.surfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: isSection ? 8 : 18
                            anchors.rightMargin: 10
                            Rectangle { visible: selected; Layout.preferredWidth: 3; Layout.preferredHeight: 14; radius: 1.5; color: panel.p.accent }
                            Text {
                                Layout.fillWidth: true
                                text: title
                                color: isSection ? panel.p.textTertiary : (selected ? panel.p.accentText : panel.p.text)
                                font.family: Theme.uiFont
                                font.pixelSize: isSection ? Theme.fontCaption : Theme.fontSmall
                                font.weight: isSection || selected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tocList.activate(index) }
                    }
                }
                Hint {
                    visible: reader.chapters.count === 0
                    iconName: "list"
                    title: zh("这本书没有目录", "No table of contents")
                    detail: reader.bookFormat === "txt" ? zh("TXT 按整本连续排版，可用进度条跳转", "TXT reads as one continuous text; use the scrubber to jump") : ""
                }
            }

            // ── Bookmarks ──
            Item {
                ListView {
                    id: bookmarkList
                    objectName: "bookmarkList"
                    anchors.fill: parent
                    visible: reader._bookmarks.length > 0
                    model: reader._bookmarks
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: AbstractButton {
                        id: mark
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: 56
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: modelData.excerpt
                        onClicked: reader.jumpToBookmark(modelData)
                        background: Rectangle {
                            radius: Theme.radiusM
                            color: mark.hovered ? panel.p.surfaceHover : "transparent"
                            FocusRing { shown: mark.visualFocus }
                        }
                        contentItem: RowLayout {
                            spacing: 10
                            LucideIcon { Layout.leftMargin: 8; name: "bookmark"; size: 16; color: panel.p.accentText }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { Layout.fillWidth: true; text: mark.modelData.excerpt || zh("书签", "Bookmark"); color: panel.p.text; font.family: reader.fontFamily; font.pixelSize: Theme.fontSmall; elide: Text.ElideRight }
                                Text {
                                    Layout.fillWidth: true
                                    text: reader.bookFormat === "pdf" ? zh("第 ", "Page ") + (mark.modelData.chapter + 1) + zh(" 页", "") : (reader.chapterTitle(mark.modelData.chapter) || reader.bookTitle)
                                    color: panel.p.textTertiary
                                    font.family: Theme.uiFont
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            IconButton {
                                implicitWidth: 28; implicitHeight: 28; iconSize: 14
                                tone: panel.p
                                iconName: "x"
                                label: zh("删除书签", "Remove bookmark")
                                opacity: mark.hovered || hovered ? 1 : 0
                                onClicked: reader.deleteBookmark(mark.modelData.id)
                            }
                        }
                    }
                }
                Hint {
                    visible: reader._bookmarks.length === 0
                    iconName: "bookmark"
                    title: zh("还没有书签", "No bookmarks yet")
                    detail: Qt.platform.os === "osx" ? zh("点顶栏的书签按钮，或按 ⌘D", "Use the bookmark button or ⌘D") : zh("点顶栏的书签按钮，或按 Ctrl+D", "Use the bookmark button or Ctrl+D")
                }
            }

            // ── Notes ──
            NotesPanel {
                reader: panel.reader
                embedded: true
            }
        }
    }

    component Hint: ColumnLayout {
        property string iconName
        property string title
        property string detail
        anchors.centerIn: parent
        width: parent.width - 32
        spacing: 8
        LucideIcon { Layout.alignment: Qt.AlignHCenter; name: parent.iconName; size: 24; color: panel.p.textTertiary }
        Text { Layout.alignment: Qt.AlignHCenter; text: parent.title; color: panel.p.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold }
        Text {
            Layout.fillWidth: true
            visible: parent.detail !== ""
            text: parent.detail
            color: panel.p.textSecondary
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontCaption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
