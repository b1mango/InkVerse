import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"
import "pages"

ApplicationWindow {
    id: window
    width: 1280
    height: 850
    visible: true
    title: "InkVerse"
    color: "#000000"

    // Global Data
    ListModel { id: globalLibraryModel }

    // State
    // 0: Dashboard, 1: Library, 2: Reader, 3: Settings
    property int currentViewIndex: 0
    property bool isReading: currentViewIndex === 2

    // Background (Ink Wash Gradient)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a1f26" } // Deep Blue-Grey
            GradientStop { position: 1.0; color: "#0f1216" } // Almost Black
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Sidebar
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            visible: !window.isReading // Auto-hide on read
            
            currentPage: getSidebarIndex(window.currentViewIndex)
            onPageSelected: (index) => {
                window.currentViewIndex = index
            }
        }

        // Main Content Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                anchors.fill: parent
                currentIndex: window.currentViewIndex

                // 0: Dashboard
                DashboardPage {
                }

                // 1: Library
                LibraryPage {
                    id: libPage
                    model: globalLibraryModel
                    onBookSelected: (book) => {
                         readerPage.bookTitle = book.title || "Untitled"
                         readerPage.bookText = backend.readBookText(book.id)
                         window.currentViewIndex = 2 // Go to Reader
                    }
                }

                // 2: Reader
                ReaderPage {
                    id: readerPage
                    onBackRequested: {
                        window.currentViewIndex = 1 // Return to library
                        libPage.refresh(backend.listBooks()) // Refresh in case
                    }
                }
                
                // 3: Settings (Placeholder)
                Item {
                    Text { 
                        anchors.centerIn: parent
                        text: "Settings (Coming Soon)"
                        color: "white"
                    }
                }
            }
        }
    }
    
    // Helper to map view index to sidebar index (e.g. Reader is not on sidebar)
    function getSidebarIndex(viewIndex) {
        if (viewIndex === 2) return 1; // Reader highlights Library
        return viewIndex;
    }
}
