# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lingua Spanner** — a KDE Plasma 6 plasmoid (applet) for translation. Supports 4 backends: Youdao web dictionary (scraping), DeepSeek API, SiliconFlow API (OpenAI-compatible), and Free Dictionary API. All HTTP via `XMLHttpRequest`.

- **Type:** Plasma/Applet (KPackageStructure)
- **Target:** Plasma 6.0+
- **Plugin ID:** `org.kde.lingua-spanner`
- **License:** GPL-2.0-or-later
- **Current version:** 1.4.2
- **Language:** QML (primary) + C++ (QClipboard PRIMARY listener, SQLite, config persistence)
- **Config:** KConfig XT (`main.xml`) for plugin-scoped keys, plus a separate JSON config file (`~/.config/linguaspanner/linguaspanner.json`) for UI state (mode/lang selections) via ProcessHelper C++ API

## Directory Structure

```
lingua-spanner/
├── CLAUDE.md
├── CMakeLists.txt          # C++ build (ProcessHelper QML module)
├── Makefile                # Dev workflow: build, install, test, restart
├── dev                     # Convenience script: ./dev build|full|qml|restart
├── docs/
│   ├── feasibility-report.md
│   ├── requirements.md
│   └── youdao-web-html-parsing-rules.md
├── package/
│   ├── metadata.json          # Plugin ID, version, category
│   ├── contents/
│   │   ├── config/
│   │   │   ├── main.xml       # KConfig XT schema (all 4 engines, shortcuts, fonts)
│   │   │   └── config.qml     # Shell that loads ConfigGeneral.qml
│   │   ├── lib/LinguaSpannerHelper/  # C++ QML module (.so + qmldir)
│   │   └── ui/
│   │       ├── main.qml                      # PlasmoidItem: UI, orchestration, shortcuts (38509 bytes)
│   │       ├── ConfigGeneral.qml             # Settings form (category pages: general + per-engine)
│   │       ├── AiConfigCategory.qml          # AI engine config section (DeepSeek + SiliconFlow)
│   │       ├── PasteSelectionHelper.qml      # Wraps ProcessHelper for QClipboard
│   │       ├── FontStyle.qml                 # Shared font-size descriptor (reads Plasmoid.configuration)
│   │       ├── AiResultPanel.qml             # Streaming + structured AI result display
│   │       ├── YoudaoResultPanel.qml         # Youdao dictionary result display
│   │       ├── DictionaryResultPanel.qml     # Free Dictionary API result display
│   │       └── services/
│   │           ├── OpenAiChatService.qml     # Generic OpenAI-compatible chat service (SSE streaming)
│   │           ├── DeepSeekService.qml       # Thin wrapper: api.deepseek.com/chat/completions
│   │           ├── SiliconFlowService.qml    # Thin wrapper: api.siliconflow.cn/v1/chat/completions
│   │           ├── FreeDictionaryApiService.qml  # api.dictionaryapi.dev (no key needed)
│   │           └── YoudaoWebNewService.qml   # dict.youdao.com scraping, regex HTML parse
├── src/
│   └── ProcessHelper.h/.cpp     # QML module: QClipboard PRIMARY selection listener + SQLite + JSON
├── tests/
│   ├── diagnostic.qml           # Interactive diagnostic UI (qml6 -I ...)
│   └── tst_ProcessHelper.qml    # QTest unit tests for ProcessHelper
└── .gitignore
```

## Architecture

### Pure QML Plasmoid (primary)

All translation logic is pure QML. A small C++ helper module (`ProcessHelper`) provides:
- PRIMARY selection reading via `QClipboard` (freshness check: `elapsed <= 1000ms`)
- SQLite persistence (`translations` table at `~/.config/linguaspanner/linguaspanner.db`) — AI translation cache
- JSON config persistence (`~/.config/linguaspanner/linguaspanner.json`) — sourceLang/targetLang/currentMode across sessions

