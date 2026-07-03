// Edge TTS Service
// Uses Microsoft Edge TTS online API (free, no key required).
// Synthesizes speech via Edge's trusted-client endpoint and plays
// the returned MP3 audio through QtMultimedia.
//
// API reference: https://github.com/rany2/edge-tts

import QtQuick
import QtMultimedia

TtsBase {
    providerName: "Edge TTS"

    // Internal audio player
    property MediaPlayer _player: MediaPlayer {
        audioOutput: AudioOutput {}
        onErrorOccurred: console.log("EdgeTts audio error:", error, errorString)
    }

    // Internal XHR for fetching audio
    property var _xhr: null
    property bool _aborted: false

    // Build SSML from plain text, voice, and speed
    function _buildSsml(text, voice, speed) {
        var v = voice && voice.length > 0 ? voice : "zh-CN-XiaoxiaoNeural"
        var r = speed !== undefined && speed !== null ? speed : 1.0
        var rate = Math.round((r - 1.0) * 100)
        var rateStr = (rate >= 0 ? "+" : "") + rate + "%"
        var escaped = text
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
        return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN">'
            + '<voice name="' + v + '">'
            + '<prosody rate="' + rateStr + '">'
            + escaped
            + '</prosody></voice></speak>'
    }

    function speak(text, voice, speed) {
        if (!text || text.trim().length === 0) {
            error("Empty text")
            return
        }

        _aborted = false
        var ssml = _buildSsml(text, voice, speed)

        // Trusted client token used by Edge browser's read-aloud feature
        var trustedToken = "6A5AA1D4EAFF4E9FB37E23D273B751D4"

        var xhr = new XMLHttpRequest()
        _xhr = xhr
        xhr.open("POST", "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=" + trustedToken)
        xhr.setRequestHeader("Content-Type", "application/ssml+xml")
        xhr.setRequestHeader("X-Microsoft-OutputFormat", "audio-24khz-160kbitrate-mono-mp3")
        xhr.responseType = "arraybuffer"

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (_aborted) return

            if (xhr.status === 200) {
                var bytes = new Uint8Array(xhr.response)
                if (bytes && bytes.byteLength > 0) {
                    _player.source = "data:audio/mp3;base64," + _arrayBufferToBase64(bytes)
                    _player.play()
                } else {
                    error("Empty audio response from Edge TTS")
                    return
                }
            } else {
                error("Edge TTS returned HTTP " + xhr.status
                    + ". This service may require the edge-tts command-line tool. "
                    + "See https://github.com/rany2/edge-tts")
                return
            }

            // Hook playback state change — emit finished when stopped
            _player.onPlaybackStateChanged = function(state) {
                if (state === MediaPlayer.StoppedState) {
                    root.finished()
                }
            }
        }

        xhr.onerror = function() {
            if (!_aborted) error("Network error calling Edge TTS")
        }

        xhr.ontimeout = function() {
            if (!_aborted) error("Edge TTS request timed out")
        }

        xhr.timeout = 15000
        xhr.send(ssml)
    }

    function stop() {
        _aborted = true
        if (_xhr) {
            _xhr.abort()
            _xhr = null
        }
        _player.stop()
        _player.source = ""
    }

    // Convert ArrayBuffer to base64 data URI for MediaPlayer
    function _arrayBufferToBase64(buffer) {
        var bytes = new Uint8Array(buffer)
        var binary = ""
        for (var i = 0; i < bytes.byteLength; i++) {
            binary += String.fromCharCode(bytes[i])
        }
        return btoa(binary)
    }
}
