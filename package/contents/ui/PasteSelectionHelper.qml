// ── Paste Selection Helper ──────────────────────────────────
// Reads text from the system's primary selection or clipboard.
// Uses the C++ ProcessHelper (LinguaSpannerHelper) which wraps
// QProcess to run xclip synchronously.

import QtQuick
import "../lib/LinguaSpannerHelper"

QtObject {
    id: root

    // C++ helper — runs xclip via QProcess
    // (ProcessHelper is not a singleton, QML_ELEMENT creates
    //  an instance for us)
    property ProcessHelper proc: ProcessHelper {}

    /// Read from PRIMARY selection (X11 middle-click / Wayland highlight)
    function readSelection() {
        return proc.readProcessOutput("xclip", ["-o", "-selection", "primary"])
    }

    /// Read from CLIPBOARD (Ctrl+C buffer)
    function readClipboard() {
        return proc.readProcessOutput("xclip", ["-o", "-selection", "clipboard"])
    }
}
