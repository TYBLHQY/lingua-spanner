// ── Paste Selection Helper ──────────────────────────────────
// Reads text from the system's primary selection or clipboard
// Used by shortcut 2 to pick text from the focused window

import QtQuick

QtObject {
    id: root

    /// Read from PRIMARY selection (middle-click paste buffer)
    /// Most Linux apps put selected text here automatically
    function readSelection() {
        // Use xclip to read primary selection
        // This is a workaround since QML doesn't have direct access to QClipboard::Selection
        try {
            var result = execSync("xclip", ["-o", "-selection", "primary"])
            return result.trim()
        } catch (e) {
            return ""
        }
    }

    /// Read from CLIPBOARD (Ctrl+C buffer)
    function readClipboard() {
        try {
            var result = execSync("xclip", ["-o", "-selection", "clipboard"])
            return result.trim()
        } catch (e) {
            return ""
        }
    }

    /// Synchronous command execution (blocking)
    function execSync(cmd, args) {
        // QML doesn't have a synchronous exec — this wraps the intent.
        // Implementation note: In the full applet, this will use
        // QProcess via a Q_INVOKABLE C++ helper, or xdotool key --delay 0 Ctrl+C
        // followed by clipboard read.
        //
        // For now, this is a placeholder that returns empty string,
        // to be replaced with an actual process call.
        return ""
    }
}
