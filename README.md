# Lingua Spanner

> KDE Plasma 6 桌面翻译部件 — 多引擎 AI 翻译与查词

选中文本，按快捷键即可翻译。支持 **DeepSeek API**、**SiliconFlow API**、**有道词典爬虫**、**Free Dictionary API** 四种翻译后端。

## 功能

- **四引擎翻译**: DeepSeek API + SiliconFlow API（AI 翻译）+ 有道词典（释义/例句/发音）+ Free Dictionary API（英语定义）
- **流式输出**: DeepSeek / SiliconFlow 支持 SSE 流式逐字输出
- **一键取词**: Plasma 全局快捷键 — 自动读取选中文本、粘贴并翻译
- **智能选区新鲜度**: 通过 `QClipboard::selectionChanged()` 检测选区新鲜度，仅采纳 3 秒内的主动选中
- **翻译历史**: AI 翻译自动缓存历史记录（内存，上限 20 条，可删除）
- **配置灵活**: API Key、模型选择、Temperature/Top-P/MaxTokens、自定义 System Prompt、字体大小均可配置
- **引擎排序**: 配置页支持启用/禁用和拖拽排序各翻译引擎

## 引擎

| 引擎 | 类型 | API Key | 特点 |
|------|------|---------|------|
| **DeepSeek** | AI 大模型 | 需要 | 上下文感知翻译，支持流式，模型可选 |
| **SiliconFlow** | AI 大模型 | 需要 | OpenAI 兼容 API，支持流式，模型可选 |
| **Youdao 词典** | 网页爬虫 | 无需 | 词典释义 + 音标 + 词形 + 发音 + 考试标签 |
| **Free Dictionary API** | 免费 API | 无需 | 英语单词语义、音标、词源（学习友好） |

## 安装

```sh
# 构建并安装
make build        # 编译 C++ 模块并打包到 package
kpackagetool6 -t Plasma/Applet -i package/

# 或一键部署
make install      # build + install + restart
```

## 开发

```sh
# 快速迭代（QML 改动）
make qml          # kpackagetool6 -u + restart

# C++ 改动
make build        # cmake --build + stage .so 到 package

# 完整部署
make full         # build + install + restart

# 测试预览（不重启面板）
make test

# 单元测试
qml6 -I package/contents/lib tests/tst_ProcessHelper.qml

# 调试日志
journalctl -f -o cat | grep -E "ProcessHelper|qml:"
```

## 配置

- 系统设置 → 桌面部件 → Lingua Spanner
- 快捷键：系统设置 → 快捷键 → Lingua Spanner（默认 Meta+1 打开面板，Meta+2 取词翻译）

## 依赖

| 依赖 | 用途 |
|------|------|
| Qt6 (Quick, Gui) | QML 运行时 + QClipboard |
| KF6 (Plasma, I18n, Config, KCM) | Plasma 部件框架 |
| xclip | 读取选中文本（PRIMARY selection） |

## 许可

GNU General Public License v2.0 or later
