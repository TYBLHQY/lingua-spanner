import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("AI Engine")
        icon: "dialog-password"
        source: "AiConfigCategory.qml"
    }
    ConfigCategory {
        name: i18n("Speech")
        icon: "audio-input-microphone"
        source: "TtsConfigCategory.qml"
    }
}
