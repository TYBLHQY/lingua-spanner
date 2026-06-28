// ── SiliconFlow API Translation Service ────────────────
// Calls api.siliconflow.cn/v1/chat/completions for AI translation.
// OpenAI-compatible API, supports streaming (SSE) and non-streaming.

import QtQuick

QtObject {
    id: root

    signal finished(var result)
    signal streamingUpdate(string partialText)
    signal error(string message)

    function translate(text, apiKey, model, systemPrompt, temperature, maxTokens, topP, stream) {
        if (!text || text.trim().length === 0) {
            error("Empty text")
            return
        }
        if (!apiKey || apiKey.length === 0) {
            error("SiliconFlow API key not configured")
            return
        }

        var url = "https://api.siliconflow.cn/v1/chat/completions"

        var systemContent = systemPrompt && systemPrompt.trim().length > 0
            ? systemPrompt.trim()
            : "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."

        var body = {
            model: model || "deepseek-ai/DeepSeek-V4-Flash",
            messages: [
                { role: "system", content: systemContent },
                { role: "user", content: text }
            ],
            stream: stream ? true : false
        }

        if (temperature !== undefined && temperature !== null && temperature >= 0 && temperature <= 2)
            body.temperature = temperature
        if (maxTokens !== undefined && maxTokens !== null && maxTokens >= 1)
            body.max_tokens = maxTokens
        if (topP !== undefined && topP !== null && topP > 0 && topP <= 1)
            body.top_p = topP

        body = JSON.stringify(body)

        var xhr = new XMLHttpRequest()
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Authorization", "Bearer " + apiKey)

        if (stream) {
            // ── Streaming mode (SSE) ──────────────────────
            xhr.setRequestHeader("Accept", "text/event-stream")

            var accumulated = ""
            var lineBuffer = ""
            var lastParsedLen = 0

            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.LOADING
                        || xhr.readyState === XMLHttpRequest.DONE) {

                    var newData = xhr.responseText.substring(lastParsedLen)
                    lastParsedLen = xhr.responseText.length

                    lineBuffer += newData
                    var lines = lineBuffer.split('\n')
                    lineBuffer = lines.pop() || ""

                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim()
                        if (!line) continue

                        if (line.indexOf("data: [DONE]") === 0) continue

                        if (line.indexOf("data: ") === 0) {
                            var jsonStr = line.substring(6).trim()
                            if (jsonStr.length === 0) continue

                            try {
                                var chunk = JSON.parse(jsonStr)
                                var choice = chunk.choices && chunk.choices[0]
                                if (choice) {
                                    if (choice.delta && choice.delta.content) {
                                        accumulated += choice.delta.content
                                        streamingUpdate(accumulated)
                                    }
                                    if (choice.finish_reason) continue
                                }
                            } catch (e) { }
                        }
                    }
                }

                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        finished({
                            translation: accumulated,
                            model: model,
                            usage: null
                        })
                    } else if (xhr.status === 401) {
                        error("Invalid SiliconFlow API key")
                    } else if (xhr.status === 429) {
                        error("SiliconFlow rate limited")
                    } else if (xhr.status >= 500) {
                        error("SiliconFlow server error (HTTP " + xhr.status + ")")
                    } else {
                        error("SiliconFlow returned HTTP " + xhr.status)
                    }
                }
            }
        } else {
            // ── Non-streaming mode ─────────────────────────
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
                        error("Failed to parse SiliconFlow response: " + e.message)
                    }
                } else if (xhr.status === 401) {
                    error("Invalid SiliconFlow API key")
                } else if (xhr.status === 429) {
                    error("SiliconFlow rate limited")
                } else if (xhr.status >= 500) {
                    error("SiliconFlow server error (HTTP " + xhr.status + ")")
                } else {
                    error("SiliconFlow returned HTTP " + xhr.status)
                }
            }
        }

        xhr.onerror = function() {
            error("Network error while calling SiliconFlow")
        }

        xhr.ontimeout = function() {
            error("SiliconFlow request timed out")
        }

        xhr.timeout = 60000
        xhr.send(body)
    }
}
