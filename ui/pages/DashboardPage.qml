import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

/*  DashboardPage – 水墨风首页 + 多维统计 + 阅读热力图 + 最近在读 + 周报  */
Item {
    id: root
    property string lang: "zh"
    property string appFont: "Long Cang"
    property int appFontBoldW: Font.Bold
    property int appFontNormW: Font.Normal

    signal openBook(var book)

    // ── Dashboard data ──
    property real totalHours: 0
    property int finishedBooks: 0
    property int totalBooks: 0
    property var heatmapData: []
    property var recentBooks: []
    property var periodStats: ({})
    property string statsPeriod: "week"  // "day", "week", "month", "year"

    // Ink palette
    readonly property string _ink:      "#2a2828"
    readonly property string _inkLight: "#555050"
    readonly property string _inkDim:   "#8a8580"

    // Computed heatmap week count (for width constraint)
    property int _heatWeeks: {
        var data = root.heatmapData
        if (!data || data.length === 0) return 26
        var pad = data[0].weekday || 0
        return Math.ceil((pad + data.length) / 7)
    }

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

    // ── Time-based greeting ──
    function _greeting() {
        var h = new Date().getHours()
        if (lang === "zh") {
            if (h < 6) return "夜深了，旅人。"
            if (h < 12) return "早安，旅人。"
            if (h < 14) return "午安，旅人。"
            if (h < 18) return "下午好，旅人。"
            return "晚上好，旅人。"
        } else {
            if (h < 6) return "Midnight, Traveler."
            if (h < 12) return "Good Morning, Traveler."
            if (h < 14) return "Good Afternoon, Traveler."
            if (h < 18) return "Good Afternoon, Traveler."
            return "Good Evening, Traveler."
        }
    }

    function _periodMinutes() {
        var ps = root.periodStats
        if (!ps) return 0
        if (statsPeriod === "day")   return ps.today_minutes || 0
        if (statsPeriod === "week")  return ps.week_minutes || 0
        if (statsPeriod === "month") return ps.month_minutes || 0
        if (statsPeriod === "year")  return ps.year_minutes || 0
        return 0
    }

    function _periodLabel() {
        if (lang === "zh") {
            if (statsPeriod === "day")   return "今日阅读"
            if (statsPeriod === "week")  return "本周阅读"
            if (statsPeriod === "month") return "本月阅读"
            return "今年阅读"
        } else {
            if (statsPeriod === "day")   return "Today"
            if (statsPeriod === "week")  return "This Week"
            if (statsPeriod === "month") return "This Month"
            return "This Year"
        }
    }

    function _periodDelta() {
        var ps = root.periodStats
        if (!ps) return 0
        if (statsPeriod === "week") return (ps.week_minutes || 0) - (ps.prev_week_minutes || 0)
        if (statsPeriod === "month") return (ps.month_minutes || 0) - (ps.prev_month_minutes || 0)
        return 0
    }

    function _formatMinutes(m) {
        if (m >= 60) return (Math.round(m / 6) / 10).toString()
        return Math.round(m).toString()
    }

    function _formatMinutesUnit(m) {
        if (m >= 60) return lang === "zh" ? "小时" : "hours"
        return lang === "zh" ? "分钟" : "min"
    }

    // Ink-wash heatmap color
    function _heatColor(minutes) {
        if (minutes <= 0) return "#12a09888"
        if (minutes < 15)  return "#40716b64"
        if (minutes < 30)  return "#60716b64"
        if (minutes < 60)  return "#88555050"
        if (minutes < 120) return "#aa3d3a38"
        return "#cc2a2828"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 50
        anchors.topMargin: 40
        spacing: 24

        // ── Greeting + Weekly Report Button ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: _greeting()
                color: _ink
                font.pixelSize: 34
                font.weight: root.appFontBoldW
                font.family: root.appFont
            }

            Item { Layout.fillWidth: true }

            // Weekly report button
            Rectangle {
                width: reportRow.implicitWidth + 20
                height: 34; radius: 17
                color: reportMa.containsMouse ? "#30a09888" : "#18a09888"
                border.color: "#30a09888"

                RowLayout {
                    id: reportRow
                    anchors.centerIn: parent
                    spacing: 6
                    // Mini scroll icon
                    Item {
                        width: 18; height: 16
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle { x: 3; y: 3; width: 12; height: 10; color: "#c8c0b0"; radius: 1
                            Column { anchors.centerIn: parent; spacing: 2
                                Repeater { model: 3; Rectangle { width: 7; height: 0.8; color: "#a09888" } }
                            }
                        }
                        Rectangle { x: 1; y: 1; width: 16; height: 4; radius: 2; color: "#b8b0a0" }
                        Rectangle { x: 1; y: 11; width: 16; height: 4; radius: 2; color: "#b8b0a0" }
                    }
                    Text {
                        text: lang === "zh" ? "阅读周报" : "Weekly Report"
                        color: _inkLight; font.pixelSize: 13
                    }
                }
                MouseArea {
                    id: reportMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var rpt = backend.generateWeeklyReport()
                        weeklyReportDialog.reportData = rpt || {}
                        weeklyReportDialog.visible = true
                    }
                }
            }
        }

        // ── Top row: Period Stats + Book Count + Heatmap ──
        RowLayout {
            spacing: 16
            Layout.fillWidth: true
            Layout.preferredHeight: 145
            Layout.maximumHeight: 145

            // ── 1. Multi-dimensional reading stats card ──
            GlassPanel {
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                layer.enabled: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    // Period tabs
                    Row {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: [
                                { key: "day",   zh: "日", en: "D" },
                                { key: "week",  zh: "周", en: "W" },
                                { key: "month", zh: "月", en: "M" },
                                { key: "year",  zh: "年", en: "Y" }
                            ]
                            Rectangle {
                                width: (200 - 28 - 6) / 4; height: 22; radius: 6
                                color: root.statsPeriod === modelData.key ? "#30a09888" : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: lang === "zh" ? modelData.zh : modelData.en
                                    color: root.statsPeriod === modelData.key ? _ink : _inkDim
                                    font.pixelSize: 11
                                    font.weight: root.statsPeriod === modelData.key ? Font.DemiBold : Font.Normal
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.statsPeriod = modelData.key
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Big number
                    Text {
                        text: _formatMinutes(_periodMinutes())
                        color: _ink
                        font.pixelSize: 34
                        font.weight: root.appFontBoldW
                        font.family: root.appFont
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: _formatMinutesUnit(_periodMinutes())
                        color: _inkDim
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: _periodLabel()
                        color: _inkDim
                        font.pixelSize: 11
                        opacity: 0.7
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Delta comparison (week/month only)
                    Text {
                        visible: statsPeriod === "week" || statsPeriod === "month"
                        text: {
                            var d = _periodDelta()
                            if (d === 0) return ""
                            var val = Math.abs(d) >= 60
                                ? (Math.round(Math.abs(d) / 6) / 10) + "h"
                                : Math.round(Math.abs(d)) + "m"
                            var prefix = d > 0 ? "↑ " : "↓ "
                            return prefix + val
                        }
                        color: _periodDelta() >= 0 ? "#5a8a6a" : "#8a5a5a"
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignHCenter
                        opacity: 0.8
                    }
                }
            }

            // ── 2. Book count card ──
            GlassPanel {
                Layout.preferredWidth: 150
                Layout.fillHeight: true
                layer.enabled: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4
                        Text {
                            text: root.finishedBooks.toString()
                            color: _ink
                            font.pixelSize: 32
                            font.weight: root.appFontBoldW
                            font.family: root.appFont
                        }
                        Text {
                            text: "/"
                            color: _inkDim
                            font.pixelSize: 20
                            Layout.alignment: Qt.AlignBaseline
                        }
                        Text {
                            text: root.totalBooks.toString()
                            color: _inkLight
                            font.pixelSize: 20
                            Layout.alignment: Qt.AlignBaseline
                        }
                    }
                    Text {
                        text: lang === "zh" ? "已读 / 总数" : "Read / Total"
                        color: _inkDim
                        font.pixelSize: 11
                        opacity: 0.7
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // ── 3. Heatmap card (constrained width) ──
            GlassPanel {
                Layout.fillWidth: true
                Layout.maximumWidth: root._heatWeeks * 12 + 80
                Layout.fillHeight: true
                layer.enabled: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: lang === "zh" ? "阅读热力图" : "Reading Heatmap"
                            color: _inkLight
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        // Legend
                        RowLayout {
                            spacing: 3
                            Text { text: lang === "zh" ? "少" : "Less"; color: _inkDim; font.pixelSize: 8 }
                            Repeater {
                                model: [0, 10, 25, 50, 100]
                                Rectangle { width: 9; height: 9; radius: 2; color: _heatColor(modelData) }
                            }
                            Text { text: lang === "zh" ? "多" : "More"; color: _inkDim; font.pixelSize: 8 }
                        }
                    }

                    // Weekday labels + grid
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Column {
                            id: weekLabels
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            spacing: 1

                            Repeater {
                                model: lang === "zh"
                                    ? ["\u4E00", "\u4E8C", "\u4E09", "\u56DB", "\u4E94", "\u516D", "\u65E5"]
                                    : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                                Text {
                                    width: 18; height: 11
                                    text: (index % 2 === 0) ? modelData : ""
                                    color: _inkDim; font.pixelSize: 7
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        Grid {
                            id: heatGridLayout
                            anchors.left: weekLabels.right
                            anchors.leftMargin: 3
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            rows: 7
                            flow: Grid.TopToBottom
                            spacing: 1

                            Repeater {
                                model: {
                                    var data = root.heatmapData
                                    if (!data || data.length === 0) return []
                                    var result = []
                                    var firstWeekday = data[0].weekday
                                    for (var p = 0; p < firstWeekday; p++)
                                        result.push({ date: "", minutes: -1, weekday: p })
                                    for (var i = 0; i < data.length; i++)
                                        result.push(data[i])
                                    return result
                                }

                                Rectangle {
                                    width: 11; height: 11; radius: 2
                                    color: modelData.minutes < 0 ? "transparent" : _heatColor(modelData.minutes)
                                    visible: modelData.minutes >= 0

                                    ToolTip {
                                        visible: cellMa.containsMouse && modelData.minutes >= 0
                                        text: {
                                            if (!modelData || modelData.minutes < 0) return ""
                                            var d = modelData.date || ""
                                            var m = Math.round(modelData.minutes || 0)
                                            if (m === 0) return d + (lang === "zh" ? "\n\u65E0\u9605\u8BFB\u8BB0\u5F55" : "\nNo reading")
                                            return d + "\n" + m + (lang === "zh" ? " \u5206\u949F" : " min")
                                        }
                                        delay: 300; font.pixelSize: 11
                                        background: Rectangle { color: "#eeecea"; border.color: "#c8c5c0"; radius: 6 }
                                    }
                                    MouseArea { id: cellMa; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }

                        // Month labels
                        Item {
                            anchors.left: heatGridLayout.left
                            anchors.right: heatGridLayout.right
                            anchors.bottom: parent.bottom
                            height: 14

                            Repeater {
                                model: {
                                    var data = root.heatmapData
                                    if (!data || data.length === 0) return []
                                    var cellStep = 11 + 1
                                    var months = []; var lastMonth = -1; var currentWeek = 0
                                    for (var i = 0; i < data.length; i++) {
                                        var idx = i + (data[0].weekday || 0)
                                        currentWeek = Math.floor(idx / 7)
                                        var d = new Date(data[i].date)
                                        var m = d.getMonth()
                                        if (m !== lastMonth) {
                                            months.push({ label: (lang === "zh"
                                                ? ["1\u6708","2\u6708","3\u6708","4\u6708","5\u6708","6\u6708","7\u6708","8\u6708","9\u6708","10\u6708","11\u6708","12\u6708"]
                                                : ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"])[m],
                                                weekOffset: currentWeek })
                                            lastMonth = m
                                        }
                                    }
                                    return months
                                }
                                Text { x: modelData.weekOffset * (11 + 1); text: modelData.label; color: _inkDim; font.pixelSize: 7 }
                            }
                        }
                    }
                }
            }
        }

        // ── Recently Reading Section ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Text {
                text: lang === "zh" ? "最近在读" : "Recently Reading"
                color: _inkLight
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.family: root.appFont
            }

            // Books grid or empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: root.recentBooks.length === 0

                    Text {
                        text: "\uD83D\uDCD6"
                        font.pixelSize: 48
                        opacity: 0.3
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: lang === "zh" ? "还没有阅读记录" : "No reading history yet"
                        color: _inkDim
                        font.pixelSize: 15
                        opacity: 0.5
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: lang === "zh" ? "去书库挑选一本书开始阅读吧" : "Pick a book from the library to start reading"
                        color: _inkDim
                        font.pixelSize: 12
                        opacity: 0.4
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Recent books (Flow auto-wrap)
                Flickable {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    contentHeight: recentFlow.implicitHeight
                    clip: true
                    visible: root.recentBooks.length > 0
                    boundsBehavior: Flickable.StopAtBounds

                    Flow {
                        id: recentFlow
                        width: parent.width
                        spacing: 14

                        Repeater {
                            model: root.recentBooks

                            GlassPanel {
                                width: 180
                                height: 75

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 6

                                    // Book title
                                    Text {
                                        text: modelData.title || ""
                                        color: _ink
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        font.family: root.appFont
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        verticalAlignment: Text.AlignBottom
                                    }

                                    // Reading time + format
                                    RowLayout {
                                        spacing: 6
                                        Layout.fillWidth: true
                                        Text {
                                            text: {
                                                var m = modelData.reading_minutes || 0
                                                if (m >= 60) return Math.round(m / 60 * 10) / 10 + (lang === "zh" ? " \u5C0F\u65F6" : "h")
                                                return Math.round(m) + (lang === "zh" ? " \u5206\u949F" : "m")
                                            }
                                            color: _inkDim
                                            font.pixelSize: 10
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            width: fmtLbl.implicitWidth + 8
                                            height: 16; radius: 8
                                            color: "#18908880"
                                            Text {
                                                id: fmtLbl
                                                anchors.centerIn: parent
                                                text: modelData.format ? modelData.format.toUpperCase() : "TXT"
                                                color: _inkDim
                                                font.pixelSize: 8
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onEntered: parent.border.color = "#50908880"
                                    onExited: parent.border.color = "#30b8b4b0"
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            var detail = backend.getBookReadingDetail(modelData.id)
                                            bookDetailDialog.detailData = detail || {}
                                            bookDetailDialog.visible = true
                                        } else {
                                            root.openBook(modelData)
                                        }
                                    }
                                    onPressAndHold: {
                                        var detail = backend.getBookReadingDetail(modelData.id)
                                        bookDetailDialog.detailData = detail || {}
                                        bookDetailDialog.visible = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Reading quote ──
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var lq = "\u201C"
                    var rq = "\u201D"
                    var quotes = lang === "zh"
                        ? [lq + "读书破万卷，下笔如有神。" + rq + " —— 杜甫",
                           lq + "书中自有黄金屋。" + rq + " —— 赵恒",
                           lq + "学而不思则罔，思而不学则殆。" + rq + " —— 孔子",
                           lq + "读万卷书，行万里路。" + rq + " —— 刘彝",
                           lq + "腹有诗书气自华。" + rq + " —— 苏轼",
                           lq + "书山有路勤为径。" + rq + " —— 韩愈"]
                        : [lq + "A reader lives a thousand lives." + rq + " - George R.R. Martin",
                           lq + "The more that you read, the more things you will know." + rq + " - Dr. Seuss",
                           lq + "A room without books is like a body without a soul." + rq + " - Cicero",
                           lq + "Reading is to the mind what exercise is to the body." + rq + " - Joseph Addison"]
                    var dayOfYear = Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0)) / 86400000)
                    return quotes[dayOfYear % quotes.length]
                }
                color: _inkDim
                font.pixelSize: 12
                font.italic: true
                font.family: root.appFont
                opacity: 0.6
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // ── Book Detail Dialog (right-click / long-press on recent book) ──
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: bookDetailDialog
        visible: false; z: 300
        anchors.fill: parent
        color: "#88282828"

        property var detailData: ({})

        MouseArea { anchors.fill: parent; onClicked: bookDetailDialog.visible = false }

        GlassPanel {
            anchors.centerIn: parent
            width: 500; height: 420
            color: "#f0eeecea"

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 30
                spacing: 16

                // Title
                Text {
                    text: bookDetailDialog.detailData.title || ""
                    color: _ink; font.pixelSize: 20; font.weight: Font.Bold
                    font.family: root.appFont
                    elide: Text.ElideRight; Layout.fillWidth: true
                }

                // Meta info row
                RowLayout {
                    spacing: 16; Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 2
                        Text { text: lang === "zh" ? "总阅读" : "Total"; color: _inkDim; font.pixelSize: 10 }
                        Text {
                            text: {
                                var m = bookDetailDialog.detailData.total_minutes || 0
                                if (m >= 60) return (Math.round(m / 6) / 10) + (lang === "zh" ? " 小时" : "h")
                                return Math.round(m) + (lang === "zh" ? " 分钟" : "m")
                            }
                            color: _ink; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text { text: lang === "zh" ? "阅读天数" : "Days"; color: _inkDim; font.pixelSize: 10 }
                        Text {
                            text: (bookDetailDialog.detailData.reading_days || 0) + (lang === "zh" ? " 天" : "d")
                            color: _ink; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Text { text: lang === "zh" ? "日均" : "Avg/Day"; color: _inkDim; font.pixelSize: 10 }
                        Text {
                            text: {
                                var m = bookDetailDialog.detailData.avg_per_day || 0
                                return Math.round(m) + (lang === "zh" ? " 分钟" : "m")
                            }
                            color: _ink; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Format badge
                    Rectangle {
                        width: detFmtLbl.implicitWidth + 12; height: 22; radius: 11
                        color: "#18908880"
                        Text {
                            id: detFmtLbl; anchors.centerIn: parent
                            text: (bookDetailDialog.detailData.format || "TXT").toUpperCase()
                            color: _inkDim; font.pixelSize: 9; font.weight: Font.DemiBold
                        }
                    }
                }

                // Separator
                Rectangle { Layout.fillWidth: true; height: 1; color: "#20a09888" }

                // Reading curve header
                Text {
                    text: lang === "zh" ? "近30天阅读曲线" : "Reading Curve (30 days)"
                    color: _inkLight; font.pixelSize: 13; font.weight: Font.DemiBold
                }

                // Bar chart
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        id: barChart
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        spacing: 1

                        Repeater {
                            model: bookDetailDialog.detailData.daily_data || []

                            Item {
                                width: (barChart.width - 29) / 30
                                height: barChart.height

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.max(parent.width - 2, 2)
                                    height: {
                                        var maxVal = 1
                                        var dd = bookDetailDialog.detailData.daily_data
                                        if (dd) for (var i = 0; i < dd.length; i++) maxVal = Math.max(maxVal, dd[i].minutes)
                                        return Math.max(2, (modelData.minutes / maxVal) * (parent.height - 4))
                                    }
                                    radius: 2
                                    color: modelData.minutes > 0 ? "#60555050" : "#15a09888"

                                    ToolTip {
                                        visible: barMa.containsMouse && modelData.minutes > 0
                                        text: modelData.date + "\n" + Math.round(modelData.minutes) + (lang === "zh" ? " 分钟" : " min")
                                        delay: 200; font.pixelSize: 10
                                        background: Rectangle { color: "#eeecea"; border.color: "#c8c5c0"; radius: 6 }
                                    }
                                    MouseArea { id: barMa; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }
                    }

                    // Date labels
                    RowLayout {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottom: parent.bottom; height: 14
                        Text {
                            text: {
                                var dd = bookDetailDialog.detailData.daily_data
                                return dd && dd.length > 0 ? dd[0].date.substring(5) : ""
                            }
                            color: _inkDim; font.pixelSize: 8
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: {
                                var dd = bookDetailDialog.detailData.daily_data
                                return dd && dd.length > 0 ? dd[dd.length - 1].date.substring(5) : ""
                            }
                            color: _inkDim; font.pixelSize: 8
                        }
                    }
                }

                // Date range
                Text {
                    text: {
                        var d = bookDetailDialog.detailData
                        if (!d || !d.first_read) return ""
                        return (lang === "zh" ? "首次阅读: " : "First read: ") + (d.first_read || "") +
                               "  ·  " + (lang === "zh" ? "最近阅读: " : "Last read: ") + (d.last_read || "")
                    }
                    color: _inkDim; font.pixelSize: 10; opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Close button
            Text {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
                text: "✕"; color: _inkDim; font.pixelSize: 16
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: bookDetailDialog.visible = false }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // ── Weekly Report Dialog ──
    // ══════════════════════════════════════════════════════════════
    Rectangle {
        id: weeklyReportDialog
        visible: false; z: 300
        anchors.fill: parent
        color: "#88282828"

        property var reportData: ({})

        MouseArea { anchors.fill: parent; onClicked: weeklyReportDialog.visible = false }

        GlassPanel {
            id: reportCard
            anchors.centerIn: parent
            width: 480; height: 520
            color: "#f0eeecea"

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 30
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: lang === "zh" ? "\uD83D\uDCDC 阅读周报" : "\uD83D\uDCDC Weekly Report"
                        color: _ink; font.pixelSize: 22; font.weight: Font.Bold
                        font.family: root.appFont
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (weeklyReportDialog.reportData.week_start || "") + " ~ " + (weeklyReportDialog.reportData.week_end || "")
                        color: _inkDim; font.pixelSize: 11
                    }
                }

                // Total time + active days
                RowLayout {
                    spacing: 20; Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: {
                                var m = weeklyReportDialog.reportData.total_minutes || 0
                                if (m >= 60) return (Math.round(m / 6) / 10).toString()
                                return Math.round(m).toString()
                            }
                            color: _ink; font.pixelSize: 36; font.weight: root.appFontBoldW; font.family: root.appFont
                        }
                        Text {
                            text: {
                                var m = weeklyReportDialog.reportData.total_minutes || 0
                                if (m >= 60) return lang === "zh" ? "小时 · 本周阅读" : "hours this week"
                                return lang === "zh" ? "分钟 · 本周阅读" : "minutes this week"
                            }
                            color: _inkDim; font.pixelSize: 12
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: (weeklyReportDialog.reportData.reading_days || 0) + " / 7"
                            color: _ink; font.pixelSize: 20; font.weight: Font.DemiBold
                        }
                        Text {
                            text: lang === "zh" ? "活跃天数" : "Active Days"
                            color: _inkDim; font.pixelSize: 11
                        }
                    }
                }

                // Separator
                Rectangle { Layout.fillWidth: true; height: 1; color: "#20a09888" }

                // Daily breakdown bar chart
                Text {
                    text: lang === "zh" ? "每日阅读" : "Daily Breakdown"
                    color: _inkLight; font.pixelSize: 13; font.weight: Font.DemiBold
                }

                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 80

                    Row {
                        id: weekBars
                        anchors.fill: parent
                        anchors.bottomMargin: 18
                        spacing: 8

                        Repeater {
                            model: weeklyReportDialog.reportData.daily || []

                            Item {
                                width: (weekBars.width - 48) / 7
                                height: weekBars.height

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width * 0.6
                                    height: {
                                        var maxVal = 1
                                        var wd = weeklyReportDialog.reportData.daily
                                        if (wd) for (var i = 0; i < wd.length; i++) maxVal = Math.max(maxVal, wd[i].minutes)
                                        return Math.max(3, (modelData.minutes / maxVal) * (parent.height - 4))
                                    }
                                    radius: 3
                                    color: modelData.minutes > 0 ? "#55555050" : "#15a09888"
                                }

                                Text {
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: -16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (lang === "zh"
                                        ? ["周一","周二","周三","周四","周五","周六","周日"]
                                        : ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"])[modelData.weekday || 0]
                                    color: _inkDim; font.pixelSize: 9
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle { Layout.fillWidth: true; height: 1; color: "#20a09888" }

                // Top books
                Text {
                    text: lang === "zh" ? "本周最爱" : "Top Books"
                    color: _inkLight; font.pixelSize: 13; font.weight: Font.DemiBold
                }

                Flickable {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    contentHeight: topBooksCol.implicitHeight; clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: topBooksCol
                        width: parent.width; spacing: 8

                        Repeater {
                            model: weeklyReportDialog.reportData.top_books || []

                            RowLayout {
                                width: topBooksCol.width; spacing: 10

                                // Rank
                                Rectangle {
                                    width: 22; height: 22; radius: 11
                                    color: index === 0 ? "#30a09888" : "#15a09888"
                                    Text {
                                        anchors.centerIn: parent
                                        text: (index + 1).toString()
                                        color: _inkLight; font.pixelSize: 11; font.weight: Font.DemiBold
                                    }
                                }

                                Text {
                                    text: modelData.title || ""
                                    color: _ink; font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: {
                                        var m = modelData.minutes || 0
                                        if (m >= 60) return (Math.round(m / 6) / 10) + "h"
                                        return Math.round(m) + "m"
                                    }
                                    color: _inkDim; font.pixelSize: 12
                                }

                                // Progress bar
                                Rectangle {
                                    Layout.preferredWidth: 60; height: 4; radius: 2
                                    color: "#15a09888"
                                    Rectangle {
                                        width: {
                                            var maxMins = 1
                                            var tb = weeklyReportDialog.reportData.top_books
                                            if (tb && tb.length > 0) maxMins = tb[0].minutes || 1
                                            return parent.width * Math.min(1, (modelData.minutes || 0) / maxMins)
                                        }
                                        height: parent.height; radius: 2
                                        color: "#60555050"
                                    }
                                }
                            }
                        }
                    }
                }

                // Comparison with prev week
                Text {
                    text: {
                        var cur = weeklyReportDialog.reportData.total_minutes || 0
                        var prev = weeklyReportDialog.reportData.prev_week_minutes || 0
                        var diff = cur - prev
                        if (diff === 0) return lang === "zh" ? "与上周持平" : "Same as last week"
                        var sign = diff > 0 ? "↑" : "↓"
                        var val = Math.abs(diff) >= 60
                            ? (Math.round(Math.abs(diff) / 6) / 10) + (lang === "zh" ? " 小时" : "h")
                            : Math.round(Math.abs(diff)) + (lang === "zh" ? " 分钟" : "m")
                        return (lang === "zh" ? "较上周 " : "vs last week ") + sign + " " + val
                    }
                    color: _inkDim; font.pixelSize: 11; opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Close button
            Text {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
                text: "✕"; color: _inkDim; font.pixelSize: 16
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: weeklyReportDialog.visible = false }
            }
        }
    }
}
