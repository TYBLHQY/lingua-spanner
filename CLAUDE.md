# CLAUDE.md

## Project Overview

**Lingua Spanner** — a KDE Plasma 6 plasmoid (applet) for translation. Supports dual-engine: Youdao web scraping dictionary and DeepSeek AI API translation. Provides two global shortcuts: open panel with input focus, and pick selected text from the focused window.

- **Type:** Plasma/Applet (KPackageStructure)
- **Target:** Plasma 6.0+
- **Plugin ID:** `org.kde.lingua-spanner`
- **License:** GPL-2.0+

## Directory Structure

```
lingua-spanner/
├── CLAUDE.md
├── CMakeLists.txt                # C++ build (AT-SPI, lexbor, OCR modules)
├── docs/
│   ├── feasibility-report.md     # Original feasibility report (archived)
│   └── requirements.md           # Project requirements document
├── package/                      # KPackage root (primary deployment unit)
│   ├── metadata.json             # Plugin metadata (name, version, category, ID)
│   ├── contents/
│   │   ├── config/
│   │   │   ├── main.xml          # KConfig XT schema (translateMode, apiKey, etc.)
│   │   │   └── config.qml        # Config UI shell (points to ConfigGeneral.qml)
│   │   └── ui/
│   │       ├── main.qml          # Main applet: PlasmoidItem, translate UI, shortcuts
│   │       ├── ConfigGeneral.qml # Settings form: engine selection, API key, etc.
│   │       ├── PasteSelectionHelper.qml  # Text picker from focused window
│   │       └── services/
│   │           ├── YoudaoWebNewService.qml  # Youdao dictionary scraping
│   │           └── DeepSeekService.qml      # DeepSeek API translation
│   └── translate/                # Translation files (empty)
├── src/                          # C++ sources (for future AT-SPI etc.)
│   ├── mainapplet.h/.cpp
│   ├── atspitextreader.h/.cpp
│   ├── htmlparser.h/.cpp
│   └── ocrrunner.h/.cpp
├── youdao-web-new-scraping-rules.md  # Youdao scraping reference
└── .gitignore
```

## Architecture

### Pure QML Plasmoid (primary)

The translation app is a pure-QML plasmoid (no C++ compilation needed). All services use `XMLHttpRequest` for HTTP calls.

| File | Role |
|------|------|
| `package/contents/ui/main.qml` | Plasmoid entry: UI, shortcuts, orchestration |
| `services/YoudaoWebNewService.qml` | Scrapes `dict.youdao.com` → parses HTML → returns exp/audio/forms |
| `services/DeepSeekService.qml` | Calls `api.deepseek.com/chat/completions` → returns translation |
| `PasteSelectionHelper.qml` | Reads primary selection / clipboard for text pick feature |

### Development Workflow

```sh
# Install plasmoid (self-contained — includes C++ helper module)
kpackagetool6 -t Plasma/Applet -i package/

# Update after changes to QML/Package files
kpackagetool6 -t Plasma/Applet -u package/

# Update after C++ helper changes
cmake --build build -j$(nproc)
kpackagetool6 -t Plasma/Applet -u package/

# Remove
kpackagetool6 -t Plasma/Applet -r org.kde.lingua-spanner

# Test just popup (no plasma restart needed)
plasmawindowed org.kde.lingua-spanner

# ── Full refresh cycle (for panel/widget testing) ──────────
# After update, run BOTH:
rm -rf ~/.cache/libqmlcache/
systemctl --user restart plasma-plasmashell

# NOTE: The restart is REQUIRED after updating to see changes
#       live on the panel. `plasmashell` caches KPackage at
#       load time; `kpackagetool6 -u` only updates files on disk.

# Config UI development
systemsettings kcm_plasmoid_config ./package/
```

### C++ Helper Module

The `LinguaSpannerHelper` QML module (in `package/contents/ui/LinguaSpannerHelper/`) wraps `QProcess` for calling `xclip` synchronously from QML.

- **Source**: `src/ProcessHelper.h` / `.cpp`
- **Build**: `cmake --build build -j$(nproc)` (Qt6 only, no KF6 needed)
- **After rebuild**: copy `.so` files to package:
  ```sh
  mkdir -p package/contents/ui/LinguaSpannerHelper
  cp -a build/liblingua_spanner_helper.so \
        ~/.local/lib/qml/LinguaSpannerHelper/lingua_spanner_helperplugin.so \
        ~/.local/lib/qml/LinguaSpannerHelper/qmldir \
        ~/.local/lib/qml/LinguaSpannerHelper/*.qmltypes \
        package/contents/ui/LinguaSpannerHelper/
  cd package/contents/ui/LinguaSpannerHelper
  ln -sf lingua_spanner_helperplugin.so liblingua_spanner_helperplugin.so
  ```
- **Self-contained**: The module is bundled in the plasmoid package (contents/ui/LinguaSpannerHelper/). No system-wide install needed.
- **QML import**: `import LinguaSpannerHelper` from `main.qml`

### Youdao Web Scraping

Reference: `youdao-web-new-scraping-rules.md`

URL: `GET https://dict.youdao.com/result?word=<word>&lang=en`
Root container: `.modules`
Parsing: regex-based in QML (future upgrade: Lexbor C++ parser)

### DeepSeek API

Endpoint: `POST https://api.deepseek.com/chat/completions`
Auth: `Authorization: Bearer <apiKey>` (stored in plaintext in KConfig)
System prompt: professional translator role with auto language detection
