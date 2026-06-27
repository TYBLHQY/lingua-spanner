import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

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
    readonly property bool autoDetectLang: Plasmoid.configuration.autoDetectLang !== false

    // ── Translation state ───────────────────────────────────
    property string inputText: ""
    property var youdaoResult: null
    property var deepseekResult: null
    property bool translating: false
    property string errorMessage: ""

    // ── PasteSelectionHelper (QProcess xclip wrapper) ───────
    PasteSelectionHelper { id: pasteSelectionHelper }

    // ── Text picked before panel opens — consumed by ─────────
    //   fullRepresentation.onVisibleChanged
    property string pendingPickText: ""

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
                checkDone()
            } else {
                deepseekService.translate(inputText, deepseekApiKey, deepseekModel)
            }
        }
    }

    function checkDone() {
        translating = false
    }

    // Called from fullRepresentation when it becomes visible.
    // Pastes pendingPickText into inputField, or focuses it.
    function handleFullRepVisible() {
        // The actual work is inside fullRepresentation.onVisibleChanged
        // This is just a notification relay — logic runs in fullRep scope
        // because inputField lives there.
    }

    // ── Read selection whenever panel opens ─────────────────
    onExpandedChanged: {
        console.log("onExpandedChanged: expanded=", root.expanded)
        if (!root.expanded) return
        var picked = pasteSelectionHelper.readSelection()
        if (!picked || picked.trim().length === 0) {
            picked = pasteSelectionHelper.readClipboard()
        }
        if (picked && picked.trim().length > 0) {
            root.pendingPickText = picked.trim()
            console.log("onExpandedChanged: pending='", root.pendingPickText, "'")
        }
    }

    // ── Translation services ───────────────────────────────
    Services.YoudaoWebNewService {
        id: youdaoService
        onFinished: function(result) {
            youdaoResult = result
            checkDone()
        }
        onError: function(msg) {
            youdaoResult = { error: msg }
            checkDone()
        }
    }

    Services.DeepSeekService {
        id: deepseekService
        onFinished: function(result) {
            deepseekResult = result
            checkDone()
        }
        onError: function(msg) {
            deepseekResult = { error: msg }
            checkDone()
        }
    }

    // ── Compact: taskbar icon ───────────────────────────────
    compactRepresentation: Kirigami.Icon {
        source: "accessories-dictionary"
        implicitWidth: Kirigami.Units.iconSizes.small
        implicitHeight: Kirigami.Units.iconSizes.small

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Read selection BEFORE toggling panel open.
                // This ensures pendingPickText is set before
                // fullRepresentation becomes visible.
                var picked = pasteSelectionHelper.readSelection()
                if (!picked || picked.trim().length === 0) {
                    picked = pasteSelectionHelper.readClipboard()
                }
                if (picked && picked.trim().length > 0) {
                    root.pendingPickText = picked.trim()
                }
                Plasmoid.activated()
            }
        }
    }

    // ── Full: popup panel ───────────────────────────────────
    fullRepresentation: Item {
        Layout.minimumWidth: 380
        Layout.minimumHeight: 320
        Layout.preferredWidth: 440
        Layout.preferredHeight: 480

        // When panel becomes visible: paste pending text or focus
        onVisibleChanged: {
            if (!visible) return
            pasteOrFocus()
        }
        Component.onCompleted: {
            if (visible) pasteOrFocus()
        }
        function pasteOrFocus() {
            if (root.pendingPickText.length > 0) {
                console.log("fullRep: pasting '", root.pendingPickText, "'")
                inputField.text = root.pendingPickText
                inputField.selectAll()
                root.pendingPickText = ""
                root.translate(inputField.text)
            } else {
                console.log("fullRep: focusing")
                inputField.forceActiveFocus()
            }
        }

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

                            PlasmaComponents3.Label {
                                text: i18n("Youdao Dictionary")
                                font.bold: true
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                            }

                            // TODO: render exp[], audio, examType, form
                            PlasmaComponents3.Label {
                                text: youdaoResult ? JSON.stringify(youdaoResult, null, 2) : ""
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
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
