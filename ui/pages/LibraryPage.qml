import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1
import "../components"

Item {
    id: root
    signal bookSelected(var book)
    
    // Model should be exposed from main context or passed in. 
    // We'll trust the main window ensures 'libraryModel' is populated or we populate it here.
    // For encapsulation, let's create our own ListModel if we can't look up, but 'libraryModel' in main.qml is easier for now.
    // Actually, accessing parent properties is brittle. Let's refer to 'libraryModel' by id if possible, but they are in different files.
    // Best practice: Pass model as property.
    property var model

    // Need a function to trigger refresh
    function refresh(books) {
        if(!model) return;
        model.clear()
        for (var i = 0; i < books.length; i++) {
            model.append(books[i])
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
                        
                        // Cover placeholder
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 12
                            Layout.bottomMargin: 0
                            radius: 8
                            color: "#000000"
                            opacity: 0.3
                            
                            Text {
                                anchors.centerIn: parent
                                text: title.substring(0, 1).toUpperCase()
                                font.pixelSize: 48
                                color: "#30ffffff"
                                font.family: "Times New Roman"
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
             if (!backend) return;
             
             var picked = []
             if (importDialog.files && importDialog.files.length) picked = importDialog.files
             else if (importDialog.selectedFiles && importDialog.selectedFiles.length) picked = importDialog.selectedFiles
             else if (importDialog.fileUrls && importDialog.fileUrls.length) picked = importDialog.fileUrls
             else if (importDialog.file) picked = [importDialog.file]
             else if (importDialog.currentFile) picked = [importDialog.currentFile]
             
             if (picked.length > 0) {
                 var books = backend.importFiles(picked)
                 root.refresh(books)
             }
        }
    }
    
    Component.onCompleted: {
        if(backend) {
            root.refresh(backend.listBooks())
        }
    }
}
