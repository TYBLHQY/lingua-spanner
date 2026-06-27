# CLAUDE.md

## Project Overview

**Lingua Spanner** — a KDE Plasma 6 plasmoid (applet) for translation. Supports dual-engine: Youdao web dictionary and DeepSeek AI API translation. Provides a single global shortcut: open panel → read selection if available → paste and translate, otherwise just focus input.

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
│   ├── feasibility-report.md  # Original feasibility report (archived)
│   └── requirements.md        # Project requirements document
├── package/                   # KPackage root (primary deployment unit)
│   ├── metadata.json          # Plugin metadata (name, version, category, ID)
│   ├── contents/
│   │   ├── config/
│   │   │   ├── main.xml       # KConfig XT schema (translateMode, apiKey, etc.)
│   │   │   └── config.qml     # Config UI shell (points to ConfigGeneral.qml)
│   │   ├── lib/
│   │   │   └── LinguaSpannerHelper/  # C++ QML module (.so + qmldir)
│   │   └── ui/
│   │       ├── main.qml            # Main applet: PlasmoidItem, translate UI
│   │       ├── ConfigGeneral.qml   # Settings form: engine selection, API key
│   │       ├── PasteSelectionHelper.qml  # Text picker wrapping ProcessHelper
│   │       └── services/
│   │           ├── DeepSeekService.qml          # DeepSeek API translation
│   │           ├── FreeDictionaryApiService.qml # Free Dictionary API (no key needed)
│   │           └── YoudaoWebNewService.qml      # Youdao web dictionary
│   └── translate/               # Translation files
├── src/
│   └── ProcessHelper.h/.cpp     # C++ QML plugin — QProcess xclip wrapper
├── tests/
│   ├── diagnostic.qml           # Interactive diagnostic UI
│   └── tst_ProcessHelper.qml    # ProcessHelper unit test
├── docs/
│   ├── feasibility-report.md           # Original feasibility report (archived)
│   ├── requirements.md                 # Project requirements document
│   └── youdao-web-html-parsing-rules.md # Youdao HTML parsing reference
└── .gitignore                  # .claude/ ignored, CLAUDE.md tracked
```

## Architecture

### Pure QML Plasmoid (primary)

The translation app is a pure-QML plasmoid with a small C++ helper module for xclip access. All HTTP calls use `XMLHttpRequest`.

| File | Role |
|------|------|
| `package/contents/ui/main.qml` | Plasmoid entry: UI, shortcuts, orchestration |
| `services/DeepSeekService.qml` | Calls `api.deepseek.com/chat/completions` → returns AI translation |
| `services/YoudaoWebNewService.qml` | Queries `dict.youdao.com` → parses HTML → returns exp/audio/forms |
| `services/FreeDictionaryApiService.qml` | Queries `api.dictionaryapi.dev` → returns English definitions (no key) |
| `PasteSelectionHelper.qml` | Reads primary selection / clipboard via ProcessHelper C++ |

### Activation behavior

Single shortcut/click → `handlePanelOpened()`:
1. **Keyboard shortcut**: reads PRIMARY selection → if found, paste + translate; else focus input (keeping previous content)
2. **Click/tap icon**: toggle panel, focus input — never reads selection

### Development Workflow

```sh
# Quick — next best thing
./dev qml       # = kpackagetool6 -u + restart (QML-only changes)
./dev build     # = cmake --build + stage .so to package (C++ changes)
./dev full      # = build + install + restart (full deploy)

# Manual step-by-step
kpackagetool6 -t Plasma/Applet -i package/     # Install
kpackagetool6 -t Plasma/Applet -u package/     # Update
kpackagetool6 -t Plasma/Applet -r org.kde.lingua-spanner  # Remove

# Testing
plasmawindowed org.kde.lingua-spanner           # Popup test (no restart)

# Restart plasma shell
./dev restart   # = kquitapp6 + plasmashell --replace

# Config UI
systemsettings kcm_plasmoid_config ./package/

# Debug logs
journalctl -f -o cat | grep -E "ProcessHelper|qml:"
```

### C++ Helper Module

The `LinguaSpannerHelper` QML module (in `package/contents/lib/LinguaSpannerHelper/`) wraps `QProcess` for calling `xclip` synchronously from QML.

- **Source**: `src/ProcessHelper.h` / `.cpp`
- **Build**: `cmake --build build -j$(nproc)` (Qt6 only, no KF6 needed)
- **After rebuild**: files auto-staged by `make build` or `./dev build`
- **Self-contained**: The module is bundled in the plasmoid package (`contents/lib/LinguaSpannerHelper/`). No system-wide install needed.
- **QML import**: `import "../lib/LinguaSpannerHelper"` from `main.qml`

### Youdao Web Dictionary

Reference: `docs/youdao-web-html-parsing-rules.md` (HTML parsing details)

URL: `GET https://dict.youdao.com/result?word=<word>&lang=en`
Root container: `.modules`
Parsing: regex-based in QML

### DeepSeek API

Endpoint: `POST https://api.deepseek.com/chat/completions`
Auth: `Authorization: Bearer <apiKey>` (stored in plaintext in KConfig)
System prompt: professional translator role with auto language detection
