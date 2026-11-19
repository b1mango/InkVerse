import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "components"
import "pages"
import "theme"

ApplicationWindow {
    id: window
    width: 1280
    height: 820
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    title: "墨界 InkVerse"
    color: Theme.bg
    font.family: Theme.uiFont
    onClosing: function(close) {
        readerPage.saveProgress()
        close.accepted = backend.endReadingSession()
    }

    // Global Data
    ListModel { id: globalLibraryModel }

    // 0: Dashboard, 1: Library, 2: Reader, 3: Settings
    property int currentViewIndex: 0
    property bool isReading: currentViewIndex === 2
    property string appLanguage: "zh"
    property var settings: ({})

    function openBook(book) {
        if (!book || !book.id) return
        readerPage.open(book)
        currentViewIndex = 2
    }

    function saveSettings(patch) {
        window.settings = backend.saveSettings(patch)
    }

    function importUrls(urls) {
        if (!urls || urls.length === 0) return
        var before = backend.listBooks().length
        var books = backend.importFiles(urls)
        libPage.refresh(books)
        dashPage.refreshDashboard()
        currentViewIndex = 1
        var added = books.length - before
        toast.show(added > 0
            ? (appLanguage === "zh" ? "已导入 " + added + " 本书" : "Imported " + added + (added === 1 ? " book" : " books"))
            : (appLanguage === "zh" ? "没有可导入的文件，支持 TXT、EPUB、PDF、MOBI" : "Nothing to import. TXT, EPUB, PDF and MOBI are supported"))
    }

    Component.onCompleted: {
        window.settings = backend.getSettings()
        Theme.preference = settings.theme || "system"
        appLanguage = settings.language || "zh"
        readerPage.applyPreferences(settings.reading || {})
    }

    Shortcut {
        sequences: [StandardKey.Find]
        enabled: !window.isReading
        onActivated: { window.currentViewIndex = 1; libPage.focusSearch() }
    }
    Shortcut {
        sequences: [StandardKey.Open]
        enabled: !window.isReading
        onActivated: { window.currentViewIndex = 1; libPage.openImportDialog() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: 216
            visible: !window.isReading
            lang: window.appLanguage
            currentPage: window.currentViewIndex === 2 ? 1 : window.currentViewIndex
            onPageSelected: (index) => {
                window.currentViewIndex = index
                if (index === 0) dashPage.refreshDashboard()
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: window.currentViewIndex

            DashboardPage {
                id: dashPage
                objectName: "dashboardPage"
                lang: window.appLanguage
                onOpenBook: (book) => window.openBook(book)
                onShowLibrary: window.currentViewIndex = 1
            }

            LibraryPage {
                id: libPage
                objectName: "libraryPage"
                lang: window.appLanguage
                model: globalLibraryModel
                onBookSelected: (book) => window.openBook(book)
                onImportRequested: (urls) => window.importUrls(urls)
            }

            ReaderPage {
                id: readerPage
                objectName: "readerPage"
                lang: window.appLanguage
                onBackRequested: {
                    window.currentViewIndex = 1
                    libPage.refresh(backend.listBooks())
                    dashPage.refreshDashboard()
                }
                onPreferencesChanged: (patch) => window.saveSettings({ reading: patch })
            }

            SettingsPage {
                id: settingsPage
                objectName: "settingsPage"
                lang: window.appLanguage
                themePreference: Theme.preference
                readingFont: window.settings.reading ? window.settings.reading.font_family : "LXGW WenKai"
                onThemeChosen: (value) => {
                    Theme.preference = value
                    window.saveSettings({ theme: value })
                }
                onLanguageChosen: (value) => {
                    window.appLanguage = value
                    window.saveSettings({ language: value })
                    libPage.refresh(backend.listBooks())
                }
                onReadingFontChosen: (value) => {
                    readerPage.fontFamily = value
                    window.saveSettings({ reading: { font_family: value } })
                }
            }
        }
    }

    // Drop books anywhere outside the reader to import them
    DropArea {
        id: windowDrop
        anchors.fill: parent
        enabled: !window.isReading
        keys: ["text/uri-list"]
        onDropped: function(drop) {
            if (!drop.hasUrls) return
            var urls = []
            for (var i = 0; i < drop.urls.length; i++) urls.push(drop.urls[i].toString())
            window.importUrls(urls)
            drop.acceptProposedAction()
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        visible: windowDrop.containsDrag
        z: 800
        radius: Theme.radiusL
        color: Qt.rgba(Theme.accentSoft.r, Theme.accentSoft.g, Theme.accentSoft.b, 0.92)
        border.color: Theme.accent
        border.width: 2

        Column {
            anchors.centerIn: parent
            spacing: 10
            LucideIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "import"; size: 36; color: Theme.accentText }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: window.appLanguage === "zh" ? "松开即可导入书库" : "Drop to import"
                color: Theme.accentText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH3
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "TXT · EPUB · PDF · MOBI"
                color: Theme.accentText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    Toast { id: toast }
}
