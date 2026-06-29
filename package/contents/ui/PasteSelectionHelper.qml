// ── Paste Selection Helper ──────────────────────────────────
// Reads PRIMARY selection text from the focused window.
// Uses the C++ ProcessHelper (LinguaSpannerHelper) which reads
// PRIMARY selection directly via QClipboard — no external tool needed.
// Selection freshness is determined by ProcessHelper.selectionTimestamp
// (updated via QClipboard when PRIMARY owner changes).

import QtQuick
import "../lib/LinguaSpannerHelper"

QtObject {
    id: root

    property ProcessHelper proc: ProcessHelper {}

    /// Read from PRIMARY selection (X11 middle-click / Wayland highlight)
    function readSelection() {
        return proc.readPrimarySelection()
    }
}
