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
- Edge-TTS 默认通过本机 Mihomo HTTP 代理 `http://127.0.0.1:7890`；端口不同可在设置中修改
- 朗读和声音列表支持 `speech.platform.bing.com` / `api.msedgeservices.com` 双向自动回退：接口拒绝、连接失败、超时或未收到音频时，切换另一个接口重试一次；分别记住上次成功的接口。每个接口最多等待 35 秒，朗读总超时 75 秒。
- 回退脚本随插件安装，使用所配置 `edge-tts` 的 Python 环境，不修改第三方依赖。接口偏好保存在 `~/.cache/linguaspanner/edge-tts/endpoints.json`（遵循 `XDG_CACHE_HOME`）；删除该文件即可重置。
- 快捷键：系统设置 → 快捷键 → Lingua Spanner（默认 Meta+1 打开面板，Meta+2 取词查词）

## 许可

GNU General Public License v2.0 or later
