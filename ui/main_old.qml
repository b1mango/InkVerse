import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    visible: true
    title: "InkVerse"
    property int currentPage: 0
    property string readerTitle: ""
    property string readerText: ""

    ListModel { id: libraryModel }

    function refreshLibrary(books) {
        libraryModel.clear()
        for (var i = 0; i < books.length; i++) {
            libraryModel.append(books[i])
        }
    }

    function openBook(book) {
        readerTitle = book.title || ""
        readerText = backend.readBookText(book.id)
        currentPage = 2
    }

    function loadLibrary() {
        if (!backend) {
            return
        }
        refreshLibrary(backend.listBooks())
    }

    FileDialog {
        id: importDialog
        title: "Import TXT"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Text files (*.txt)"]
        onAccepted: {
            if (!backend) {
                return
            }
            var picked = []
            if (importDialog.files && importDialog.files.length) {
                picked = importDialog.files
            } else if (importDialog.selectedFiles && importDialog.selectedFiles.length) {
                picked = importDialog.selectedFiles
            } else if (importDialog.fileUrls && importDialog.fileUrls.length) {
                picked = importDialog.fileUrls
            } else if (importDialog.file) {
                picked = [importDialog.file]
            } else if (importDialog.currentFile) {
                picked = [importDialog.currentFile]
            }
            if (!picked.length) {
                return
            }
            backend.importFiles(picked)
            loadLibrary()
            currentPage = 1
        }
    }

    onCurrentPageChanged: {
        if (currentPage === 1) {
            loadLibrary()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#0f1418"

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0f1418" }
                GradientStop { position: 1.0; color: "#0b1116" }
            }
        }

        Rectangle {
            id: sidebar
            width: 220
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "#11171d"

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                Text {
                    text: "inkverse"
                    color: "#e6e6e6"
                    font.pixelSize: 26
                    font.bold: true
                }

                Rectangle { height: 1; width: parent.width; color: "#1f2a33" }

                Column {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 10
                        color: currentPage === 0 ? "#1e2730" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Dashboard"
                            color: "#cbd5e1"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: currentPage = 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 10
                        color: currentPage === 1 ? "#1e2730" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "Library"
                            color: "#cbd5e1"
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: currentPage = 1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                Item { height: 12; width: 1 }

                Text {
                    text: "Shelf"
                    color: "#8c98a4"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 10
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "+ New shelf"
                        color: "#9fb0bf"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Item { height: 12; width: 1 }

                Text {
                    text: "Settings"
                    color: "#7d8a96"
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            id: content
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "transparent"

            Rectangle {
                id: topBar
                height: 64
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                color: "transparent"

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: 360
                    height: 36
                    radius: 18
                    color: "#161d23"
                    border.color: "#242e37"

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.margins: 10
                        color: "#cbd5e1"
                        font.pixelSize: 13
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search my library"
                        color: "#6b7a86"
                        font.pixelSize: 13
                        visible: searchInput.text.length === 0
                    }
                }

                Rectangle {
                    id: importButton
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96
                    height: 34
                    radius: 17
                    color: "#2a323a"

                    Text {
                        anchors.centerIn: parent
                        text: "Import"
                        color: "#e6e6e6"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: importDialog.open()
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            StackLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: topBar.bottom
                anchors.bottom: parent.bottom
                currentIndex: currentPage

                Item {
                    Text {
                        text: "Dashboard"
                        anchors.centerIn: parent
                        color: "#e5e7eb"
                        font.pixelSize: 26
                    }
                }

                Item {
                    GridView {
                        id: libraryGrid
                        anchors.fill: parent
                        anchors.margins: 24
                        cellWidth: 200
                        cellHeight: 220
                        model: libraryModel
                        delegate: Rectangle {
                            width: 180
                            height: 200
                            radius: 14
                            color: "#141b22"
                            border.color: "#1f2a33"
                            border.width: 1

                            Rectangle {
                                width: parent.width - 24
                                height: 120
                                radius: 10
                                color: "#202833"
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 12
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 12
                                spacing: 6

                                Text {
                                    text: title
                                    color: "#e5e7eb"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: author ? author : "Unknown"
                                    color: "#9aa6b2"
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: "Status: " + status
                                    color: "#64748b"
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: openBook(model)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    Component.onCompleted: loadLibrary()
                }

                Item {
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 52
                            color: "transparent"

                            Rectangle {
                                width: 70
                                height: 30
                                radius: 15
                                color: "#2a323a"
                                anchors.left: parent.left
                                anchors.leftMargin: 24
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Back"
                                    color: "#e6e6e6"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: currentPage = 1
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }

                            Text {
                                text: readerTitle
                                anchors.left: parent.left
                                anchors.leftMargin: 110
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#e5e7eb"
                                font.pixelSize: 16
                                elide: Text.ElideRight
                            }
                        }

                        Flickable {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 52
                            anchors.bottom: parent.bottom
                            contentWidth: width
                            contentHeight: textBlock.height + 40
                            clip: true

                            Text {
                                id: textBlock
                                width: parent.width - 48
                                anchors.left: parent.left
                                anchors.leftMargin: 24
                                anchors.top: parent.top
                                anchors.topMargin: 16
                                text: readerText
                                color: "#e5e7eb"
                                font.pixelSize: 16
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
