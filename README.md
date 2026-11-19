# InkVerse

<p align="center">
  <img src="assets/icons/app.ico" alt="InkVerse" width="112" height="112" />
</p>

<p align="center">冷调徽墨与竹青配色的轻量电子书阅读器</p>

<p align="center">
  <a href="https://github.com/b1mango/InkVerse/releases/tag/%E5%A2%A8%E7%95%8CInkVerse-v0.1.0-alpha"><img src="https://img.shields.io/badge/release-v0.1.0--alpha-2ea043" alt="release v0.1.0-alpha" /></a>
  <img src="https://img.shields.io/badge/platform-Windows-1f6feb" alt="Windows" />
  <a href="#license"><img src="https://img.shields.io/badge/license-MIT%20declared-f5c542" alt="MIT declared; license file missing" /></a>
</p>

## 功能

- 一个书库读 EPUB、MOBI、PDF、TXT：侧栏按格式分组并计数，「图书」打不开的 TXT 与 MOBI 也能直接读
- 继续阅读：最近在读的书放大为主角，带进度与一键继续；也在读、最近添加两排书架，阅读时长与半年热力图
- 书库：全部 / 想读 / 已读完 / 格式 / 收藏集，封面网格与列表两种视图，按最近阅读、书名、作者、添加时间排序，⌘F 搜索
- 收藏集：把封面拖到侧栏的收藏集即可归类，右键重命名或删除
- 打开书时封面从书架放大到页面；阅读时顶栏和进度条自动隐去，靠近边缘或按键即回
- 阅读页左侧栏：目录、书签（⌘D）、划线笔记；右侧外观：背景、正文字体、字号（⌘+ / ⌘−）、边距、段距、翻页或滚动、单双页
- 翻页与滚动两种模式都能划线、评论，笔记点击跳回原文
- 主题、阅读参数、每本书的阅读位置与进度自动保存；跟随系统「减弱动态效果」
- 窗口内任意位置拖入文件即可导入；删除前二次确认

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

## 打包

```bash
python -m pip install pyinstaller
pyinstaller InkVerse.spec --noconfirm
```

- macOS（arm64）：生成 `dist/InkVerse.app`，未签名，首次需右键「打开」。
- Windows：生成 `dist/InkVerse/`，再用 Inno Setup 编译 `InkVerse_installer.iss` 得到安装包；GitHub Actions 的 `Windows build` 工作流（手动触发或推送 `v*` 标签）会完成测试、打包、冒烟测试和安装包编译，安装包作为构建产物下载。
- 打包后可用 `InkVerse --smoke-test <目录>` 在临时书库上自检：依次截取首页、书库和第一本书，`smoke-test.json` 记录 QML 警告，无警告时退出码为 0。

## License

原 README 声明项目使用 MIT License，但仓库当前未附 `LICENSE` 文件。该声明保留供项目方确认；补充许可证文本后再将徽章更新为正式许可证链接。
