// ── Free Dictionary API Service ─────────────────────────────
// Calls https://api.dictionaryapi.dev/api/v2/entries/en/<word>
// Provides English dictionary definitions (no API key needed)

import QtQuick

QtObject {
    id: root

    signal finished(var result)
    signal error(string message)

    function fetch(word) {
        if (!word || word.trim().length === 0) {
            error("Empty word")
            return
        }

        var url = "https://api.dictionaryapi.dev/api/v2/entries/en/" + encodeURIComponent(word)

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Accept", "application/json")

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 200) {
                var result = parseResponse(xhr.responseText, word)
                finished(result)
            } else if (xhr.status === 404) {
                // Word not found — try to extract the API error message
                var msg = "Word not found in dictionary"
                try {
                    var errResp = JSON.parse(xhr.responseText)
                    if (errResp.message) msg = errResp.message
                } catch (_) {}
                finished({ word: word, exp: [], audio: [], phonetic: "", origin: "", error: msg })
            } else if (xhr.status >= 500) {
                error("Dictionary API server error (HTTP " + xhr.status + ")")
            } else {
                error("Dictionary API returned HTTP " + xhr.status)
            }
        }

        xhr.onerror = function() {
            error("Network error while calling Dictionary API")
        }

        xhr.ontimeout = function() {
            error("Dictionary API request timed out")
        }

        xhr.timeout = 10000
        xhr.send()
    }

    function parseResponse(responseText, word) {
        var data
        try {
            data = JSON.parse(responseText)
        } catch (e) {
            return { word: word, exp: [], audio: [], phonetic: "", origin: "", error: "Failed to parse response" }
        }

        if (!data || data.length === 0) {
            return { word: word, exp: [], audio: [], phonetic: "", origin: "", error: "No definitions found" }
        }

        var entry = data[0]

        // ── Build exp (definitions grouped by part of speech) ──
        var exp = []
        var meanings = entry.meanings || []
        for (var m = 0; m < meanings.length; m++) {
            var meaning = meanings[m]
            var tr = []
            var definitions = meaning.definitions || []
            for (var d = 0; d < definitions.length; d++) {
                var defText = definitions[d].definition || ""
                var example = definitions[d].example || ""
                // Append example in dimmed parentheses if available
                if (example.length > 0) {
                    defText += "（" + example + "）"
                }
                if (defText.length > 0) {
                    tr.push(defText)
                }
            }
            exp.push({
                po: meaning.partOfSpeech || "",
                tr: tr
            })
        }

        // ── Build audio ────────────────────────────────────────
        var audio = []
        var phonetics = entry.phonetics || []
        // Dedup by URL
        var seenUrls = {}
        for (var p = 0; p < phonetics.length; p++) {
            var audioUrl = phonetics[p].audio || ""
            if (audioUrl.length === 0) continue
            // Resolve protocol-relative URLs
            if (audioUrl.indexOf("//") === 0) {
                audioUrl = "https:" + audioUrl
            }
            if (seenUrls[audioUrl]) continue
            seenUrls[audioUrl] = true
            audio.push({
                text: phonetics[p].text || "",
                url: audioUrl
            })
        }

        // ── Phonetic text ──────────────────────────────────
        var phonetic = ""
        if (entry.phonetic) {
            phonetic = entry.phonetic
        }
        // Prefer a text from phonetics array
        for (p = 0; p < phonetics.length; p++) {
            if (phonetics[p].text && phonetics[p].text.length > 0) {
                phonetic = phonetics[p].text
                break
            }
        }

        return {
            word: entry.word || word,
            exp: exp,
            audio: audio,
            phonetic: phonetic,
            origin: entry.origin || "",
            examType: [],
            form: [],
            error: ""
        }
    }
}
