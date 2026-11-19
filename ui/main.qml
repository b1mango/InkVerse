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

    property string appLanguage: "zh"
    property var settings: ({})
    property var books: []
    property var collections: []
    property string navKey: "now"              // sidebar selection
    property bool isReading: false
    readonly property bool isSettings: navKey === "settings"

    function zh(a, b) { return appLanguage === "zh" ? a : b }

    function reloadLibrary() {
        books = backend.listBooks()
        collections = backend.listFolders() || []
        nowPage.refresh()
    }

    function navigate(key) {
        if (isReading) return
        navKey = key
        if (key === "now") nowPage.refresh()
    }

    // ── Opening a book: the cover grows from where it was clicked, then the page fades in ──
    property rect _sourceRect: Qt.rect(0, 0, 0, 0)
    property var _pendingBook: null

    function openBook(book, sourceItem) {
        if (!book || !book.id || isReading || zoom.running) return
        _pendingBook = book
        var cover = book.cover_path || ""
        if (!cover) for (var i = 0; i < books.length; i++) if (books[i].id === book.id) { cover = books[i].cover_path || ""; break }
        if (sourceItem && cover && !Theme.reduceMotion) {
            var r = sourceItem.mapToItem(window.contentItem, 0, 0, sourceItem.width, sourceItem.height)
            _sourceRect = Qt.rect(r.x, r.y, r.width, r.height)
            coverProxy.source = cover.charAt(0) === "/" ? "file://" + cover : "file:///" + cover
            zoom.direction = 1
            zoom.restart()
        } else {
            _sourceRect = Qt.rect(0, 0, 0, 0)
            _enterReader()
        }
    }

    function _enterReader() {
        readerPage.open(_pendingBook)
        isReading = true
        readerPage.forceActiveFocus()
    }

    function closeBook() {
        isReading = false
        reloadLibrary()
        if (_sourceRect.width > 0 && !Theme.reduceMotion) { zoom.direction = -1; zoom.restart() }
    }

    function saveSettings(patch) { window.settings = backend.saveSettings(patch) }

    function importUrls(urls) {
        if (!urls || urls.length === 0) return
        var before = books.length
        backend.importFiles(urls)
        reloadLibrary()
        if (navKey === "now" || navKey === "settings") navKey = "all"
        var added = books.length - before
        toast.show(added > 0
            ? zh("已导入 " + added + " 本书", "Imported " + added + (added === 1 ? " book" : " books"))
            : zh("没有可导入的文件，支持 TXT、EPUB、MOBI、PDF", "Nothing to import. TXT, EPUB, MOBI and PDF are supported"))
    }

    Component.onCompleted: {
        Theme.reduceMotion = typeof systemReduceMotion !== "undefined" && systemReduceMotion
        window.settings = backend.getSettings()
        Theme.preference = settings.theme || "system"
        appLanguage = settings.language || "zh"
        readerPage.applyPreferences(settings.reading || {})
        backend.ensureCovers()
        reloadLibrary()
    }
    Connections { target: backend; function onCoversUpdated() { window.reloadLibrary() } }

    Shortcut { sequences: [StandardKey.Find]; enabled: !window.isReading; onActivated: sidebar.focusSearch() }
    Shortcut { sequences: [StandardKey.Open]; enabled: !window.isReading; onActivated: libPage.openImportDialog() }
    Shortcut { sequence: "Ctrl+,"; enabled: !window.isReading; onActivated: window.navigate("settings") }

    // ── Library shell ──
    Item {
        id: shell
        anchors.fill: parent
        opacity: window.isReading ? 0 : 1
        enabled: !window.isReading
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: window.width < 1100 ? 204 : 232
                lang: window.appLanguage
                books: window.books
                collections: window.collections
                currentKey: window.navKey
                onNavigate: (key) => window.navigate(key)
                onCollectionsEdited: window.reloadLibrary()
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.navKey === "now" ? 0 : window.isSettings ? 2 : 1

                ReadingNowPage {
                    id: nowPage
                    objectName: "nowPage"
                    lang: window.appLanguage
                    books: window.books
                    onOpenBook: (book, source) => window.openBook(book, source)
                    onShowLibrary: window.navigate("all")
                    onImportRequested: libPage.openImportDialog()
                }

                LibraryPage {
                    id: libPage
                    objectName: "libraryPage"
                    lang: window.appLanguage
                    books: window.books
                    collections: window.collections
                    scopeKey: window.navKey
                    searchText: sidebar.searchText
                    viewMode: window.settings.library_view || "grid"
                    sortMode: window.settings.library_sort || "recent"
                    hiddenBookId: zoom.running && window._pendingBook ? window._pendingBook.id : ""
                    onBookSelected: (book, source) => window.openBook(book, source)
                    onImportRequested: (urls) => window.importUrls(urls)
                    onLibraryChanged: window.reloadLibrary()
                    onViewModeChosen: (mode) => window.saveSettings({ library_view: mode })
                    onSortModeChosen: (mode) => window.saveSettings({ library_sort: mode })
                }

                SettingsPage {
                    id: settingsPage
                    objectName: "settingsPage"
                    lang: window.appLanguage
                    themePreference: Theme.preference
                    readingFont: window.settings.reading ? window.settings.reading.font_family : "LXGW WenKai"
                    onThemeChosen: (value) => { Theme.preference = value; window.saveSettings({ theme: value }) }
                    onLanguageChosen: (value) => { window.appLanguage = value; window.saveSettings({ language: value }) }
                    onReadingFontChosen: (value) => { readerPage.fontFamily = value; window.saveSettings({ reading: { font_family: value } }) }
                }
            }
        }
    }

    // ── Reader layer ──
    ReaderPage {
        id: readerPage
        objectName: "readerPage"
        anchors.fill: parent
        lang: window.appLanguage
        visible: opacity > 0
        z: 899
        opacity: window.isReading ? 1 : 0
        enabled: window.isReading
        Behavior on opacity { NumberAnimation { duration: window.isReading ? Theme.durBase : Theme.durExit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
        onBackRequested: window.closeBook()
        onPreferencesChanged: (patch) => window.saveSettings({ reading: patch })
    }

    // Cover flying between its tile and the centre of the window
    Image {
        id: coverProxy
        objectName: "coverProxy"
        visible: zoom.running
        z: 900
        readonly property real targetH: Math.min(window.height * 0.66, 560)
        // Keep the tile's own proportions all the way, so it reads as the same object
        width: window._sourceRect.height > 0 ? targetH * window._sourceRect.width / window._sourceRect.height : targetH * 3 / 4
        height: targetH
        x: (window.width - width) / 2
        y: (window.height - height) / 2
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        transform: [
            Scale { id: proxyScale; origin.x: 0; origin.y: 0 },
            Translate { id: proxyMove }
        ]
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: Qt.rgba(0, 0, 0, 0.08); border.width: 1 }
    }

    // The reader's paper colour rises behind the flying cover, so the cover lands on the page
    Rectangle {
        id: zoomBackdrop
        anchors.fill: parent
        z: 898
        color: readerPage.bgColor
        opacity: 0
        visible: zoom.running
    }

    // Scale/translate only (no width/height animation), so the move stays on the GPU.
    // Open: fly to the centre, swap in the reader underneath, fade the cover out over the text.
    // Close: the reader fades, the cover flies back onto its tile and dissolves into it.
    SequentialAnimation {
        id: zoom
        property int direction: 1
        readonly property real sx: window._sourceRect.width / Math.max(1, coverProxy.width)
        readonly property real sy: window._sourceRect.height / Math.max(1, coverProxy.height)
        readonly property real dx: window._sourceRect.x - coverProxy.x
        readonly property real dy: window._sourceRect.y - coverProxy.y
        ScriptAction { script: { coverProxy.opacity = 1; zoomBackdrop.opacity = zoom.direction > 0 ? 0 : 1 } }
        ParallelAnimation {
            NumberAnimation { target: proxyScale; property: "xScale"; from: zoom.direction > 0 ? zoom.sx : 1; to: zoom.direction > 0 ? 1 : zoom.sx; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: proxyScale; property: "yScale"; from: zoom.direction > 0 ? zoom.sy : 1; to: zoom.direction > 0 ? 1 : zoom.sy; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: proxyMove; property: "x"; from: zoom.direction > 0 ? zoom.dx : 0; to: zoom.direction > 0 ? 0 : zoom.dx; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: proxyMove; property: "y"; from: zoom.direction > 0 ? zoom.dy : 0; to: zoom.direction > 0 ? 0 : zoom.dy; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { target: zoomBackdrop; property: "opacity"; from: zoom.direction > 0 ? 0 : 1; to: zoom.direction > 0 ? 1 : 0; duration: Theme.durSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeInOut }
        }
        ScriptAction { script: if (zoom.direction > 0) window._enterReader() }
        NumberAnimation { target: coverProxy; property: "opacity"; to: 0; duration: Theme.durBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
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
        color: Qt.rgba(Theme.accentSoft.r, Theme.accentSoft.g, Theme.accentSoft.b, 0.94)
        border.color: Theme.accent
        border.width: 2
        Column {
            anchors.centerIn: parent
            spacing: 10
            LucideIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "import"; size: 36; color: Theme.accentText }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: window.zh("松开即可导入书库", "Drop to import")
                color: Theme.accentText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH3
                font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "EPUB · MOBI · PDF · TXT"
                color: Theme.accentText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    Toast { id: toast }
}
