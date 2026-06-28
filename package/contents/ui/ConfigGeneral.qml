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
    property alias cfg_deepseekModel: modelCombo.currentValue
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
    property alias cfg_siliconFlowModel: sfModel.text
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
            QQC2.ComboBox {
                id: modelCombo
                Layout.fillWidth: true
                model: [
                    { text: "DeepSeek-V4-Flash", value: "deepseek-v4-flash" },
                    { text: "DeepSeek-V4-Pro", value: "deepseek-v4-pro" }
                ]
                textRole: "text"
                valueRole: "value"

                property bool _ready: false
                Component.onCompleted: {
                    var cfg = page.cfg_deepseekModel
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].value === cfg) {
                            currentIndex = i
                            break
                        }
                    }
                    _ready = true
                }
            }

            PlasmaComponents3.Label {
                text: i18n("System Prompt:")
            }
            QQC2.TextArea {
                id: promptField
                Layout.fillWidth: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 4
                placeholderText: i18n("Enter system prompt for the AI translator…")
                wrapMode: Text.WordWrap
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
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10

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
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10

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
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                editable: true
            }

            QQC2.CheckBox {
                id: streamCheck
                text: i18n("Stream output")
                Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
        }

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
            QQC2.TextField {
                id: sfModel
                Layout.fillWidth: true
                placeholderText: "deepseek-ai/DeepSeek-V4-Flash"
            }

            QQC2.CheckBox {
                id: sfStream
                text: i18n("Stream output")
                Layout.columnSpan: 2
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
