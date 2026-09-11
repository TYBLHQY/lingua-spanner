# Lingua Spanner

> KDE Plasma 6 桌面查词部件 — 有道词典 + Edge-TTS 语音朗读

选中文本，按快捷键即可查词。支持**有道词典网页爬虫**释义/音标/例句/发音，以及 **Edge-TTS** 文本语音朗读。

## 功能

- **有道词典查词**: 网页爬虫获取释义、音标、词形、考试标签、例句
- **一键取词**: Plasma 全局快捷键 — 自动读取选中文本、粘贴并查词
- **文本朗读**: 内置 Edge-TTS 语音合成，支持多语言音色
- **面板固定**: Ctrl+P 固定/取消固定面板

## 引擎

| 引擎 | 类型 | API Key | 特点 |
|------|------|---------|------|
| **Youdao 词典** | 网页爬虫 | 无需 | 词典释义 + 音标 + 词形 + 发音 + 考试标签 |

## 安装

```sh
make install
```

> 需要先安装依赖：Qt6 (Quick, Gui) + KF6 (Plasma, I18n, Config, KCM)
> TTS 功能需要：`pip install edge-tts`

## 配置

- 系统设置 → 桌面部件 → Lingua Spanner
- 快捷键：系统设置 → 快捷键 → Lingua Spanner（默认 Meta+1 打开面板，Meta+2 取词查词）

## 许可

GNU General Public License v2.0 or later
