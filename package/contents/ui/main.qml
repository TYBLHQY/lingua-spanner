import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// Custom QML plugin (QClipboard PRIMARY selection)
import "../lib/LinguaSpannerHelper"

// Translation services
import "services" as Services

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    hideOnWindowDeactivate: !root.pinned

    // Config shortcuts
    readonly property var _modeOrder: JSON.parse(Plasmoid.configuration.modeOrder || '["youdao","deepseek","siliconflow","dictionary"]')
    readonly property var _modeEnabled: JSON.parse(Plasmoid.configuration.modeEnabled || '["youdao","deepseek","siliconflow","dictionary"]')
    readonly property string deepseekApiKey: Plasmoid.configuration.deepseekApiKey || ""
    readonly property string deepseekModel: Plasmoid.configuration.deepseekModel || "deepseek-v4-flash"
    readonly property double deepseekTemperature: Plasmoid.configuration.deepseekTemperature !== undefined ? Plasmoid.configuration.deepseekTemperature : 1.0
    readonly property int deepseekMaxTokens: Plasmoid.configuration.deepseekMaxTokens || 4096
    readonly property double deepseekTopP: Plasmoid.configuration.deepseekTopP !== undefined ? Plasmoid.configuration.deepseekTopP : 1.0
    readonly property bool deepseekStream: Plasmoid.configuration.deepseekStream !== undefined ? Plasmoid.configuration.deepseekStream : true
    readonly property string siliconFlowApiKey: Plasmoid.configuration.siliconFlowApiKey || ""
    readonly property string siliconFlowModel: Plasmoid.configuration.siliconFlowModel || "deepseek-ai/DeepSeek-V4-Flash"
    readonly property bool siliconFlowStream: Plasmoid.configuration.siliconFlowStream !== undefined ? Plasmoid.configuration.siliconFlowStream : true

    // Font sizes (from config)
    readonly property int fontSizeBase: Plasmoid.configuration.fontSizeBase || 14
    readonly property int fontSizeLarge: fontSizeBase + 1
    readonly property int fontSizeSmall: Math.max(6, fontSizeBase - 2)
    readonly property int fontSizeSecondary: Math.max(6, fontSizeBase - 1)

    // Custom font family (empty = system default)
    readonly property string fontFamily: Plasmoid.configuration.fontFamily || ""

    // Pin state — keep panel open on window focus loss
    property bool pinned: false

    // Toggle pin with Ctrl+P
    Shortcut {
        sequence: "Ctrl+P"
        onActivated: root.pinned = !root.pinned
    }

    // Language pair (AI modes only)
    property string sourceLang: "auto"
    property string targetLang: "auto"

    readonly property var _langModel: [
        { text: "简体中文",            value: "zh" },
        { text: "English",            value: "en" },
        { text: "Deutsch",            value: "de" },
        { text: "日本語",              value: "ja" },
        { text: "Français",           value: "fr" },
        { text: "Español",            value: "es" }
    ]

    // Mode label lookup
    readonly property var _modeLabels: ({
        "youdao":      i18n("Youdao"),
        "deepseek":    i18n("DeepSeek"),
        "siliconflow": i18n("SiliconFlow"),
        "dictionary":  i18n("Free Dictionary API")
    })

    // TTS mode label lookup
    readonly property var _ttsModeLabels: ({
        "edge-tts": i18n("Edge TTS")
    })

    // TTS config shortcuts
    readonly property var _ttsModeOrder: JSON.parse(Plasmoid.configuration.ttsModeOrder || '["edge-tts"]')
    readonly property var _ttsModeEnabled: JSON.parse(Plasmoid.configuration.ttsModeEnabled || '["edge-tts"]')

    // Currently selected mode (from ComboBox)
    property string currentMode: {
        for (var i = 0; i < root._modeOrder.length; i++)
            if (root._modeEnabled.indexOf(root._modeOrder[i]) >= 0)
                return root._modeOrder[i]
        return "youdao"
    }

    // TTS state
    property string currentTtsMode: {
        for (var i = 0; i < root._ttsModeOrder.length; i++)
            if (root._ttsModeEnabled.indexOf(root._ttsModeOrder[i]) >= 0)
                return root._ttsModeOrder[i]
        return "edge-tts"
    }
    property string ttsInputText: ""
    property bool ttsPlaying: false
    property string ttsErrorMessage: ""
    property string ttsVoice: ""
    property double ttsSpeed: 1.0

    // Translation state
    property string inputText: ""
    property var youdaoResult: null
    property var dictionaryResult: null
    property bool translating: false
    property string errorMessage: ""

    // 同语言翻译拦截
    // AI 模式下 sourceLang 和 targetLang 显式相同时禁止翻译
    readonly property bool _sameLangPair: (root.currentMode === "deepseek" || root.currentMode === "siliconflow")
        && root.sourceLang !== "auto"
        && root.targetLang !== "auto"
        && root.sourceLang === root.targetLang

    // DeepSeek streaming display
    property string streamingTranslation: ""
    property string streamingInput: ""

    // Structured AI result (parsed JSON for display)
    property var aiResult: null

    // DB record ID (UUID) for the currently displayed AI result
    // Used by deleteCurrentResult() to remove from the cache DB.
    property string currentTranslationId: ""

    // Flat grid models for column-aligned display
    // (moved to YoudaoResultPanel.qml, AiResultPanel.qml)

    // History cache (DB-backed, used for duplicate detection)
    function _getCachedHistory(text, sourceLang, targetLang) {
        try {
            var json = pasteSelectionHelper.proc.exec(
                "SELECT id, result_json FROM translations WHERE (input_text=? OR cleaned_input=?) AND source_lang=? AND target_lang=? AND (engine='deepseek' OR engine='siliconflow') ORDER BY created_at DESC LIMIT 1",
                JSON.stringify([text, text, sourceLang, targetLang])
            )
            var rows = JSON.parse(json)
            if (rows.length > 0) {
                var parsed = JSON.parse(rows[0].result_json || "{}")
                return {
                    id: rows[0].id,
                    translation: parsed.translate || "",
                    result: parsed
                }
            }
        } catch (e) {}
        return null
    }

    // Shared cache-hit apply
    // Both DeepSeek and SiliconFlow use the same logic when a
    // cached result is found.
    function _applyCachedResult(cached) {
        pasteSelectionHelper.proc.exec(
            "UPDATE translations SET created_at=strftime('%Y-%m-%dT%H:%M:%S','now') WHERE id=?",
            JSON.stringify([cached.id])
        )
        streamingInput = root.inputText
        streamingTranslation = cached.translation
        root.aiResult = cached.result
        root.currentTranslationId = cached.id
        translating = false
    }

    // UUID generator
    function _generateUuid() {
        var hex = "0123456789abcdef"
        var uuid = ""
        for (var i = 0; i < 36; i++) {
            if (i === 8 || i === 13 || i === 18 || i === 23) {
                uuid += "-"
            } else if (i === 14) {
                uuid += "4"
            } else if (i === 19) {
                uuid += hex[Math.floor(Math.random() * 4) + 8]  // 8,9,a,b
            } else {
                uuid += hex[Math.floor(Math.random() * 16)]
            }
        }
        return uuid
    }

    // DB insert helper
    function _insertTranslation(engine, result) {
        try {
            var uuid = root._generateUuid()
            var srcLang = result.source_lang || root.sourceLang
            var tgtLang = result.target_lang || root.targetLang
            var cleaned = result.cleaned_input || root.inputText
            var jsonStr = JSON.stringify(result)
            pasteSelectionHelper.proc.exec(
                "INSERT INTO translations(id,input_text,cleaned_input,engine,source_lang,target_lang,result_json) VALUES(?,?,?,?,?,?,?)",
                JSON.stringify([uuid, root.inputText, cleaned, engine, srcLang, tgtLang, jsonStr])
            )
            root.currentTranslationId = uuid
        } catch (e) {
            console.log("DB insert failed:", e)
            root.currentTranslationId = ""
        }
    }

    // Delete current result (DB + UI state)
    function deleteCurrentResult() {
        var idToDelete = root.currentTranslationId

        // Fallback: if no tracked ID, look up by content
        if (!idToDelete && root.inputText.length > 0) {
            var engine = root.currentMode === "siliconflow" ? "siliconflow" : "deepseek"
            try {
                var rows = JSON.parse(pasteSelectionHelper.proc.exec(
                    "SELECT id FROM translations WHERE input_text=? AND engine=? AND source_lang=? AND target_lang=? ORDER BY created_at DESC LIMIT 1",
                    JSON.stringify([root.inputText, engine, root.sourceLang, root.targetLang])
                ))
                idToDelete = rows.length > 0 ? rows[0].id : ""
            } catch (e) {
                console.log("DB lookup for delete failed:", e)
            }
        }

        if (idToDelete) {
            try {
                pasteSelectionHelper.proc.exec(
                    "DELETE FROM translations WHERE id=?",
                    JSON.stringify([idToDelete])
                )
                console.log("Deleted translation record id=" + idToDelete)
            } catch (e) {
                console.log("DB delete failed:", e)
            }
        } else {
            console.log("deleteCurrentResult: no DB record found")
        }

        root.currentTranslationId = ""
        root.aiResult = null
        root.streamingTranslation = ""
        root.streamingInput = ""
        root.inputText = ""
        if (root.p_inputField) {
            root.p_inputField.text = ""
        }
        root.errorMessage = ""
        // Focus input after clearing
        if (root.p_inputField) {
            root.p_inputField.forceActiveFocus()
        }
    }

    // Cancel the current translation
    function cancelTranslation() {
        if (root.currentMode === "deepseek") {
            deepseekService.cancel()
        } else if (root.currentMode === "siliconflow") {
            siliconFlowService.cancel()
        }
        root.translating = false
        root.streamingTranslation = ""
        root.streamingInput = ""
        root.errorMessage = ""
        // Focus input and select all so user can re-translate
        if (root.p_inputField) {
            root.p_inputField.forceActiveFocus()
            if (root.p_inputField.text.trim().length > 0) {
                root.p_inputField.selectAll()
            }
        }
    }

    // Reference to inputField inside fullRepresentation
    property QtObject p_inputField: null

    // Distinguish click (just toggle) from shortcut (pick+paste)
    property bool _openedByClick: false

    // Performance timing for async selection
    property var _tPanelOpen: 0

    // PasteSelectionHelper (reads PRIMARY via QClipboard)
    PasteSelectionHelper { id: pasteSelectionHelper }

    // Current mode persistence
    // Persists through ProcessHelper's separate config so mode
    // choice survives across sessions independently of KConfig.
    function _saveUiConfig(obj) {
        try {
            var existing = JSON.parse(pasteSelectionHelper.proc.loadConfig() || "{}")
            for (var k in obj)
                existing[k] = obj[k]
            pasteSelectionHelper.proc.saveConfig(JSON.stringify(existing))
        } catch(e) {}
    }

    function _loadUiConfig() {
        try {
            var cfg = JSON.parse(pasteSelectionHelper.proc.loadConfig())
            if (cfg.sourceLang && cfg.sourceLang !== root.sourceLang)
                root.sourceLang = cfg.sourceLang
            if (cfg.targetLang && cfg.targetLang !== root.targetLang)
                root.targetLang = cfg.targetLang
            if (cfg.currentMode && cfg.currentMode !== root.currentMode)
                root.currentMode = cfg.currentMode
            if (cfg.currentTtsMode && cfg.currentTtsMode !== root.currentTtsMode)
                root.currentTtsMode = cfg.currentTtsMode

            // Sync mode combo after loading (it init'ed with defaults)
            Qt.callLater(function() {
                // mode combo
                for (var i = 0; i < modeCombo.model.length; i++)
                    if (modeCombo.model[i].value === root.currentMode)
                        { modeCombo.currentIndex = i; break }
                // source lang combo
                for (var i = 0; i < sourceLangCombo.model.length; i++)
                    if (sourceLangCombo.model[i].value === root.sourceLang)
                        { sourceLangCombo.currentIndex = i; break }
                // target lang combo
                for (var i = 0; i < targetLangCombo.model.length; i++)
                    if (targetLangCombo.model[i].value === root.targetLang)
                        { targetLangCombo.currentIndex = i; break }
                // tts mode combo
                // tts mode combo
                for (var i = 0; i < ttsModeCombo.model.length; i++)
                    if (ttsModeCombo.model[i].value === root.currentTtsMode)
                        { ttsModeCombo.currentIndex = i; break }
            })
        } catch(e) {}
    }

    function translate(text) {
        if (!text || text.trim().length === 0) return
        var t = text.trim()
        if (root.translating && root.inputText === t) return
        inputText = t
        translating = true
        errorMessage = ""
        youdaoResult = null
        dictionaryResult = null
        root.aiResult = null
        root.currentTranslationId = ""

        // Reset streaming state for new translation
        streamingTranslation = ""
        streamingInput = ""

        var mode = root.currentMode

        // AI 模式下源语言和目标语言相同时禁止翻译
        if ((mode === "deepseek" || mode === "siliconflow") && root._sameLangPair) {
            errorMessage = i18n("Source and target languages are the same")
            translating = false
            return
        }

        if (mode === "youdao") {
            youdaoService.fetch(inputText)
        } else if (mode === "dictionary") {
            dictionaryService.fetch(inputText)
        } else if (mode === "siliconflow") {
            // siliconflow — check history cache first
            var cached = _getCachedHistory(inputText, root.sourceLang, root.targetLang)
            if (cached) {
                root._applyCachedResult(cached)
            } else if (!siliconFlowApiKey) {
                errorMessage = i18n("SiliconFlow API key not configured")
                translating = false
            } else {
                streamingInput = inputText
                siliconFlowService.translate(inputText, siliconFlowApiKey, siliconFlowModel, siliconFlowStream, null, 4096, null, root.sourceLang, root.targetLang)
            }
        } else {
            // deepseek — check history cache first
            var cached = _getCachedHistory(inputText, root.sourceLang, root.targetLang)
            if (cached) {
                root._applyCachedResult(cached)
            } else if (!deepseekApiKey) {
                errorMessage = i18n("DeepSeek API key not configured")
                translating = false
            } else {
                streamingInput = inputText
                deepseekService.translate(inputText, deepseekApiKey, deepseekModel, deepseekStream, deepseekTemperature, deepseekMaxTokens, deepseekTopP, root.sourceLang, root.targetLang)
            }
        }
    }

    // TTS handler
    function speak(text) {
        if (!text || text.trim().length === 0) return
        ttsPlaying = true
        ttsErrorMessage = ""
        var mode = root.currentTtsMode
        if (mode === "edge-tts") {
            edgeTtsService.speak(text, root.ttsVoice || "", root.ttsSpeed || 1.0)
        }
    }

    function ttsStop() {
        var mode = root.currentTtsMode
        if (mode === "edge-tts") {
            edgeTtsService.stop()
        }
        ttsPlaying = false
    }

    // Pick text from focused window when panel opens
    onExpandedChanged: {
        console.log("onExpandedChanged: expanded=", root.expanded)
        if (!root.expanded) {
            // Reset click flag when panel closes, so next keyboard
            // shortcut correctly triggers selection reading.
            root._openedByClick = false
            return
        }
        Qt.callLater(root.handlePanelOpened)
    }

    // Also handle initial load (plasmawindowed starts expanded)
    Component.onCompleted: {
        pasteSelectionHelper.proc.initDb()
        console.log("Component.onCompleted: expanded=", root.expanded)
        root._loadUiConfig()
        if (root.expanded) {
            Qt.callLater(root.handlePanelOpened)
        }
    }

    function handlePanelOpened() {
        // 1. Try to read selection (only for shortcut path)
        var fromShortcut = !root._openedByClick
        root._openedByClick = false

        if (fromShortcut) {
            // Read PRIMARY selection synchronously via QClipboard
            var picked = pasteSelectionHelper.readSelection()
            root.handlePickedSelection(picked)
            return
        }

        // 2. Click path: focus input, select all if not empty
        if (p_inputField) {
            p_inputField.forceActiveFocus()
            if (p_inputField.text.trim().length > 0) {
                p_inputField.selectAll()
            }
        }
    }

    /// Handles selection result
    function handlePickedSelection(text) {
        // Freshness check: only accept PRIMARY content if the selection
        // owner changed within the last 1 second. Older content is stale
        // (user selected text 20s ago but hasn't selected anything new).
        var elapsed = Date.now() - pasteSelectionHelper.proc.selectionTimestamp
        var isFresh = elapsed <= 1000

        if (!text || text.trim().length === 0 || !isFresh) {
            console.log("selection ready, fresh=", isFresh, "elapsed=", elapsed, "ms — focusing input")
            if (p_inputField) {
                p_inputField.forceActiveFocus()
                if (p_inputField.text.trim().length > 0) {
                    p_inputField.selectAll()
                }
            }
            return
        }

        console.log("selection ready, fresh, elapsed=", elapsed, "ms, text='", text, "'")
        p_inputField.text = text.trim()
        p_inputField.selectAll()
        root.translate(p_inputField.text)
    }

    // Translation services
    Services.YoudaoWebNewService {
        id: youdaoService
        onFinished: function(result) {
            youdaoResult = result
            translating = false
        }
        onError: function(msg) {
            youdaoResult = { error: msg }
            translating = false
        }
    }

    Services.DeepSeekService {
        id: deepseekService
        onStreamingUpdate: function(text) {
            root.streamingTranslation = text
        }
        onFinished: function(result) {
            translating = false
            if (result.translation) {
                root.aiResult = result
                root._insertTranslation("deepseek", result)
            }
        }
        onError: function(msg) {
            translating = false
            streamingTranslation = ""
            streamingInput = ""
            root.errorMessage = msg
        }
    }

    // Free Dictionary API service
    Services.FreeDictionaryApiService {
        id: dictionaryService
        onFinished: function(result) {
            dictionaryResult = result
            translating = false
        }
        onError: function(msg) {
            dictionaryResult = { error: msg }
            translating = false
        }
    }

    // SiliconFlow API service
    Services.SiliconFlowService {
        id: siliconFlowService
        onStreamingUpdate: function(text) {
            root.streamingTranslation = text
        }
        onFinished: function(result) {
            translating = false
            if (result.translation) {
                root.aiResult = result
                root._insertTranslation("siliconflow", result)
            }
        }
        onError: function(msg) {
            translating = false
            streamingTranslation = ""
            streamingInput = ""
            root.errorMessage = msg
        }
    }

    // TTS services
    Services.EdgeTtsService {
        id: edgeTtsService
        onFinished: {
            root.ttsPlaying = false
        }
        onError: function(msg) {
            root.ttsPlaying = false
            root.ttsErrorMessage = msg
        }
    }

    // Compact: taskbar icon
    compactRepresentation: Kirigami.Icon {
        source: "translate"
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: Kirigami.Units.iconSizes.small

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root._openedByClick = true
                root.expanded = !root.expanded
            }
        }
    }

    // Full: popup panel
    fullRepresentation: Item {
        Layout.minimumWidth: 380
        Layout.minimumHeight: 320
        Layout.preferredWidth: 440
        Layout.preferredHeight: 480

        // 吸顶加载条 (web 风格)
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 3
            visible: root.translating
            color: "transparent"

            Rectangle {
                id: loaderBar
                width: parent.width * 0.35
                height: parent.height
                radius: 1.5
                color: Kirigami.Theme.highlightColor

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.translating

                    NumberAnimation {
                        from: 0; to: parent.width - loaderBar.width
                        duration: 600; easing.type: Easing.InOutCubic
                    }
                    PauseAnimation { duration: 200 }
                    NumberAnimation {
                        from: parent.width - loaderBar.width; to: 0
                        duration: 600; easing.type: Easing.InOutCubic
                    }
                    PauseAnimation { duration: 200 }
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.translating

                    NumberAnimation { from: 0.3; to: 1.0; duration: 400 }
                    PauseAnimation { duration: 600 }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 400 }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Input area (replaces former header)
            Item {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    implicitHeight: inputRow.implicitHeight

                    RowLayout {
                        id: inputRow
                        anchors.left: parent.left
                        anchors.right: parent.right

                        QQC2.TextField {
                            id: inputField
                            Layout.fillWidth: true
                            placeholderText: i18n("Enter text to translate…")
                            font.family: root.fontFamily || undefined
                            onAccepted: {
                                root.translate(text)
                                selectAll()
                            }
                            Component.onCompleted: root.p_inputField = inputField
                        }

                        QQC2.Button {
                            icon.name: root.pinned ? "window-pin" : "window-unpin"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            onClicked: root.pinned = !root.pinned
                            Accessible.name: root.pinned ? i18n("Unpin") : i18n("Pin")
                            QQC2.ToolTip {
                                text: root.pinned
                                    ? i18n("Keep open when switching windows")
                                    : i18n("Pin panel open")
                                delay: Kirigami.Units.toolTipDelay
                                visible: hovered
                            }
                        }
                    }
                }

                // Translate mode selector
                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    implicitHeight: modeRow.implicitHeight

                    RowLayout {
                        id: modeRow
                        anchors.left: parent.left
                        anchors.right: parent.right

                        QQC2.ComboBox {
                            id: modeCombo
                            Layout.fillWidth: true

                            // Build model from enabled modes
                            model: {
                                var order = root._modeOrder
                                var enabled = root._modeEnabled
                                var items = []
                                for (var i = 0; i < order.length; i++)
                                    if (enabled.indexOf(order[i]) >= 0)
                                        items.push({ text: root._modeLabels[order[i]] || order[i], value: order[i] })
                                return items
                            }
                            textRole: "text"
                            valueRole: "value"

                            // Guard to prevent init-time writes to config
                            property bool _ready: false

                            // Sync from config
                            Component.onCompleted: {
                                for (var i = 0; i < model.length; i++) {
                                    if (model[i].value === root.currentMode) {
                                        currentIndex = i
                                        break
                                    }
                                }
                                _ready = true
                            }
                            // Sync on user change
                            onCurrentValueChanged: {
                                if (!_ready) return
                                if (currentValue !== root.currentMode) {
                                    // Clear results
                                    youdaoResult = null
                                    dictionaryResult = null
                                    // Write to local state
                                    root.currentMode = currentValue
                                    root._saveUiConfig({currentMode: root.currentMode})
                                    // Auto-translate if input is not empty
                                    Qt.callLater(function() {
                                        if (inputField.text.trim().length > 0) {
                                            root.translate(inputField.text)
                                        }
                                    })
                                }
                            }
                        }

                        // TTS mode selector
                        QQC2.ComboBox {
                            id: ttsModeCombo
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                            model: {
                                var order = root._ttsModeOrder
                                var enabled = root._ttsModeEnabled
                                var items = []
                                for (var i = 0; i < order.length; i++)
                                    if (enabled.indexOf(order[i]) >= 0)
                                        items.push({ text: root._ttsModeLabels[order[i]] || order[i], value: order[i] })
                                return items
                            }
                            textRole: "text"
                            valueRole: "value"

                            property bool _ready: false

                            Component.onCompleted: {
                                for (var i = 0; i < model.length; i++) {
                                    if (model[i].value === root.currentTtsMode) {
                                        currentIndex = i
                                        break
                                    }
                                }
                                _ready = true
                            }
                            onCurrentValueChanged: {
                                if (!_ready) return
                                if (currentValue !== root.currentTtsMode) {
                                    root.currentTtsMode = currentValue
                                    root._saveUiConfig({currentTtsMode: root.currentTtsMode})
                                }
                            }
                        }

                        QQC2.Button {
                            icon.name: root.ttsPlaying ? "media-playback-stop" : "media-playback-start"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            Accessible.name: root.ttsPlaying ? i18n("Stop") : i18n("Speak")
                            QQC2.ToolTip {
                                text: root.ttsPlaying ? i18n("Stop speaking") : i18n("Speak input text")
                                delay: Kirigami.Units.toolTipDelay
                                visible: hovered
                            }
                            onClicked: {
                                if (root.ttsPlaying) {
                                    root.ttsStop()
                                } else {
                                    root.speak(inputField.text)
                                }
                            }
                        }
                    }
                }

                // Language bar (AI modes only)
                Item {
                    visible: root.currentMode === "deepseek" || root.currentMode === "siliconflow"
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    implicitHeight: langRow.implicitHeight

                    RowLayout {
                        id: langRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.ComboBox {
                            id: sourceLangCombo
                            Layout.fillWidth: true
                            model: root._langModel
                            textRole: "text"
                            valueRole: "value"

                            // Guard to prevent init-time writes to config
                            property bool _ready: false

                            Component.onCompleted: {
                                for (var i = 0; i < model.length; i++)
                                    if (model[i].value === root.sourceLang) {
                                        currentIndex = i
                                        break
                                    }
                                _ready = true
                            }
                            onCurrentValueChanged: {
                                if (!_ready) return
                                if (root.sourceLang !== currentValue) {
                                    root.sourceLang = currentValue
                                    root._saveUiConfig({sourceLang: currentValue})
                                }
                            }
                        }

                        QQC2.Button {
                            text: "⇄"
                            font.pixelSize: root.fontSizeLarge
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            flat: true
                            Accessible.name: i18n("Swap languages")
                            onClicked: {
                                // Swap values
                                var tmp = root.sourceLang
                                root.sourceLang = root.targetLang
                                root.targetLang = tmp
                                root._saveUiConfig({sourceLang: root.sourceLang, targetLang: root.targetLang})

                                // Update ComboBox visual selection
                                for (var i = 0; i < sourceLangCombo.model.length; i++)
                                    if (sourceLangCombo.model[i].value === root.sourceLang)
                                        { sourceLangCombo.currentIndex = i; break }
                                for (var i = 0; i < targetLangCombo.model.length; i++)
                                    if (targetLangCombo.model[i].value === root.targetLang)
                                        { targetLangCombo.currentIndex = i; break }
                            }
                        }

                        QQC2.ComboBox {
                            id: targetLangCombo
                            Layout.fillWidth: true
                            model: root._langModel
                            textRole: "text"
                            valueRole: "value"

                            // Guard to prevent init-time writes to config
                            property bool _ready: false

                            Component.onCompleted: {
                                for (var i = 0; i < model.length; i++)
                                    if (model[i].value === root.targetLang) {
                                        currentIndex = i
                                        break
                                    }
                                _ready = true
                            }
                            onCurrentValueChanged: {
                                if (!_ready) return
                                if (root.targetLang !== currentValue) {
                                    root.targetLang = currentValue
                                    root._saveUiConfig({targetLang: currentValue})
                                }
                            }
                        }
                    }
                }

                // Results area
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.bottomMargin: Kirigami.Units.largeSpacing
                    clip: true
                    contentWidth: availableWidth
                    QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        // Error
                        PlasmaComponents3.Label {
                            visible: root.errorMessage !== ""
                            text: root.errorMessage
                            color: Kirigami.Theme.negativeTextColor
                            font.italic: true
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Youdao result
                        YoudaoResultPanel {
                            result: youdaoResult
                        }

                        // Free Dictionary API result
                        DictionaryResultPanel {
                            result: dictionaryResult
                        }

                        // AI engine result (DeepSeek / SiliconFlow)
                        AiResultPanel {
                            streamingInput: root.streamingInput
                            translating: root.translating
                            streamingTranslation: root.streamingTranslation
                            aiResult: root.aiResult
                            onCancelRequested: root.cancelTranslation()
                            onDeleteRequested: root.deleteCurrentResult()
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

    // Tooltip
    toolTipMainText: i18n("Lingua Spanner — Translate")
    toolTipSubText: {
        if (inputText.length > 0) return i18n("Last: %1", inputText)
        return i18n("Click or press shortcut to open")
    }
}
