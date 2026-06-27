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
    property alias cfg_deepseekModel: modelField.text
    property string cfg_deepseekModelDefault: "deepseek-chat"
    property alias cfg_deepseekSystemPrompt: promptField.text
    property string cfg_deepseekSystemPromptDefault: "You are a professional translator. Translate the given text accurately and naturally. Preserve the original meaning, tone, and style. If the source is English, translate to Chinese; if Chinese, translate to English. Output ONLY the translation, no explanations."
    property alias cfg_autoDetectLang: autoDetectCheck.checked
    property bool cfg_autoDetectLangDefault: true
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

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: i18n("API Key:")
            }

            QQC2.TextField {
                id: apiKeyField
                Layout.fillWidth: true
                placeholderText: i18n("sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                echoMode: TextInput.Password
            }
        }

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: i18n("Model:")
            }

            QQC2.TextField {
                id: modelField
                Layout.fillWidth: true
                placeholderText: "deepseek-chat"
            }
        }

        RowLayout {
            Layout.fillWidth: true

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
        }

        // ── Other settings ───────────────────────────────────
        Kirigami.Heading {
            level: 3
            text: i18n("Other")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        QQC2.CheckBox {
            id: autoDetectCheck
            text: i18n("Auto-detect language")
            checked: true
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