### Result panel architecture

`main.qml` owns all state (`youDaoResult`, `dictionaryResult`, `aiResult`) and delegates display to separate panels:

- `AiResultPanel.qml` — handles both streaming (SSE in-progress) and structured result (parsed JSON) for DeepSeek + SiliconFlow. Contains floating action buttons: cancel (during streaming), refresh + delete (after result).
- `YoudaoResultPanel.qml` — flat grid models for word/phonetic/definition display from scraped HTML.
- `DictionaryResultPanel.qml` — JSON-to-flat-grid for Free Dictionary API responses.
- `FontStyle.qml` — shared `QtObject` providing canonical `base`, `large`, `small`, `secondary` pixel sizes from `Plasmoid.configuration.fontSizeBase`. Imported by all result panels.

### Translation DB schema

```sql
CREATE TABLE translations (
  id            TEXT    PRIMARY KEY,  -- UUID v4
  input_text    TEXT    NOT NULL,
  cleaned_input TEXT    NOT NULL DEFAULT '',
  engine        TEXT    NOT NULL,
  source_lang   TEXT    NOT NULL DEFAULT '',
  target_lang   TEXT    NOT NULL DEFAULT '',
  result_json   TEXT    NOT NULL DEFAULT '{}',
  created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now'))
);
```

Cache lookups match on `LOWER(input_text) OR LOWER(cleaned_input)` + `LOWER(source_lang)` + `LOWER(target_lang)` + engine family (`deepseek`/`siliconflow`). All comparisons are case-insensitive. `_insertTranslation()` generates a new UUID on INSERT; `refreshTranslation()` does an UPDATE on the existing UUID.

### AI result JSON schema

```javascript
{
  "translate":      "translated text",
  "source_lang":    "en",           // detected or specified
  "target_lang":    "zh",
  "cleaned_input":  "normalized input text",
  "words":          [{ "word": "hello", "pos": "int", "meaning": "你好" }],
  "frequently":     [{ "phrase": "hello world", "translation": "你好世界" }],
  "examples":       [{ "sentence": "Hello, how are you?", "translation": "你好吗？" }]
}
```

POS tags use lowercase abbreviated forms (v, n, adj, adv, prep, int, etc.).

### Dual config system

| Scope | Storage | Backend | Content |
|-------|---------|---------|---------|
| **Plugin settings** | KConfig XT (`main.xml`) | Plasma/KConfig | API keys, models, temperature, shortcuts, font size |
| **UI state** | `linguaspanner.json` JSON file | ProcessHelper C++ | sourceLang, targetLang, currentMode (persists across Plasma sessions independently) |

| Service | API | Backend |
|---------|-----|---------|
| `DeepSeekService.qml` | `POST api.deepseek.com/chat/completions` | Thin wrapper over OpenAiChatService |
| `SiliconFlowService.qml` | `POST api.siliconflow.cn/v1/chat/completions` | Thin wrapper over OpenAiChatService |
| `YoudaoWebNewService.qml` | `GET dict.youdao.com/result?word=X&lang=en` | Dictionary scraping, regex HTML parse |
| `FreeDictionaryApiService.qml` | `GET api.dictionaryapi.dev/api/v2/entries/en/X` | English definitions (no key) |

**OpenAiChatService.qml** is the generic SSE-streaming base for both AI engines — it encapsulates XMLHttpRequest, SSE `data:` line-buffer parsing with `lastParsedLen` tracking, streaming update signals, cancel support, and error handling. DeepSeekService and SiliconFlowService are simple 20-line wrappers that configure the endpoint URL.

### Activation lifecycle

`onExpandedChanged` / `Component.onCompleted` → `handlePanelOpened()`:
1. **Keyboard shortcut** (`_openedByClick=false`): reads PRIMARY selection via QClipboard → freshness check → paste + translate; fall through to focus input if stale or empty.
2. **Click** (`_openedByClick=true`): toggle panel, focus input only — never reads selection.
3. **Panel close**: resets `_openedByClick` flag so next shortcut path works.

