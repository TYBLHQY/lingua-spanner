// ── Youdao Web New Service ─────────────────────────────────
// Scrapes dict.youdao.com for word definitions
// Reference: youdao-web-new-scraping-rules.md

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

        var url = "https://dict.youdao.com/result?word=" + word + "&lang=en"

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
        // Strip data-v-xxx attributes for easier matching
        html = html.replace(/\sdata-v-\w+=["'][^"']*["']/g, "")

        // Extract exp (definition items)
        var exp = []

        // Try English source: .simple .word-exp
        // <li class="word-exp"><span class="pos">int.</span><span class="trans">释义</span></li>
        var wordExpRegex = /<li[^>]*class="[^"]*\bword-exp\b[^"]*"[^>]*>.*?<span[^>]*class="pos"[^>]*>([\s\S]*?)<\/span>.*?<span[^>]*class="trans"[^>]*>([\s\S]*?)<\/span>[\s\S]*?<\/li>/gi
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

        // If no English results, try Chinese source: .simple .word-exp-ce
        if (exp.length === 0) {
            // <li class="word-exp-ce ..."><span class="col1 index">1</span>...<a class="point">apple</a>...<div class="word-exp_tran">苹果；</div></li>
            var wordExpCeRegex = /<li[^>]*class="[^"]*\bword-exp-ce\b[^"]*"[^>]*>[\s\S]*?<a[^>]*class="point"[^>]*>([\s\S]*?)<\/a>[\s\S]*?<div[^>]*class="word-exp_tran"[^>]*>([\s\S]*?)<\/div>/gi

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

        // Fallback: .fanyi .trans-content
        if (exp.length === 0) {
            var fanyiRegex = /<div[^>]*class="fanyi"[^>]*>[\s\S]*?<div[^>]*class="trans-content"[^>]*>([\s\S]*?)<\/div>/i
            var fanyiMatch = fanyiRegex.exec(html)
            if (fanyiMatch) {
                var fanyiText = fanyiMatch[1].trim()
                exp.push({ po: "", tr: [fanyiText] })
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
