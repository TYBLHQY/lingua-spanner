# Lingua Spanner

> KDE Plasma 6 桌面翻译部件 — 支持 DeepSeek AI 翻译与有道词典查词

一站式翻译工具：选中文本，按快捷键即可翻译。支持 AI 大模型（DeepSeek）翻译与有道词典释义两种引擎。

## 功能

- **双引擎翻译**: DeepSeek API（AI 翻译）与有道词典（传统词典释义 + 例句 + 发音）
- **免费英语词典**: 内置 [Free Dictionary API](https://dictionaryapi.dev/) 支持（无需 API Key）
- **一键取词**: Plasma 全局快捷键 — 自动读取选中文本、粘贴并翻译
- **智能激活**: 快捷键自动检测选区内容；点击图标仅聚焦输入框，不干扰已有内容
- **语言自动检测**: 自动识别源语言并翻译为目标语言
- **轻量纯 QML**: 配合少量 C++ 辅助模块，HTTP 请求通过 `XMLHttpRequest` 完成
- **可配置**: API Key、系统提示词、模型参数（temperature/top-p/maxTokens）均可自定义

## 安装

```sh
# 构建并安装
make build        # 编译 C++ 辅助模块并打包到 package
kpackagetool6 -t Plasma/Applet -i package/

# 或一键部署
make install      # build + install + restart plasma shell
```

## 开发

```sh
# 快速迭代（QML 改动）
make qml          # = kpackagetool6 -u + restart

# C++ 改动
make build        # = cmake --build + stage .so 到 package

# 完整部署
make full         # = build + install + restart

# 测试预览
plasmawindowed org.kde.lingua-spanner

# 调试日志
journalctl -f -o cat | grep -E "ProcessHelper|qml:"
```

## 配置

- 系统设置 → 桌面部件 → Lingua Spanner
- 关键配置项：翻译引擎选择、DeepSeek API Key、系统提示词、temperature/top-p/maxTokens

## 依赖

| 依赖 | 用途 |
|------|------|
| Qt6 (Quick) | QML 运行时 |
| KF6 (Plasma, I18n, Config) | Plasma 部件框架 |
| xclip | 读取选中文本（PRIMARY selection） |
| curl | DeepSeek API 调用（可选，QML 用 XMLHttpRequest 兜底） |

## 许可

GNU General Public License v2.0 or later
