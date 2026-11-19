import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../components"
import "../theme"

/*  DashboardPage – 阅读概览：时长、完成度、热力图、继续阅读；周报与单本详情在模态框里  */
Item {
    id: root
    property string lang: "zh"
    signal openBook(var book)
    signal showLibrary()

    property real totalHours: 0
    property int finishedBooks: 0
    property int totalBooks: 0
    property var heatmapData: []
    property var recentBooks: []
    property var periodStats: ({})
    property string statsPeriod: "week"

    readonly property int _cell: 12
    readonly property int _gap: 3

    function zh(a, b) { return lang === "zh" ? a : b }
    function fileUrl(p) { return !p ? "" : (p.charAt(0) === "/" ? "file://" + p : "file:///" + p) }

    function refreshDashboard() {
        if (!backend) return
        var stats = backend.getDashboardStats()
        if (stats) {
            totalHours = stats.total_hours || 0
            finishedBooks = stats.finished_books || 0
            totalBooks = stats.total_books || 0
        }
        heatmapData = backend.getReadingHeatmap() || []
        recentBooks = backend.getRecentBooks() || []
        periodStats = backend.getReadingStatsByPeriod() || {}
    }

    Component.onCompleted: refreshDashboard()

    function _periodMinutes() {
        var ps = root.periodStats
        if (!ps) return 0
        if (statsPeriod === "day") return ps.today_minutes || 0
        if (statsPeriod === "week") return ps.week_minutes || 0
        if (statsPeriod === "month") return ps.month_minutes || 0
        return ps.year_minutes || 0
    }
    function _periodPrevMinutes() {
        var ps = root.periodStats
        if (statsPeriod === "week") return ps.prev_week_minutes || 0
        if (statsPeriod === "month") return ps.prev_month_minutes || 0
        return 0
    }
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
            spacing: 16

            RowLayout {
                Layout.topMargin: 32
                Layout.fillWidth: true
                Text {
                    text: zh("阅读概览", "Overview")
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontH1
                    font.weight: Font.DemiBold
                    Accessible.role: Accessible.Heading
                }
                Item { Layout.fillWidth: true }
                AppButton {
                    text: zh("阅读周报", "Weekly report")
                    iconName: "calendar"
                    onClicked: { weeklyReportDialog.reportData = backend.generateWeeklyReport() || {}; weeklyReportDialog.open() }
                }
            }

            // ── Stats row ──
            GridLayout {
                Layout.fillWidth: true
                columns: width > 980 ? 3 : 2
                columnSpacing: 12
                rowSpacing: 12

                // Reading time for the chosen period
                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 168
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: zh("阅读时长", "Reading time"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium }
                            SegmentedControl {
                                segmentHeight: 24
                                value: root.statsPeriod
                                options: [
                                    { label: zh("日", "D"), value: "day" }, { label: zh("周", "W"), value: "week" },
                                    { label: zh("月", "M"), value: "month" }, { label: zh("年", "Y"), value: "year" }
                                ]
                                onActivated: (v) => root.statsPeriod = v
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Row {
                            spacing: 6
                            Text { text: root._number(root._periodMinutes()); color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 34; font.weight: Font.DemiBold; font.features: Theme.tabular }
                            Text { anchors.baseline: parent.children[0].baseline; text: root._unit(root._periodMinutes()); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.statsPeriod !== "week" && root.statsPeriod !== "month")
                                    return root.statsPeriod === "day" ? zh("今天", "Today") : zh("今年累计", "This year")
                                var cur = root._periodMinutes(), prev = root._periodPrevMinutes(), d = cur - prev
                                var base = root.statsPeriod === "week" ? zh("较上周", "vs last week") : zh("较上月", "vs last month")
                                if (Math.round(d) === 0) return base + zh(" 持平", " unchanged")
                                return base + (d > 0 ? " +" : " −") + root._duration(d)
                            }
                            color: Theme.textSecondary
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontCaption
                            font.features: Theme.tabular
                        }
                    }
                }

                // Finished / total
                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 168
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 4
                        Text { text: zh("已读完", "Finished"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium }
                        Item { Layout.fillHeight: true }
                        Row {
                            spacing: 6
                            Text { text: root.finishedBooks; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 34; font.weight: Font.DemiBold; font.features: Theme.tabular }
                            Text { anchors.baseline: parent.children[0].baseline; text: "/ " + root.totalBooks + zh(" 本", " books"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.features: Theme.tabular }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            height: 6; radius: 3
                            color: Theme.sunken
                            Rectangle {
                                width: root.totalBooks > 0 ? parent.width * root.finishedBooks / root.totalBooks : 0
                                height: parent.height; radius: 3
                                color: Theme.accent
                            }
                        }
                        Text {
                            text: zh("累计阅读 ", "Total ") + root._duration(root.totalHours * 60)
                            color: Theme.textSecondary
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontCaption
                            font.features: Theme.tabular
                        }
                    }
                }

                // Heatmap: the one coloured element on the page
                Card {
                    id: heatCard
                    Layout.fillWidth: true
                    Layout.columnSpan: parent.columns === 3 ? 1 : 2
                    Layout.preferredWidth: parent.columns === 3 ? 2 : 1
                    Layout.preferredHeight: 168
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
                    readonly property int visibleWeeks: Math.max(1, Math.min(weeks, Math.floor((width - 56) / (root._cell + root._gap))))

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: zh("阅读热力图", "Activity"); color: Theme.textSecondary; font.family: Theme.uiFont; font.pixelSize: Theme.fontSmall; font.weight: Font.Medium }
                            Text { text: zh("少", "Less"); color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 11 }
                            Repeater { model: [0, 10, 25, 50, 100, 150]; Rectangle { width: 10; height: 10; radius: 2; color: root._heatColor(modelData) } }
                            Text { text: zh("多", "More"); color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 11 }
                        }
                        Row {
                            spacing: 6
                            Column {
                                spacing: root._gap
                                Repeater {
                                    model: lang === "zh" ? ["一", "", "三", "", "五", "", "日"] : ["Mon", "", "Wed", "", "Fri", "", "Sun"]
                                    Text { width: 24; height: root._cell; text: modelData; color: Theme.textTertiary; font.family: Theme.uiFont; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight }
                                }
                            }
                            Grid {
                                rows: 7
                                flow: Grid.TopToBottom
                                spacing: root._gap
                                Repeater {
                                    // Only the latest weeks that fit
                                    model: heatCard.cells.slice(Math.max(0, (heatCard.weeks - heatCard.visibleWeeks) * 7))
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

            // ── Continue reading ──
            Text {
                Layout.topMargin: 12
                text: zh("继续阅读", "Continue reading")
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontH3
                font.weight: Font.DemiBold
                Accessible.role: Accessible.Heading
            }

            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: 24
                visible: root.recentBooks.length === 0
                iconName: "book-open"
                title: zh("还没有阅读记录", "No reading yet")
                detail: zh("从书库打开一本书，这里会记下你读到哪里", "Open a book from the library and it will show up here")
                actionText: zh("前往书库", "Go to library")
                actionIcon: "library"
                onAction: root.showLibrary()
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 40
                visible: root.recentBooks.length > 0
                columns: Math.max(1, Math.floor((width + 12) / (300 + 12)))
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: root.recentBooks
                    delegate: AbstractButton {
                        id: recent
                        Layout.fillWidth: true
                        implicitHeight: 96
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: modelData.title
                        onClicked: root.openBook(modelData)
                        Keys.onMenuPressed: root._openDetail(modelData)

                        background: Rectangle {
                            radius: Theme.radiusL
                            color: recent.hovered ? Theme.surfaceHover : Theme.surface
                            border.color: Theme.border
                            FocusRing { shown: recent.visualFocus }
                        }
                        contentItem: RowLayout {
                            spacing: 14
                            Rectangle {
                                Layout.leftMargin: 14
                                Layout.preferredWidth: 51
                                Layout.preferredHeight: 68
                                radius: Theme.radiusS
                                color: Theme.sunken
                                border.color: Theme.border
                                clip: true
                                Image { anchors.fill: parent; anchors.margins: 1; source: root.fileUrl(modelData.cover_path); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { Layout.fillWidth: true; text: modelData.title || ""; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text {
                                    Layout.fillWidth: true
                                    text: root._duration(modelData.reading_minutes || 0) + "  ·  " + (modelData.format || "txt").toUpperCase()
                                    color: Theme.textSecondary
                                    font.family: Theme.uiFont
                                    font.pixelSize: Theme.fontCaption
                                    font.features: Theme.tabular
                                }
                                Text {
                                    visible: !!modelData.last_read
                                    text: zh("最近 ", "Last ") + (modelData.last_read || "")
                                    color: Theme.textTertiary
                                    font.family: Theme.uiFont
                                    font.pixelSize: Theme.fontCaption
                                    font.features: Theme.tabular
                                }
                            }
                            IconButton {
                                Layout.rightMargin: 8
                                iconName: "chart"
                                label: zh("阅读详情", "Reading details")
                                opacity: recent.hovered || recent.activeFocus ? 1 : 0
                                onClicked: root._openDetail(modelData)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: root._openDetail(modelData)
                        }
                    }
                }
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
