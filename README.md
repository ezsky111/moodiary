<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/banner/dark_zh.svg">
  <source media="(prefers-color-scheme: light)" srcset="res/banner/light_zh.svg">
  <img alt="The preview for moodiary." src="res/banner/light_zh.svg">
</picture>
<p align="center">简体中文</p>

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41.0-blue?style=for-the-badge">
  <img src="https://img.shields.io/github/repo-size/ezsky111/moodiary?style=for-the-badge&color=ff7070">
  <img src="https://img.shields.io/github/stars/ezsky111/moodiary?style=for-the-badge&color=965f8a">
  <img src="https://img.shields.io/github/v/release/ezsky111/moodiary?style=for-the-badge&color=4f5e7f">
  <img src="https://img.shields.io/github/license/ezsky111/moodiary?style=for-the-badge&color=4ac6b7">
</div>

> 本项目基于 [ZhuJHua/moodiary](https://github.com/ZhuJHua/moodiary) 进行维护和修复。原作者项目已停止更新很长时间，本 fork 版本主要修复了使用中发现的 bug，并实现了一些新功能。
>
> 注：本仓库基于上游 fork 的 tag 版本构建。原项目的完整粒度提交历史可在上游 `develop` 分支找到，因上游打 tag 时进行了 squash 导致的部分历史粒度丢失，敬请谅解。

## ✨ 功能特性

- **跨平台支持**：🌍 兼容 Android、iOS、Windows、MacOS、Linux\*。
- **Material Design**：🎨 界面直观且用户友好，遵循 Material Design 设计规范。
- **多种编辑器**：📝 支持 Markdown 、纯文本、富文本等多种形式的文本编辑。
- **多媒体附件**：📷 可以为你的日记添加图片、音频、视频甚至画一张画。
- **搜索和分类**：🔍 轻松通过全文搜索及分类管理你的日记。
- **自定义主题**：🌈 支持浅色和深色模式，以及多种配色的主题。
- **自定义字体**：✍️ 支持导入不同的字体，并支持可变字体。
- **数据安全**：🔒 通过密码来保障你的日记安全，支持通过生物识别解锁。
- **导出和分享**：🧾 支持所有数据的导入/导出，以及单篇日记的分享。
- **备份与同步**：☁ 支持局域网同步，快速在设备间同步数据，以及 WebDav 备份。
- **足迹地图**：🗺️ 在地图上查看你足迹，生活中的每一步都值得被记录。
- **智能助手**：💬 支持接入第三方大模型（OpenAI/Anthropic），提供聊天问答、日记自动分类、AI 润色等功能
- **AI 伴侣人设**：🎭 可自定义 AI 伴侣的名字、性格和说话风格，获得个性化对话体验
- **日记记忆与分析**：🧠 AI 伴侣自动了解近期日记内容，支持对任意时间范围的日记进行 AI 分析总结，并在对话中自然引用
- **本地自然语言处理（NLP）**：🤖 更安全的智能助手，让你的日记更懂你。

（注：跨平台能力由 Flutter 提供，带 * 号的平台可能需要更多测试）

## 🛠️ 本版本修复与新增内容

### 新增功能

- **AI 伴侣人设**：用户可自定义 AI 伴侣的名字、性格、说话风格和称呼，人设会持续影响 AI 的回复方式，打造个性化陪伴体验
- **日记记忆功能**：AI 伴侣自动获取最近 14 天的日记内容，在聊天时自然提及用户生活中的点滴，让对话更有上下文感
- **日记分析总结**：支持选择任意时间范围，将范围内的日记交给 AI 进行全面分析总结（包含日记 ID 索引），分析结果会在聊天时自动传递给 AI，使其对用户有更深入的了解
- **AI 自动分类**：AI 助手新增自动识别日记内容并推荐分类标签的功能
- **分类标签展示**：在日记卡片和详情页显示分类标签，方便快速识别日记归属
- **Excel 导入功能**：新增 Excel 文件导入支持，方便数据迁移

### Bug 修复

- **修复 WebDAV 同步加密上传功能**：修复webdav加密同步功能中只加密文字，不加密照片、视频等富文本的bug，加密同步功能可以正常工作
- **修复日记数据兼容性**：修复了旧版日记数据缺少 `show` 字段导致的加载失败问题
- **修复 Rust 库打包问题**：修复了 Rust 动态库未正确打包到 APK 的问题
- **移除了日记内容封面显示大图的问题**：移除了在日记详情页面使用日记里面图片当做封面图的问题，界面更简洁美观

### 移除

- **AI 排版功能**：移除了 ai 自动排版功能（ai 在排版过程中会丢失日记原有的富文本样式，且效果不佳）

### 依赖更新

- **flutter_rust_bridge**: 2.9.0 → 2.11.1
- **Flutter SDK**: 更新至 3.41.0

## 🔧 主要技术栈

- [Flutter](https://github.com/flutter/flutter)（跨平台 UI 框架）
- [Isar](https://github.com/isar/isar)（高性能本地数据库）
- [GetX](https://github.com/jonataslaw/getx)（状态管理框架）
- [flutter_rust_bridge](https://github.com/Deskhun/flutter_rust_bridge)（Rust FFI 桥接）
- [Rust](https://www.rust-lang.org/)（加密等高性能本地处理）

## 📸 应用截图

> 应用持续更新中，新版本界面可能稍有变化

### 移动端

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/mobile_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/mobile_light_zh.webp">
  <img alt="The mobile screenshot for moodiary." src="res/screenshot/mobile_light_zh.webp">
</picture>

### 桌面端

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="res/screenshot/desktop_dark_zh.webp">
  <source media="(prefers-color-scheme: light)" srcset="res/screenshot/desktop_light_zh.webp">
  <img alt="The desktop screenshot for moodiary." src="res/screenshot/desktop_light_zh.webp">
</picture>

## 🚀 安装指南

### 直接安装

通过下载 Release 中已编译好的安装包来使用，如果没有你所需要的平台，请使用手动编译。

### 手动编译

#### 环境要求

- Flutter SDK (>= 3.41.0 Stable)
- Dart (>= 3.7.0)
- Rust 工具链（Nightly）
- Clang/LLVM
- 兼容的 IDE（如 Android Studio、Visual Studio Code）

#### 安装步骤

1. **克隆仓库**：

```bash
git clone https://github.com/ezsky111/moodiary.git
cd moodiary
```

2. **安装依赖**：

```bash
flutter pub get
```

3. **运行应用**：

```bash
flutter run
```

4. **打包发布**：

- Android: `flutter build apk --split-per-abi`
- iOS: `flutter build ipa`
- Windows: `flutter build windows`
- MacOS: `flutter build macos`

## 📝 更多说明

### 自然语言处理（NLP）

> 处于实验阶段

如今，越来越多的行业产品开始融入 AI 技术，这无疑极大地提升了我们的使用体验。然而，对于日记应用来说，将数据交给大型模型处理并不可接受，因为无法确定这些数据是否会被用于训练。因此，更好的方法是采用本地模型。虽然由于体积限制，本地模型的能力可能不如大型模型强大，但在一定程度上仍能为我们提供必要的帮助。

目前，源码中集成了以下任务：

#### 基于 Bert 预训练模型的 SQuAD 任务

采用了 MobileBert 来处理 SQuAD 任务，这是一个简单的机器阅读理解任务。你可以向它提出问题，它会返回你需要的答案。模型文件采用 TensorFlow Lite 所需的 `.tflite` 格式，所以你可以添加自己的模型文件到 `assets/tflite` 目录下。

感谢以下开源项目：

- [Chinese MobileBERT](https://github.com/ymcui/Chinese-MobileBERT)
- [Mobilebert](https://github.com/google-research/google-research/tree/master/mobilebert)
- [ChineseSquad](https://github.com/junzeng-pluto/ChineseSquad)

## 🤝 贡献指南

欢迎贡献！请按照以下步骤进行贡献：

1. Fork 本仓库。
2. 创建一个新分支（`git checkout -b feature-branch-name`）。
3. 提交你的修改（`git commit -am 'Add some feature'`）。
4. 推送到分支（`git push origin feature-branch-name`）。
5. 创建一个 Pull Request。

请确保你的代码遵循 [Flutter 风格指南](https://flutter.dev/docs/development/tools/formatting) 并包含适当的测试。

## 📄 许可证

此项目基于 AGPL-3.0 许可证进行许可，详情请参阅 [LICENSE](LICENSE) 文件。

## 💖 鸣谢

- 感谢原作者 [ZhuJHua](https://github.com/ZhuJHua/moodiary) 提供的优秀项目基础
- 感谢 Flutter 团队提供出色的框架
- 感谢开源社区的宝贵贡献
