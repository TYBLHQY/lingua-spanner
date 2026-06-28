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
    property string cfg_deepseekModelList: ""
    property string cfg_deepseekModelListDefault: ""
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
    property string cfg_siliconFlowModelList: ""
    property string cfg_siliconFlowModelListDefault: ""
    property alias cfg_siliconFlowStream: sfStream.checked
    property bool cfg_siliconFlowStreamDefault: true

    // ── Mode list config (JSON arrays) ────────────────────
    property string cfg_modeOrder: '["youdao","deepseek","siliconflow","dictionary"]'
    property string cfg_modeOrderDefault: '["youdao","deepseek","siliconflow","dictionary"]'
    property string cfg_modeEnabled: '["youdao","deepseek","siliconflow","dictionary"]'
    property string cfg_modeEnabledDefault: '["youdao","deepseek","siliconflow","dictionary"]'

    property string cfg_shortcutOpen: "Meta+1"
    property string cfg_shortcutOpenDefault: "Meta+1"
    property string cfg_shortcutPick: "Meta+2"
    property string cfg_shortcutPickDefault: "Meta+2"

    property alias cfg_fontSizeBase: fontSizeSpin.value
    property int cfg_fontSizeBaseDefault: 14

    // ── Helper: persist/restore model lists as JSON strings ──
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

    // ── Mode list data ────────────────────────────────────
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

    // ── UI ────────────────────────────────────────────────────
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ── Mode list ────────────────────────────────
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

                    // Guard against initial editText change overwriting saved config
                    property bool _ready: false

                    Component.onCompleted: {
                        // Restore persisted model list if available
                        var saved = page.parseModelList(page.cfg_deepseekModelList)
                        if (saved)
                            model = saved

                        var idx = find(page.cfg_deepseekModel)
                        if (idx >= 0)
                            currentIndex = idx
                        else
                            editText = page.cfg_deepseekModel
                        _ready = true
                    }
                    onEditTextChanged: {
                        if (_ready)
                            page.cfg_deepseekModel = editText
                    }
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
                                    if (models.length > 0) {
                                        modelCombo.model = models
                                        page.cfg_deepseekModelList = page.stringifyModelList(models)
                                    }
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

                    // Guard against initial editText change overwriting saved config
                    property bool _ready: false

                    Component.onCompleted: {
                        // Restore persisted model list if available
                        var saved = page.parseModelList(page.cfg_siliconFlowModelList)
                        if (saved)
                            model = saved

                        var idx = find(page.cfg_siliconFlowModel)
                        if (idx >= 0)
                            currentIndex = idx
                        else
                            editText = page.cfg_siliconFlowModel
                        _ready = true
                    }
                    onEditTextChanged: {
                        if (_ready)
                            page.cfg_siliconFlowModel = editText
                    }
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
                                    if (chatModels.length > 0) {
                                        sfModelCombo.model = chatModels
                                        page.cfg_siliconFlowModelList = page.stringifyModelList(chatModels)
                                    }
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

        // ── Display settings ───────────────────────────
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
        }

        // ── Security note ────────────────────────────────────
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
