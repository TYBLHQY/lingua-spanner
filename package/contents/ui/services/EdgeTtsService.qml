// Edge-TTS Text-to-Speech Service
// Calls the edge-tts CLI via ProcessHelper for async command execution.
// Caches generated audio by text+voice hash to avoid repeated synthesis.
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

    /// Path to the edge-tts binary.
    /// Empty string (default) = search via PATH.
    property string binaryPath: ""

    // --- signals ---

    /// Emitted when synthesis completes successfully.
    /// audioFilePath: absolute path to the generated audio file.
    signal finished(string audioFilePath)

    /// Emitted on any error (command not found, runtime error, etc.)
    signal error(string message)

    // --- internal state ---

    property string _text: ""
    property bool _connected: false

    // --- cache ---

    /// Shared TTS cache directory.
    readonly property string _cacheDir: root.proc.cacheDir("ttscache")

    /// Maximum cached audio files.
    readonly property int _maxCacheFiles: 100

    property Timer _timeoutTimer: Timer {
        interval: 40000
        onTriggered: root._onTimeout()
    }

    /// DJB2 hash of the TTS arguments for cache key.
    function _hashString(str) {
        var hash = 5381
        for (var i = 0; i < str.length; i++)
            hash = ((hash << 5) + hash) + str.charCodeAt(i)
        return (hash >>> 0).toString(16)
    }

    function _cacheKey(text) {
        var raw = text.trim() + "|" + root.voice + "|" + root.rate + "|" + root.volume + "|" + root.pitch
        return "tts_" + root._hashString(raw) + ".mp3"
    }

    function _cachePath(text) {
        return root._cacheDir + "/" + root._cacheKey(text)
    }

    // --- public methods ---

    /// Resolve the edge-tts binary. Returns the configured path or falls back to "edge-tts".
    function _getEdgeTtsBin() {
        return root.binaryPath.length > 0 ? root.binaryPath : "edge-tts"
    }

    /// Synthesize text into an audio file and signal completion.
    /// Returns cached audio immediately if available.
    function synthesize(text) {
        if (!text || text.trim().length === 0) {
            root.error(qsTr("No text to synthesize"))
            return
        }
        root._ensureConnected()

        var cachePath = root._cachePath(text)
        if (root.proc.fileExists(cachePath)) {
            // Cache hit — emit immediately
            root.finished(cachePath)
            return
        }

        root._text = text.trim()
        root._timeoutTimer.start()
        root.proc.runCommand(root._getEdgeTtsBin(), [
            "--text", root._text,
            "--voice", root.voice,
            "--rate", root.rate,
            "--volume", root.volume,
            "--pitch", root.pitch,
            "--write-media", cachePath
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
            // Trim cache on each new addition so we never exceed the limit.
            root.proc.cleanTtsCache(root._cacheDir, root._maxCacheFiles)
            root.finished(root._cachePath(root._text))
        } else {
            // Synthesis failed — remove the partial/corrupt cache file
            var badPath = root._cachePath(root._text)
            if (root.proc.fileExists(badPath))
                root.proc.removeFile(badPath)

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
        root.error(errorMessage)
    }

    function _onTimeout() {
        root.proc.cancelCommand()
        // Remove the partial cache file on timeout
        var badPath = root._cachePath(root._text)
        if (root.proc.fileExists(badPath))
            root.proc.removeFile(badPath)
        root.error(qsTr("Edge-TTS timed out (40s)"))
    }
}
