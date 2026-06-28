// ── Paste Selection Helper ──────────────────────────────────
// Reads PRIMARY selection text from the focused window.
// Uses the C++ ProcessHelper (LinguaSpannerHelper) which wraps
// QProcess to run xclip synchronously.

import QtQuick
import "../lib/LinguaSpannerHelper"

QtObject {
    id: root

    property ProcessHelper proc: ProcessHelper {}

    /// Read from PRIMARY selection (X11 middle-click / Wayland highlight)
    function readSelection() {
        return proc.readProcessOutput("xclip", ["-o", "-selection", "primary"])
    }

    /// Read PRIMARY selection asynchronously.
    /// Results arrive via ProcessHelper.selectionReady / selectionError signals.
    function readSelectionAsync() {
        proc.readSelectionAsync()
    }

    /// Clear PRIMARY selection — prevents stale content
    /// from being re-pasted on the next shortcut press.
    function clearSelection() {
        proc.readProcessOutput("xclip", ["-i", "/dev/null", "-selection", "primary"])
    }
}
