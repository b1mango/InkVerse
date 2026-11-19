import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components"
import "../theme"

/*  ReadingNowPage – 继续阅读：最近打开的书放大成主角（封面、进度、继续按钮），
    其余在读与最近添加排成书架，阅读时长与热力图收在一条安静的统计带里。  */
Item {
    id: root
    property string lang: "zh"
    property var books: []
    signal openBook(var book, var sourceItem)
    signal showLibrary()
    signal importRequested()

    property real totalHours: 0
    property int finishedBooks: 0
    property int totalBooks: 0
    property var heatmapData: []
    property var periodStats: ({})

    readonly property int _cell: 11
    readonly property int _gap: 3

    function zh(a, b) { return lang === "zh" ? a : b }
    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }
    function percentOf(b) { return b && b.progress && b.progress.percent !== undefined ? b.progress.percent : 0 }

    // Opened and not finished, most recent first
    readonly property var inProgress: {
        var out = []
        for (var i = 0; i < books.length; i++) {
            var b = books[i]
            if (b.last_opened && b.status !== "read" && percentOf(b) < 0.995) out.push(b)
        }
        out.sort(function(a, b) { return (b.last_opened || 0) - (a.last_opened || 0) })
        return out
    }
    readonly property var current: inProgress.length > 0 ? inProgress[0] : null
    readonly property var recentlyAdded: {
        var reading = {}
        for (var i = 0; i < inProgress.length; i++) reading[inProgress[i].id] = true
        var out = books.filter(function(b) { return !reading[b.id] })
        out.sort(function(a, b) { return (b.added_at || 0) - (a.added_at || 0) })
        return out.slice(0, 12)
    }

    function refresh() {
        if (!backend) return
        var stats = backend.getDashboardStats()
        if (stats) {
            totalHours = stats.total_hours || 0
            finishedBooks = stats.finished_books || 0
            totalBooks = stats.total_books || 0
        }
        heatmapData = backend.getReadingHeatmap() || []
        periodStats = backend.getReadingStatsByPeriod() || {}
    }
    function refreshDashboard() { refresh() }
    Component.onCompleted: refresh()

    function _number(m) { return m >= 60 ? (Math.round(m / 6) / 10).toString() : Math.round(m).toString() }
    function _unit(m) { return m >= 60 ? zh("小时", "hours") : zh("分钟", "min") }
    function _duration(m) {
        m = Math.abs(m)
        return m >= 60 ? (Math.round(m / 6) / 10) + zh(" 小时", " h") : Math.round(m) + zh(" 分钟", " min")
    }
    function _heatColor(minutes) {
        if (minutes <= 0) return Theme.dark ? Theme.surfaceHover : Theme.sunken
        var a = minutes < 15 ? 0.28 : minutes < 30 ? 0.46 : minutes < 60 ? 0.64 : minutes < 120 ? 0.82 : 1.0
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, a)
    }
    function _openDetail(book) {
        bookDetailDialog.detailData = backend.getBookReadingDetail(book.id) || {}
        bookDetailDialog.open()
    }

    ScrollView {
        id: scroller
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: scroller.availableWidth - 2 * Theme.pagePadding
            x: Theme.pagePadding
            spacing: 0

            RowLayout {
                Layout.topMargin: 28
                Layout.fillWidth: true
                Text {
                    text: zh("继续阅读", "Reading Now")
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontH1
                    font.weight: Font.DemiBold
                    Accessible.role: Accessible.Heading
                }
                Item { Layout.fillWidth: true }
                AppButton {
                    visible: root.books.length > 0
                    text: zh("阅读周报", "Weekly report")
                    iconName: "calendar"
                    variant: "ghost"
                    compact: true
                    onClicked: { weeklyReportDialog.reportData = backend.generateWeeklyReport() || {}; weeklyReportDialog.open() }
                }
            }

            // ── Hero: the book in hand ──
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.preferredHeight: root.current ? heroRow.implicitHeight : 0
                visible: root.current !== null

                RowLayout {
                    id: heroRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 32

                    Item {
                        id: heroCover
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 252
                        scale: heroMouse.pressed ? 0.98 : heroMouse.containsMouse ? 1.02 : 1
                        transformOrigin: Item.Bottom
                        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
                        BorderImage {
                            anchors.fill: parent
                            anchors.margins: -32
                            anchors.topMargin: -22
                            anchors.bottomMargin: -44
                            source: "../../assets/images/cover-shadow.png"
                            border { left: 40; right: 40; top: 40; bottom: 40 }
                            opacity: Theme.dark ? 0.8 : 0.38
                        }
                        Rectangle { anchors.fill: parent; radius: 3; color: Theme.sunken }
                        Image {
                            id: heroImage
                            anchors.fill: parent
                            source: root.current ? root.fileUrl(root.current.cover_path) : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.height: 504
                        }
                        Rectangle { anchors.fill: parent; color: "transparent"; radius: 3; border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08) }
                        MouseArea { id: heroMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openBook(root.current, heroCover) }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        spacing: 6
                        Text {
                            text: root.current ? (root.current.format || "txt").toUpperCase() + "  ·  " + zh("上次阅读 ", "Last read ") + Qt.formatDate(new Date((root.current.last_opened || 0) * 1000), "M月d日") : ""
                            color: Theme.textTertiary
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Medium
                            font.letterSpacing: 0.3
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.current ? root.current.title : ""
                            color: Theme.text
                            font.family: Theme.uiFont
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                            lineHeight: 1.18
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.current ? (root.current.author || zh("作者未知", "Unknown author")) : ""
                            color: Theme.textSecondary
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontBody
                        }
                        RowLayout {
                            Layout.topMargin: 14
                            Layout.maximumWidth: 360
                            spacing: 10
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 4
                                radius: 2
                                color: Theme.dark ? Theme.borderStrong : Theme.sunken
                                Rectangle { width: parent.width * root.percentOf(root.current); height: parent.height; radius: 2; color: Theme.accent }
                            }
                            Text {
                                text: Math.max(1, Math.round(root.percentOf(root.current) * 100)) + "%"
                                color: Theme.textSecondary
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontCaption
                                font.features: Theme.tabular
                            }
                        }
                        RowLayout {
                            Layout.topMargin: 14
                            spacing: 8
                            AppButton { text: zh("继续阅读", "Continue"); iconName: "book-open"; variant: "primary"; onClicked: root.openBook(root.current, heroCover) }
                            AppButton { text: zh("阅读详情", "Details"); iconName: "chart"; variant: "ghost"; onClicked: root._openDetail(root.current) }
                        }
                    }
                }
            }

            EmptyState {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 72
                Layout.bottomMargin: 24
                visible: root.current === null
                iconName: root.books.length === 0 ? "library" : "book-open"
                title: root.books.length === 0 ? zh("书库还是空的", "Your library is empty") : zh("还没有正在读的书", "Nothing in progress")
                detail: root.books.length === 0
                    ? zh("把文件拖进窗口，或点击下方导入\n支持 EPUB · MOBI · PDF · TXT", "Drag files into the window or import them below\nEPUB · MOBI · PDF · TXT")
                    : zh("从书库打开一本书，这里会记下你读到哪里", "Open a book and it will wait for you here")
                actionText: root.books.length === 0 ? zh("导入书籍", "Import books") : zh("浏览全部图书", "Browse all books")
                actionIcon: root.books.length === 0 ? "import" : "library"
                onAction: root.books.length === 0 ? root.importRequested() : root.showLibrary()
            }

            // ── Shelves ──
            // Other books in progress: compact rows, so the page keeps one hero
            Text {
                Layout.topMargin: 36
                visible: root.inProgress.length > 1
                text: zh("也在读", "Also reading")
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH3
                font.weight: Font.DemiBold
                Accessible.role: Accessible.Heading
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                visible: root.inProgress.length > 1
                columns: Math.max(1, Math.floor((width + 12) / (300 + 12)))
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: root.inProgress.slice(1, 7)
                    delegate: AbstractButton {
                        id: cont
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 84
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: modelData.title
                        onClicked: root.openBook(modelData, contCover)
                        background: Rectangle {
                            radius: Theme.radiusL
                            color: cont.hovered ? Theme.surfaceHover : Theme.surface
                            border.color: Theme.border
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            FocusRing { shown: cont.visualFocus }
                        }
                        contentItem: RowLayout {
                            spacing: 14
                            Rectangle {
                                id: contCover
                                Layout.leftMargin: 12
                                Layout.preferredWidth: 45
                                Layout.preferredHeight: 60
                                radius: 2
                                color: Theme.sunken
                                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
                                clip: true
                                Image { anchors.fill: parent; anchors.margins: 1; source: root.fileUrl(cont.modelData.cover_path); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.height: 120 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.rightMargin: 14
                                spacing: 6
                                Text { Layout.fillWidth: true; text: cont.modelData.title; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 3
                                        radius: 1.5
                                        color: Theme.dark ? Theme.borderStrong : Theme.sunken
                                        Rectangle { width: parent.width * root.percentOf(cont.modelData); height: parent.height; radius: 1.5; color: Theme.accent }
                                    }
                                    Text { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: Math.max(1, Math.round(root.percentOf(cont.modelData) * 100)) + "%"; color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular }
                                    Text { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; text: (cont.modelData.format || "txt").toUpperCase(); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                            }
                        }
                    }
                }
            }
            Shelf {
                title: zh("最近添加", "Recently added")
                model: root.recentlyAdded
                visible: root.books.length > 0
            }

            // ── Quiet stats strip ──
            Card {
                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.bottomMargin: 40
                Layout.preferredHeight: 150
                visible: root.books.length > 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 28

                    ColumnLayout {
                        Layout.preferredWidth: 150
                        spacing: 2
                        Text { text: zh("本周阅读", "This week"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.weight: Font.Medium }
                        Row {
                            spacing: 5
                            Text { id: weekNum; text: root._number(root.periodStats.week_minutes || 0); color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 28; font.weight: Font.DemiBold; font.features: Theme.tabular }
                            Text { anchors.baseline: weekNum.baseline; text: root._unit(root.periodStats.week_minutes || 0); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption }
                        }
                        Text {
                            text: {
                                var d = (root.periodStats.week_minutes || 0) - (root.periodStats.prev_week_minutes || 0)
                                if (Math.round(d) === 0) return zh("与上周持平", "Same as last week")
                                return zh("较上周", "vs last week") + (d > 0 ? " +" : " −") + root._duration(d)
                            }
                            color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                            text: zh("已读完 ", "Finished ") + root.finishedBooks + " / " + root.totalBooks + zh(" 本", "")
                            color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
                        }
                    }
                    Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }
                    Item {
                        id: heat
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        readonly property var cells: {
                            var data = root.heatmapData
                            if (!data || data.length === 0) return []
                            var out = []
                            for (var p = 0; p < (data[0].weekday || 0); p++) out.push({ date: "", minutes: -1 })
                            for (var i = 0; i < data.length; i++) out.push(data[i])
                            return out
                        }
                        readonly property int weeks: Math.ceil(cells.length / 7)
                        readonly property int visibleWeeks: Math.max(1, Math.min(weeks, Math.floor((width - 30) / (root._cell + root._gap))))
                        Text { id: heatTitle; text: zh("近半年", "Past six months"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.weight: Font.Medium }
                        Row {
                            anchors.top: heatTitle.bottom
                            anchors.topMargin: 10
                            spacing: 6
                            Column {
                                spacing: root._gap
                                Repeater {
                                    model: lang === "zh" ? ["一", "", "三", "", "五", "", "日"] : ["M", "", "W", "", "F", "", "S"]
                                    Text { width: 18; height: root._cell; text: modelData; color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight }
                                }
                            }
                            Grid {
                                rows: 7
                                flow: Grid.TopToBottom
                                spacing: root._gap
                                Repeater {
                                    model: heat.cells.slice(Math.max(0, (heat.weeks - heat.visibleWeeks) * 7))
                                    Rectangle {
                                        width: root._cell; height: root._cell; radius: 2
                                        color: modelData.minutes < 0 ? "transparent" : root._heatColor(modelData.minutes)
                                        ToolTip.visible: cellMouse.containsMouse && modelData.minutes >= 0
                                        ToolTip.delay: 200
                                        ToolTip.text: modelData.date + "  " + (modelData.minutes > 0 ? root._duration(modelData.minutes) : zh("未阅读", "No reading"))
                                        MouseArea { id: cellMouse; anchors.fill: parent; hoverEnabled: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // A horizontal shelf of covers with progress
    component Shelf: ColumnLayout {
        id: shelf
        property string title
        property var model: []
        Layout.fillWidth: true
        Layout.topMargin: 36
        spacing: 12
        Text { text: shelf.title; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontH3; font.weight: Font.DemiBold; Accessible.role: Accessible.Heading }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 256
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            model: shelf.model
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: BookTile {
                id: shelfTile
                required property var modelData
                width: 148
                height: 256
                book: modelData
                lang: root.lang
                onOpen: root.openBook(modelData, shelfTile.coverItem)
                onMenuRequested: root._openDetail(modelData)
            }
        }
    }

    // ── Single-book detail ──
    AppModal {
        id: bookDetailDialog
        property var detailData: ({})
        title: detailData.title || ""
        preferredWidth: 520

        RowLayout {
            Layout.fillWidth: true
            spacing: 28
            Repeater {
                model: [
                    { label: zh("总阅读", "Total"), value: root._duration(bookDetailDialog.detailData.total_minutes || 0) },
                    { label: zh("阅读天数", "Days"), value: (bookDetailDialog.detailData.reading_days || 0) + zh(" 天", " d") },
                    { label: zh("日均", "Per day"), value: Math.round(bookDetailDialog.detailData.avg_per_day || 0) + zh(" 分钟", " min") }
                ]
                ColumnLayout {
                    spacing: 2
                    Text { text: modelData.label; color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption }
                    Text { text: modelData.value; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontH3; font.weight: Font.DemiBold; font.features: Theme.tabular }
                }
            }
            Item { Layout.fillWidth: true }
        }

        Text { Layout.topMargin: 8; text: zh("近 30 天", "Last 30 days"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            Row {
                id: barChart
                anchors.fill: parent
                anchors.bottomMargin: 18
                spacing: 2
                readonly property real maxVal: {
                    var m = 1, dd = bookDetailDialog.detailData.daily_data
                    if (dd) for (var i = 0; i < dd.length; i++) m = Math.max(m, dd[i].minutes)
                    return m
                }
                Repeater {
                    model: bookDetailDialog.detailData.daily_data || []
                    Item {
                        width: (barChart.width - 29 * barChart.spacing) / 30
                        height: barChart.height
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(2, modelData.minutes / barChart.maxVal * (parent.height - 4))
                            radius: 2
                            color: modelData.minutes > 0 ? Theme.accent : Theme.sunken
                            ToolTip.visible: barMouse.containsMouse && modelData.minutes > 0
                            ToolTip.text: modelData.date + "  " + root._duration(modelData.minutes)
                            MouseArea { id: barMouse; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }
            }
            Text {
                anchors.left: parent.left; anchors.bottom: parent.bottom
                text: { var dd = bookDetailDialog.detailData.daily_data; return dd && dd.length ? dd[0].date.substring(5) : "" }
                color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 11; font.features: Theme.tabular
            }
            Text {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                text: { var dd = bookDetailDialog.detailData.daily_data; return dd && dd.length ? dd[dd.length - 1].date.substring(5) : "" }
                color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 11; font.features: Theme.tabular
            }
        }

        Text {
            visible: !!bookDetailDialog.detailData.first_read
            text: zh("首次阅读 ", "First read ") + (bookDetailDialog.detailData.first_read || "") + "  ·  " + zh("最近阅读 ", "Last read ") + (bookDetailDialog.detailData.last_read || "")
            color: Theme.textTertiary
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontCaption
            font.features: Theme.tabular
        }
        AppButton {
            Layout.alignment: Qt.AlignRight
            text: zh("打开这本书", "Open book")
            iconName: "book-open"
            variant: "primary"
            onClicked: { bookDetailDialog.close(); root.openBook({ id: bookDetailDialog.detailData.book_id || bookDetailDialog.detailData.id, title: bookDetailDialog.detailData.title, format: bookDetailDialog.detailData.format }) }
            visible: !!(bookDetailDialog.detailData.book_id || bookDetailDialog.detailData.id)
        }
    }

    // ── Weekly report ──
    AppModal {
        id: weeklyReportDialog
        property var reportData: ({})
        title: zh("阅读周报", "Weekly report")
        preferredWidth: 480

        Text {
            text: (weeklyReportDialog.reportData.week_start || "") + " – " + (weeklyReportDialog.reportData.week_end || "")
            color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
        }
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 0
                Row {
                    spacing: 6
                    Text { text: root._number(weeklyReportDialog.reportData.total_minutes || 0); color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 34; font.weight: Font.DemiBold; font.features: Theme.tabular }
                    Text { anchors.baseline: parent.children[0].baseline; text: root._unit(weeklyReportDialog.reportData.total_minutes || 0); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall }
                }
                Text {
                    text: {
                        var cur = weeklyReportDialog.reportData.total_minutes || 0
                        var d = cur - (weeklyReportDialog.reportData.prev_week_minutes || 0)
                        if (Math.round(d) === 0) return zh("与上周持平", "Same as last week")
                        return zh("较上周", "vs last week") + (d > 0 ? " +" : " −") + root._duration(d)
                    }
                    color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 0
                Text { Layout.alignment: Qt.AlignRight; text: (weeklyReportDialog.reportData.reading_days || 0) + " / 7"; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontH2; font.weight: Font.DemiBold; font.features: Theme.tabular }
                Text { Layout.alignment: Qt.AlignRight; text: zh("有阅读的天数", "Active days"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 104
            Row {
                id: weekBars
                anchors.fill: parent
                anchors.bottomMargin: 22
                spacing: 10
                readonly property real maxVal: {
                    var m = 1, wd = weeklyReportDialog.reportData.daily
                    if (wd) for (var i = 0; i < wd.length; i++) m = Math.max(m, wd[i].minutes)
                    return m
                }
                Repeater {
                    model: weeklyReportDialog.reportData.daily || []
                    Item {
                        width: (weekBars.width - 6 * weekBars.spacing) / 7
                        height: weekBars.height
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(3, modelData.minutes / weekBars.maxVal * (parent.height - 4))
                            radius: 3
                            color: modelData.minutes > 0 ? Theme.accent : Theme.sunken
                        }
                        Text {
                            anchors.top: parent.bottom; anchors.topMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (lang === "zh" ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"])[modelData.weekday || 0]
                            color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 11
                        }
                    }
                }
            }
        }

        Text { Layout.topMargin: 4; text: zh("本周读得最多", "Most read"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium; visible: (weeklyReportDialog.reportData.top_books || []).length > 0 }
        Repeater {
            model: weeklyReportDialog.reportData.top_books || []
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: index + 1; color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.features: Theme.tabular; Layout.preferredWidth: 14 }
                Text { Layout.fillWidth: true; text: modelData.title || ""; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontBody; elide: Text.ElideRight }
                Text { text: root._duration(modelData.minutes || 0); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontCaption; font.features: Theme.tabular }
            }
        }
    }
}
