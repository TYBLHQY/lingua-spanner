// ── DeepSeek API Translation Service ───────────────────────
// Calls api.deepseek.com/chat/completions for AI translation

pragma Singleton

import QtQuick

QtObject {
    id: root

    signal finished(var result)
    signal error(string message)

    function translate(text, apiKey, model) {
        if (!text || text.trim().length === 0) {
            error("Empty text")
            return
        }
        if (!apiKey || apiKey.length === 0) {
            error("API key not configured")
            return
        }

        var url = "https://api.deepseek.com/chat/completions"
        var body = JSON.stringify({
            model: model || "deepseek-chat",
            messages: [
                {
                    role: "system",
                    content: "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."
                },
                {
                    role: "user",
                    content: text
                }
            ],
            temperature: 0.3,
            max_tokens: 4096,
            stream: false
        })

        var xhr = new XMLHttpRequest()
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Authorization", "Bearer " + apiKey)
        xhr.setRequestHeader("Accept", "application/json")

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText)
                    var translation = resp.choices && resp.choices[0]
                        ? resp.choices[0].message.content.trim()
                        : ""
                    finished({
                        translation: translation,
                        model: resp.model || model,
                        usage: resp.usage || null
                    })
                } catch (e) {
                    error("Failed to parse DeepSeek response: " + e.message)
                }
            } else if (xhr.status === 401) {
                error("Invalid DeepSeek API key")
            } else if (xhr.status === 429) {
                error("DeepSeek rate limited")
            } else if (xhr.status >= 500) {
                error("DeepSeek server error (HTTP " + xhr.status + ")")
            } else {
                error("DeepSeek returned HTTP " + xhr.status)
            }
        }

        xhr.onerror = function() {
            error("Network error while calling DeepSeek")
        }

        xhr.ontimeout = function() {
            error("DeepSeek request timed out")
        }

        xhr.timeout = 30000
        xhr.send(body)
    }
}
