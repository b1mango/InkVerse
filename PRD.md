# 墨界 InkVerse — 产品需求文档 (PRD)

> **项目名称：** 墨界 (InkVerse)  
> **版本：** v0.1.0  
> **技术栈：** PySide6 + QML (Python 3.14)  
> **运行环境：** Windows / macOS / Linux  
> **核心定位：** 「毛玻璃态 × 水墨东方」全格式轻量电子书阅读器

---

## 一、设计语言

墨界以 **Glassmorphism（毛玻璃态）** 与 **水墨东方美学** 为双轴设计基准：

- 外层 UI（侧边栏、仪表盘、书库卡片）采用半透明毛玻璃面板，柔和阴影 + 高光边缘
- 阅读界面转入宣纸水墨气韵，配合中文书法字体营造东方阅读体验
- 双主题系统：
  - **水墨 (ink)** — 冷灰淡蓝背景，默认字体「汉仪行楷简」
  - **素笺 (cream)** — 暖黄羊皮纸底色，默认字体「心海行楷」
- 自定义图标：上下文菜单、周报按钮等均使用 Rectangle 自绘水墨矢量图标，替代 emoji
- 字体权重自适应：笔画较粗的字体（如心海行楷）自动降权至 `Font.Light`/`Font.Medium`

---

## 二、界面布局与全局导航

### 2.1 侧边栏 (Sidebar)

- [x] 水墨背景 + 毛玻璃叠层，Material Symbols Outlined 图标
- [x] 顶部导航：首页 (Dashboard) · 书库 (Library)
- [x] 底部导航：设置 (Settings)
- [x] 阅读模式下自动隐藏侧边栏与背景图，聚焦正文
- [x] 字体权重属性 (`appFontBoldW` / `appFontNormW`) 向下传播至所有页面

### 2.2 页面路由

| 页面 | 文件 | 说明 |
|------|------|------|
| 首页 | `DashboardPage.qml` | 阅读统计看板 + 热力图 + 最近阅读 |
| 书库 | `LibraryPage.qml` | 书籍 / 文件夹网格 + 搜索筛选 + 拖拽 |
| 阅读 | `ReaderPage.qml` | 正文渲染 + 目录 + 批注 + 进度条 |
| 设置 | `SettingsPage.qml` | 主题 / 字体 / 语言切换 |

### 2.3 主窗口

- [x] 默认尺寸 1280 × 850，`StackLayout` 切换四页
- [x] 主题联动背景图（ink: `background.png`; cream: `bg_landscape.svg`）
- [x] 8 款字体热加载（TTF/OTF from `assets/fonts/`）

---

## 三、书库管理与导入系统

### 3.1 书籍卡片

- [x] 响应式 `GridView` 网格布局
- [x] 封面自动提取：EPUB 内嵌封面 / PDF 首页 / MOBI 转 EPUB 后提取
- [x] 无封面时生成随机色块 + 书名极简排版封面
- [x] 异步封面抓取：后台 `CoverWorker(QThread)` 从在线 API 获取真实封面与作者信息
- [x] 标题粗体 + 溢出省略，作者次要字体

### 3.2 文件夹管理

- [x] 创建 / 删除 / 重命名虚拟文件夹
- [x] 文件夹卡片 2×2 宫格封面：展示前 4 本书的封面缩略图，空位显示 📜 占位
- [x] 拖拽归档：代理拖拽（Proxy Drag）将书籍拖入文件夹 `DropArea`
  - 代理 Rectangle 跟随光标，原卡片留在原位（opacity 0.4）
  - `Drag.drop()` + 50ms `Timer` 延迟清理，确保 DropArea 可靠接收
  - 文件夹 DropArea 使用 `Qt.callLater` 延迟刷新模型
- [x] 文件夹面包屑导航：点击进入文件夹，显示文件夹内书籍列表
- [x] 文件夹右键菜单：重命名 / 删除（自绘水墨图标）
- [x] 书籍右键菜单：设置状态 / 移入文件夹 / 从文件夹移出 / 删除
- [x] 已归档书籍不在主视图顶层显示
- [x] 状态筛选模式下不显示文件夹
- [x] 网格中无"新建文件夹"卡片，仅顶部标题栏保留新建按钮

### 3.3 搜索与筛选

- [x] 顶部搜索框实时过滤书名 / 作者
- [x] 状态标签筛选：全部 / 待看 / 在看 / 已看

### 3.4 导入

- [x] 右上角"导入"按钮，调用系统文件管理器批量选择
- [x] 支持格式：**TXT · EPUB · MOBI · PDF**
- [x] 导入策略：文件统一复制到 `~/.inkverse/imports/`，避免原路径失效

---

## 四、核心阅读引擎

### 4.1 多格式阅读

| 格式 | 全文 | 章节目录 | 逐章阅读 | 特殊处理 |
|------|:----:|:--------:|:--------:|----------|
| TXT | ✅ | — | — | 段落规范化（中文缩进 + 空行合并） |
| EPUB | ✅ | ✅ TOC + spine | ✅ | HTML→纯文本（保留段落，过滤 script/style） |
| PDF | ✅ | ✅ outline / 逐页 | ✅ | PyMuPDF 渲染 PNG 页面，缓存至 `cache/pdf_pages/` |
| MOBI | ✅ | ✅ 转 EPUB 或 HTML pagebreak | ✅ | `mobi` 库转换，缓存至 `cache/mobi_epub/` |

