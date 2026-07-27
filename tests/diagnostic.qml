// Lingua Spanner Diagnostic
// Run: qml6 -I ../package/contents/lib diagnostic.qml
// Tests: ProcessHelper (QClipboard), Youdao

import QtQuick
import QtQuick.Window
import QtQuick.Controls

import "../package/contents/lib/LinguaSpannerHelper"

Window {
    width: 600; height: 400
    visible: true
    title: "Lingua Spanner Diagnostic"

    // Create once, use everywhere
    readonly property ProcessHelper proc: ProcessHelper {}

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Label { text: "Lingua Spanner Diagnostic"; font.bold: true; font.pixelSize: 18 }

        // ProcessHelper test
        Rectangle { width: parent.width; height: 1; color: "#ccc" }
        Label { text: "1. ProcessHelper (QClipboard PRIMARY)"; font.bold: true }

        Label { id: primaryLabel; text: "PRIMARY: —"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }

        Button {
            text: "Read PRIMARY selection"
            onClicked: {
                var text = proc.readPrimarySelection()
                primaryLabel.text = text.length > 0
                    ? "PRIMARY: \"" + text + "\""
                    : "PRIMARY: (empty)"
                primaryLabel.color = text.length > 0 ? "green" : "red"
            }
        }

        // Plasmoid flow simulation
        Rectangle { width: parent.width; height: 1; color: "#ccc" }
        Label { text: "2. Simulate Plasmoid Flow"; font.bold: true }
        Label { id: flowLabel; text: "Click to simulate"; color: "gray"; wrapMode: Text.WordWrap; width: parent.width }

        Button {
            text: "Simulate: pick + look up"
            onClicked: {
                var picked = proc.readPrimarySelection()
                if (picked && picked.trim().length > 0) {
                    flowLabel.text = "✅ Picked: \"" + picked + "\""
                    flowLabel.color = "green"
                    flowLabel.text += "\n→ Would look up: \"" + picked.trim() + "\""
                } else {
                    flowLabel.text = "❌ No selection found"
                    flowLabel.color = "red"
                    flowLabel.text += "\n→ Select text in another window first"
                }
            }
        }

        // Youdao test
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

        Item { height: 20 }
        Label { text: "Tip: Select text in another window, then click 'Read PRIMARY'"; color: "gray"; font.italic: true; wrapMode: Text.WordWrap; width: parent.width }
    }
}
