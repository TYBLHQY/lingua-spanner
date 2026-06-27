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
            // deepseek
            if (!deepseekApiKey) {
                deepseekResult = { error: i18n("DeepSeek API key not configured") }
                translating = false
            } else {
                deepseekService.translate(inputText, deepseekApiKey, deepseekModel)
            }
        }
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

        // 2. No selection / click path: focus input, keep existing content
        if (p_inputField) {
            p_inputField.forceActiveFocus()
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
            deepseekResult = result
            translating = false
        }
        onError: function(msg) {
            deepseekResult = { error: msg }
            translating = false
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

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ════════════════════════════════════════════════
            //  Header
            // ════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                implicitHeight: headerRow.implicitHeight

                RowLayout {
                    id: headerRow
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Kirigami.Heading {
                        level: 2
                        text: i18n("Lingua Spanner")
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.BusyIndicator {
                        visible: root.translating
                        running: root.translating
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                }
            }

            // ════════════════════════════════════════════════
            //  Input area
            // ════════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                implicitHeight: inputRow.implicitHeight

                RowLayout {
                    id: inputRow
                    anchors.left: parent.left
                    anchors.right: parent.right

                    QQC2.TextField {
                        id: inputField
                        Layout.fillWidth: true
                        placeholderText: i18n("Enter text to translate…")
                        onAccepted: root.translate(text)
                        Component.onCompleted: root.p_inputField = inputField
                    }

                    QQC2.Button {
                        text: i18n("Translate")
                        icon.name: "translate"
                        enabled: inputField.text.trim().length > 0 && !root.translating
                        onClicked: root.translate(inputField.text)
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
                        opacity: 0.2
                        height: youdaoCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                        ColumnLayout {
                            id: youdaoCol
                            anchors {
                                fill: parent
                                margins: Kirigami.Units.smallSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            // ── Audio bar ──────────────────
                            Flow {
                                visible: youdaoResult.audio && youdaoResult.audio.length > 0
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Repeater {
                                    model: youdaoResult ? youdaoResult.audio : []

                                    delegate: Button {
                                        id: audioBtn
                                        required property var modelData
                                        text: modelData.text
                                        icon.name: "media-playback-start"
                                        flat: true
                                        Accessible.name: i18n("Play pronunciation")
                                        onClicked: {
                                            audioPlayer.source = modelData.url
                                            audioPlayer.play()
                                        }
                                    }
                                }

                                MediaPlayer { id: audioPlayer }
                            }

                            // ── Exam type tags ─────────────
                            Flow {
                                visible: youdaoResult.examType && youdaoResult.examType.length > 0
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Repeater {
                                    model: youdaoResult ? youdaoResult.examType : []

                                    delegate: Rectangle {
                                        required property string modelData
                                        color: Kirigami.Theme.highlightColor
                                        opacity: 0.6
                                        radius: Kirigami.Units.smallSpacing
                                        implicitHeight: examLabel.implicitHeight + Kirigami.Units.smallSpacing
                                        implicitWidth: examLabel.implicitWidth + Kirigami.Units.smallSpacing

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
                                visible: youdaoResult.form && youdaoResult.form.length > 0
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Repeater {
                                    model: youdaoResult ? youdaoResult.form : []

                                    delegate: Rectangle {
                                        required property var modelData
                                        color: Kirigami.Theme.backgroundColor
                                        border.color: Kirigami.Theme.disabledTextColor
                                        border.width: 1
                                        opacity: 0.5
                                        radius: Kirigami.Units.smallSpacing
                                        implicitHeight: formLabel.implicitHeight + Kirigami.Units.smallSpacing
                                        implicitWidth: formLabel.implicitWidth + Kirigami.Units.smallSpacing

                                        PlasmaComponents3.Label {
                                            id: formLabel
                                            anchors.centerIn: parent
                                            text: modelData.form + " " + modelData.type
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                                            color: Kirigami.Theme.disabledTextColor
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
                                            color: Kirigami.Theme.alternateBackgroundColor
                                            radius: Kirigami.Units.smallSpacing
                                            opacity: 0.4
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

                    // ── DeepSeek result ───────────────────
                    Rectangle {
                        visible: deepseekResult !== null
                        Layout.fillWidth: true
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.backgroundColor
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        opacity: 0.2
                        height: dsCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                        ColumnLayout {
                            id: dsCol
                            anchors {
                                fill: parent
                                margins: Kirigami.Units.smallSpacing
                            }
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.Label {
                                text: i18n("DeepSeek AI Translation")
                                font.bold: true
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                            }

                            PlasmaComponents3.Label {
                                text: deepseekResult ? (deepseekResult.translation || deepseekResult.error || JSON.stringify(deepseekResult)) : ""
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                            }
                        }
                    }

                    // ── Placeholder ───────────────────────
                    PlasmaComponents3.Label {
                        visible: !root.translating
                            && youdaoResult === null
                            && deepseekResult === null
                            && root.errorMessage === ""
                        text: i18n("Type text above and press Enter or click Translate.")
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.gridUnit
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
