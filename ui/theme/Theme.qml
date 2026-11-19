pragma Singleton
import QtQuick

/*  Theme – 墨界设计令牌（唯一事实来源）
    冷调徽墨松烟 × 竹青：浅色为冷白麻纸，深色为松烟玄黑，竹青是全应用唯一强调色。
    界面文字用系统无衬线；书法字体只留给侧栏字标，阅读正文字体由阅读设置决定。
*/
QtObject {
    id: theme

    // "system" | "light" | "dark"，由设置页写入并持久化
    property string preference: "system"
    readonly property bool dark: preference === "dark"
        || (preference === "system" && Qt.styleHints.colorScheme === Qt.ColorScheme.Dark)

    readonly property QtObject light: QtObject {
        readonly property color bg: "#F4F5F3"
        readonly property color sidebar: "#ECEEEB"
        readonly property color surface: "#FBFBFA"
        readonly property color surfaceHover: "#EEF0ED"
        readonly property color sunken: "#E7EAE6"
        readonly property color border: "#DCE0DB"
        readonly property color borderStrong: "#C3C9C2"
        readonly property color text: "#1B201F"
        readonly property color textSecondary: "#4E5855"
        readonly property color textTertiary: "#66706C"
        readonly property color accent: "#2E6B62"
        readonly property color accentHover: "#25594F"
        readonly property color accentSoft: "#DCE9E5"
        readonly property color accentText: "#2B655C"
        readonly property color textOnAccent: "#FFFFFF"
        readonly property color danger: "#B3473C"
        readonly property color dangerSoft: "#F5E2DF"
        readonly property color scrim: "#59101414"
        readonly property color shadow: "#1A101414"
        readonly property color inverse: "#1B201F"
        readonly property color textOnInverse: "#F4F5F3"
    }

    readonly property QtObject night: QtObject {
        readonly property color bg: "#121414"
        readonly property color sidebar: "#0E1010"
        readonly property color surface: "#191C1C"
        readonly property color surfaceHover: "#202424"
        readonly property color sunken: "#0C0E0E"
        readonly property color border: "#262B2A"
        readonly property color borderStrong: "#363D3B"
        readonly property color text: "#E4E8E6"
        readonly property color textSecondary: "#A7AFAC"
        readonly property color textTertiary: "#86908C"
        readonly property color accent: "#5E9F92"
        readonly property color accentHover: "#71B1A4"
        readonly property color accentSoft: "#1B2F2B"
        readonly property color accentText: "#80BDB0"
        readonly property color textOnAccent: "#0D1312"
        readonly property color danger: "#E08377"
        readonly property color dangerSoft: "#3A2321"
        readonly property color scrim: "#99000000"
        readonly property color shadow: "#66000000"
        readonly property color inverse: "#E4E8E6"
        readonly property color textOnInverse: "#121414"
    }

    readonly property QtObject p: dark ? night : light

    // ── Colour aliases for the current scheme ──
    readonly property color bg: p.bg
    readonly property color sidebar: p.sidebar
    readonly property color surface: p.surface
    readonly property color surfaceHover: p.surfaceHover
    readonly property color sunken: p.sunken
    readonly property color border: p.border
    readonly property color borderStrong: p.borderStrong
    readonly property color text: p.text
    readonly property color textSecondary: p.textSecondary
    readonly property color textTertiary: p.textTertiary
    readonly property color accent: p.accent
    readonly property color accentHover: p.accentHover
    readonly property color accentSoft: p.accentSoft
    readonly property color accentText: p.accentText
    readonly property color textOnAccent: p.textOnAccent
    readonly property color danger: p.danger
    readonly property color dangerSoft: p.dangerSoft
    readonly property color scrim: p.scrim
    readonly property color shadow: p.shadow
    readonly property color inverse: p.inverse
    readonly property color textOnInverse: p.textOnInverse

    // ── Type ──
    readonly property string uiFont: Qt.platform.os === "windows" ? "Microsoft YaHei UI"
        : Qt.platform.os === "osx" ? "PingFang SC" : "Noto Sans CJK SC"
    readonly property string brandFont: "HYXingKaiJ"   // 汉仪行楷简
    readonly property var tabular: ({ "tnum": 1 })
    // Body faces offered for reading; the first three ship in assets/fonts
    readonly property var readingFonts: [
        { label: "霞鹜文楷", en: "LXGW WenKai", family: "LXGW WenKai" },
        { label: "朱雀仿宋", en: "Zhuque Fangsong", family: "Zhuque Fangsong (technical preview)" },
        { label: "小赖", en: "Xiaolai", family: "Xiaolai" },
        { label: "宋体", en: "Song", family: Qt.platform.os === "windows" ? "SimSun" : "Songti SC" },
        { label: "楷体", en: "Kai", family: Qt.platform.os === "windows" ? "KaiTi" : "Kaiti SC" },
        { label: "黑体", en: "Sans", family: uiFont }
    ]

    readonly property int fontCaption: 12
    readonly property int fontSmall: 13
    readonly property int fontBody: 14
    readonly property int fontTitle: 15
    readonly property int fontH3: 17
    readonly property int fontH2: 20
    readonly property int fontH1: 24
    readonly property int fontDisplay: 30

    // ── Shape & rhythm (4 px grid) ──
    readonly property int radiusS: 6
    readonly property int radiusM: 8
    readonly property int radiusL: 12
    readonly property int controlHeight: 36
    readonly property int hitTarget: 44
    readonly property int pagePadding: 40

    // ── Motion: felt, not watched ──
    readonly property int fast: 120
    readonly property int base: 180
}
