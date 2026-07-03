// Lingua Spanner configuration — Translation Modes, TTS Modes, Display

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

KCMUtils.SimpleKCM {
    id: page

    // KConfig XT bindings — mode lists
    property string cfg_modeOrder: '["youdao","deepseek","siliconflow","dictionary"]'
    property string cfg_modeOrderDefault: '["youdao","deepseek","siliconflow","dictionary"]'
    property string cfg_modeEnabled: '["youdao","deepseek","siliconflow","dictionary"]'
    property string cfg_modeEnabledDefault: '["youdao","deepseek","siliconflow","dictionary"]'

    // KConfig XT bindings — TTS mode lists
    property string cfg_ttsModeOrder: '["edge-tts"]'
    property string cfg_ttsModeOrderDefault: '["edge-tts"]'
    property string cfg_ttsModeEnabled: '["edge-tts"]'
    property string cfg_ttsModeEnabledDefault: '["edge-tts"]'

    // KConfig XT bindings — shortcuts
    property string cfg_shortcutOpen: "Meta+1"
    property string cfg_shortcutOpenDefault: "Meta+1"
    property string cfg_shortcutPick: "Meta+2"
    property string cfg_shortcutPickDefault: "Meta+2"

    // KConfig XT bindings — display
    property alias cfg_fontSizeBase: fontSizeSpin.value
    property int cfg_fontSizeBaseDefault: 14
    property string cfg_fontFamily: ""
    property string cfg_fontFamilyDefault: ""

    // Helper: persist/restore model lists as JSON strings
    function parseModelList(json, fallback) {
        if (!json) return fallback
        try {
            var arr = JSON.parse(json)
            return Array.isArray(arr) && arr.length > 0 ? arr : fallback
        } catch(e) { return fallback }
    }
    function stringifyModelList(arr) {
        return JSON.stringify(arr)
    }

    // Mode list data
    readonly property var _modeMeta: [
        {id: "youdao",     label: i18n("Youdao")},
        {id: "deepseek",   label: i18n("DeepSeek")},
        {id: "siliconflow", label: i18n("SiliconFlow")},
        {id: "dictionary",  label: i18n("Free Dictionary API")}
    ]

    // TTS mode metadata
    readonly property var _ttsModeMeta: [
        {id: "edge-tts", label: i18n("Edge TTS")}
    ]

    property var _curTtsOrder: parseModelList(cfg_ttsModeOrder, ["edge-tts"])
    property var _curTtsEnabled: parseModelList(cfg_ttsModeEnabled, ["edge-tts"])

    onCfg_ttsModeOrderChanged: _curTtsOrder = parseModelList(cfg_ttsModeOrder, ["edge-tts"])
    onCfg_ttsModeEnabledChanged: _curTtsEnabled = parseModelList(cfg_ttsModeEnabled, ["edge-tts"])

    property var _curOrder: parseModelList(cfg_modeOrder, ["youdao","deepseek","siliconflow","dictionary"])
    property var _curEnabled: parseModelList(cfg_modeEnabled, ["youdao","deepseek","siliconflow","dictionary"])

    onCfg_modeOrderChanged: _curOrder = parseModelList(cfg_modeOrder, ["youdao","deepseek","siliconflow","dictionary"])
    onCfg_modeEnabledChanged: _curEnabled = parseModelList(cfg_modeEnabled, ["youdao","deepseek","siliconflow","dictionary"])

    function _modeLabel(id) {
        for (var i = 0; i < page._modeMeta.length; i++)
            if (page._modeMeta[i].id === id) return page._modeMeta[i].label
        return id
    }
    function _saveOrder() { cfg_modeOrder = JSON.stringify(page._curOrder) }
    function _saveEnabled() { cfg_modeEnabled = JSON.stringify(page._curEnabled) }

    function _moveUp(idx) {
        if (idx <= 0) return
        var a = page._curOrder.slice()
        var tmp = a[idx]; a[idx] = a[idx-1]; a[idx-1] = tmp
        page._curOrder = a
        _saveOrder()
    }
    function _moveDown(idx) {
        if (idx >= page._curOrder.length - 1) return
        var a = page._curOrder.slice()
        var tmp = a[idx]; a[idx] = a[idx+1]; a[idx+1] = tmp
        page._curOrder = a
        _saveOrder()
    }
    function _toggleEnabled(id) {
        var a = page._curEnabled.slice()
        var idx = a.indexOf(id)
        if (idx >= 0) { a.splice(idx, 1) } else { a.push(id) }
        page._curEnabled = a
        _saveEnabled()
    }

    // TTS mode management
    function _ttsModeLabel(id) {
        for (var i = 0; i < page._ttsModeMeta.length; i++)
            if (page._ttsModeMeta[i].id === id) return page._ttsModeMeta[i].label
        return id
    }
    function _saveTtsOrder() { cfg_ttsModeOrder = JSON.stringify(page._curTtsOrder) }
    function _saveTtsEnabled() { cfg_ttsModeEnabled = JSON.stringify(page._curTtsEnabled) }
    function _ttsMoveUp(idx) {
        if (idx <= 0) return
        var a = page._curTtsOrder.slice()
        var tmp = a[idx]; a[idx] = a[idx-1]; a[idx-1] = tmp
        page._curTtsOrder = a
        _saveTtsOrder()
    }
    function _ttsMoveDown(idx) {
        if (idx >= page._curTtsOrder.length - 1) return
        var a = page._curTtsOrder.slice()
        var tmp = a[idx]; a[idx] = a[idx+1]; a[idx+1] = tmp
        page._curTtsOrder = a
        _saveTtsOrder()
    }
    function _ttsToggleEnabled(id) {
        var a = page._curTtsEnabled.slice()
        var idx = a.indexOf(id)
        if (idx >= 0) { a.splice(idx, 1) } else { a.push(id) }
        page._curTtsEnabled = a
        _saveTtsEnabled()
    }

    // UI
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // Mode list
        Kirigami.Heading {
            level: 3
            text: i18n("Translation Modes")
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            implicitHeight: modeCol.implicitHeight + Kirigami.Units.smallSpacing

            ColumnLayout {
                id: modeCol
                anchors {
                    fill: parent
                    margins: Kirigami.Units.smallSpacing
                }
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: page._curOrder

                    delegate: RowLayout {
                        required property int index
                        required property string modelData
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true

                        QQC2.Switch {
                            checked: page._curEnabled.indexOf(modelData) >= 0
                            onToggled: page._toggleEnabled(modelData)
                            Accessible.name: i18n("Enable %1", page._modeLabel(modelData))
                        }

                        PlasmaComponents3.Label {
                            text: page._modeLabel(modelData)
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        QQC2.Button {
                            icon.name: "arrow-up"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            enabled: index > 0
                            flat: true
                            onClicked: page._moveUp(index)
                            Accessible.name: i18n("Move %1 up", page._modeLabel(modelData))
                        }

                        QQC2.Button {
                            icon.name: "arrow-down"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            enabled: index < page._curOrder.length - 1
                            flat: true
                            onClicked: page._moveDown(index)
                            Accessible.name: i18n("Move %1 down", page._modeLabel(modelData))
                        }
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // TTS mode list
        Kirigami.Heading {
            level: 3
            text: i18n("TTS Modes")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        Rectangle {
            Layout.fillWidth: true
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            implicitHeight: ttsModeCol.implicitHeight + Kirigami.Units.smallSpacing

            ColumnLayout {
                id: ttsModeCol
                anchors {
                    fill: parent
                    margins: Kirigami.Units.smallSpacing
                }
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: page._curTtsOrder

                    delegate: RowLayout {
                        required property int index
                        required property string modelData
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true

                        QQC2.Switch {
                            checked: page._curTtsEnabled.indexOf(modelData) >= 0
                            onToggled: page._ttsToggleEnabled(modelData)
                            Accessible.name: i18n("Enable %1", page._ttsModeLabel(modelData))
                        }

                        PlasmaComponents3.Label {
                            text: page._ttsModeLabel(modelData)
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        QQC2.Button {
                            icon.name: "arrow-up"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            enabled: index > 0
                            flat: true
                            onClicked: page._ttsMoveUp(index)
                            Accessible.name: i18n("Move %1 up", page._ttsModeLabel(modelData))
                        }

                        QQC2.Button {
                            icon.name: "arrow-down"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium
                            enabled: index < page._curTtsOrder.length - 1
                            flat: true
                            onClicked: page._ttsMoveDown(index)
                            Accessible.name: i18n("Move %1 down", page._ttsModeLabel(modelData))
                        }
                    }
                }
            }
        }

        // Display settings
        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        Kirigami.Heading {
            level: 3
            text: i18n("Display")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            PlasmaComponents3.Label {
                text: i18n("Base Font Size (px):")
            }
            QQC2.SpinBox {
                id: fontSizeSpin
                from: 8
                to: 24
                stepSize: 1
                editable: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }

            PlasmaComponents3.Label {
                text: i18n("Font Family:")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.ComboBox {
                    id: fontFamilyCombo
                    editable: true
                    Layout.fillWidth: true

                    // Guard against initial editText change
                    property bool _ready: false

                    Component.onCompleted: {
                        model = Qt.fontFamilies()
                        // Restore saved font family
                        var saved = page.cfg_fontFamily
                        if (saved && saved.length > 0) {
                            var idx = find(saved)
                            if (idx >= 0) {
                                currentIndex = idx
                            } else {
                                editText = saved
                            }
                        }
                        _ready = true
                    }

                    onEditTextChanged: {
                        if (_ready)
                            page.cfg_fontFamily = editText
                    }
                }

                QQC2.Button {
                    icon.name: "edit-clear"
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                    flat: true
                    Accessible.name: i18n("Reset to default font")
                    onClicked: {
                        fontFamilyCombo.editText = ""
                        page.cfg_fontFamily = ""
                    }
                }
            }
        }

        // Security note
        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        PlasmaComponents3.Label {
            text: i18n("API keys are stored in plaintext in the plasmoid configuration. Treat them like passwords.")
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            font.pixelSize: page.cfg_fontSizeBase - 1
        }

        Item { Layout.fillHeight: true }
    }
}
