import QtQuick 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 30

        Text {
            text: "Good Evening, Traveler."
            color: "#ffffff"
            font.pixelSize: 32
            font.weight: Font.Light
        }

        // Stats Row
        RowLayout {
            spacing: 20
            Layout.fillWidth: true
            
            GlassPanel {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 120
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "12.5 hrs"; color: "#fff"; font.pixelSize: 28; font.bold: true }
                    Text { text: "Reading Time"; color: "#80ffffff"; font.pixelSize: 14 }
                }
            }
            
            GlassPanel {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 120
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "4"; color: "#fff"; font.pixelSize: 28; font.bold: true }
                    Text { text: "Books Finished"; color: "#80ffffff"; font.pixelSize: 14 }
                }
            }
            
            Item { Layout.fillWidth: true }
        }

        // Heatmap Placeholder
        GlassPanel {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            
            Text {
                text: "Activity Heatmap (Coming Soon)"
                anchors.centerIn: parent
                color: "#40ffffff"
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
