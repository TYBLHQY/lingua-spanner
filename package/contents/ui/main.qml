// Lingua Spanner — Youdao Dictionary Plasmoid
// Single-engine: Youdao web dictionary (scraping)
// Clipboard PRIMARY selection → look up on shortcut
// TTS: Edge-TTS for reading input text aloud

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

    // Pin state — keep panel open on window focus loss
    property bool pinned: false

    // Toggle pin with Ctrl+P
    Shortcut {
        sequence: "Ctrl+P"
        onActivated: root.pinned = !root.pinned
    }

    // TTS config — voice auto-selected by language
    readonly property string ttsVoice: {
        // Youdao results use "en" for English or Chinese
        return Plasmoid.configuration.edgeTtsVoiceEn || "en-US-EmmaMultilingualNeural"
    }
    readonly property string ttsRate: Plasmoid.configuration.edgeTtsRate || "+0%"
    readonly property string ttsVolume: Plasmoid.configuration.edgeTtsVolume || "+0%"
    readonly property string ttsPitch: Plasmoid.configuration.edgeTtsPitch || "+0Hz"

    // Font sizes (from config)
    readonly property int fontSizeBase: Plasmoid.configuration.fontSizeBase || 14

    // Custom font family (empty = system default)
    readonly property string fontFamily: Plasmoid.configuration.fontFamily || ""

    // Translation state
    property string inputText: ""
    property var youdaoResult: null
    property bool translating: false
    property string errorMessage: ""

    // TTS
    property bool ttsPlaying: false
    property string _ttsPlayingText: ""
    property bool _ttsRetrying: false

    // Reference to inputField inside fullRepresentation
    property QtObject p_inputField: null

    // Distinguish click (just toggle) from shortcut (pick+paste)
    property bool _openedByClick: false

    // PasteSelectionHelper (reads PRIMARY via QClipboard)
    PasteSelectionHelper { id: pasteSelectionHelper }

    // Focus the input field and select all text
    function _focusAndSelectInput() {
        if (root.p_inputField) {
            root.p_inputField.forceActiveFocus()
            if (root.p_inputField.text.trim().length > 0)
                root.p_inputField.selectAll()
        }
    }

    /// Stop any in-flight TTS. Synthesis (edge-tts) and playback (paplay) run
    /// as two separate processes, and either one may be the one currently
    /// running — cancelling an idle one is a no-op.
    function stopTts() {
        edgeTtsService.cancel()
        ttsAudioPlayer.cancelCommand()
        root.ttsPlaying = false
        root._ttsPlayingText = ""
        root._ttsRetrying = false
    }

    function translate(text) {
        if (!text || text.trim().length === 0) return
        var t = text.trim()
        if (root.translating) return
        // Stop any ongoing TTS when starting a new translation
        if (root.ttsPlaying) root.stopTts()
        inputText = t
        translating = true
        errorMessage = ""
        youdaoResult = null

        youdaoService.fetch(inputText)
    }

    // Pick text from focused window when panel opens
    onExpandedChanged: {
        console.log("onExpandedChanged: expanded=", root.expanded, " pinned=", root.pinned)
        if (!root.expanded) {
            // Shortcut-triggered close while panel has no focus: refocus instead of close.
            if (!root._openedByClick && root.pinned && p_inputField && !p_inputField.activeFocus) {
                console.log("shortcut close while unfocused — refocusing")
                root._openedByClick = true
                root.expanded = true
                return
            }
            root._openedByClick = false
            return
        }
        Qt.callLater(root.handlePanelOpened)
    }

    Component.onCompleted: {
        if (root.expanded) {
            Qt.callLater(root.handlePanelOpened)
        }
    }

    function handlePanelOpened() {
        var fromShortcut = !root._openedByClick
        root._openedByClick = false

        if (fromShortcut) {
            var picked = pasteSelectionHelper.readSelection()
            root.handlePickedSelection(picked)
            return
        }

        root._focusAndSelectInput()
    }

    /// Handles selection result
    function handlePickedSelection(text) {
        var elapsed = Date.now() - pasteSelectionHelper.proc.selectionTimestamp
        var isFresh = elapsed <= 2000

        if (!text || text.trim().length === 0 || !isFresh) {
            console.log("selection ready, fresh=", isFresh, "elapsed=", elapsed, "ms — focusing input")
            root._focusAndSelectInput()
            return
        }

        console.log("selection ready, fresh, elapsed=", elapsed, "ms, text='", text, "'")
        text = text.replace(/\r\n/g, " ").replace(/\n/g, " ").replace(/\s+/g, " ")
        p_inputField.text = text.trim()
        p_inputField.selectAll()
        if (Plasmoid.configuration.autoTranslateOnSelection !== false) {
            root.translate(p_inputField.text)
        }
    }

    // Youdao translation service (single engine)
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

    // TTS service
    Services.EdgeTtsService {
        id: edgeTtsService
        voice: root.ttsVoice
        rate: root.ttsRate
        volume: root.ttsVolume
        pitch: root.ttsPitch
        binaryPath: Plasmoid.configuration.edgeTtsBinaryPath || ""

        onFinished: function(audioFilePath) {
            root.ttsPlaying = true
            ttsAudioPlayer.runCommand("paplay", [audioFilePath])
        }
        onError: function(msg) {
            root.errorMessage = msg
            root.ttsPlaying = false
            root._ttsPlayingText = ""
            root._ttsRetrying = false
        }
    }

    // Background ProcessHelper for audio playback + error recovery
    ProcessHelper {
        id: ttsAudioPlayer
        onCommandFinished: function(exitCode, stdOut, stdErr) {
            if (exitCode === 0) {
                root.ttsPlaying = false
                root._ttsPlayingText = ""
                root._ttsRetrying = false
                return
            }

            var text = root._ttsPlayingText
            if (!text) {
                root.ttsPlaying = false
                return
            }

            if (root._ttsRetrying) {
                root.errorMessage = i18n("TTS playback failed after retry")
                root.ttsPlaying = false
                root._ttsPlayingText = ""
                root._ttsRetrying = false
                return
            }

            root._ttsRetrying = true
            var cacheDir = edgeTtsService._cacheDir
            var cacheKey = edgeTtsService._cacheKey(text)
            if (cacheDir && cacheKey) {
                var badFile = cacheDir + "/" + cacheKey
                pasteSelectionHelper.proc.removeFile(badFile)
            }
            edgeTtsService.synthesize(text)
        }
    }

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

        // Loading bar
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

            // Input field
            QQC2.TextField {
                id: inputField
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                placeholderText: i18n("Enter text to look up…")
                font.family: root.fontFamily || undefined
                readOnly: root.ttsPlaying
                onReadOnlyChanged: {
                    if (!readOnly) {
                        forceActiveFocus()
                        if (text.trim().length > 0)
                            selectAll()
                    }
                }
                onAccepted: {
                    root.translate(text)
                    selectAll()
                }
                Component.onCompleted: root.p_inputField = inputField
            }

            // Results area
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
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

                    Item { Layout.fillHeight: true }
                }
            }

            // TTS bar — full-width, pinned to the bottom of the panel
            QQC2.Button {
                id: ttsPlayBtn
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing
                implicitHeight: Kirigami.Units.iconSizes.medium

                text: i18n("Read aloud")
                icon.name: "media-playback-start"
                enabled: root.inputText !== "" && !root.translating && !root.ttsPlaying

                onClicked: {
                    var text = root.inputText
                    if (!text || text.trim().length === 0) return

                    root.errorMessage = ""
                    root.ttsPlaying = true
                    root._ttsPlayingText = text
                    root._ttsRetrying = false
                    edgeTtsService.synthesize(text)

                    root._focusAndSelectInput()
                }
            }
        }
    }

    // Tooltip
    toolTipMainText: i18n("Lingua Spanner — Youdao Dictionary")
    toolTipSubText: {
        if (inputText.length > 0) return i18n("Last: %1", inputText)
        return i18n("Click or press shortcut to open")
    }
}
