# Lingua Spanner

> 跨进程文本拾取 Plasma 6 桌面部件

一站式解决「屏幕上看得见但选不中、复制不了」的文本提取问题。

## 核心功能

1. **AT-SPI 文本拾取** — 通过无障碍接口获取任何支持 AT-SPI 的应用中的选中文本
2. **HTML 解析与清洗** — 利用 lexbor 引擎解析剪贴板 HTML 内容，提取纯净文本
3. **OCR 文字识别** — 对无法直接获取文本的区域（图片/视频/非标准控件）调用 Tesseract 进行识别

## 项目结构

```
lingua-spanner/
├── CMakeLists.txt            # 构建配置
├── metadata.json             # Plasma 部件元数据
├── contents/
│   ├── ui/
│   │   └── main.qml          # QML 用户界面
│   └── config/
│       └── main.xml          # 配置界面
├── src/
│   ├── mainapplet.h/.cpp     # Plasma::Applet 子类，核心中枢
│   ├── atspitextreader.h/.cpp # AT-SPI D-Bus 封装
│   ├── htmlparser.h/.cpp     # lexbor HTML 解析封装
│   └── ocrrunner.h/.cpp      # OCR 调用（QProcess/libttesseract C++ API）
├── tests/                     # 单元测试
├── docs/
│   └── feasibility-report.md  # 可行性报告
└── .gitignore
```

## 依赖

| 依赖 | 用途 | 可选性 |
|------|------|--------|
| Qt6 (Core, DBus, Quick) | 基础框架 | 必选 |
| KF6 (Plasma, I18n, Config) | Plasma 部件框架 | 必选 |
| lexbor (html, css, dom) | HTML/CSS 解析 | 可选（可用 Qt 内置引擎替代） |
| at-spi2-core | AT-SPI D-Bus 服务 | 必选 |
| tesseract-ocr + 语言包 | OCR 文字识别 | 可选 |
| leptonica | tesseract 底层图像库 | 可选（tesseract CLI 模式不需要） |
