// ── Youdao Web New Service ─────────────────────────────────
// Scrapes dict.youdao.com for word definitions
// Reference: youdao-web-new-scraping-rules.md

import QtQuick

QtObject {
    id: root

    signal finished(var result)
    signal error(string message)

    function preprocessWord(raw) {
        // Strip trailing single punctuation characters that may be attached
        // from sentence-ending text (e.g. "totality," → "totality", "philosophy." → "philosophy")
        var s = raw.trim()
        var trailingPunct = /[.,/?。，？;；'‘’"“”]/g
        while (trailingPunct.test(s.slice(-1))) {
            s = s.slice(0, -1)
        }
        return s
    }

    function fetch(word) {
        if (!word || word.trim().length === 0) {
            error("Empty word")
            return
        }

        word = preprocessWord(word)

        var url = "https://dict.youdao.com/result?word=" + encodeURIComponent(word) + "&lang=en"

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Accept", "text/html,application/xhtml+xml")
        xhr.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 200) {
                var result = parseHTML(xhr.responseText, word)
                finished(result)
            } else {
                error("Youdao returned HTTP " + xhr.status)
            }
        }

        xhr.onerror = function() {
            error("Network error while fetching youdao")
        }

        xhr.ontimeout = function() {
            error("Youdao request timed out")
        }

        xhr.timeout = 10000
        xhr.send()
    }

    function parseHTML(html, word) {
        // Strip Vue scoped-style data-v-xxx attributes
        // Bare Vue attributes: data-v-xxxxx (no =value)
        html = html.replace(/\sdata-v-[a-f0-9]+/g, "")
        // Also strip data-v-xxx="..." format
        html = html.replace(/\sdata-v-\w+="[^"]*"/g, "")
        // Normalize <section> to <div>
        html = html.replace(/<section/g, "<div").replace(/<\/section>/g, "</div>")

        // Extract .modules content
        var modStart = html.indexOf('<div class="modules">')
        if (modStart < 0) return { word: word, exp: [], examType: [], audio: [], form: [] }
        modStart += '<div class="modules">'.length

        // Track nesting depth to find matching closing </div>
        var depth = 1, i = modStart
        while (depth > 0 && i < html.length) {
            if (html.substr(i, 4) === '<div' && html.substr(i, 5) !== '</div') {
                var closeTag = html.indexOf('>', i)
                if (closeTag > 0 && html[closeTag - 1] !== '/') depth++
            } else if (html.substr(i, 6) === '</div>') {
                depth--
            }
            i++
        }
        var mod = html.substring(modStart, depth === 0 ? i - 6 : undefined)

        // Extract exp (definition items)
        var exp = []
        var seen = {}

        // Try English source: .word-exp
        var wordExpRegex = /<li[^>]*word-exp[^>]*>.*?class="pos"[^>]*>([\s\S]*?)<\/span>.*?class="trans"[^>]*>([\s\S]*?)<\/span>/gi
        var match
        var seen = {} // dedup

        while ((match = wordExpRegex.exec(html)) !== null) {
            var po = match[1].trim()
            var trRaw = match[2].trim()
            // Replace <> with fullwidth
            trRaw = trRaw.replace(/</g, "〈").replace(/>/g, "〉")

            // Handle 【名】 prefix
            if (trRaw.indexOf("【名】") === 0) { // 【名】
                po = "名"
                trRaw = trRaw.substring(3)
            }

            var tr = trRaw.split(/[；;]/).map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
            if (po.length > 0 && tr.length > 0) {
                var key = po + "|" + tr.join(";")
                if (!seen[key]) {
                    seen[key] = true
                    exp.push({ po: po, tr: tr })
                }
            }
        }

        // If no English results, try Chinese source: .word-exp-ce
        if (exp.length === 0) {
            var wordExpCeRegex = /<li[^>]*word-exp-ce[^>]*>.*?class="point"[^>]*>([\s\S]*?)<\/a>.*?class="word-exp_tran[^"]*"[^>]*>([\s\S]*?)<\/div>/gi

            while ((match = wordExpCeRegex.exec(html)) !== null) {
                po = match[1].trim()
                trRaw = match[2].trim()
                // Remove trailing ；;
                trRaw = trRaw.replace(/[；;]\s*$/, "")
                tr = trRaw.split(/[；;]/).map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
                if (tr.length > 0) {
                    var key2 = po + "|" + tr.join(";")
                    if (!seen[key2]) {
                        seen[key2] = true
                        exp.push({ po: po, tr: tr })
                    }
                }
            }
        }

        // Chinese word-exp-ce fallback: point without word-exp_tran
        if (exp.length === 0) {
            var ceFallbackRegex = /<li[^>]*word-exp-ce[^>]*>.*?class="point"[^>]*>([\s\S]*?)<\/a>/gi
            while ((match = ceFallbackRegex.exec(html)) !== null) {
                var pointText = match[1].trim()
                if (pointText.length > 0 && !seen[pointText]) {
                    seen[pointText] = true
                    exp.push({ po: "", tr: [pointText] })
                }
            }
        }

        // Fallback: .trans-content (machine translation)
        if (exp.length === 0) {
            var fanyiMatch = html.match(/class="trans-content"[^>]*>([\s\S]*?)<\/div>/i)
            if (fanyiMatch) {
                var fanyiText = fanyiMatch[1].replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim()
                // Remove garbage suffix: 以上为机器翻译结果...
                fanyiText = fanyiText.replace(/以上为机器翻译结果.*$/, "").trim()
                if (fanyiText.length > 0) {
                    exp.push({ po: "", tr: [fanyiText] })
                }
            }
        }

        // Extract examType
        var examTypes = []
        var examRegex = /<span[^>]*class="exam_type-value"[^>]*>([\s\S]*?)<\/span>/gi
        while ((match = examRegex.exec(html)) !== null) {
            examTypes.push(match[1].trim())
        }

        // Extract audio
        var audio = []
        // Look for .per-phone blocks
        var perPhoneRegex = /<div[^>]*class="per-phone"[^>]*>[\s\S]*?<span[^>]*class="phonetic"[^>]*>([\s\S]*?)<\/span>/gi
        var phoneIdx = 0
        while ((match = perPhoneRegex.exec(html)) !== null) {
            var phonetic = match[1].trim()
            var type = phoneIdx === 0 ? 1 : 2 // 1=uk, 2=us
            audio.push({
                text: phonetic,
                url: "https://dict.youdao.com/dictvoice?audio=" + encodeURIComponent(word) + "&type=" + type
            })
            phoneIdx++
        }

        // Extract word forms
        var forms = []
        var formRegex = /<li[^>]*class="word-wfs-cell-less"[^>]*>[\s\S]*?<span[^>]*class="wfs-name"[^>]*>([\s\S]*?)<\/span>[\s\S]*?<span[^>]*class="transformation"[^>]*>([\s\S]*?)<\/span>/gi
        while ((match = formRegex.exec(html)) !== null) {
            forms.push({
                type: match[1].trim(),
                form: match[2].trim()
            })
        }

        return {
            word: word,
            exp: exp,
            examType: examTypes,
            audio: audio,
            form: forms
        }
    }
}