### Action flow (AI result)

After an AI translation completes (result visible):
- **Refresh** (`view-refresh`): re-submits same input text to API (bypasses cache), updates existing DB record in-place (preserves UUID). On completion or error, auto-focuses input and selects all. During refresh error, `streamingInput` is preserved so the panel stays visible.
- **Delete** (`edit-delete`): removes DB record by UUID (with content-based fallback lookup), clears all state (`aiResult`, `streamingInput`, `inputText`), focuses input.
- **Cancel** (`dialog-cancel`): aborts in-flight XMLHttpRequest, clears streaming state, focuses input+selects all for quick re-translate.

### Config pipeline

`main.xml` (KConfig XT) → `config.qml` (shell) → `ConfigGeneral.qml` + `AiConfigCategory.qml`. Config keys like `modeOrder`, `modeEnabled`, `fontSizeBase` are JSON strings parsed in QML. AI model lists (`deepseekModelList`, `siliconFlowModelList`) are cached JSON from model-list API fetches — `AiConfigCategory.qml` auto-fetches available models from each provider when the API key is entered.

ConfigGeneral is a multi-page KCM: general settings (engine ordering, font, shortcuts) plus per-engine category sections loaded via `AiConfigCategory` for DeepSeek and SiliconFlow.

### Concurrency guard

A single `translating` boolean gates all entry points: `translate()`, `refreshTranslation()`, and mode switching all bail out early if `translating` is true. The mode ComboBox is explicitly disabled during translation. `cancelTranslation()` resets the flag.

## Development

```sh
# Convenience script (alternative to make)
./dev status         # same as make status
./dev build | full | qml | install | test | restart

# Info
make status          # git log, plasmoid install status, module file info
make configure       # cmake configure (needed once after clone)
make clean           # remove build directory

# Iterate
make build           # cmake --build + stage .so to package (C++ changes)
make qml             # kpackagetool6 -u + restart (QML-only changes)
make full            # full deploy (build + install + restart)
make test            # install + plasmawindowed preview (no shell restart)
make restart         # kquitapp6 + plasmashell --replace

# Tests
qml6 -I package/contents/lib tests/tst_ProcessHelper.qml   # C++ QML module unit tests
qml6 -I package/contents/lib tests/diagnostic.qml          # Interactive diagnostics UI

# Debug
journalctl -f -o cat | grep -E "ProcessHelper|qml:"       # Plasmoid logs
```

### Code conventions

- **Language**: All user-facing strings use Chinese comments; English for internal logic.
- **Streaming AI services**: Both AI wrappers use OpenAiChatService which parses SSE `data:` lines manually from XMLHttpRequest responseText using a line-buffer pattern with `lastParsedLen` tracking — not EventSource.
- **DB IDs**: UUID v4 strings, not auto-increment integers. Generated client-side in QML via `_generateUuid()`.
- **Rich text**: AI result text containing parenthetical notes (parentheses, angle brackets, square/curly brackets) is rendered via `grayBrackets()` which wraps bracketed content in `<font color="gray">` tags for `TextEdit.RichText` display.
- **Result panel reuse**: All panels share `FontStyle { id: fs }` for consistent font sizing driven by a single config key.

## Commit workflow

1. Verify git status is clean (`git status`)
2. Stage only relevant files with `git add -A`
3. Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `style:`, `refactor:`
4. For feature/fix commits with significant changes, include a body with bullet points
5. Tag format: `v<major>.<minor>.<patch>` — matched to `package/metadata.json` → `KPlugin.Version`

## Update / release workflow

1. Bump `package/metadata.json` → `KPlugin.Version` to the new version string
2. Commit: `chore: bump metadata.json version to X.X.X`
3. Tag: `git tag vX.X.X HEAD`
4. Push with `git push --atomic origin main vX.X.X`
