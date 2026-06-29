import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtMultimedia

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// ── Custom QML plugin (QClipboard PRIMARY selection) ──────
import "../lib/LinguaSpannerHelper"

// ── Translation services ───────────────────────────────────
import "services" as Services

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    hideOnWindowDeactivate: !root.pinned

    // ── Config shortcuts ────────────────────────────────────
    readonly property var _modeOrder: JSON.parse(Plasmoid.configuration.modeOrder || '["youdao","deepseek","siliconflow","dictionary"]')
    readonly property var _modeEnabled: JSON.parse(Plasmoid.configuration.modeEnabled || '["youdao","deepseek","siliconflow","dictionary"]')
    readonly property string deepseekApiKey: Plasmoid.configuration.deepseekApiKey || ""
    readonly property string deepseekModel: Plasmoid.configuration.deepseekModel || "deepseek-v4-flash"
    readonly property double deepseekTemperature: Plasmoid.configuration.deepseekTemperature !== undefined ? Plasmoid.configuration.deepseekTemperature : 1.0
    readonly property int deepseekMaxTokens: Plasmoid.configuration.deepseekMaxTokens || 4096
    readonly property double deepseekTopP: Plasmoid.configuration.deepseekTopP !== undefined ? Plasmoid.configuration.deepseekTopP : 1.0
    readonly property string systemPromptDefault: "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."
    readonly property string systemPrompt: {
        var v = Plasmoid.configuration.systemPrompt
        return (v && v.trim().length > 0) ? v.trim() : systemPromptDefault
    }
    readonly property bool deepseekStream: Plasmoid.configuration.deepseekStream !== undefined ? Plasmoid.configuration.deepseekStream : true
    readonly property string siliconFlowApiKey: Plasmoid.configuration.siliconFlowApiKey || ""
    readonly property string siliconFlowModel: Plasmoid.configuration.siliconFlowModel || "deepseek-ai/DeepSeek-V4-Flash"
    readonly property bool siliconFlowStream: Plasmoid.configuration.siliconFlowStream !== undefined ? Plasmoid.configuration.siliconFlowStream : true

    // ── Font sizes (from config) ────────────────────────────
    readonly property int fontSizeBase: Plasmoid.configuration.fontSizeBase || 14
    readonly property int fontSizeLarge: fontSizeBase + 1
    readonly property int fontSizeSmall: Math.max(6, fontSizeBase - 2)
    readonly property int fontSizeSecondary: Math.max(6, fontSizeBase - 1)

    // ── Mode label lookup ───────────────────────────────────
    readonly property var _modeLabels: ({
        "youdao":      i18n("Youdao"),
        "deepseek":    i18n("DeepSeek"),
        "siliconflow": i18n("SiliconFlow"),
        "dictionary":  i18n("Free Dictionary API")
    })

    // ── Currently selected mode (from ComboBox) ──────────────
    property string currentMode: {
        for (var i = 0; i < root._modeOrder.length; i++)
            if (root._modeEnabled.indexOf(root._modeOrder[i]) >= 0)
                return root._modeOrder[i]
        return "youdao"
    }

    // ── Translation state ───────────────────────────────────
    property string inputText: ""
    property var youdaoResult: null
    property var deepseekResult: null
    property var dictionaryResult: null
    property bool translating: false
    property string errorMessage: ""

    // ── DeepSeek streaming display ──────────────────────────
    property string streamingTranslation: ""
    property string streamingInput: ""

    // ── DeepSeek history (in-memory) ────────────────────────
    property var dsHistory: []

    // When the system prompt changes, clear history to avoid
    // stale cached results being returned without a new API call.
    onSystemPromptChanged: {
        dsHistory = []
    }

    function addHistory(input, translation) {
        var entry = findInHistory(input)
        if (entry) {
            entry.translation = translation
            promoteHistory(entry)
        } else {
            entry = { input: input, translation: translation }
            dsHistory.unshift(entry)
            promoteHistory(entry)
        }
    }

    function deleteHistory(index) {
        dsHistory.splice(index, 1)
        var tmp = dsHistory
        dsHistory = []
        dsHistory = tmp
    }

    // ── Reference to inputField inside fullRepresentation ───
    property QtObject p_inputField: null

    // ── Distinguish click (just toggle) from shortcut (pick+paste)
    property bool _openedByClick: false

    // ── Pin state ──────────────────────────────────────────
    property bool pinned: false

    // ── Performance timing for async selection
    property var _tPanelOpen: 0

    // ── PasteSelectionHelper (reads PRIMARY via QClipboard) ─
    PasteSelectionHelper { id: pasteSelectionHelper }

    // ── Dim parenthetical notes gray ────────────────────
    function grayBrackets(text) {
        return text
            .replace(/（[^）]*）/g,       m => '<font color="gray">' + m + '</font>')
            .replace(/\([^)]*\)/g,        m => '<font color="gray">' + m + '</font>')
            .replace(/【[^】]*】/g,       m => '<font color="gray">' + m + '</font>')
            .replace(/\[[^\]]*\]/g,       m => '<font color="gray">' + m + '</font>')
            .replace(/\{[^}]*\}/g,        m => '<font color="gray">' + m + '</font>')
            .replace(/\n/g, '<br>')
    }

    // ── Translation handler ─────────────────────────────────
    function translate(text) {
        if (!text || text.trim().length === 0) return
        inputText = text.trim()
        translating = true
        errorMessage = ""
        youdaoResult = null
        deepseekResult = null
        dictionaryResult = null

        // Reset streaming state for new translation
        streamingTranslation = ""
        streamingInput = ""

        var mode = root.currentMode

        if (mode === "youdao") {
            youdaoService.fetch(inputText)
        } else if (mode === "dictionary") {
            dictionaryService.fetch(inputText)
        } else if (mode === "siliconflow") {
            // siliconflow — check history cache first
            var cached = findInHistory(inputText)
            if (cached) {
                promoteHistory(cached)
                translating = false
            } else if (!siliconFlowApiKey) {
                errorMessage = i18n("SiliconFlow API key not configured")
                translating = false
            } else {
                streamingInput = inputText
                siliconFlowService.translate(inputText, siliconFlowApiKey, siliconFlowModel, systemPrompt, null, 4096, null, siliconFlowStream)
            }
        } else {
            // deepseek — check history cache first
            var cached = findInHistory(inputText)
            if (cached) {
                // Found in history: display from cache, no API call
                promoteHistory(cached)
                translating = false
            } else if (!deepseekApiKey) {
                errorMessage = i18n("DeepSeek API key not configured")
                translating = false
            } else {
                streamingInput = inputText
                deepseekService.translate(inputText, deepseekApiKey, deepseekModel, systemPrompt, deepseekTemperature, deepseekMaxTokens, deepseekTopP, deepseekStream)
            }
        }
    }

    // ── History helpers ──────────────────────────────────
    function findInHistory(text) {
        for (var i = 0; i < dsHistory.length; i++) {
            if (dsHistory[i].input === text) return dsHistory[i]
        }
        return null
    }

    function promoteHistory(entry) {
        // Remove from current position
        for (var i = 0; i < dsHistory.length; i++) {
            if (dsHistory[i] === entry) {
                dsHistory.splice(i, 1)
                break
            }
        }
        // Add to front as NEW
        entry.isNew = true
        dsHistory.unshift(entry)
        // Others become HISTORY
        for (i = 1; i < dsHistory.length; i++) {
            dsHistory[i].isNew = false
        }
        if (dsHistory.length > 20) dsHistory.length = 20
        // Force QML re-evaluation
        var tmp = dsHistory
        dsHistory = []
        dsHistory = tmp
    }

    // ── Pick text from focused window when panel opens ────
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
        console.log("Component.onCompleted: expanded=", root.expanded)
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

    // ── Translation services ───────────────────────────────
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
            streamingTranslation = ""
            streamingInput = ""
            if (result.translation) {
                root.addHistory(inputText, result.translation)
            }
        }
        onError: function(msg) {
            translating = false
            streamingTranslation = ""
            streamingInput = ""
            root.errorMessage = msg
        }
    }

    // ── Free Dictionary API service ──────────────────────────
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

    // ── SiliconFlow API service ──────────────────────────────
    Services.SiliconFlowService {
        id: siliconFlowService
        onStreamingUpdate: function(text) {
            root.streamingTranslation = text
        }
        onFinished: function(result) {
            translating = false
            streamingTranslation = ""
            streamingInput = ""
            if (result.translation) {
                root.addHistory(inputText, result.translation)
            }
        }
        onError: function(msg) {
            translating = false
            streamingTranslation = ""
            streamingInput = ""
            root.errorMessage = msg
        }
    }

    // ── Compact: taskbar icon ───────────────────────────────
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

    // ── Full: popup panel ───────────────────────────────────
    fullRepresentation: Item {
        Layout.minimumWidth: 380
        Layout.minimumHeight: 320
        Layout.preferredWidth: 440
        Layout.preferredHeight: 480

        // ── 吸顶加载条 (web 风格) ────────────────────────
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

            // ════════════════════════════════════════════════
            //  Input area (replaces former header)
            // ════════════════════════════════════════════════
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
                            text: root.pinned ? i18n("Pinned: stay open when focus changes") : i18n("Pin to keep open when switching windows")
                            delay: Kirigami.Units.toolTipDelay
                            visible: hovered
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════
            //  Translate mode selector
            // ════════════════════════════════════════════════
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
                                deepseekResult = null
                                dictionaryResult = null
                                // Write to local state
                                root.currentMode = currentValue
                                // Auto-translate if input is not empty
                                Qt.callLater(function() {
                                    if (inputField.text.trim().length > 0) {
                                        root.translate(inputField.text)
                                    }
                                })
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════
            //  Results area
            // ════════════════════════════════════════════════
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

                    // ── Error ─────────────────────────────
                    PlasmaComponents3.Label {
                        visible: root.errorMessage !== ""
                        text: root.errorMessage
                        color: Kirigami.Theme.negativeTextColor
                        font.italic: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // ── Youdao result ─────────────────────
                    Rectangle {
                        visible: youdaoResult !== null
                        Layout.fillWidth: true
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.backgroundColor
                        implicitHeight: youdaoCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                        ColumnLayout {
                            id: youdaoCol
                            anchors {
                                fill: parent
                                margins: Kirigami.Units.smallSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            // ── No result notice ────────────
                            PlasmaComponents3.Label {
                                visible: youdaoResult && youdaoResult.exp.length === 0
                                text: i18n("No dictionary results found.")
                                color: Kirigami.Theme.disabledTextColor
                                font.italic: true
                                Layout.fillWidth: true
                            }

                            // ── Audio bar ──────────────────
                            Rectangle {
                                visible: youdaoResult && youdaoResult.audio && youdaoResult.audio.length > 0
                                Layout.fillWidth: true
                                color: Kirigami.Theme.backgroundColor
                                border.color: Kirigami.Theme.disabledTextColor
                                border.width: 1
                                radius: Kirigami.Units.smallSpacing
                                implicitHeight: audioRow.implicitHeight + Kirigami.Units.smallSpacing

                                RowLayout {
                                    id: audioRow
                                    anchors {
                                        fill: parent
                                        leftMargin: Kirigami.Units.smallSpacing
                                        rightMargin: Kirigami.Units.smallSpacing
                                    }
                                    spacing: Kirigami.Units.smallSpacing

                                    Repeater {
                                        model: youdaoResult ? youdaoResult.audio : []

                                        delegate: QQC2.Button {
                                            id: audioBtn
                                            required property var modelData
                                            text: modelData.text
                                            icon.name: "media-playback-start"
                                            flat: true
                                            Accessible.name: i18n("Play pronunciation")
                                            Layout.fillWidth: true
                                            onClicked: {
                                                audioPlayer.source = modelData.url
                                                audioPlayer.play()
                                            }
                                        }
                                    }
                                }

                                MediaPlayer {
                                    id: audioPlayer
                                    audioOutput: AudioOutput {}
                                    onErrorOccurred: console.log("audioPlayer error:", error, errorString)
                                    onPlaybackStateChanged: console.log("audioPlayer state:", playbackState)
                                }
                            }

                            // ── Exam type tags ─────────────
                            Flow {
                                visible: youdaoResult && youdaoResult.examType && youdaoResult.examType.length > 0
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Repeater {
                                    model: youdaoResult ? youdaoResult.examType : []

                                    delegate: PlasmaComponents3.Label {
                                        required property string modelData
                                        text: modelData
                                        color: Kirigami.Theme.linkColor
                                        font.pixelSize: root.fontSizeSmall
                                    }
                                }
                            }

                            // ── Forms ──────────────────────
                            Flow {
                                visible: youdaoResult && youdaoResult.form && youdaoResult.form.length > 0
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Repeater {
                                    model: youdaoResult ? youdaoResult.form : []

                                    delegate: Rectangle {
                                        required property var modelData
                                        color: "transparent"
                                        border.color: Kirigami.Theme.disabledTextColor
                                        border.width: 1
                                        radius: Kirigami.Units.smallSpacing
                                        implicitHeight: formLabel.implicitHeight + Kirigami.Units.smallSpacing
                                        implicitWidth: formLabel.implicitWidth + Kirigami.Units.smallSpacing + 10

                                        PlasmaComponents3.Label {
                                            id: formLabel
                                            anchors.centerIn: parent
                                            text: modelData.form + " " + modelData.type
                                            font.pixelSize: root.fontSizeSmall
                                        }
                                    }
                                }
                            }

                            // ── Definitions (exp) ──────────
                            Repeater {
                                model: youdaoResult ? youdaoResult.exp : []

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    // Part of speech label
                                    PlasmaComponents3.Label {
                                        visible: modelData.po.length > 0
                                        text: modelData.po
                                        font.bold: true
                                        color: Kirigami.Theme.neutralTextColor
                                        font.pixelSize: root.fontSizeBase
                                    }


                                    // Translations
                                    Repeater {
                                        model: modelData.tr

                                        delegate: Rectangle {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.leftMargin: Kirigami.Units.smallSpacing
                                            color: Kirigami.Theme.backgroundColor
                                            radius: Kirigami.Units.smallSpacing
                                            implicitHeight: trEdit.height + Kirigami.Units.smallSpacing

                                            TextEdit {
                                                id: trEdit
                                                anchors {
                                                    left: parent.left
                                                    right: parent.right
                                                    margins: Kirigami.Units.smallSpacing
                                                }
                                                text: root.grayBrackets(modelData)
                                                textFormat: TextEdit.RichText
                                                wrapMode: TextEdit.WordWrap
                                                font.pixelSize: root.fontSizeSecondary
                                                readOnly: true
                                                selectByMouse: true
                                                height: contentHeight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Free Dictionary API result ────────────
                    Rectangle {
                        visible: dictionaryResult !== null && root.currentMode === "dictionary"
                        Layout.fillWidth: true
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.backgroundColor
                        implicitHeight: dictCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                        ColumnLayout {
                            id: dictCol
                            anchors {
                                fill: parent
                                margins: Kirigami.Units.smallSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            // ── No result / error notice ──────
                            PlasmaComponents3.Label {
                                visible: dictionaryResult && (
                                    dictionaryResult.error ||
                                    dictionaryResult.exp.length === 0)
                                text: dictionaryResult && dictionaryResult.error
                                    ? dictionaryResult.error
                                    : i18n("No dictionary results found.")
                                color: dictionaryResult && dictionaryResult.error
                                    ? Kirigami.Theme.negativeTextColor
                                    : Kirigami.Theme.disabledTextColor
                                font.italic: true
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            // ── Phonetic text ────────────────
                            PlasmaComponents3.Label {
                                visible: dictionaryResult && dictionaryResult.phonetic
                                    && dictionaryResult.phonetic.length > 0
                                text: dictionaryResult.phonetic
                                font.bold: true
                                color: Kirigami.Theme.neutralTextColor
                                font.pixelSize: root.fontSizeLarge
                                Layout.fillWidth: true
                            }

                            // ── Origin / etymology ────────────
                            PlasmaComponents3.Label {
                                visible: dictionaryResult && dictionaryResult.origin
                                    && dictionaryResult.origin.length > 0
                                text: i18n("Origin: %1", dictionaryResult.origin)
                                font.italic: true
                                color: Kirigami.Theme.disabledTextColor
                                wrapMode: Text.WordWrap
                                font.pixelSize: root.fontSizeSecondary
                                Layout.fillWidth: true
                            }

                            // ── Audio bar ──────────────────
                            Rectangle {
                                visible: dictionaryResult && dictionaryResult.audio
                                    && dictionaryResult.audio.length > 0
                                Layout.fillWidth: true
                                color: Kirigami.Theme.backgroundColor
                                border.color: Kirigami.Theme.disabledTextColor
                                border.width: 1
                                radius: Kirigami.Units.smallSpacing
                                implicitHeight: dictAudioRow.implicitHeight + Kirigami.Units.smallSpacing

                                RowLayout {
                                    id: dictAudioRow
                                    anchors {
                                        fill: parent
                                        leftMargin: Kirigami.Units.smallSpacing
                                        rightMargin: Kirigami.Units.smallSpacing
                                    }
                                    spacing: Kirigami.Units.smallSpacing

                                    Repeater {
                                        model: dictionaryResult ? dictionaryResult.audio : []

                                        delegate: QQC2.Button {
                                            id: dictAudioBtn
                                            required property var modelData
                                            text: modelData.text ? modelData.text : i18n("Play")
                                            icon.name: "media-playback-start"
                                            flat: true
                                            Accessible.name: i18n("Play pronunciation")
                                            Layout.fillWidth: true
                                            onClicked: {
                                                dictAudioPlayer.source = modelData.url
                                                dictAudioPlayer.play()
                                            }
                                        }
                                    }
                                }

                                MediaPlayer {
                                    id: dictAudioPlayer
                                    audioOutput: AudioOutput {}
                                    onErrorOccurred: console.log("dictAudioPlayer error:", error, errorString)
                                }
                            }

                            // ── Definitions (exp) ──────────
                            Repeater {
                                model: dictionaryResult ? dictionaryResult.exp : []

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    // Part of speech label
                                    PlasmaComponents3.Label {
                                        visible: modelData.po.length > 0
                                        text: modelData.po
                                        font.bold: true
                                        color: Kirigami.Theme.neutralTextColor
                                        font.pixelSize: root.fontSizeBase
                                    }


                                    // Definitions
                                    Repeater {
                                        model: modelData.tr

                                        delegate: Rectangle {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.leftMargin: Kirigami.Units.smallSpacing
                                            color: Kirigami.Theme.backgroundColor
                                            radius: Kirigami.Units.smallSpacing
                                            implicitHeight: dictTrEdit.height + Kirigami.Units.smallSpacing

                                            TextEdit {
                                                id: dictTrEdit
                                                anchors {
                                                    left: parent.left
                                                    right: parent.right
                                                    margins: Kirigami.Units.smallSpacing
                                                }
                                                text: root.grayBrackets(modelData)
                                                textFormat: TextEdit.RichText
                                                wrapMode: TextEdit.WordWrap
                                                font.pixelSize: root.fontSizeSecondary
                                                readOnly: true
                                                selectByMouse: true
                                                height: contentHeight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── DeepSeek streaming result ─────────────────
                    Rectangle {
                        visible: (root.currentMode === "deepseek" || root.currentMode === "siliconflow") && root.streamingInput !== ""
                        Layout.fillWidth: true
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.backgroundColor
                        implicitHeight: streamCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                        ColumnLayout {
                            id: streamCol
                            anchors {
                                fill: parent
                                margins: Kirigami.Units.smallSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents3.Label {
                                    text: i18n("STREAMING")
                                    font.bold: true
                                    font.pixelSize: root.fontSizeSmall
                                    color: Kirigami.Theme.neutralTextColor
                                }

                                Item { Layout.fillWidth: true }

                                // ── 流式动画圆点 ──
                                Row {
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        delegate: Rectangle {
                                            width: 5; height: 5
                                            radius: 2.5
                                            color: Kirigami.Theme.highlightColor
                                            opacity: 0.3
                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: root.translating && root.streamingInput !== ""

                                                PauseAnimation { duration: 200 * index }

                                                NumberAnimation {
                                                    from: 0.3; to: 1.0
                                                    duration: 400
                                                    easing.type: Easing.InOutQuad
                                                }
                                                NumberAnimation {
                                                    from: 1.0; to: 0.3
                                                    duration: 400
                                                    easing.type: Easing.InOutQuad
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            PlasmaComponents3.Label {
                                text: root.streamingInput
                                font.pixelSize: root.fontSizeSecondary
                                color: Kirigami.Theme.neutralTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            TextEdit {
                                text: root.streamingTranslation !== "" ? root.grayBrackets(root.streamingTranslation) : i18n("Waiting for response…")
                                textFormat: TextEdit.RichText
                                font.pixelSize: root.fontSizeBase
                                wrapMode: TextEdit.WordWrap
                                Layout.fillWidth: true
                                readOnly: true
                                selectByMouse: true
                                height: contentHeight
                            }
                        }
                    }

                    // ── AI engine history (DeepSeek / SiliconFlow) ──
                    Repeater {
                        id: histRepeater
                        model: (root.currentMode === "deepseek" || root.currentMode === "siliconflow") ? root.dsHistory : []

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            radius: Kirigami.Units.smallSpacing
                            color: Kirigami.Theme.backgroundColor
                            border.color: Kirigami.Theme.disabledTextColor
                            border.width: 1
                            implicitHeight: histCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                            ColumnLayout {
                                id: histCol
                                anchors {
                                    fill: parent
                                    margins: Kirigami.Units.smallSpacing
                                }
                                spacing: Kirigami.Units.smallSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    PlasmaComponents3.Label {
                                        text: modelData.isNew ? i18n("[NEW]") : i18n("[HISTORY]")
                                        font.bold: true
                                        font.pixelSize: root.fontSizeSmall
                                        color: modelData.isNew ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.neutralTextColor
                                    }

                                    Item { Layout.fillWidth: true }

                                    QQC2.Button {
                                        icon.name: "edit-delete"
                                        flat: true
                                        implicitWidth: Kirigami.Units.iconSizes.small
                                        implicitHeight: Kirigami.Units.iconSizes.small
                                        onClicked: root.deleteHistory(index)
                                        Accessible.name: i18n("Delete history entry")
                                    }
                                }

                                TextEdit {
                                    text: modelData.input
                                    font.pixelSize: root.fontSizeSecondary
                                    color: Kirigami.Theme.neutralTextColor
                                    wrapMode: TextEdit.WordWrap
                                    Layout.fillWidth: true
                                    readOnly: true
                                    selectByMouse: true
                                    height: contentHeight
                                }

                                TextEdit {
                                    text: root.grayBrackets(modelData.translation)
                                    textFormat: TextEdit.RichText
                                    font.pixelSize: root.fontSizeBase
                                    wrapMode: TextEdit.WordWrap
                                    Layout.fillWidth: true
                                    readOnly: true
                                    selectByMouse: true
                                    height: contentHeight
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ── Tooltip ─────────────────────────────────────────────
    toolTipMainText: i18n("Lingua Spanner — Translate")
    toolTipSubText: {
        if (inputText.length > 0) return i18n("Last: %1", inputText)
        return i18n("Click or press shortcut to open")
    }
}
