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
    color: window.appTheme === "ink" ? "#e0e2e5" : "#ece4d8"
    onClosing: function(close) { close.accepted = backend.endReadingSession() }

    // Global Data
    ListModel { id: globalLibraryModel }

    // State
    // 0: Dashboard, 1: Library, 2: Reader, 3: Settings
    property int currentViewIndex: 0
    property bool isReading: currentViewIndex === 2
    property string appLanguage: "zh"  // "zh" or "en"
    property string appTheme: "ink"    // "ink" or "cream"
    property string appFont: "汉仪行楷简"   // UI display font
    // Font weight: reduce for inherently bold fonts
    property int appFontBoldW:  appFont === "HYXinHaiXingKaiW" ? Font.Medium  : Font.Bold
    property int appFontNormW:  appFont === "HYXinHaiXingKaiW" ? Font.Light   : Font.Normal

    // ── Background (theme-dependent, hidden during reading) ──
    Image {
        id: bgImage
        anchors.fill: parent
        source: window.appTheme === "ink"
            ? "../assets/images/background.png"
            : "../assets/images/bg_landscape.svg"
        fillMode: Image.PreserveAspectCrop
        opacity: window.appTheme === "ink" ? 0.25 : 0.5
        visible: !window.isReading
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
            lang: window.appLanguage
            theme: window.appTheme
            appFont: window.appFont
            appFontBoldW: window.appFontBoldW
            appFontNormW: window.appFontNormW
            
            currentPage: getSidebarIndex(window.currentViewIndex)
            onPageSelected: (index) => {
                window.currentViewIndex = index
                if (index === 0) dashPage.refreshDashboard()
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
                    id: dashPage
                    lang: window.appLanguage
                    appFont: window.appFont
                    appFontBoldW: window.appFontBoldW
                    appFontNormW: window.appFontNormW
                    onOpenBook: (book) => {
                        readerPage.bookId = book.id || ""
                        readerPage.bookTitle = book.title || "Untitled"
                        readerPage.bookFormat = book.format || "txt"
                        if (book.format === "pdf") {
                            readerPage.bookText = ""
                            readerPage.loadChapters()
                        } else if (book.format === "epub" || book.format === "mobi") {
                            readerPage.bookText = ""
                            readerPage.loadChapters()
                        } else {
                            readerPage.loadTextBook()
                            readerPage.loadChapters()
                        }
                        readerPage._startSession()
                        window.currentViewIndex = 2
                    }
                }

                // 1: Library
                LibraryPage {
                    id: libPage
                    lang: window.appLanguage
                    appFont: window.appFont
                    appFontBoldW: window.appFontBoldW
                    appFontNormW: window.appFontNormW
                    model: globalLibraryModel
                    onBookSelected: (book) => {
                         readerPage.bookId = book.id || ""
                         readerPage.bookTitle = book.title || "Untitled"
                         readerPage.bookFormat = book.format || "txt"

                         if (book.format === "pdf") {
                             readerPage.bookText = ""
                             readerPage.loadChapters()
                         } else if (book.format === "epub" || book.format === "mobi") {
                             readerPage.bookText = ""
                             readerPage.loadChapters()
                         } else {
                             readerPage.loadTextBook()
                             readerPage.loadChapters()
                         }
                         readerPage._startSession()
                         window.currentViewIndex = 2
                    }
                }

                // 2: Reader
                ReaderPage {
                    id: readerPage
                    lang: window.appLanguage
                    onBackRequested: {
                        window.currentViewIndex = 1
                        libPage.refresh(backend.listBooks())
                        dashPage.refreshDashboard()
                    }
                }
                
                // 3: Settings
                SettingsPage {
                    id: settingsPage
                    currentLanguage: window.appLanguage
                    currentTheme: window.appTheme
                    currentFont: window.appFont
                    onLanguageChanged: (lang) => {
                        window.appLanguage = lang
                        libPage.refresh(backend.listBooks())
                    }
                    onThemeChanged: (theme) => {
                        window.appTheme = theme
                        // Auto-set default font per theme
                        if (theme === "ink") {
                            window.appFont = "汉仪行楷简"
                            settingsPage.currentFont = "汉仪行楷简"
                        } else {
                            window.appFont = "HYXinHaiXingKaiW"
                            settingsPage.currentFont = "HYXinHaiXingKaiW"
                        }
                    }
                    onFontChanged: (font) => {
                        window.appFont = font
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
