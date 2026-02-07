import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"

Item {
    id: root
    signal bookSelected(var book)
    
    // Model should be exposed from main context or passed in.
    property var model

    function refresh(books) {
        if (!model || !books || !books.length) return
        model.clear()
        for (var i = 0; i < books.length; i++) {
            var b = books[i]
            model.append({
                "id":              b.id              || "",
                "title":           b.title           || "Untitled",
                "author":          b.author          || "",
                "cover_path":      b.cover_path      || "",
                "status":          b.status          || "to_read",
                "reading_minutes": b.reading_minutes  || 0,
                "path":            b.path            || "",
                "format":          b.format          || "txt"
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20

        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Library"
                color: "#ffffff"
                font.pixelSize: 32
                font.weight: Font.Light
            }
            
            Item { Layout.fillWidth: true }
            
            Rectangle {
                width: 100
                height: 36
                radius: 18
                color: "#20ffffff"
                border.color: "#30ffffff"
                
                Text {
                    anchors.centerIn: parent
                    text: "+ Import"
                    color: "#ffffff"
                    font.pixelSize: 14
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: importDialog.open()
                }
            }
        }

        // Grid
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: 220
            cellHeight: 280
            model: root.model
            
            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight
                
                GlassPanel {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#cc1a1f26" // Darker card
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 0
                        spacing: 0
                        
                        // Cover
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 12
                            Layout.bottomMargin: 0
                            radius: 8
                            clip: true
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: cover_path ? "file:///" + cover_path : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                            }
                        }
                        
                        // Meta
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 16
                            Layout.topMargin: 12
                            Layout.bottomMargin: 16
                            spacing: 4
                            
                            Text {
                                text: title
                                color: "#eeeeee"
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: author ? author : "Unknown Author"
                                color: "#80ffffff"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bookSelected(model)
                        onEntered: parent.border.color = "#60ffffff"
                        onExited: parent.border.color = "#30ffffff"
                    }
                }
            }
        }
    }
    
    FileDialog {
        id: importDialog
        title: "Import Books"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Text files (*.txt)"]
        onAccepted: {
             if (!backend) { console.warn("[LibraryPage] backend not available"); return; }

             var picked = []
             if (importDialog.files && importDialog.files.length > 0)
                 picked = importDialog.files
             else if (importDialog.currentFiles && importDialog.currentFiles.length > 0)
                 picked = importDialog.currentFiles
             else if (importDialog.file && importDialog.file.toString() !== "")
                 picked = [importDialog.file]
             else if (importDialog.currentFile && importDialog.currentFile.toString() !== "")
                 picked = [importDialog.currentFile]

             if (picked.length > 0) {
                 var urls = []
                 for (var k = 0; k < picked.length; k++)
                     urls.push(picked[k].toString())
                 var books = backend.importFiles(urls)
                 root.refresh(books)
             }
        }
    }
    
    Component.onCompleted: {
        if (backend) {
            backend.ensureCovers()
            root.refresh(backend.listBooks())
        }
    }

    Connections {
        target: backend || null
        function onCoversUpdated() {
            root.refresh(backend.listBooks())
        }
    }
}
