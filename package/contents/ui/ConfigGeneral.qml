import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

KCMUtils.SimpleKCM {
    id: page

    // ── KConfig XT bindings ───────────────────────────────────
    property alias cfg_translateMode: modeCombo.currentValue
    property alias cfg_deepseekApiKey: apiKeyField.text
    property alias cfg_deepseekModel: modelField.text
    property alias cfg_autoDetectLang: autoDetectCheck.checked

    // ── UI ────────────────────────────────────────────────────
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 3
            text: i18n("Translate Engine")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        // ── Mode selection ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents3.Label {
                text: i18n("Translate mode:")
            }

            QQC2.ComboBox {
                id: modeCombo
                model: [
                    { text: i18n("Youdao (web scraping)"), value: "youdao" },
                    { text: i18n("DeepSeek API"), value: "deepseek" },
                    { text: i18n("Both"), value: "both" }
                ]
                textRole: "text"
                valueRole: "value"
                Layout.fillWidth: true
            }
        }

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
