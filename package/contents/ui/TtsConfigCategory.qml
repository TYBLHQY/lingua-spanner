// TTS Engine Configuration — Edge-TTS
// Per-language voice selection with list caching.
// Requires: pip install edge-tts
// https://github.com/rany2/edge-tts

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

import "../lib/LinguaSpannerHelper"

KCMUtils.SimpleKCM {
    id: page

    // KConfig XT bindings — Edge-TTS common settings
    property string cfg_edgeTtsRate: "+0%"
    property string cfg_edgeTtsRateDefault: "+0%"
    property string cfg_edgeTtsVolume: "+0%"
    property string cfg_edgeTtsVolumeDefault: "+0%"
    property string cfg_edgeTtsPitch: "+0Hz"
    property string cfg_edgeTtsPitchDefault: "+0Hz"

    // KConfig XT bindings — per-language voice selection
    property string cfg_edgeTtsVoiceZh: "zh-CN-XiaoxiaoNeural"
    property string cfg_edgeTtsVoiceZhDefault: "zh-CN-XiaoxiaoNeural"
    property string cfg_edgeTtsVoiceEn: "en-US-EmmaMultilingualNeural"
    property string cfg_edgeTtsVoiceEnDefault: "en-US-EmmaMultilingualNeural"
    property string cfg_edgeTtsVoiceDe: "de-DE-KatjaNeural"
    property string cfg_edgeTtsVoiceDeDefault: "de-DE-KatjaNeural"
    property string cfg_edgeTtsVoiceJa: "ja-JP-NanamiNeural"
    property string cfg_edgeTtsVoiceJaDefault: "ja-JP-NanamiNeural"
    property string cfg_edgeTtsVoiceFr: "fr-FR-DeniseNeural"
    property string cfg_edgeTtsVoiceFrDefault: "fr-FR-DeniseNeural"
    property string cfg_edgeTtsVoiceEs: "es-ES-ElviraNeural"
    property string cfg_edgeTtsVoiceEsDefault: "es-ES-ElviraNeural"

    // KConfig XT bindings — cached voice lists (JSON object, keyed by language prefix)
    property string cfg_edgeTtsVoiceLists: "{}"
    property string cfg_edgeTtsVoiceListsDefault: "{}"

    ProcessHelper { id: _procHelper }

    property bool _fetchingVoices: false

    // Language metadata
    readonly property var _langMeta: [
        { id: "zh", label: i18n("简体中文"), prefix: "zh-" },
        { id: "en", label: i18n("English"),  prefix: "en-" },
        { id: "de", label: i18n("Deutsch"),  prefix: "de-" },
        { id: "ja", label: i18n("日本語"),   prefix: "ja-" },
        { id: "fr", label: i18n("Français"),  prefix: "fr-" },
        { id: "es", label: i18n("Español"),   prefix: "es-" }
    ]

    // Restore cached voice lists on load
    function _restoreVoiceLists() {
        var raw = page.cfg_edgeTtsVoiceLists
        if (!raw || raw === "{}") return false
        try {
            var lists = JSON.parse(raw)
            if (typeof lists !== "object") return false
            for (var i = 0; i < page._langMeta.length; i++) {
                var lang = page._langMeta[i]
                var key = lang.id
                var list = lists[key]
                if (Array.isArray(list) && list.length > 0)
                    page._setComboModel(key, list)
            }
            return true
        } catch(e) { return false }
    }

    // Helper to set a combo's model by language id, preserving the user's configured value
    function _setComboModel(langId, voices) {
        var combo = page._getCombo(langId)
        if (!combo) return
        var saved = page._getConfigProp(langId)
        combo.model = voices
        var idx = combo.find(saved)
        if (idx >= 0) combo.currentIndex = idx
        else combo.editText = saved
    }

    function _getCombo(langId) {
        if (langId === "zh") return zhVoiceCombo
        if (langId === "en") return enVoiceCombo
        if (langId === "de") return deVoiceCombo
        if (langId === "ja") return jaVoiceCombo
        if (langId === "fr") return frVoiceCombo
        if (langId === "es") return esVoiceCombo
        return null
    }

    function _getConfigProp(langId) {
        if (langId === "zh") return page.cfg_edgeTtsVoiceZh
        if (langId === "en") return page.cfg_edgeTtsVoiceEn
        if (langId === "de") return page.cfg_edgeTtsVoiceDe
        if (langId === "ja") return page.cfg_edgeTtsVoiceJa
        if (langId === "fr") return page.cfg_edgeTtsVoiceFr
        if (langId === "es") return page.cfg_edgeTtsVoiceEs
        return ""
    }

    // Parse edge-tts --list-voices output, group by language, populate combos, cache result
    function _parseVoiceList(exitCode, stdOut, stdErr) {
        _fetchingVoices = false
        if (exitCode !== 0) return

        var allVoices = []
        var lines = stdOut.split('\n')
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)
            var name = parts.length > 0 ? parts[0] : ""
            if (name.length > 0 && name !== "Name" && name.indexOf("-") >= 0)
                allVoices.push(name)
        }
        if (allVoices.length === 0) return

        // Group by language prefix
        var lists = {}
        for (var j = 0; j < page._langMeta.length; j++) {
            var prefix = page._langMeta[j].prefix
            var filtered = []
            for (var k = 0; k < allVoices.length; k++) {
                if (allVoices[k].indexOf(prefix) === 0)
                    filtered.push(allVoices[k])
            }
            if (filtered.length > 0)
                lists[page._langMeta[j].id] = filtered
        }

        // Populate combos
        for (var lid in lists) {
            if (lists.hasOwnProperty(lid))
                page._setComboModel(lid, lists[lid])
        }

        // Cache to config
        page.cfg_edgeTtsVoiceLists = JSON.stringify(lists)
    }

    // UI
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Layout.fillWidth: true

        // Title & description
        Kirigami.Heading {
            level: 2
            text: i18n("Edge-TTS")
            Layout.fillWidth: true
        }

        // Common settings
        Kirigami.Heading {
            level: 3
            text: i18n("Common Settings")
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Rate
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Rate (%):")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                }

                QQC2.Slider {
                    id: rateSlider
                    Layout.fillWidth: true
                    from: -50; to: 50; value: 0; stepSize: 1

                    Component.onCompleted: {
                        var v = page.cfg_edgeTtsRate
                        if (v.length > 0) {
                            var n = parseInt(v.replace(/[+%]/g, ''))
                            if (!isNaN(n)) value = Math.max(-50, Math.min(50, n))
                        }
                    }
                    onMoved: {
                        var sign = value >= 0 ? "+" : ""
                        page.cfg_edgeTtsRate = sign + value + "%"
                    }
                }

                PlasmaComponents3.Label {
                    text: {
                        var s = rateSlider.value
                        return (s >= 0 ? "+" : "") + s + "%"
                    }
                    font.weight: Font.Medium
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Volume
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Volume (%):")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                }

                QQC2.Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: -50; to: 50; value: 0; stepSize: 1

                    Component.onCompleted: {
                        var v = page.cfg_edgeTtsVolume
                        if (v.length > 0) {
                            var n = parseInt(v.replace(/[+%]/g, ''))
                            if (!isNaN(n)) value = Math.max(-50, Math.min(50, n))
                        }
                    }
                    onMoved: {
                        var sign = value >= 0 ? "+" : ""
                        page.cfg_edgeTtsVolume = sign + value + "%"
                    }
                }

                PlasmaComponents3.Label {
                    text: {
                        var s = volumeSlider.value
                        return (s >= 0 ? "+" : "") + s + "%"
                    }
                    font.weight: Font.Medium
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Pitch
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: i18n("Pitch (Hz):")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                }

                QQC2.Slider {
                    id: pitchSlider
                    Layout.fillWidth: true
                    from: -50; to: 50; value: 0; stepSize: 1

                    Component.onCompleted: {
                        var v = page.cfg_edgeTtsPitch
                        if (v.length > 0) {
                            var n = parseInt(v.replace(/[+Hz]/g, ''))
                            if (!isNaN(n)) value = Math.max(-50, Math.min(50, n))
                        }
                    }
                    onMoved: {
                        var sign = value >= 0 ? "+" : ""
                        page.cfg_edgeTtsPitch = sign + value + "Hz"
                    }
                }

                PlasmaComponents3.Label {
                    text: {
                        var s = pitchSlider.value
                        return (s >= 0 ? "+" : "") + s + "Hz"
                    }
                    font.weight: Font.Medium
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Per-language Voices
        Kirigami.Heading {
            level: 3
            text: i18n("Voices (per language)")
            Layout.fillWidth: true
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            // 简体中文
            PlasmaComponents3.Label { text: page._langMeta[0].label }
            QQC2.ComboBox {
                id: zhVoiceCombo; editable: true; Layout.fillWidth: true
                model: [page.cfg_edgeTtsVoiceZhDefault]
                property bool _ready: false
                Component.onCompleted: {
                    var v = page.cfg_edgeTtsVoiceZh
                    var idx = find(v); if (idx >= 0) currentIndex = idx; else editText = v
                    _ready = true
                }
                onEditTextChanged: { if (_ready) page.cfg_edgeTtsVoiceZh = editText }
            }

            // English
            PlasmaComponents3.Label { text: page._langMeta[1].label }
            QQC2.ComboBox {
                id: enVoiceCombo; editable: true; Layout.fillWidth: true
                model: [page.cfg_edgeTtsVoiceEnDefault]
                property bool _ready: false
                Component.onCompleted: {
                    var v = page.cfg_edgeTtsVoiceEn
                    var idx = find(v); if (idx >= 0) currentIndex = idx; else editText = v
                    _ready = true
                }
                onEditTextChanged: { if (_ready) page.cfg_edgeTtsVoiceEn = editText }
            }

            // Deutsch
            PlasmaComponents3.Label { text: page._langMeta[2].label }
            QQC2.ComboBox {
                id: deVoiceCombo; editable: true; Layout.fillWidth: true
                model: [page.cfg_edgeTtsVoiceDeDefault]
                property bool _ready: false
                Component.onCompleted: {
                    var v = page.cfg_edgeTtsVoiceDe
                    var idx = find(v); if (idx >= 0) currentIndex = idx; else editText = v
                    _ready = true
                }
                onEditTextChanged: { if (_ready) page.cfg_edgeTtsVoiceDe = editText }
            }

            // 日本語
            PlasmaComponents3.Label { text: page._langMeta[3].label }
            QQC2.ComboBox {
                id: jaVoiceCombo; editable: true; Layout.fillWidth: true
                model: [page.cfg_edgeTtsVoiceJaDefault]
                property bool _ready: false
                Component.onCompleted: {
                    var v = page.cfg_edgeTtsVoiceJa
                    var idx = find(v); if (idx >= 0) currentIndex = idx; else editText = v
                    _ready = true
                }
                onEditTextChanged: { if (_ready) page.cfg_edgeTtsVoiceJa = editText }
            }

            // Français
            PlasmaComponents3.Label { text: page._langMeta[4].label }
            QQC2.ComboBox {
                id: frVoiceCombo; editable: true; Layout.fillWidth: true
                model: [page.cfg_edgeTtsVoiceFrDefault]
                property bool _ready: false
                Component.onCompleted: {
                    var v = page.cfg_edgeTtsVoiceFr
                    var idx = find(v); if (idx >= 0) currentIndex = idx; else editText = v
                    _ready = true
                }
                onEditTextChanged: { if (_ready) page.cfg_edgeTtsVoiceFr = editText }
            }

            // Español
            PlasmaComponents3.Label { text: page._langMeta[5].label }
            QQC2.ComboBox {
                id: esVoiceCombo; editable: true; Layout.fillWidth: true
                model: [page.cfg_edgeTtsVoiceEsDefault]
                property bool _ready: false
                Component.onCompleted: {
                    var v = page.cfg_edgeTtsVoiceEs
                    var idx = find(v); if (idx >= 0) currentIndex = idx; else editText = v
                    _ready = true
                }
                onEditTextChanged: { if (_ready) page.cfg_edgeTtsVoiceEs = editText }
            }
        }

        // Refresh + auto-fetch
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                id: refreshBtn
                icon.name: "view-refresh"
                text: i18n("Refresh voice list")
                enabled: !page._fetchingVoices
                Accessible.name: i18n("Fetch available voices from edge-tts")

                Component.onCompleted: {
                    _procHelper.commandFinished.connect(page._parseVoiceList)
                }
                onClicked: {
                    page._fetchingVoices = true
                    _procHelper.runCommand("edge-tts", ["--list-voices"])
                }
            }
        }

        // Installation hint (bottom, discreet)
        PlasmaComponents3.Label {
            text: i18n("Requires pip install edge-tts · Voices provided by Microsoft Edge online TTS")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            font.pixelSize: 12
        }

        Item { Layout.fillHeight: true }
    }

    // Auto-fetch voice list on first load (if not cached)
    Component.onCompleted: {
        if (!page._restoreVoiceLists()) {
            // No cached data — trigger fetch
            Qt.callLater(function() {
                page._fetchingVoices = true
                _procHelper.runCommand("edge-tts", ["--list-voices"])
            })
        }
    }
}
