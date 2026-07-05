# Lingua Spanner

> KDE Plasma 6 桌面翻译部件 — 多引擎 AI 翻译与查词

选中文本，按快捷键即可翻译。支持 **DeepSeek API**、**SiliconFlow API**、**有道词典爬虫**、**Free Dictionary API** 四种翻译后端。

## 功能

- **四引擎翻译**: DeepSeek API + SiliconFlow API（AI 翻译）+ 有道词典（释义/例句/发音）+ Free Dictionary API（英语定义）
- **流式输出**: DeepSeek / SiliconFlow 支持 SSE 流式逐字输出
- **一键取词**: Plasma 全局快捷键 — 自动读取选中文本、粘贴并翻译
- **翻译历史缓存**: AI 翻译自动缓存历史记录，相同文本+语言对直接命中
- **例句展示**: AI 翻译结果包含词汇分析、常用搭配及双语例句
- **引擎排序**: 配置页支持启用/禁用和排序各翻译引擎
- **语言对选择**: AI 模式支持手动指定源语言和目标语言，或自动检测
- **文本朗读**: 内置 Edge-TTS 语音合成，按语言自动匹配音色

## 引擎

| 引擎 | 类型 | API Key | 特点 |
|------|------|---------|------|
| **DeepSeek** | AI 大模型 | 需要 | 上下文感知翻译，支持流式，模型可选 |
| **SiliconFlow** | AI 大模型 | 需要 | OpenAI 兼容 API，支持流式，模型可选 |
| **Youdao 词典** | 网页爬虫 | 无需 | 词典释义 + 音标 + 词形 + 发音 + 考试标签 |
| **Free Dictionary API** | 免费 API | 无需 | 英语单词语义、音标、词源 |

## 安装

```sh
make install
```

> 需要先安装依赖：Qt6 (Quick, Gui) + KF6 (Plasma, I18n, Config, KCM)

## 配置

- 系统设置 → 桌面部件 → Lingua Spanner
- 快捷键：系统设置 → 快捷键 → Lingua Spanner（默认 Meta+1 打开面板，Meta+2 取词翻译）

## 许可

GNU General Public License v2.0 or later
