// ── SiliconFlow API Translation Service ────────────────
// Calls api.siliconflow.cn/v1/chat/completions for AI translation.
// OpenAI-compatible API, supports streaming (SSE) and non-streaming.

import QtQuick

QtObject {
    id: root

    signal finished(var result)
    signal streamingUpdate(string partialText)
    signal error(string message)

    function translate(text, apiKey, model, stream, temperature, maxTokens, topP, sourceLang, targetLang) {
        if (!text || text.trim().length === 0) {
            error("Empty text")
            return
        }
        if (!apiKey || apiKey.length === 0) {
            error("SiliconFlow API key not configured")
            return
        }

        var url = "https://api.siliconflow.cn/v1/chat/completions"

        // Build the prompt with language pair
        var langInfo = ""
        if (sourceLang && sourceLang !== "auto" && sourceLang.length > 0)
            langInfo += " Source language: " + sourceLang + "."
        if (targetLang && targetLang !== "auto" && targetLang.length > 0)
            langInfo += " Target language: " + targetLang + "."
        if (!langInfo)
            langInfo = " Auto-detect source and target language."

        var systemContent = "You are a bilingual translator. Translate the given text and provide lexical analysis. Output ONLY a JSON object following this schema: {\"translate\":\"(str)\",\"source_lang\":\"(str)\",\"target_lang\":\"(str)\",\"words\":[{\"word\":\"(str)\",\"pos\":\"(str)\",\"meaning\":\"(str)\"}],\"frequently\":[{\"phrase\":\"(str)\",\"translation\":\"(str)\"}]}." + langInfo + " POS tags must use lowercase abbreviated forms: v, n, v/n, adj, adv, pron, prep, conj, interj, art, num, det, abbr. Never use full words (verb, noun, etc.), uppercase, or punctuated variants (v., V, Verb, etc.). Use v/n for words serving as both verb and noun, and similarly for other multi-POS combos. Rules: translate is required. For single-word input include words (max 8 meanings) and optionally frequently (max 4 collocations). For sentence input optionally include words (2-5 key vocabulary). Use ISO 639-1 language codes."

        var body = {
            model: model || "deepseek-ai/DeepSeek-V4-Flash",
            messages: [
                { role: "system", content: systemContent },
                { role: "user", content: text }
            ],
            stream: stream ? true : false,
            response_format: { type: "json_object" }
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
                        var result = { translation: accumulated }
                        try {
                            var parsed = JSON.parse(accumulated)
                            for (var k in parsed)
                                result[k] = parsed[k]
                        } catch(e) {
                            console.log("SiliconFlow: failed to parse streamed JSON:", e.message)
                        }
                        finished(result)
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
                        var content = resp.choices && resp.choices[0]
                            ? resp.choices[0].message.content.trim()
                            : ""
                        var result = { translation: content }
                        try {
                            var parsed = JSON.parse(content)
                            for (var k in parsed)
                                result[k] = parsed[k]
                        } catch(e) {
                            console.log("SiliconFlow: failed to parse non-stream JSON:", e.message)
                        }
                        finished(result)
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
