# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lingua Spanner** — a KDE Plasma 6 plasmoid (applet) for dictionary look-up. Single engine: Youdao web dictionary (HTML scraping). TTS via Edge-TTS CLI. All HTTP via `XMLHttpRequest`.

- **Type:** Plasma/Applet (KPackageStructure)
- **Target:** Plasma 6.0+
- **Plugin ID:** `org.kde.lingua-spanner`
- **License:** GPL-2.0-or-later
- **Language:** QML (primary) + C++ (QClipboard PRIMARY listener, SQLite, config persistence)
- **Config:** KConfig XT (`main.xml`) for plugin-scoped keys

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
│   ├── metadata.json
│   ├── contents/
│   │   ├── config/
│   │   │   ├── main.xml       # KConfig XT schema (shortcuts, fonts, TTS)
│   │   │   └── config.qml     # Shell that loads ConfigGeneral + TtsConfigCategory
│   │   ├── lib/LinguaSpannerHelper/  # C++ QML module (.so + qmldir)
│   │   └── ui/
│   │       ├── main.qml                # PlasmoidItem: UI, orchestration, shortcuts
│   │       ├── ConfigGeneral.qml       # Settings form (display + behavior)
│   │       ├── TtsConfigCategory.qml   # Edge-TTS per-language voice + rate/volume/pitch
│   │       ├── PasteSelectionHelper.qml # Wraps ProcessHelper for QClipboard
│   │       ├── FontStyle.qml            # Shared font-size descriptor
│   │       ├── YoudaoResultPanel.qml    # Youdao dictionary result display
│   │       └── services/
│   │           ├── YoudaoWebNewService.qml   # dict.youdao.com scraping, regex HTML parse
│   │           └── EdgeTtsService.qml       # Edge-TTS text-to-speech via ProcessHelper
├── src/
│   └── ProcessHelper.h/.cpp   # QML module: QClipboard PRIMARY selection listener + SQLite + process execution
├── tests/
│   ├── diagnostic.qml
│   └── tst_ProcessHelper.qml
└── .gitignore
```

## Architecture

### Pure QML Plasmoid (primary)

All dictionary look-up logic is pure QML. A small C++ helper module (`ProcessHelper`) provides:
- PRIMARY selection reading via `QClipboard` (freshness check: `elapsed <= 2000ms`)
- Process execution (Edge-TTS CLI, audio playback via paplay)
- File cache management for TTS audio

### Single engine: Youdao Web Dictionary

`YoudaoWebNewService.qml` scrapes `dict.youdao.com/result?word=X&lang=en` via `XMLHttpRequest`, parsing HTML with regex to extract:
- Word / phonetic / audio URLs
- Definitions (exp) with part-of-speech (po) and translations (tr)
- Exam type tags (CET4, CET6, GRE, etc.)
- Word forms (plural, past tense, etc.)

### Result panel

`YoudaoResultPanel.qml` renders dictionary results in a flat grid:
- Audio playback bar (via Qt Multimedia `MediaPlayer`)
- Exam type tags
- Word forms (plural, past tense, etc.)
- Definitions — 2-column grid (word class + definition) when POS is present, simple list otherwise
- Gray-bracket rendering for parenthetical notes

### TTS via Edge-TTS

`EdgeTtsService.qml` calls the `edge-tts` CLI via `ProcessHelper.runCommand()`:
- Synthesizes text → MP3 file (cached by text+voice hash)
- Playback via `paplay` (PulseAudio)
- Cache eviction: LRU, max 100 files
- Timeout: 40s per synthesis

### Activation lifecycle

`onExpandedChanged` / `Component.onCompleted` → `handlePanelOpened()`:
1. **Keyboard shortcut** (`_openedByClick=false`): reads PRIMARY selection via QClipboard → freshness check → paste + look up; fall through to focus input if stale or empty.
2. **Click** (`_openedByClick=true`): toggle panel, focus input only — never reads selection.
3. **Panel close**: resets `_openedByClick` flag so next shortcut path works.

### Config pipeline

`main.xml` (KConfig XT) → `config.qml` (shell) → `ConfigGeneral.qml` + `TtsConfigCategory.qml`.

ConfigGeneral: display settings (font size, font family) and behavior (auto look up on selection).
TtsConfigCategory: per-language voice selection, rate/volume/pitch sliders, binary path, voice list refresh.

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
- **Rich text**: Dictionary result text containing parenthetical notes is rendered via `grayBrackets()` which wraps bracketed content in `<font color="gray">` tags.
- **Font sizing**: `FontStyle.qml` provides canonical `base`, `large`, `small`, `secondary` pixel sizes from `Plasmoid.configuration.fontSizeBase`.

## Commit workflow

1. Verify git status is clean (`git status`)
2. Stage only relevant files with `git add -A`
3. Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `style:`, `refactor:`
4. Tag format: `v<major>.<minor>.<patch>` — matched to `package/metadata.json` → `KPlugin.Version`

## Update / release workflow

1. Bump `package/metadata.json` → `KPlugin.Version` to the new version string
2. Commit: `chore: bump metadata.json version to X.X.X`
3. Tag: `git tag vX.X.X HEAD`
4. Push with `git push --atomic origin main vX.X.X`
