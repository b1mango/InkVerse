# 墨界 InkVerse

> 「毛玻璃态 × 水墨东方」全格式轻量电子书阅读器

<p align="center">
  <strong>PySide6 + QML</strong> · TXT / EPUB / MOBI / PDF · 中英双语
</p>

---

## 特性一览

**水墨美学**
- 毛玻璃态 (Glassmorphism) 全局面板 + 东方水墨设计语言
- 双主题：水墨 (ink) / 素笺 (cream)，实时切换配色与背景图
- 5 款中文书法字体，字体权重自适应
- 自绘水墨矢量图标，替代 emoji

**书库管理**
- 响应式网格视图，自动提取 / 生成封面
- 虚拟文件夹：创建、重命名、删除，2×2 宫格封面预览
- 代理拖拽归档：将书籍拖入文件夹，磁吸式交互
- 搜索 + 状态筛选（全部 / 待看 / 在看 / 已看）

**多格式阅读**
- TXT · EPUB · MOBI · PDF，统一阅读界面
- 章节目录抽屉，点击跳转
- 进度条 + 章节刻度标记 + 磁吸吸附 + 标题预览

**批注系统**
- 自由文本选择 + 4 色高亮（黄 / 绿 / 蓝 / 红）
- 右键添加 / 编辑评论
- 笔记面板：按章节 + 位置排序，点击跳转

**数据看板**
- 阅读热力图（GitHub 风格，近 6 个月）
- 多维度统计：日 / 周 / 月 / 年 + 同比对比
- 单本阅读详情 + 阅读周报

---

## 技术栈

| 层面 | 技术 |
|------|------|
| 前端 | QML (Qt Quick) |
| 后端 | Python 3.14 + PySide6 |
| 电子书 | ebooklib (EPUB) · PyMuPDF (PDF) · mobi (MOBI) |
| 封面 | QThread 异步抓取 + 本地生成 |
| 存储 | 本地 JSON 文件系统 (`~/.inkverse/`) |

---

## 快速开始

### 环境要求

- Python ≥ 3.10
- pip

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/<your-username>/InkVerse.git
cd InkVerse

# 创建虚拟环境
python -m venv .venv

# 激活虚拟环境
# Windows:
.venv\Scripts\activate
# macOS/Linux:
source .venv/bin/activate

# 安装依赖
pip install PySide6 ebooklib PyMuPDF mobi

# 启动应用
python -m app.main
```

---

## 项目结构

```
InkVerse/
├── app/
│   ├── __init__.py
│   └── main.py              # QML 引擎 + LibraryBackend QObject
├── core/
│   ├── __init__.py
│   ├── library.py            # 书库 / 文件夹 / 统计 / 批注 逻辑
│   ├── cover.py              # 封面提取与生成
│   └── storage.py            # 存储路径管理
├── ui/
│   ├── main.qml              # 主窗口 + 全局状态
│   ├── components/
│   │   ├── GlassPanel.qml    # 毛玻璃面板组件
│   │   └── Sidebar.qml       # 侧边栏导航
│   └── pages/
│       ├── DashboardPage.qml # 首页仪表盘
│       ├── LibraryPage.qml   # 书库管理
│       ├── ReaderPage.qml    # 阅读器
│       └── SettingsPage.qml  # 设置
├── assets/
│   ├── fonts/                # 8 款字体 (TTF/OTF)
│   └── images/               # 背景图 + 素材
├── PRD.md                    # 产品需求文档
└── README.md
```

---

## 本地数据

所有数据存储于 `~/.inkverse/`：

```
~/.inkverse/
├── metadata.json        # 书库元数据 + 文件夹
├── reading_stats.json   # 阅读会话记录
├── imports/             # 导入的电子书副本
└── cache/
    ├── covers/          # 封面图
    ├── mobi_epub/       # MOBI 转换缓存
    ├── pdf_pages/       # PDF 页面渲染缓存
    └── annotations/     # 批注 (per-book JSON)
```

---

## 开源协议

MIT License
