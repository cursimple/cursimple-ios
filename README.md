# 课简 · CurSimple for iOS

课表、今日概览与学期管理，一个应用装下整个学期。

这是课简的 iOS 客户端，使用 SwiftUI 与 Swift 6 编写，不依赖第三方框架。界面默认中文，同时提供英文。

## 当前进度

已具备：

- 周视图与日视图课表，连堂课程合并、重叠课程叠放
- 课程添加、编辑、删除，单双周与自定义周次
- 学期开始日期、教学周数、节次作息设置，多学期切换
- 今日概览：进度环、当前课程、下一节课、倒计时与全天时间线
- 课程笔记：清单、优先级、截止时间、课程关联与筛选
- 上课提醒：提前时间、考试开关、滚动本地通知排程
- 节假日与调休，临时补课 / 停课 / 调课
- 课表分享码与二维码，导入为新学期（与现有客户端互通）
- 主题色、课程配色、周起始日与周末显示设置
- 简体 / 繁体中文与英文，本地 JSON 原子落盘，离线可用

后续计划：桌面小组件、课表文件导入、更多平台能力。

## 开发

要求 Xcode 27 或更新版本、iOS 18 SDK。

```sh
# 生成 Xcode 工程
brew install xcodegen
xcodegen generate

# 领域逻辑测试（不需要模拟器）
swift test --package-path CurSimpleCore

# 构建应用
xcodebuild -project CurSimple.xcodeproj -scheme CurSimple \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## 结构

```
CurSimpleCore/    平台无关的领域模型、周次计算、冲突检测与本地存储
CurSimple/        SwiftUI 界面
docs/             设计与实现说明
```

## 许可

MIT License，见 [LICENSE](LICENSE)。