### 4.2 阅读界面

- [x] 滚动模式：`TextEdit` (readOnly) 渲染全章文本
- [x] 左侧目录抽屉 (TOC)：章节列表，点击跳转
- [x] 右侧设置抽屉：字号调节等阅读参数
- [x] 进度条 + 章节刻度标记
  - 章节位置自动标注刻度点（`Repeater` + `_chapterMarkers`）
  - 磁吸吸附：拖拽进度条靠近刻度时自动吸附（12px 阈值）
  - 浮现章节标题预览 Tooltip

### 4.3 批注系统

- [x] 批注模式切换：工具栏按钮启用 `selectByMouse`
- [x] 自由文本选择：鼠标框选任意文本段
- [x] 多色高亮：4 种预设色（黄 / 绿 / 蓝 / 红），点选即创建高亮
- [x] Canvas 叠层渲染高亮矩形
- [x] 右键交互：
  - 右键点击已有高亮 → 上下文菜单「添加/编辑评论」「删除划线」
  - 评论输入覆盖层，支持新增或修改评论
- [x] 笔记面板：
  - 按章节索引 + 文本位置排序
  - 每条批注显示：色条 + 高亮原文 + 评论 + 章节信息 + 编辑/删除图标
  - 点击批注自动跳转到对应位置
- [x] 后端：per-book JSON 存储（`~/.inkverse/cache/annotations/{bookId}.json`）
  - 数据结构：`{ id, chapter_index, start, end, text, color, comment, created_at }`
  - API：`loadAnnotations` / `saveAnnotation` / `updateAnnotationComment` / `updateAnnotationColor` / `deleteAnnotation`

---

## 五、阅读数据看板

### 5.1 仪表盘统计

- [x] 总阅读时长 / 已读完书籍数 / 书库总数
- [x] 最近阅读 6 本（含 `last_read` 时间 + 阅读时长）

### 5.2 阅读热力图

- [x] GitHub 风格日历热力矩阵，近 182 天（≈6 月）
- [x] 绿色深浅与每日阅读时长线性正相关
- [x] 数据结构：`{ date, minutes, weekday }`

### 5.3 多维度统计

- [x] 今日 / 本周 / 本月 / 本年 累计阅读时间
- [x] 与上周 / 上月对比数据
- [x] 单本详情：累计耗时、阅读天数、日均时长、首次/末次阅读、近 30 天日数据

### 5.4 阅读周报

- [x] 一键生成周报弹窗（水墨卷轴图标按钮）
- [x] 内容：本周总时长、阅读天数、Top 5 书籍、每日明细、与上周对比
- [x] 数据来源：`reading_stats.json`，纯本地 JSON，不引入数据库

---

## 六、设置系统

- [x] **主题切换：** 水墨 (ink) / 素笺 (cream)，实时切换背景、配色、默认字体
- [x] **字体选择：** 5 款中文书法字体
  - Long Cang / 汉仪行楷简 / 心海行楷 (HYXinHaiXingKaiW) / Ma Shan Zheng / LXGW WenKai
- [x] **国际化：** 中文 (zh) / English (en) 双语 UI

---

## 七、存储与数据管理

### 7.1 本地目录结构

```
~/.inkverse/
├── metadata.json          # 书库元数据 (books[]) + 文件夹 (folders[])
├── reading_stats.json     # 阅读会话记录 [{ date, book_id, minutes }]
├── imports/               # 导入的电子书文件副本
└── cache/
    ├── covers/            # 封面图 (PNG)
    ├── mobi_epub/         # MOBI → EPUB 转换缓存
    ├── pdf_pages/         # PDF 页面渲染缓存 (PNG)
    └── annotations/       # 批注 (每书一个 JSON)
```

### 7.2 设计原则

- [x] 纯文件系统，不引入数据库
- [x] 导入文件复制到 `imports/`，与原路径解耦
- [x] 封面、PDF 页面、MOBI 转换结果均缓存为二进制文件，提升加载速度

---

## 八、未来规划 (Roadmap)

| 优先级 | 功能 | 说明 |
|--------|------|------|
| P1 | 气泡式查词翻译 | 选中文本浮现 Popup 展示释义/翻译 |
| P1 | 拖拽导入 Drop Zone | 书库支持直接拖入文件导入 |
| P2 | 智能光感模式 | 根据系统时间自动日/夜主题切换 |
| P2 | Zen Mode | 鼠标静止 3 秒后自动隐藏所有 UI |
| P2 | 数据备份与迁移 | 一键导出/导入存储目录 |
| P3 | 云同步 | 本地优先，可选接入云同步模块 |
| P3 | WebView 渲染 | 为 EPUB/TXT 提供高级排版路径 |
| P3 | TXT 智能目录 | 正则扫描「第一章」等关键词生成虚拟 TOC |
