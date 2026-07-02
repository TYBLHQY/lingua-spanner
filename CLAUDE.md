# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lingua Spanner** — a KDE Plasma 6 plasmoid (applet) for translation. Supports 4 translation backends: Youdao web dictionary (scraping), DeepSeek API, SiliconFlow API (OpenAI-compatible), and Free Dictionary API. All HTTP via `XMLHttpRequest`.

- **Type:** Plasma/Applet (KPackageStructure)
- **Target:** Plasma 6.0+
- **Plugin ID:** `org.kde.lingua-spanner`
- **License:** GPL-2.0+
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
│   │       ├── main.qml              # PlasmoidItem: UI, orchestration, shortcuts
│   │       ├── ConfigGeneral.qml     # Settings form
│   │       ├── PasteSelectionHelper.qml  # Wraps ProcessHelper for QClipboard
│   │       └── services/
│   │           ├── DeepSeekService.qml
│   │           ├── SiliconFlowService.qml
│   │           ├── FreeDictionaryApiService.qml
│   │           └── YoudaoWebNewService.qml
├── src/
│   └── ProcessHelper.h/.cpp     # QML module: QClipboard PRIMARY selection listener
├── tests/
│   ├── diagnostic.qml           # Interactive diagnostic UI (qml6 -I ...)
│   └── tst_ProcessHelper.qml    # QTest unit tests for ProcessHelper
└── .gitignore
```

## Architecture

### Pure QML Plasmoid (primary)

All translation logic is pure QML. A small C++ helper module (`ProcessHelper`) provides:
- PRIMARY selection reading via `QClipboard`
- SQLite persistence (`translations` table at `~/.config/linguaspanner/linguaspanner.db`) — AI translation cache
- JSON config persistence (`~/.config/linguaspanner/linguaspanner.json`) — sourceLang/targetLang/currentMode across sessions

### Translation DB schema

```sql
CREATE TABLE translations (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  input_text    TEXT    NOT NULL,
  cleaned_input TEXT    NOT NULL DEFAULT '',
  engine        TEXT    NOT NULL,
  source_lang   TEXT    NOT NULL DEFAULT '',
  target_lang   TEXT    NOT NULL DEFAULT '',
  result_json   TEXT    NOT NULL DEFAULT '{}',
  created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now'))
);
```

Cache lookups match on (input_text OR cleaned_input) + source_lang + target_lang + engine family (deepseek/siliconflow). Mismatch in any condition triggers a new API call.

### Dual config system

| Scope | Storage | Backend | Content |
|-------|---------|---------|---------|
| **Plugin settings** | KConfig XT (`main.xml`) | Plasma/KConfig | API keys, models, temperature, shortcuts, font size |
| **UI state** | `linguaspanner.json` JSON file | ProcessHelper C++ | sourceLang, targetLang, currentMode (persists across Plasma sessions independently) |

| Service | API | Backend |
|---------|-----|---------|
| `DeepSeekService.qml` | `POST api.deepseek.com/chat/completions` | AI translation |
| `SiliconFlowService.qml` | `POST api.siliconflow.cn/v1/chat/completions` | AI translation (OpenAI-compatible) |
| `YoudaoWebNewService.qml` | `GET dict.youdao.com/result?word=X&lang=en` | Dictionary scraping, regex HTML parse |
| `FreeDictionaryApiService.qml` | `GET api.dictionaryapi.dev/api/v2/entries/en/X` | English definitions (no key) |

### Activation lifecycle

`onExpandedChanged` / `Component.onCompleted` → `handlePanelOpened()`:
1. **Keyboard shortcut** (`_openedByClick=false`): reads PRIMARY selection via QClipboard → freshness check (`elapsed <= 1000` ms since `QClipboard::changed(Selection)`) → paste + translate; fall through to focus input if stale or empty.
2. **Click** (`_openedByClick=true`): toggle panel, focus input only — never reads selection.
3. **Panel close**: resets `_openedByClick` flag so next shortcut path works.

### Config pipeline

`main.xml` (KConfig XT) → `config.qml` (shell) → `ConfigGeneral.qml` (actual 630-line settings widget). Config keys like `modeOrder`, `modeEnabled`, `fontSizeBase` are JSON strings parsed in QML. AI model lists (`deepseekModelList`, `siliconFlowModelList`) are cached JSON from model-list API fetches — `ConfigGeneral.qml` auto-fetches available models from each provider when the API key is entered.

### Selection freshness (`ProcessHelper`)

`ProcessHelper` constructor connects `QGuiApplication::clipboard()->changed(QClipboard::Selection)` and records `m_selectionTimestamp`. When `readPrimarySelection()` is called, `main.qml` checks `elapsed <= 1000` — stale selections (>1s since last change) are silently ignored, falling through to focus the input field.

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
- **Streaming AI services**: Both DeepSeekService and SiliconFlowService support SSE streaming — the QML parses SSE `data:` lines manually from XMLHttpRequest responseText using a line-buffer pattern with `lastParsedLen` tracking.
- **Result JSON schema**: AI services return JSON with `{"translate","source_lang","target_lang","cleaned_input","words":[{...}],"frequently":[{...}]}`. POS tags use lowercase abbreviated forms (v, n, adj, adv, etc.).

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
