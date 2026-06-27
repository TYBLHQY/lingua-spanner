import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtMultimedia

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// ── Custom QML plugin (xclip via QProcess) ───────────────
import "../lib/LinguaSpannerHelper"

// ── Translation services ───────────────────────────────────
import "services" as Services

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── Config shortcuts ────────────────────────────────────
    readonly property string translateMode: Plasmoid.configuration.translateMode || "youdao"
    readonly property string deepseekApiKey: Plasmoid.configuration.deepseekApiKey || ""
    readonly property string deepseekModel: Plasmoid.configuration.deepseekModel || "deepseek-chat"

    // ── Translation state ───────────────────────────────────
    property string inputText: ""
    property var youdaoResult: null
    property var deepseekResult: null
    property bool translating: false
    property string errorMessage: ""

    // ── DeepSeek history (in-memory) ────────────────────────
    property var dsHistory: []

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

    // ── PasteSelectionHelper (QProcess xclip wrapper) ───────
    PasteSelectionHelper { id: pasteSelectionHelper }

    // ── Format definition text (split （notes） into dimmed) ─
    function formatDefinition(text) {
        return text.replace(/（[^）]*）/g, function(m) { return '<font color="gray">' + m + '</font>' })
    }

    // ── Translation handler ─────────────────────────────────
    function translate(text) {
        if (!text || text.trim().length === 0) return
        inputText = text.trim()
        translating = true
        errorMessage = ""
        youdaoResult = null
        deepseekResult = null

        var mode = translateMode

        if (mode === "youdao") {
            youdaoService.fetch(inputText)
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
                deepseekService.translate(inputText, deepseekApiKey, deepseekModel)
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
            var picked = pasteSelectionHelper.readSelection()
            console.log("handlePanelOpened: selection='", picked, "'")

            // If we have text, paste into input and translate
            if (picked && picked.trim().length > 0) {
                console.log("handlePanelOpened: pasting '", picked, "'")
                p_inputField.text = picked.trim()
                p_inputField.selectAll()
                root.translate(p_inputField.text)
                // Clear PRIMARY so next press without new selection
                // doesn't re-paste stale content.
                pasteSelectionHelper.clearSelection()
                return
            }
        }

        // 2. No selection / click path: focus input, select all if not empty
        if (p_inputField) {
            p_inputField.forceActiveFocus()
            if (p_inputField.text.trim().length > 0) {
                p_inputField.selectAll()
            }
        }
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
        onFinished: function(result) {
            translating = false
            if (result.translation) {
                root.addHistory(inputText, result.translation)
            }
        }
        onError: function(msg) {
            translating = false
            root.errorMessage = msg
        }
    }

    // ── Compact: taskbar icon ───────────────────────────────
    compactRepresentation: Kirigami.Icon {
        source: "crow-translate"
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
                        icon.name: "translate"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                        enabled: inputField.text.trim().length > 0 && !root.translating
                        onClicked: root.translate(inputField.text)
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
                        model: [
                            { text: i18n("Youdao (web scraping)"), value: "youdao" },
                            { text: i18n("DeepSeek API"), value: "deepseek" }
                        ]
                        textRole: "text"
                        valueRole: "value"

                        // Sync from config
                        Component.onCompleted: {
                            for (var i = 0; i < model.length; i++) {
                                if (model[i].value === root.translateMode) {
                                    currentIndex = i
                                    break
                                }
                            }
                        }
                        // Sync to config on change
                        onCurrentValueChanged: {
                            if (currentValue !== root.translateMode) {
                                // Clear results
                                youdaoResult = null
                                deepseekResult = null
                                // Write to config
                                Plasmoid.configuration.translateMode = currentValue
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
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
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

                                    delegate: Rectangle {
                                        required property string modelData
                                        color: Kirigami.Theme.highlightColor
                                        radius: Kirigami.Units.smallSpacing
                                        implicitHeight: examLabel.implicitHeight + Kirigami.Units.smallSpacing
                                        implicitWidth: examLabel.implicitWidth + Kirigami.Units.smallSpacing + 10

                                        PlasmaComponents3.Label {
                                            id: examLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                                        }
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
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
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
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
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
                                            implicitHeight: trLabel.implicitHeight + Kirigami.Units.smallSpacing

                                            PlasmaComponents3.Label {
                                                id: trLabel
                                                anchors {
                                                    left: parent.left
                                                    right: parent.right
                                                    margins: Kirigami.Units.smallSpacing
                                                }
                                                text: formatDefinition(modelData)
                                                textFormat: Text.StyledText
                                                wrapMode: Text.WordWrap
                                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── DeepSeek history (仅 DeepSeek 模式) ──
                    Repeater {
                        id: histRepeater
                        model: root.translateMode === "deepseek" ? root.dsHistory : []

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
                                        text: modelData.isNew ? i18n("NEW") : i18n("HISTORY")
                                        font.bold: true
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                                        color: modelData.isNew ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
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

                                PlasmaComponents3.Label {
                                    text: modelData.input
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                                    color: Kirigami.Theme.neutralTextColor
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                PlasmaComponents3.Label {
                                    text: modelData.translation
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
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
