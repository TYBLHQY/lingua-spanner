// ── Lingua Spanner Diagnostic ──────────────────────────────
// Run: qml6 -I ../package/contents/lib diagnostic.qml
// Tests: ProcessHelper (xclip), Youdao, DeepSeek

import QtQuick
import QtQuick.Window
import QtQuick.Controls

import "../package/contents/lib/LinguaSpannerHelper"

Window {
    width: 600; height: 400
    visible: true
    title: "Lingua Spanner Diagnostic"

    // Creaate once, use everywhere
    readonly property ProcessHelper proc: ProcessHelper {}

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Label { text: "Lingua Spanner Diagnostic"; font.bold: true; font.pixelSize: 18 }

        // ── ProcessHelper test ────────────────────────────
        Rectangle { width: parent.width; height: 1; color: "#ccc" }
        Label { text: "1. ProcessHelper (xclip)"; font.bold: true }

        Label { id: primaryLabel; text: "PRIMARY: —"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }
        Label { id: clipboardLabel; text: "CLIPBOARD: —"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }

        Button {
            text: "Read PRIMARY selection"
            onClicked: {
                var text = proc.readProcessOutput("xclip", ["-o", "-selection", "primary"])
                primaryLabel.text = text.length > 0
                    ? "PRIMARY: \"" + text + "\""
                    : "PRIMARY: (empty)"
                primaryLabel.color = text.length > 0 ? "green" : "red"
            }
        }

        Button {
            text: "Read CLIPBOARD"
            onClicked: {
                var text = proc.readProcessOutput("xclip", ["-o", "-selection", "clipboard"])
                clipboardLabel.text = text.length > 0
                    ? "CLIPBOARD: \"" + text + "\""
                    : "CLIPBOARD: (empty)"
                clipboardLabel.color = text.length > 0 ? "green" : "red"
            }
        }

        // ── Plasmoid flow simulation ──────────────────────
        Rectangle { width: parent.width; height: 1; color: "#ccc" }
        Label { text: "2. Simulate Plasmoid Flow"; font.bold: true }
        Label { id: flowLabel; text: "Click to simulate"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }

        Button {
            text: "Simulate: pick + translate"
            onClicked: {
                var picked = proc.readProcessOutput("xclip", ["-o", "-selection", "primary"])
                if (!picked || picked.trim().length === 0) {
                    picked = proc.readProcessOutput("xclip", ["-o", "-selection", "clipboard"])
                }
                if (picked && picked.trim().length > 0) {
                    flowLabel.text = "✅ Picked: \"" + picked + "\""
                    flowLabel.color = "green"
                    flowLabel.text += "\n→ Would translate: \"" + picked.trim() + "\""
                } else {
                    flowLabel.text = "❌ No selection found"
                    flowLabel.color = "red"
                    flowLabel.text += "\n→ Select text in another window first"
                }
            }
        }

        // ── Youdao test ───────────────────────────────────
        Rectangle { width: parent.width; height: 1; color: "#ccc" }
        Label { text: "3. Youdao Web Scraping"; font.bold: true }
        Label { id: youdaoLabel; text: "not tested"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }

        Button {
            text: "Test Youdao (hello)"
            onClicked: {
                youdaoLabel.text = "Fetching…"
                var xhr = new XMLHttpRequest()
                xhr.open("GET", "https://dict.youdao.com/result?word=hello&lang=en")
                xhr.setRequestHeader("Accept", "text/html")
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE) return
                    if (xhr.status === 200) {
                        youdaoLabel.text = "✅ HTTP 200, " + xhr.responseText.length + " bytes"
                        youdaoLabel.color = "green"
                    } else {
                        youdaoLabel.text = "❌ HTTP " + xhr.status
                        youdaoLabel.color = "red"
                    }
                }
                xhr.timeout = 10000
                xhr.send()
            }
        }

        // ── DeepSeek test ─────────────────────────────────
        Rectangle { width: parent.width; height: 1; color: "#ccc" }
        Label { text: "4. DeepSeek API"; font.bold: true }
        Label { id: dsLabel; text: "Need API key configured"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }
        TextField { id: apiKeyInput; placeholderText: "Paste DeepSeek API key here"; width: parent.width }

        Button {
            text: "Test DeepSeek"
            onClicked: {
                var key = apiKeyInput.text.trim()
                if (!key) { dsLabel.text = "❌ No API key"; dsLabel.color = "red"; return }
                dsLabel.text = "Calling DeepSeek…"
                var xhr = new XMLHttpRequest()
                xhr.open("POST", "https://api.deepseek.com/chat/completions")
                xhr.setRequestHeader("Content-Type", "application/json")
                xhr.setRequestHeader("Authorization", "Bearer " + key)
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE) return
                    if (xhr.status === 200) {
                        dsLabel.text = "✅ DeepSeek response received"
                        dsLabel.color = "green"
                    } else {
                        dsLabel.text = "❌ HTTP " + xhr.status
                        dsLabel.color = "red"
                    }
                }
                xhr.timeout = 15000
                xhr.send(JSON.stringify({
                    model: "deepseek-chat",
                    messages: [
                        { role: "system", content: "Translate to Chinese." },
                        { role: "user", content: "Hello, world!" }
                    ],
                    temperature: 0.3,
                    max_tokens: 100
                }))
            }
        }

        Item { height: 20 }
        Label { text: "Tip: Select text in another window, then click 'Read PRIMARY'"; color: "gray"; font.italic: true; wrapMode: Text.WordWrap; width: parent.width }
    }
}