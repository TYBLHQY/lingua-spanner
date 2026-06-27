# Lingua Spanner — 需求文档

| 版本 | 日期 | 作者 | 说明 |
|------|------|------|------|
| 1.0 | 2026-06-27 | Claude | 初稿 |

---

## 目录

1. [项目概述](#1-项目概述)
2. [参考项目](#2-参考项目)
3. [核心功能](#3-核心功能)
4. [有道爬虫翻译](#4-有道爬虫翻译)
5. [DeepSeek API 翻译](#5-deepseek-api-翻译)
6. [快捷键方案](#6-快捷键方案)
7. [配置项](#7-配置项)
8. [目录结构](#8-目录结构)
9. [技术方案](#9-技术方案)
10. [开发路线图](#10-开发路线图)

---

## 1. 项目概述

### 1.1 产品定位

**Lingua Spanner** — 基于 KDE Plasma 6 的桌面翻译部件（Plasmoid），融合两种翻译引擎：

| 引擎 | 类型 | 特点 |
|------|------|------|
| **有道词典爬虫** | Web Scraping | 零 API 成本，词典释义精准（含音标、词形、考试标签） |
| **DeepSeek API** | AI 大模型 | 上下文感知翻译，自然流畅，支持长文本 |

### 1.2 目标用户

- **Linux 桌面用户**（KDE Plasma 6），日常需要快速查词/翻译
- **开发者/学生**，频繁在终端、代码编辑器、PDF 阅读器中遇到生词
- **效率追求者**，不愿在浏览器和翻译应用间来回切换

### 1.3 关键场景

| 场景 | 操作 | 期望结果 |
|------|------|----------|
| 阅读英文文档遇生词 | 选中单词 → Meta+2 | 自动取词 → 打开翻译面板 → 显示释义 |
| 翻译整段文字 | Meta+1 → 粘贴 → 回车 | DeepSeek AI 翻译结果 |
| 快速查词 | Meta+1 → 输入 → 回车 | 有道词典释义 + 发音 |

---

## 2. 参考项目

### 2.1 api-pulse（配置结构参考）

`api-pulse` 是同一工作空间下的 Plasma 6 纯 QML Plasmoid，其目录结构和配置管理模式作为本项目的参考：

- **目录布局**：`package/` 为 KPackage 根，内含 `metadata.json`、`contents/ui/`、`contents/config/`
- **配置管道**：`main.xml` (KConfig XT schema) → `config.qml` (外壳) → `ConfigGeneral.qml` (实际配置页)
- **HTTP 调用**：QML 中使用 `XMLHttpRequest` 原生发起 API 请求
- **部署命令**：`kpackagetool6 -t Plasma/Applet -i package/`

### 2.2 有道爬虫规则（有道翻译参考）

详见 `youdao-web-new-scraping-rules.md`，本文档规范了有道新版页面的 HTML 结构、CSS 选择器和提取逻辑。

---

## 3. 核心功能

### 3.1 功能总览

| 编号 | 功能 | 描述 | 优先级 | 状态 |
|------|------|------|--------|------|
| F-1 | 双引擎翻译 | 集成有道爬虫 + DeepSeek API 翻译 | P0 | ✅ 已实现 |
| F-2 | 快捷键打开面板 | Meta+1 → 展开面板，自动聚焦输入框 | P0 | ✅ 骨架 |
| F-3 | 拾取选中文本 | Meta+2 → 获取焦点窗口选中文本 → 面板展开 → 粘贴 → 全选 | P0 | ✅ 骨架 |
| F-4 | 有道释义展示 | 显示词性（po）、释义（tr）、音标、词形变化 | P1 | ⏳ 待完善 |
| F-5 | DeepSeek 译文展示 | 显示 AI 翻译结果、使用模型、token 用量 | P0 | ✅ 已实现 |
| F-6 | 发音播放 | 有道结果中播放单词发音（英式/美式） | P1 | 🔜 待实现 |
| F-7 | 翻译历史 | 记录最近翻译的词句（本地存储） | P2 | ❌ 待规划 |
| F-8 | 自动语言检测 | 输入英 → 译中，输入中 → 译英 | P1 | ✅ 已实现 |

### 3.2 双引擎模式

用户可配置三种翻译模式：

| 模式 | 行为 | 适用场景 |
|------|------|----------|
| `youdao` | 仅使用有道爬虫查词 | 日常单词速查，无需 API Key |
| `deepseek` | 仅使用 DeepSeek AI 翻译 | 长文本翻译，需要 API Key |
| `both` | 同时显示有道释义 + DeepSeek 翻译 | 最全面，既有词典释义又有 AI 译文 |

---

## 4. 有道爬虫翻译

### 4.1 概述

有道爬虫翻译服务（`YoudaoWebNewService.qml`）通过抓取 `dict.youdao.com` 页面并解析 HTML 来获取单词的词典释义，零 API 成本。

### 4.2 请求规则

```
URL:    GET https://dict.youdao.com/result?word=<word>&lang=en
参数:   word 放入待查词（不 encodeURIComponent），始终附加 &lang=en
超时:   10 秒
```

### 4.3 语音 URL

```
英式（type=1）：https://dict.youdao.com/dictvoice?audio=<word>&type=1
美式（type=2）：https://dict.youdao.com/dictvoice?audio=<word>&type=2
```

### 4.4 解析规则

| 数据 | 选择器 / 规则 | 说明 |
|------|--------------|------|
| 英文释义 | `.simple .word-exp` → `.pos`（词性）+ `.trans`（释义） | 英文查词 |
| 中文释义 | `.simple .word-exp-ce` → `.point`（对应词）+ `.word-exp_tran`（释义） | 中文查词 |
| 翻译兜底 | `.fanyi .trans-content` | 无词典条目时的机器翻译 |
| 音标音频 | `.per-phone` → `.phonetic` 文本 + 构建语音 URL | 遍历 per-phone 块 |
| 考试类型 | `.exam_type .exam_type-value` | CET4/6、考研等标签 |
| 词形变化 | `.word-wfs-less .word-wfs-cell-less` → `.wfs-name` + `.transformation` | 复数/时态等 |

### 4.5 QML 实现说明

有道爬虫在 QML 中使用 **正则表达式** 解析 HTML，原因：

- QML 的 `XMLHttpRequest` 只能获取响应文本
- QML 没有内置的 DOM/CSS 选择器解析能力
- 正则方式在查词场景下足够可靠（页面结构变化不频繁）

> **未来升级**：在有道解析复杂度增加时，可升级为 C++ 模块调用 Lexbor 库解析，参见 `youdao-web-new-scraping-rules.md` 第 10 节。

### 4.6 响应结构

```json
{
  "word": "hello",
  "exp": [
    { "po": "int.", "tr": ["喂，你好（用于问候或打招呼）", "喂，你好（打电话时的招呼语）"] }
  ],
  "examType": ["初中", "高中", "CET4"],
  "audio": [
    { "text": "英 / həˈləʊ /", "url": "https://dict.youdao.com/dictvoice?audio=hello&type=1" },
    { "text": "美 / həˈloʊ /", "url": "https://dict.youdao.com/dictvoice?audio=hello&type=2" }
  ],
  "form": [
    { "form": "hellos", "type": "复数" },
    { "form": "helloes", "type": "第三人称单数" }
  ]
}
```

---

## 5. DeepSeek API 翻译

### 5.1 概述

DeepSeek API 翻译服务（`DeepSeekService.qml`）调用 DeepSeek 大模型进行 AI 翻译，提供高质量的上下文感知翻译。

### 5.2 请求规则

```
URL:     POST https://api.deepseek.com/chat/completions
Headers: Authorization: Bearer <apiKey>
         Content-Type: application/json
超时:    30 秒
```

### 5.3 请求体

```json
{
  "model": "deepseek-chat",
  "messages": [
    {
      "role": "system",
      "content": "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."
    },
    {
      "role": "user",
      "content": "<待翻译文本>"
    }
  ],
  "temperature": 0.3,
  "max_tokens": 4096,
  "stream": false
}
```

### 5.4 响应处理

| HTTP 状态码 | 含义 | 用户提示 |
|-------------|------|----------|
| 200 | 成功 | 显示翻译结果 |
| 401 | API Key 无效 | 提示"请检查 API Key 配置" |
| 429 | 请求频率超限 | 提示"请求太频繁，请稍后再试" |
| 5xx | 服务端错误 | 提示"DeepSeek 服务暂时不可用" |

### 5.5 响应结构

```json
{
  "translation": "你好，世界！",
  "model": "deepseek-chat",
  "usage": {
    "prompt_tokens": 45,
    "completion_tokens": 15,
    "total_tokens": 60
  }
}
```

---

## 6. 快捷键方案

### 6.1 快捷键定义

| 快捷键 | 默认绑定 | 功能 | 状态 |
|--------|----------|------|------|
| **快捷键 1** | `Meta+1` | 打开翻译面板，自动聚焦输入框 | ✅ |
| **快捷键 2** | `Meta+2` | 获取当前焦点窗口的选中文本 → 打开面板 → 粘贴到输入框 → 全选文本 | ✅ |

> **说明**：Meta 键在大多数 Linux 桌面环境下对应 `Super`（Windows 徽标键）。

### 6.2 快捷键 1（打开面板）

```
用户按下 Meta+1
    ↓
KGlobalAccel 触发 Plasmoid.activated()
    ↓
PlasmoidItem.fullRepresentation 展开
    ↓
QML Component.onCompleted / onExpandedChanged
    → inputField.forceActiveFocus()
```

### 6.3 快捷键 2（取词翻译）

```
用户选中文字后按 Meta+2
    ↓
KGlobalAccel 触发自定义 Action
    ↓
PasteSelectionHelper.readSelection()
    ├─ 尝试读取 PRIMARY selection（xclip -o -selection primary）
    └─ 兜底：读取 CLIPBOARD（xclip -o -selection clipboard）
         或 xdotool 模拟 Ctrl+C → 读剪贴板
    ↓
pendingPickText = 获取的文本
Plasmoid.activated()
    ↓
onExpandedChanged → 检测到 pendingPickText
    → inputField.text = pendingPickText
    → inputField.selectAll()
    → 自动触发 translate(inputField.text)
```

---

## 7. 配置项

### 7.1 KConfig XT Schema

所有配置项定义在 `package/contents/config/main.xml` 中：

| 配置键 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `translateMode` | String | `"youdao"` | 翻译模式: `youdao` / `deepseek` / `both` |
| `deepseekApiKey` | String | `""` | DeepSeek API Key（明文存储） |
| `deepseekModel` | String | `"deepseek-chat"` | DeepSeek 模型名 |
| `autoDetectLang` | Bool | `true` | 自动检测语言方向 |

### 7.2 配置界面

配置页面 `ConfigGeneral.qml` 包含：

- **翻译模式选择**：下拉选择 youdao / deepseek / both
- **DeepSeek 设置**：API Key 输入框（密码模式）、模型名输入
- **其他设置**：自动检测语言复选框

### 7.3 安全说明

- API Key 以明文存储在 KDE 配置文件中（`~/.config/lingspannerrc`）
- 同 Plasma 其他部件的 API Key 处理方式一致
- 配置页面显示安全提示

---

## 8. 目录结构

```
lingua-spanner/
├── .gitignore
├── CLAUDE.md                     # 项目约定文档
├── CMakeLists.txt                # C++ 构建（AT-SPI / lexbor / OCR）
├── README.md                     # 项目说明
├── docs/
│   ├── feasibility-report.md     # 原始可行性报告（归档）
│   └── requirements.md           # 本需求文档
├── package/                      # KPackage 打包目录
│   ├── metadata.json             # Plasma 部件元数据
│   ├── contents/
│   │   ├── config/
│   │   │   ├── main.xml          # KConfig XT 配置 schema
│   │   │   └── config.qml        # 配置外壳
│   │   └── ui/
│   │       ├── main.qml          # 主 applet（UI + 快捷键 + 编排）
│   │       ├── ConfigGeneral.qml # 配置页面
│   │       ├── PasteSelectionHelper.qml  # 取词辅助
│   │       └── services/
│   │           ├── YoudaoWebNewService.qml  # 有道爬虫翻译
│   │           └── DeepSeekService.qml       # DeepSeek API 翻译
│   └── translate/
├── src/                          # C++ 源码（预留）
│   ├── mainapplet.h/.cpp
│   ├── atspitextreader.h/.cpp
│   ├── htmlparser.h/.cpp
│   └── ocrrunner.h/.cpp
└── youdao-web-new-scraping-rules.md
```

### 8.1 与 api-pulse 的对比

| 维度 | api-pulse | lingua-spanner |
|------|-----------|---------------|
| 技术栈 | 纯 QML | 纯 QML（主要）+ C++（预留）|
| 打包目录 | `package/` | `package/` |
| 配置 schema | `contents/config/main.xml` | `contents/config/main.xml` |
| 配置页 | `contents/ui/ConfigGeneral.qml` | `contents/ui/ConfigGeneral.qml` |
| 服务调用 | 直接写在 `main.qml` 中 | 拆分为独立的 `services/*.qml` 文件 |
| C++ 模块 | 不需要 | 保留（AT-SPI 取词/OCR 等） |

---

## 9. 技术方案

### 9.1 系统架构

```
┌───────────────────────────────────────────────────────────┐
│  Plasma 6 Plasmoid (QML UI)                               │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  PlasmoidItem (main.qml)                            │  │
│  │  ┌──────────────┐  ┌────────────┐  ┌─────────────┐ │  │
│  │  │ 输入区域      │  │ 结果展示    │  │ 配置页面     │ │  │
│  │  └──────┬───────┘  └─────┬──────┘  └──────┬──────┘ │  │
│  └─────────┼────────────────┼────────────────┼─────────┘  │
│            │                │                │            │
│    ┌───────▼────────────────▼────────────────▼──────────┐ │
│    │  Services Layer                                   │ │
│    │  ┌────────────────────┐  ┌────────────────────┐   │ │
│    │  │ YoudaoWebNewService │  │ DeepSeekService   │   │ │
│    │  │ (XMLHttpRequest)    │  │ (XMLHttpRequest)   │   │ │
│    │  └─────────┬──────────┘  └────────┬───────────┘   │ │
│    └────────────┼──────────────────────┼───────────────┘ │
│                 │                      │                 │
│    ┌────────────▼──────────┐  ┌────────▼───────────┐    │
│    │ dict.youdao.com       │  │ api.deepseek.com   │    │
│    │ (HTTP HTML response)  │  │ (JSON API)         │    │
│    └───────────────────────┘  └────────────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  PasteSelectionHelper (取词)                        │ │
│  │  ├─ xclip / xdotool → PRIMARY selection            │ │
│  │  └─ 兜底：剪贴板 clipboard                           │ │
│  └─────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

### 9.2 处理管线

```
快捷键 1 (Meta+1)
    ↓
面板展开 → inputField.forceActiveFocus()
    ↓
用户输入文字 → 回车
    ↓
translate(text) 派发
    ├─ youdao:  XMLHttpRequest → parseHTML → 显示 exp[]
    ├─ deepseek: XMLHttpRequest → 解析 response → 显示 translation
    └─ both:    同时发起两个请求 → 合并显示


快捷键 2 (Meta+2)
    ↓
PasteSelectionHelper.readSelection()
    ↓
pendingPickText 暂存
Plasmoid.activated()
    ↓
面板展开 → onExpandedChanged
    → 检测 pendingPickText
    → inputField.text = pendingPickText
    → inputField.selectAll()
    → 自动触发 translate()
```

### 9.3 关键技术决策

| 决策 | 方案 | 理由 |
|------|------|------|
| **HTTP 请求** | QML 原生 `XMLHttpRequest` | KDE Plasma 6 内置支持，无需额外依赖 |
| **HTML 解析** | 正则表达式 | 查词页面结构稳定，QML 无内置 DOM 解析器 |
| **API Key 存储** | KConfig XT（明文） | 与 Plasma 组件生态一致，用户自担安全风险 |
| **取词实现** | `xclip` 读 PRIMARY selection | 无需 AT-SPI C++ 模块，轻量快捷 |
| **快捷键绑定** | KGlobalAccel（通过 Plasma 框架）| Plasmoid 原生支持 |
| **面板触发** | `Plasmoid.activated()` | Plasma 6 标准弹出方式 |

### 9.4 依赖

| 依赖 | 用途 | 必需/可选 |
|------|------|-----------|
| KDE Plasma 6 | 运行环境 | 必需 |
| Qt6 (Core, Quick, QML) | 基础框架 | 必需 |
| xclip | 读取系统选中文本 | 必需 |
| xdotool（可选） | 模拟键盘操作取词 | 可选（取词增强） |

---

## 10. 开发路线图

```
Phase 1：项目骨架（当前）
├── 目录结构重组 → package/ 布局
├── KConfig XT 配置 schema
├── 基础 PlasmoidItem UI
├── YoudaoWebNewService（有道爬虫）
├── DeepSeekService（DeepSeek API）
├── ConfigGeneral（配置页面）
├── PasteSelectionHelper（取词骨架）
├── 快捷键绑定框架
├── Git 仓库初始化
└── ✅ 已完成

Phase 2：功能完善（1-2 天）
├── 完善有道释义 UI 渲染（exp/audio/form 卡片展示）
├── 完善 DeepSeek 译文 UI 渲染（markdown 格式支持）
├── 实现 xclip 取词（readSelection）
├── 实现画面渲染优化（滚动布局、错误反馈、空状态）
├── 快捷键真实绑定（KGlobalAccel）
└── 本地打包测试（kpackagetool6 -i）

Phase 3：增强（3-5 天）
├── 发音播放功能（QMediaPlayer 播放音频 URL）
├── 翻译历史记录（本地 JSON 存储）
├── 自动语言检测优化
├── 富文本解析增强（Lexbor C++ 模块）
├── 多语言支持（i18n）
└── 兼容性测试（Wayland / X11）

Phase 4：打磨（2-3 天）
├── 性能优化（缓存、懒加载）
├── 错误处理与用户引导完善
├── 配置页优化（主题跟随、键盘导航）
├── 文档完善
└── 发布
```

---

## 附录

### A. 参考链接

- [Plasma 6 Widget 开发文档](https://develop.kde.org/docs/plasma/widget/)
- [Plasma 6 Widget C++ API](https://develop.kde.org/docs/plasma/widget/c-api/)
- [Plasma 6 Widget KF6 迁移](https://develop.kde.org/docs/plasma/widget/porting_kf6/)
- [DeepSeek API 文档](https://platform.deepseek.com/api-docs)
- [有道词典](https://dict.youdao.com/)
- [Lexbor 库](https://github.com/lexbor/lexbor)

### B. 术语表

| 术语 | 说明 |
|------|------|
| Plasmoid | KDE Plasma 桌面部件 |
| KPackage | Plasma 部件的打包格式 |
| KConfig XT | KDE 的 XML 驱动配置框架 |
| KGlobalAccel | KDE 全局快捷键框架 |
| AT-SPI | 辅助技术服务接口（无障碍） |
| PRIMARY selection | X11/Wayland 的主选中缓冲（鼠标选中即存在） |
