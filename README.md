# InkVerse

<p align="center">
  <img src="assets/icons/app.ico" alt="InkVerse" width="112" height="112" />
</p>

<p align="center">毛玻璃态与水墨东方风格的轻量电子书阅读器</p>

<p align="center">
  <a href="https://github.com/b1mango/InkVerse/releases/tag/%E5%A2%A8%E7%95%8CInkVerse-v0.1.0-alpha"><img src="https://img.shields.io/badge/release-v0.1.0--alpha-2ea043" alt="release v0.1.0-alpha" /></a>
  <img src="https://img.shields.io/badge/platform-Windows-1f6feb" alt="Windows" />
  <a href="#license"><img src="https://img.shields.io/badge/license-MIT%20declared-f5c542" alt="MIT declared; license file missing" /></a>
</p>

## 功能

- 支持 TXT、EPUB、MOBI、PDF，统一阅读界面与章节导航
- 书库网格、虚拟文件夹、搜索和阅读状态筛选
- 阅读进度、章节刻度、标题预览与单本阅读详情
- 文本选择、高亮和按章节位置排序的批注
- 日、周、月、年阅读统计与近六个月热力图
- EPUB/PDF 封面提取、自动生成和在线封面与作者信息查询
- 水墨与素笺主题、中文字体和 QML 界面

## 安装

Windows 用户可从 [GitHub Releases](https://github.com/b1mango/InkVerse/releases/tag/%E5%A2%A8%E7%95%8CInkVerse-v0.1.0-alpha) 下载 `InkVerse-v0.1.0-alpha.exe`。源码运行需要 Python 3.10 或更高版本与 pip：

```bash
git clone https://github.com/b1mango/InkVerse.git
cd InkVerse
python -m venv .venv
```

Windows 激活虚拟环境：

```powershell
.venv\Scripts\activate
```

macOS/Linux 激活虚拟环境：

```bash
source .venv/bin/activate
```

## 开发

安装依赖并启动：

```bash
python -m pip install PySide6 ebooklib PyMuPDF mobi Pillow
python -m app.main
```

阅读数据存储在 `~/.inkverse/`，包括书库元数据、导入副本、阅读统计、封面缓存和批注。应用会为缺少封面的书籍访问在线书目服务；不要把本地书籍或凭据提交到仓库。

## License

原 README 声明项目使用 MIT License，但仓库当前未附 `LICENSE` 文件。该声明保留供项目方确认；补充许可证文本后再将徽章更新为正式许可证链接。
