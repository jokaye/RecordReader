# RecordReader

RecordReader 是一个轻量 SwiftUI iPhone 录音播放器。它扫描用户选择的录音文件夹，播放本地音频，保存收藏和分类，并使用 iOS 原生中文语音识别为选中的录音生成字幕片段。

## v1 范围

- 仅支持 iPhone / iOS。
- 中文界面。
- 仅做中文语音转字幕，固定使用 `zh_CN`。
- 选择录音文件夹。
- 扫描 iOS/AVFoundation 常见录音音频文件：`3g2`, `3gp`, `3gp2`, `3gpp`, `aac`, `aif`, `aiff`, `aifc`, `amr`, `caf`, `flac`, `m4a`, `mp3`, `wav`。
- 无封面图的深色播放器界面。
- 收藏录音。
- 设置分类，并按全部/收藏/分类筛选。
- 使用 iOS Speech 生成中文字幕。
- 用本地 JSON 持久化元数据。
- 通过 GitHub Actions + XcodeGen 云编译。

明确不做：SmartSub 集成、Whisper/Core ML 模型管理、翻译、批处理、SRT/VTT 导出、桌面端、iPad 专门布局、同步。

## 云编译

当前本机没有完整 Xcode，因此仓库配置了 GitHub Actions 云编译。

1. Push the repository to GitHub.
2. Open the `iOS` workflow.
3. Run `workflow_dispatch`, or push to `main`.

The workflow runs:

```bash
swift test
xcodegen generate
xcodebuild -project RecordReader.xcodeproj -scheme RecordReader -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 本地开发

在安装完整 Xcode 的 Mac 上：

```bash
brew install xcodegen
swift test
xcodegen generate
xcodebuild -project RecordReader.xcodeproj -scheme RecordReader -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 继续开发

从 `docs/superpowers/milestones.md` 开始。它记录已完成 milestone、本地环境阻塞和下一步云端验证 checkpoint。
