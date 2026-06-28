import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

KCMUtils.SimpleKCM {
    id: page

    // ── KConfig XT bindings ───────────────────────────────────
    property string cfg_translateMode: "youdao"
    property string cfg_translateModeDefault: "youdao"
    property alias cfg_deepseekApiKey: apiKeyField.text
    property string cfg_deepseekApiKeyDefault: ""
    property string cfg_deepseekModel: "deepseek-v4-flash"
    property string cfg_deepseekModelDefault: "deepseek-v4-flash"
    property alias cfg_deepseekSystemPrompt: promptField.text
    property string cfg_deepseekSystemPromptDefault: "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."
    property double cfg_deepseekTemperature: 1.0
    property double cfg_deepseekTemperatureDefault: 1.0
    property alias cfg_deepseekMaxTokens: maxTokensSpin.value
    property int cfg_deepseekMaxTokensDefault: 4096
    property double cfg_deepseekTopP: 1.0
    property double cfg_deepseekTopPDefault: 1.0
    property alias cfg_deepseekStream: streamCheck.checked
    property bool cfg_deepseekStreamDefault: true
    property alias cfg_siliconFlowApiKey: sfApiKey.text
    property string cfg_siliconFlowApiKeyDefault: ""
    property string cfg_siliconFlowModel: "deepseek-ai/DeepSeek-V4-Flash"
    property string cfg_siliconFlowModelDefault: "deepseek-ai/DeepSeek-V4-Flash"
    property alias cfg_siliconFlowStream: sfStream.checked
    property bool cfg_siliconFlowStreamDefault: true
    property string cfg_shortcutOpen: "Meta+1"
    property string cfg_shortcutOpenDefault: "Meta+1"
    property string cfg_shortcutPick: "Meta+2"
    property string cfg_shortcutPickDefault: "Meta+2"

    // ── UI ────────────────────────────────────────────────────
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ── System Prompt (shared by all AI engines) ─────────
        Kirigami.Heading {
            level: 3
            text: i18n("System Prompt")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        QQC2.TextArea {
            id: promptField
            Layout.fillWidth: true
            placeholderText: i18n("Enter system prompt for the AI translator…")
            wrapMode: Text.WordWrap
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // ── DeepSeek settings ────────────────────────────────
        Kirigami.Heading {
            level: 3
            text: i18n("DeepSeek API")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                text: i18n("API Key:")
            }
            QQC2.TextField {
                id: apiKeyField
                Layout.fillWidth: true
                placeholderText: i18n("sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                echoMode: TextInput.Password
            }

            PlasmaComponents3.Label {
                text: i18n("Model:")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: modelCombo
                    editable: true
                    Layout.fillWidth: true
                    model: ["deepseek-v4-flash", "deepseek-v4-pro"]

                    Component.onCompleted: editText = page.cfg_deepseekModel
                    onEditTextChanged: page.cfg_deepseekModel = editText
                }

                QQC2.Button {
                    id: dsRefreshBtn
                    icon.name: "view-refresh"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                    enabled: !dsRefreshBtn.busy

                    property bool busy: false
                    Accessible.name: i18n("Refresh model list")

                    onClicked: {
                        var key = apiKeyField.text.trim()
                        if (!key) return

                        dsRefreshBtn.busy = true
                        dsRefreshBtn.enabled = false

                        var xhr = new XMLHttpRequest()
                        xhr.open("GET", "https://api.deepseek.com/models")
                        xhr.setRequestHeader("Authorization", "Bearer " + key)
                        xhr.setRequestHeader("Accept", "application/json")

                        xhr.onreadystatechange = function() {
                            if (xhr.readyState !== XMLHttpRequest.DONE) return
                            dsRefreshBtn.busy = false
                            dsRefreshBtn.enabled = true

                            if (xhr.status !== 200) {
                                console.log("DeepSeek models fetch failed:", xhr.status)
                                return
                            }

                            try {
                                var resp = JSON.parse(xhr.responseText)
                                if (resp.data) {
                                    var models = resp.data
                                        .filter(function(m) { return m.id })
                                        .map(function(m) { return m.id })
                                        .sort()
                                    if (models.length > 0)
                                        modelCombo.model = models
                                }
                            } catch (e) {
                                console.log("Failed to parse DeepSeek models:", e.message)
                            }
                        }

                        xhr.onerror = function() {
                            dsRefreshBtn.busy = false
                            dsRefreshBtn.enabled = true
                            console.log("Network error fetching DeepSeek models")
                        }

                        xhr.send()
                    }
                }
            }

            PlasmaComponents3.Label {
                text: i18n("Temperature:")
            }
            QQC2.SpinBox {
                id: tempSpin
                from: 0
                to: 20
                stepSize: 1
                editable: true
                Layout.fillWidth: true

                // Scale: internal int 0-20 → display 0.0-2.0
                readonly property int factor: 10
                readonly property real realValue: value / factor

                Component.onCompleted: value = Math.round(page.cfg_deepseekTemperature * factor)

                validator: DoubleValidator {
                    bottom: Math.min(tempSpin.from, tempSpin.to) / tempSpin.factor
                    top: Math.max(tempSpin.from, tempSpin.to) / tempSpin.factor
                    decimals: 1
                    notation: DoubleValidator.StandardNotation
                }

                textFromValue: function(value, locale) {
                    return Number(value / factor).toLocaleString(locale, 'f', 1)
                }

                valueFromText: function(text, locale) {
                    return Math.round(Number.fromLocaleString(locale, text) * factor)
                }

                // Sync back to config on user interaction
                onValueModified: page.cfg_deepseekTemperature = realValue
            }

            PlasmaComponents3.Label {
                text: i18n("Top-P:")
            }
            QQC2.SpinBox {
                id: topPSpin
                from: 0
                to: 100
                stepSize: 5
                editable: true
                Layout.fillWidth: true

                // Scale: internal int 0-100 → display 0.00-1.00
                readonly property int factor: 100
                readonly property real realValue: value / factor

                Component.onCompleted: value = Math.round(page.cfg_deepseekTopP * factor)

                validator: DoubleValidator {
                    bottom: Math.min(topPSpin.from, topPSpin.to) / topPSpin.factor
                    top: Math.max(topPSpin.from, topPSpin.to) / topPSpin.factor
                    decimals: 2
                    notation: DoubleValidator.StandardNotation
                }

                textFromValue: function(value, locale) {
                    return Number(value / factor).toLocaleString(locale, 'f', 2)
                }

                valueFromText: function(text, locale) {
                    return Math.round(Number.fromLocaleString(locale, text) * factor)
                }

                // Sync back to config on user interaction
                onValueModified: page.cfg_deepseekTopP = realValue
            }

            PlasmaComponents3.Label {
                text: i18n("Max Tokens:")
            }
            QQC2.SpinBox {
                id: maxTokensSpin
                from: 1
                to: 384000
                stepSize: 256
                Layout.fillWidth: true
                editable: true
            }

            PlasmaComponents3.Label {
                text: i18n("Stream output:")
            }
            QQC2.CheckBox {
                id: streamCheck
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // ── SiliconFlow settings ─────────────────────────
        Kirigami.Heading {
            level: 3
            text: i18n("SiliconFlow API")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                text: i18n("API Key:")
            }
            QQC2.TextField {
                id: sfApiKey
                Layout.fillWidth: true
                placeholderText: i18n("sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                echoMode: TextInput.Password
            }

            PlasmaComponents3.Label {
                text: i18n("Model:")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: sfModelCombo
                    editable: true
                    Layout.fillWidth: true

                    // Preseed with default + fetched models later
                    model: [
                        "deepseek-ai/DeepSeek-V4-Flash",
                        "deepseek-ai/DeepSeek-V3.2",
                        "Pro/zai-org/GLM-5",
                        "Pro/zai-org/GLM-4.7",
                        "Qwen/Qwen3-8B",
                        "Qwen/Qwen3-14B"
                    ]

                    Component.onCompleted: editText = page.cfg_siliconFlowModel
                    onEditTextChanged: page.cfg_siliconFlowModel = editText
                }

                QQC2.Button {
                    id: refreshBtn
                    icon.name: "view-refresh"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                    enabled: !refreshBtn.busy

                    property bool busy: false

                    Accessible.name: i18n("Refresh model list")

                    onClicked: {
                        var key = sfApiKey.text.trim()
                        if (!key) return

                        refreshBtn.busy = true
                        refreshBtn.enabled = false

                        var xhr = new XMLHttpRequest()
                        xhr.open("GET", "https://api.siliconflow.cn/v1/models?type=text&sub_type=chat")
                        xhr.setRequestHeader("Authorization", "Bearer " + key)
                        xhr.setRequestHeader("Accept", "application/json")

                        xhr.onreadystatechange = function() {
                            if (xhr.readyState !== XMLHttpRequest.DONE) return
                            refreshBtn.busy = false
                            refreshBtn.enabled = true

                            if (xhr.status !== 200) {
                                console.log("SiliconFlow models fetch failed:", xhr.status)
                                return
                            }

                            try {
                                var resp = JSON.parse(xhr.responseText)
                                if (resp.object === "list" && resp.data) {
                                    var chatModels = resp.data
                                        .filter(function(m) { return m.object === "model" && m.id })
                                        .map(function(m) { return m.id })
                                        .sort()
                                    if (chatModels.length > 0)
                                        sfModelCombo.model = chatModels
                                }
                            } catch (e) {
                                console.log("Failed to parse models:", e.message)
                            }
                        }

                        xhr.onerror = function() {
                            refreshBtn.busy = false
                            refreshBtn.enabled = true
                            console.log("Network error fetching SiliconFlow models")
                        }

                        xhr.send()
                    }
                }
            }

            PlasmaComponents3.Label {
                text: i18n("Stream output:")
            }
            QQC2.CheckBox {
                id: sfStream
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
        }

        // ── Security note ────────────────────────────────────
        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        PlasmaComponents3.Label {
            text: i18n("API keys are stored in plaintext in the plasmoid configuration. Treat them like passwords.")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        }

        Item { Layout.fillHeight: true }
    }
}
