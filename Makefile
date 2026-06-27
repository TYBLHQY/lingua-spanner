# ── Lingua Spanner Makefile ─────────────────────────────────
# Usage:
#   make           — full cycle (build → stage → install → test)
#   make qml       — quick QML-only update + test
#   make build     — compile C++ + stage .so to package
#   make install   — kpackagetool6 update
#   make test      — plasmawindowed preview
#   make restart   — restart plasmashell (for panel widget)
#   make clean     — clean build dir

SHELL := /usr/bin/env bash
PROJ  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PLUGIN_SRC := $(PROJ)/build/liblingua_spanner_helper.so
PLUGIN_DST := $(PROJ)/package/contents/lib/LinguaSpannerHelper
PLUGIN_OUT := $(HOME)/.local/lib/qml/LinguaSpannerHelper

# ── Detect number of CPU cores ─────────────────────────────
JOBS := $(shell nproc 2>/dev/null || echo 2)

# ── Default: full cycle (C++ + install + test) ─────────────
.PHONY: all
all: build install test

# ── Build C++ module + stage .so to package ────────────────
.PHONY: build
build:
	@echo "==> [build] Compiling C++ helper…"
	cmake --build $(PROJ)/build -j$(JOBS)
	@echo "==> [build] Staging .so files to package…"
	cp -a $(PLUGIN_SRC) $(PLUGIN_DST)/
	cp -a $(PLUGIN_OUT)/lingua_spanner_helperplugin.so $(PLUGIN_DST)/
	ln -sf lingua_spanner_helperplugin.so $(PLUGIN_DST)/liblingua_spanner_helperplugin.so
	@echo "==> [build] Done."

# ── Install/update plasmoid (QML + package only) ──────────
.PHONY: install
install:
	@echo "==> [install] Updating plasmoid package…"
	kpackagetool6 -t Plasma/Applet -u $(PROJ)/package/ 2>&1 | grep -v "does not match"
	@echo "==> [install] Clearing QML cache…"
	rm -rf ~/.cache/libqmlcache/
	@echo "==> [install] Done."

# ── Quick QML-only cycle ──────────────────────────────────
.PHONY: qml
qml: install test

# ── Test with plasmawindowed ──────────────────────────────
.PHONY: test
test:
	@echo "==> [test] Launching plasmawindowed (pid=$$), press Ctrl+C to close…"
	plasmawindowed org.kde.lingua-spanner &
	@while true; do sleep 1; done

# ── Restart Plasma shell (for panel widget refresh) ───────
.PHONY: restart
restart:
	@echo "==> [restart] Restarting plasma-plasmashell…"
	systemctl --user restart plasma-plasmashell
	@echo "==> [restart] Done."

# ── Full refresh (for testing widget on panel/desktop) ────
.PHONY: full
full: build install restart

# ── Clean ─────────────────────────────────────────────────
.PHONY: clean
clean:
	@echo "==> [clean] Removing build directory…"
	rm -rf $(PROJ)/build
	@echo "==> [clean] Done."

# ── Show status ───────────────────────────────────────────
.PHONY: status
status:
	@echo "=== Git ===" && git -C $(PROJ) log --oneline -3 2>/dev/null
	@echo ""
	@echo "=== Plasmoid ===" && kpackagetool6 -t Plasma/Applet -s org.kde.lingua-spanner 2>/dev/null || echo "(not installed)"
	@echo ""
	@echo "=== Helper module ===" && ls -la $(PLUGIN_DST)/*.so 2>/dev/null
