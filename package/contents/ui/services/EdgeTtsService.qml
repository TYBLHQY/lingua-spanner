// Edge-TTS Text-to-Speech Service
// Calls the edge-tts CLI via ProcessHelper for async command execution.
// Requires: pip install edge-tts
// GitHub: https://github.com/rany2/edge-tts

import QtQuick
import "../../lib/LinguaSpannerHelper"

QtObject {
    id: root

    // --- public properties (set by main.qml) ---

    /// Internal ProcessHelper for async command execution.
    property ProcessHelper proc: ProcessHelper {}

    /// TTS configuration parameters (from Plasmoid.configuration via main.qml).
    property string voice: "en-US-EmmaMultilingualNeural"
    property string rate: "+0%"
    property string volume: "+0%"
    property string pitch: "+0Hz"

    // --- signals ---

    /// Emitted when synthesis completes successfully.
    /// audioFilePath: absolute path to the generated audio file.
    signal finished(string audioFilePath)

    /// Emitted on any error (command not found, runtime error, etc.)
    signal error(string message)

    // --- internal state ---

    property string _tempFilePath: ""
    property string _text: ""
    property bool _connected: false

    // --- timeout ---

    property Timer _timeoutTimer: Timer {
        interval: 40000
        onTriggered: root._onTimeout()
    }

    // --- public methods ---

    /// Synthesize text into an audio file and signal completion.
    function synthesize(text) {
        if (!text || text.trim().length === 0) {
            root.error(qsTr("No text to synthesize"))
            return
        }
        if (root.proc.busy) {
            root.error(qsTr("TTS is busy"))
            return
        }
        root._ensureConnected()

        root._text = text.trim()
        root._tempFilePath = root.proc.cacheFilePath("tts", ".mp3")
        root._timeoutTimer.start()
        root.proc.runCommand("edge-tts", [
            "--text", root._text,
            "--voice", root.voice,
            "--rate", root.rate,
            "--volume", root.volume,
            "--pitch", root.pitch,
            "--write-media", root._tempFilePath
        ])
    }

    /// Cancel the current TTS command.
    function cancel() {
        root._timeoutTimer.stop()
        root.proc.cancelCommand()
    }

    // --- private ---

    function _ensureConnected() {
        if (root._connected) return
        root.proc.commandFinished.connect(root._onFinished)
        root.proc.commandError.connect(root._onError)
        root._connected = true
    }

    function _onFinished(exitCode, stdOut, stdErr) {
        root._timeoutTimer.stop()
        if (exitCode === 0) {
            root.finished(root._tempFilePath)
        } else {
            // Distinguish "command not found" from other errors
            var lowerErr = (stdErr + " " + stdOut).toLowerCase()
            if (lowerErr.indexOf("not found") >= 0
                || lowerErr.indexOf("command not found") >= 0
                || lowerErr.indexOf("no such file") >= 0) {
                root.error(qsTr("edge-tts not found.\nPlease install: pip install edge-tts"))
            } else {
                root.error(qsTr("Edge-TTS error (exit %1): %2").arg(exitCode).arg(stdErr || stdOut))
            }
        }
    }

    function _onError(errorMessage) {
        root._timeoutTimer.stop()
        // From ProcessHelper: FailedToStart, timed out, or "already running"
        root.error(errorMessage)
    }

    function _onTimeout() {
        root.proc.cancelCommand()
        root.error(qsTr("Edge-TTS timed out (40s)"))
    }
}
