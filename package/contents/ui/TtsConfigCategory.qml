// TTS (Text-to-Speech) default voice and speed configuration

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

KCMUtils.SimpleKCM {
    id: page

    // KConfig XT bindings
    property string cfg_ttsDefaultVoice: ""
    property string cfg_ttsDefaultVoiceDefault: ""
    property double cfg_ttsSpeed: 1.0
    property double cfg_ttsSpeedDefault: 1.0

    // UI
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 3
            text: i18n("Speech Settings")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                text: i18n("Default Voice:")
            }
            QQC2.TextField {
                Layout.fillWidth: true
                placeholderText: i18n("e.g. zh-CN-XiaoxiaoNeural")
                text: page.cfg_ttsDefaultVoice
                onTextChanged: page.cfg_ttsDefaultVoice = text
            }

            PlasmaComponents3.Label {
                text: i18n("Default Speech Speed:")
            }
            QQC2.SpinBox {
                id: ttsSpeedSpin
                from: 50
                to: 200
                stepSize: 10
                editable: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                // Scale: internal int 50-200 → display 0.50-2.00
                readonly property int factor: 100
                readonly property real realValue: value / factor

                Component.onCompleted: value = Math.round(page.cfg_ttsSpeed * factor)

                textFromValue: function(value, locale) {
                    return Number(value / factor).toLocaleString(locale, 'f', 2)
                }
                valueFromText: function(text, locale) {
                    return Math.round(Number.fromLocaleString(locale, text) * factor)
                }

                // Sync back to config on user interaction
                onValueModified: page.cfg_ttsSpeed = realValue
            }
        }

        Item { Layout.fillHeight: true }
    }
}
