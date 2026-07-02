// ── OpenAI Chat Completions API Translation Service ─────────
// Generic service for any OpenAI-compatible Chat API provider.
// Supports streaming (SSE) and non-streaming modes.
// Set baseUrl and serviceName for each provider.
//
// https://platform.openai.com/docs/api-reference/chat/create

import QtQuick

QtObject {
    id: root

    // ── Provider identity (set by wrappers) ────────────────
    property string baseUrl: ""
    property string serviceName: "OpenAI-compatible API"

    signal finished(var result)
    signal streamingUpdate(string partialText)
    signal error(string message)

    property var _xhr: null
    property bool _aborted: false

    function cancel() {
        root._aborted = true
        if (root._xhr) {
            root._xhr.abort()
            root._xhr = null
        }
    }

    function translate(text, apiKey, model, stream, temperature, maxTokens, topP, sourceLang, targetLang) {
        root._xhr = null
        root._aborted = false
        if (!text || text.trim().length === 0) {
            error("Empty text")
            return
        }
        if (!apiKey || apiKey.length === 0) {
            error(root.serviceName + " API key not configured")
            return
        }
        if (!model) {
            error(root.serviceName + ": model not specified")
            return
        }
        // 源语言和目标语言相同时无需翻译
        if (sourceLang && targetLang && sourceLang !== "auto" && targetLang !== "auto" && sourceLang === targetLang) {
            error("Source and target languages are the same")
            return
        }

        var url = root.baseUrl + "/chat/completions"

        // Build the prompt with language pair
        var langInfo = ""
        if (sourceLang && sourceLang !== "auto" && sourceLang.length > 0)
            langInfo += " Source language: " + sourceLang + "."
        if (targetLang && targetLang !== "auto" && targetLang.length > 0)
            langInfo += " Target language: " + targetLang + "."
        if (!langInfo)
            langInfo = " Auto-detect source and target language."

        var systemContent = "You are a bilingual translator. Translate the given text and provide lexical analysis. Output ONLY a JSON object following this schema: {\"translate\":\"(str)\",\"source_lang\":\"(str)\",\"target_lang\":\"(str)\",\"cleaned_input\":\"(str)\",\"words\":[{\"word\":\"(str)\",\"pos\":\"(str)\",\"meaning\":\"(str)\"}],\"frequently\":[{\"phrase\":\"(str)\",\"translation\":\"(str)\"}]}." + langInfo + " POS tags must use lowercase abbreviated forms: v, n, v/n, adj, adv, pron, prep, conj, interj, art, num, det, abbr. Never use full words (verb, noun, etc.), uppercase, or punctuated variants (v., V, Verb, etc.). Use v/n for words serving as both verb and noun, and similarly for other multi-POS combos. Rules: translate is required. For single-word input include words (max 8 meanings) and optionally frequently (max 4 collocations). For sentence input optionally include words (2-5 key vocabulary). Use ISO 639-1 language codes. cleaned_input: normalize the user's input — trim, collapse multiple spaces/newlines into single space, fix common encoding artifacts. Keep the text readable and faithful to the original."

        var body = {
            model: model,
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
        root._xhr = xhr
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
                    if (root._aborted) return
                    if (xhr.status === 200) {
                        var result = { translation: accumulated }
                        try {
                            var parsed = JSON.parse(accumulated)
                            for (var k in parsed)
                                result[k] = parsed[k]
                        } catch(e) {
                            console.log(root.serviceName + ": failed to parse streamed JSON:", e.message)
                        }
                        finished(result)
                    } else if (xhr.status === 401) {
                        error("Invalid " + root.serviceName + " API key")
                    } else if (xhr.status === 429) {
                        error(root.serviceName + " rate limited")
                    } else if (xhr.status >= 500) {
                        error(root.serviceName + " server error (HTTP " + xhr.status + ")")
                    } else {
                        error(root.serviceName + " returned HTTP " + xhr.status)
                    }
                }
            }
        } else {
            // ── Non-streaming mode ─────────────────────────
            xhr.setRequestHeader("Accept", "application/json")

            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (root._aborted) return

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
                            console.log(root.serviceName + ": failed to parse non-stream JSON:", e.message)
                        }
                        finished(result)
                    } catch (e) {
                        error("Failed to parse " + root.serviceName + " response: " + e.message)
                    }
                } else if (xhr.status === 401) {
                    error("Invalid " + root.serviceName + " API key")
                } else if (xhr.status === 429) {
                    error(root.serviceName + " rate limited")
                } else if (xhr.status >= 500) {
                    error(root.serviceName + " server error (HTTP " + xhr.status + ")")
                } else {
                    error(root.serviceName + " returned HTTP " + xhr.status)
                }
            }
        }

        xhr.onerror = function() {
            if (root._aborted) return
            error("Network error while calling " + root.serviceName)
        }

        xhr.ontimeout = function() {
            if (root._aborted) return
            error(root.serviceName + " request timed out")
        }

        xhr.timeout = 60000
        xhr.send(body)
    }
}
