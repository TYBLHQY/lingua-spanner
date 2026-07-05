// Lingua Spanner configuration — Translation Modes & Display

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

    // KConfig XT bindings — TTS modes
    property string cfg_ttsModeOrder: '["edge-tts"]'
    property string cfg_ttsModeOrderDefault: '["edge-tts"]'
    property string cfg_ttsModeEnabled: '["edge-tts"]'
    property string cfg_ttsModeEnabledDefault: '["edge-tts"]'

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

    property var _curOrder: parseModelList(cfg_modeOrder, ["youdao","deepseek","siliconflow","dictionary"])
    property var _curEnabled: parseModelList(cfg_modeEnabled, ["youdao","deepseek","siliconflow","dictionary"])

    onCfg_modeOrderChanged: _curOrder = parseModelList(cfg_modeOrder, ["youdao","deepseek","siliconflow","dictionary"])
    onCfg_modeEnabledChanged: _curEnabled = parseModelList(cfg_modeEnabled, ["youdao","deepseek","siliconflow","dictionary"])

    function _modeLabel(id) {
        for (var i = 0; i < page._modeMeta.length; i++)
            if (page._modeMeta[i].id === id) return page._modeMeta[i].label
        return id
    }
    function _ttsLabel(id) {
        if (id === "edge-tts") return i18n("Edge-TTS")
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

    // TTS modes — reactive properties
    property var _ttsOrder: parseModelList(cfg_ttsModeOrder, ["edge-tts"])
    property var _ttsEnabled: parseModelList(cfg_ttsModeEnabled, ["edge-tts"])

    onCfg_ttsModeOrderChanged: _ttsOrder = parseModelList(cfg_ttsModeOrder, ["edge-tts"])
    onCfg_ttsModeEnabledChanged: _ttsEnabled = parseModelList(cfg_ttsModeEnabled, ["edge-tts"])

    function _saveTtsOrder() { cfg_ttsModeOrder = JSON.stringify(page._ttsOrder) }
    function _saveTtsEnabled() { cfg_ttsModeEnabled = JSON.stringify(page._ttsEnabled) }

    function _toggleTtsEnabled(id) {
        var a = page._ttsEnabled.slice()
        var idx = a.indexOf(id)
        if (idx >= 0) { a.splice(idx, 1) } else { a.push(id) }
        page._ttsEnabled = a
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
                            enabled: page._curEnabled.length > 1 || !checked
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

        // TTS modes
        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

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
                    model: page._ttsOrder

                    delegate: RowLayout {
                        required property int index
                        required property string modelData
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true

                        QQC2.Switch {
                            checked: page._ttsEnabled.indexOf(modelData) >= 0
                            enabled: page._ttsEnabled.length > 1 || !checked
                            onToggled: page._toggleTtsEnabled(modelData)
                            Accessible.name: i18n("Enable %1", page._ttsLabel(modelData))
                        }

                        PlasmaComponents3.Label {
                            text: page._ttsLabel(modelData)
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
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

                    // Guard against initial editText change overwriting saved config
                    property bool _ready: false

                    // Populate font list on load while preserving saved value
                    Component.onCompleted: {
                        model = Qt.fontFamilies()

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
                    onClicked: fontFamilyCombo.editText = ""
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
