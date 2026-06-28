# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lingua Spanner** — a KDE Plasma 6 plasmoid (applet) for translation. Supports 4 translation backends: Youdao web dictionary (scraping), DeepSeek API, SiliconFlow API (OpenAI-compatible), and Free Dictionary API. All HTTP via `XMLHttpRequest`.

- **Type:** Plasma/Applet (KPackageStructure)
- **Target:** Plasma 6.0+
- **Plugin ID:** `org.kde.lingua-spanner`
- **License:** GPL-2.0+

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
│   │       ├── PasteSelectionHelper.qml  # Wraps ProcessHelper for xclip
│   │       └── services/
│   │           ├── DeepSeekService.qml
│   │           ├── SiliconFlowService.qml
│   │           ├── FreeDictionaryApiService.qml
│   │           └── YoudaoWebNewService.qml
├── src/
│   └── ProcessHelper.h/.cpp     # QML module: xclip wrapper + QClipboard listener
├── tests/
│   ├── diagnostic.qml           # Interactive diagnostic UI (qml6 -I ...)
│   └── tst_ProcessHelper.qml    # QTest unit tests for ProcessHelper
└── .gitignore
```

## Architecture

### Pure QML Plasmoid (primary)

All translation logic is pure QML. A small C++ helper module (`ProcessHelper`) provides xclip access and PRIMARY selection timestamp tracking via `QClipboard`.

| Service | API | Backend |
|---------|-----|---------|
| `DeepSeekService.qml` | `POST api.deepseek.com/chat/completions` | AI translation |
| `SiliconFlowService.qml` | `POST api.siliconflow.cn/v1/chat/completions` | AI translation (OpenAI-compatible) |
| `YoudaoWebNewService.qml` | `GET dict.youdao.com/result?word=X&lang=en` | Dictionary scraping, regex HTML parse |
| `FreeDictionaryApiService.qml` | `GET api.dictionaryapi.dev/api/v2/entries/en/X` | English definitions (no key) |

### Activation

Shortcut/click → `handlePanelOpened()`:
1. **Keyboard shortcut**: reads PRIMARY selection asynchronously → freshness check (must be within 1s of last `QClipboard::changed(Selection)` signal) → paste + translate; otherwise focus input.
2. **Click**: toggle panel, focus input only — never reads selection.

### Config pipeline

`main.xml` (KConfig XT) → `config.qml` (shell) → `ConfigGeneral.qml` (actual widget). Config keys like `modeOrder`, `modeEnabled`, `fontSizeBase` are JSON strings parsed in QML. AI model lists (`deepseekModelList`, `siliconFlowModelList`) are cached JSON from model-list API fetches.

### Selection freshness (`ProcessHelper`)

`ProcessHelper` constructor connects `QGuiApplication::clipboard()->changed(QClipboard::Selection)` and records `m_selectionTimestamp`. When xclip async read completes, `main.qml` checks `elapsed <= 1000` — stale selections (>1s since last change) are silently ignored, replacing the old `clearSelection()` approach.

## Development

```sh
# Info
make status          # git log, plasmoid install status, module file info
make configure       # cmake configure (first time after clone)

# Iterate
make build           # cmake --build + stage .so to package (C++ changes)
make qml             # kpackagetool6 -u + restart (QML-only changes)
make full            # full deploy (build + install + restart)
make test            # install + plasmawindowed preview (no shell restart)
make restart         # kquitapp6 + plasmashell --replace

# Tests
qml6 -I package/contents/lib tests/tst_ProcessHelper.qml   # Unit tests
qml6 -I package/contents/lib tests/diagnostic.qml          # Interactive diagnostics

# Debug
journalctl -f -o cat | grep -E "ProcessHelper|qml:"       # Plasmoid logs
```
