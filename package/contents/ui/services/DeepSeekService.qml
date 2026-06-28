// ── DeepSeek API Translation Service ───────────────────────
// Calls api.deepseek.com/chat/completions for AI translation.
// Supports both streaming (SSE) and non-streaming modes.

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
            error("API key not configured")
            return
        }

        var url = "https://api.deepseek.com/chat/completions"

        var systemContent = systemPrompt && systemPrompt.trim().length > 0
            ? systemPrompt.trim()
            : "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."

        var body = {
            model: model || "deepseek-v4-flash",
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
            var streamFinished = false

            xhr.onreadystatechange = function() {
                // Process incremental data on LOADING (3) and finalize on DONE (4)
                if (xhr.readyState === XMLHttpRequest.LOADING
                        || xhr.readyState === XMLHttpRequest.DONE) {

                    // Get only the new portion of responseText
                    var newData = xhr.responseText.substring(lastParsedLen)
                    lastParsedLen = xhr.responseText.length

                    // SSE line parsing with partial-line buffer
                    lineBuffer += newData
                    var lines = lineBuffer.split('\n')
                    lineBuffer = lines.pop() || "" // keep incomplete tail

                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim()
                        if (!line) continue

                        if (line.indexOf("data: [DONE]") === 0) {
                            streamFinished = true
                            continue
                        }

                        if (line.indexOf("data: ") === 0) {
                            var jsonStr = line.substring(6).trim()
                            if (jsonStr.length === 0) continue

                            try {
                                var chunk = JSON.parse(jsonStr)
                                var choice = chunk.choices && chunk.choices[0]
                                if (choice) {
                                    // Accumulate content delta
                                    if (choice.delta && choice.delta.content) {
                                        accumulated += choice.delta.content
                                        streamingUpdate(accumulated)
                                    }
                                    // Check for stream end
                                    if (choice.finish_reason) {
                                        streamFinished = true
                                    }
                                }
                            } catch (e) {
                                // Partial JSON line — skip, accumulate on next chunk
                            }
                        }
                    }
                }

                // Finalize on DONE
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        finished({
                            translation: accumulated,
                            model: model,
                            usage: null
                        })
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
        }

        xhr.onerror = function() {
            error("Network error while calling DeepSeek")
        }

        xhr.ontimeout = function() {
            error("DeepSeek request timed out")
        }

        xhr.timeout = 60000
        xhr.send(body)
    }
}
