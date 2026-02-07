import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#fdfbf7"

    property string bookId: ""
    property string bookTitle: ""
    property string bookText: ""
    signal backRequested()

    // Chapter model
    ListModel { id: chapterModel }

    function loadChapters() {
        chapterModel.clear()
        // TXT has no reliable TOC; chapters will be loaded for EPUB/PDF
    }

    function scrollToOffset(charOffset) {
        if (charOffset < 0 || !root.bookText) return
        var total = root.bookText.length
        if (total <= 0) return
        var ratio = charOffset / total
        var targetY = ratio * flickable.contentHeight
        flickable.contentY = Math.max(0,
            Math.min(targetY, flickable.contentHeight - flickable.height))
    }

    // ── Top Bar ─────────────────────────────────────────────────
    Rectangle {
        id: topBar
        width: parent.width
        height: 50
        color: "transparent"
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20

            // Back button
            Rectangle {
                width: 70
                height: 30
                radius: 6
                color: backMa.containsMouse ? "#15000000" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "← 返回"
                    color: "#5c5c5c"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.bookTitle
                color: "#333333"
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideMiddle
                Layout.maximumWidth: 400
            }

            Item { Layout.fillWidth: true }

            // Toggle TOC
            Rectangle {
                width: 70
                height: 30
                radius: 6
                color: tocMa.containsMouse ? "#15000000" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "☰ 目录"
                    color: "#5c5c5c"
                    font.pixelSize: 14
                }
                MouseArea {
                    id: tocMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tocPanel.visible = !tocPanel.visible
                }
            }
        }
    }

    // ── Content area (TOC + Text) ───────────────────────────────
    RowLayout {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // ── TOC Sidebar ─────────────────────────────────────────
        Rectangle {
            id: tocPanel
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            visible: chapterModel.count > 0
            color: "#f4f1ec"

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: "#e0ddd8"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // TOC Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    color: "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "目录"
                        color: "#333"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    // Chapter count badge
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: chapterModel.count + " 章"
                        color: "#999"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: "#e0ddd8"
                    }
                }

                // Chapter list
                ListView {
                    id: tocList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: chapterModel

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: tocList.width
                        height: 38
                        color: delegateMa.containsMouse ? "#e8e5e0" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: title
                            color: "#444"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: delegateMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.scrollToOffset(offset)
                        }
                    }
                }
            }
        }

        // ── Reading Area ────────────────────────────────────────
        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: textContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar { }

            Text {
                id: textContent
                width: flickable.width
                text: root.bookText
                wrapMode: Text.WordWrap
                color: "#1a1a1a"
                font.pixelSize: 18
                font.family: "Georgia"
                lineHeight: 1.6
                leftPadding: Math.max(40, (flickable.width - 760) / 2)
                rightPadding: Math.max(40, (flickable.width - 760) / 2)
                topPadding: 30
                bottomPadding: 60
            }
        }
    }
}
