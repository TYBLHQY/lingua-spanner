// AI engine result panel (extracted from main.qml)
// Renders streaming and structured results from DeepSeek/SiliconFlow,
// including word analysis, collocations, and floating action buttons.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Rectangle {
    id: pane

    // --- public properties ---
    property string streamingInput: ""
    property bool translating: false
    property string streamingTranslation: ""
    property var aiResult: null

    FontStyle { id: fs }

    // --- signals ---
    signal cancelRequested()
    signal deleteRequested()
    signal refreshRequested()

    // --- computed flat models (mirror main.qml) ---
    readonly property var _flatWordModel: {
        if (!pane.aiResult || !pane.aiResult.words) return []
        var m = []
        var words = pane.aiResult.words
        for (var i = 0; i < words.length; i++) {
            m.push({ text: words[i].word || "", bold: true, rich: false, fillWidth: false, color: "" })
            m.push({ text: words[i].pos || "", bold: false, rich: false, fillWidth: false, color: Kirigami.Theme.neutralTextColor })
            m.push({ text: pane.grayBrackets(words[i].meaning || ""), bold: false, rich: true, fillWidth: true, color: "" })
        }
        return m
    }

    readonly property var _flatFreqModel: {
        if (!pane.aiResult || !pane.aiResult.frequently) return []
        var m = []
        var freq = pane.aiResult.frequently
        for (var i = 0; i < freq.length; i++) {
            m.push({ text: freq[i].phrase || "", bold: true, rich: false, fillWidth: false, color: "" })
            m.push({ text: pane.grayBrackets(freq[i].translation || ""), bold: false, rich: true, fillWidth: true, color: "" })
        }
        return m
    }

    readonly property var _flatExampleModel: {
        if (!pane.aiResult || !pane.aiResult.examples) return []
        var m = []
        var examples = pane.aiResult.examples
        for (var i = 0; i < examples.length; i++) {
            var sentence = examples[i].sentence || ""
            var trans = examples[i].translation || ""
            m.push({
                text: sentence + "<br>" + trans,
                rich: true,
                sentence: sentence,
                translation: trans
            })
        }
        return m
    }

    // --- layout ---
    visible: pane.streamingInput !== ""
    Layout.fillWidth: true
    radius: Kirigami.Units.smallSpacing
    color: Kirigami.Theme.backgroundColor
    implicitHeight: resultCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: resultCol
        anchors {
            fill: parent
            margins: Kirigami.Units.smallSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        // STREAMING MODE — raw text as it arrives
        ColumnLayout {
            visible: pane.translating
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            // Waiting state (no content yet)
            RowLayout {
                visible: pane.streamingTranslation === ""
                spacing: 4

                PlasmaComponents3.Label {
                    text: i18n("Waiting for response")
                    font.pixelSize: fs.base
                    font.family: fs.family || undefined
                    color: Kirigami.Theme.textColor
                }

                Row {
                    spacing: 3
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: 5; height: 5
                            radius: 2.5
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.3
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: pane.translating
                                PauseAnimation { duration: 200 * index }
                                NumberAnimation {
                                    from: 0.3; to: 1.0; duration: 400; easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    from: 1.0; to: 0.3; duration: 400; easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }

            // Streaming content
            TextEdit {
                visible: pane.streamingTranslation !== ""
                text: pane.streamingTranslation
                textFormat: TextEdit.PlainText
                font.pixelSize: fs.base
                font.family: fs.family || undefined
                color: Kirigami.Theme.textColor
                wrapMode: TextEdit.WordWrap
                Layout.fillWidth: true
                readOnly: true
                selectByMouse: true
                height: contentHeight
            }
        }

        // STRUCTURED RESULT — parsed JSON display
        ColumnLayout {
            visible: !pane.translating && pane.aiResult !== null
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Translation
            PlasmaComponents3.Label {
                text: i18n("Translation")
                font.bold: true
                font.pixelSize: fs.small
                color: Kirigami.Theme.neutralTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            TextEdit {
                text: pane.grayBrackets(pane.aiResult ? pane.aiResult.translate || pane.streamingTranslation : "")
                textFormat: TextEdit.RichText
                font.pixelSize: fs.large
                font.family: fs.family || undefined
                color: Kirigami.Theme.textColor
                wrapMode: TextEdit.WordWrap
                Layout.fillWidth: true
                readOnly: true
                selectByMouse: true
                height: contentHeight
            }

            // Words (词汇分析)
            ColumnLayout {
                visible: pane.aiResult && pane.aiResult.words && pane.aiResult.words.length > 0
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents3.Label {
                    text: i18n("Word Analysis")
                    font.bold: true
                    font.pixelSize: fs.small
                    color: Kirigami.Theme.neutralTextColor
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                GridLayout {
                    columns: 3
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    // Headers
                    PlasmaComponents3.Label {
                        text: i18n("Word")
                        font.bold: true
                        font.pixelSize: fs.small
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents3.Label {
                        text: i18n("POS")
                        font.bold: true
                        font.pixelSize: fs.small
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents3.Label {
                        text: i18n("Meaning")
                        font.bold: true
                        font.pixelSize: fs.small
                        color: Kirigami.Theme.disabledTextColor
                    }

                    // Separator
                    Rectangle {
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        height: 1
                        color: Kirigami.Theme.disabledTextColor
                        opacity: 0.2
                    }

                    // Data cells
                    Repeater {
                        model: pane._flatWordModel

                        delegate: Text {
                            required property var modelData
                            text: modelData.text
                            font.bold: modelData.bold || false
                            font.pixelSize: fs.base
                            font.family: fs.family || undefined
                            color: modelData.color || Kirigami.Theme.textColor
                            textFormat: modelData.rich ? Text.StyledText : Text.PlainText
                            wrapMode: modelData.fillWidth ? Text.WordWrap : Text.NoWrap
                            Layout.fillWidth: modelData.fillWidth || false
                            Layout.alignment: Qt.AlignTop
                        }
                    }
                }
            }

            // Frequently (常用搭配)
            ColumnLayout {
                visible: pane.aiResult && pane.aiResult.frequently && pane.aiResult.frequently.length > 0
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents3.Label {
                    text: i18n("Collocations")
                    font.bold: true
                    font.pixelSize: fs.small
                    color: Kirigami.Theme.neutralTextColor
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                GridLayout {
                    columns: 2
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    // Headers
                    PlasmaComponents3.Label {
                        text: i18n("Phrase")
                        font.bold: true
                        font.pixelSize: fs.small
                        color: Kirigami.Theme.disabledTextColor
                    }
                    PlasmaComponents3.Label {
                        text: i18n("Translation")
                        font.bold: true
                        font.pixelSize: fs.small
                        color: Kirigami.Theme.disabledTextColor
                    }

                    // Separator
                    Rectangle {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        height: 1
                        color: Kirigami.Theme.disabledTextColor
                        opacity: 0.2
                    }

                    // Data cells
                    Repeater {
                        model: pane._flatFreqModel

                        delegate: Text {
                            required property var modelData
                            text: modelData.text
                            font.bold: modelData.bold || false
                            font.pixelSize: fs.base
                            font.family: fs.family || undefined
                            color: modelData.color || Kirigami.Theme.textColor
                            textFormat: modelData.rich ? Text.StyledText : Text.PlainText
                            wrapMode: modelData.fillWidth ? Text.WordWrap : Text.NoWrap
                            Layout.fillWidth: modelData.fillWidth || false
                            Layout.alignment: Qt.AlignTop
                        }
                    }
                }
            }

            // Examples (例句)
            ColumnLayout {
                visible: pane.aiResult && pane.aiResult.examples && pane.aiResult.examples.length > 0
                Layout.fillWidth: true
                spacing: 2

                PlasmaComponents3.Label {
                    text: i18n("Examples")
                    font.bold: true
                    font.pixelSize: fs.small
                    color: Kirigami.Theme.neutralTextColor
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Repeater {
                    model: pane._flatExampleModel

                    delegate: ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        Text {
                            text: modelData.sentence
                            font.italic: true
                            font.pixelSize: fs.base
                            font.family: fs.family || undefined
                            color: Kirigami.Theme.textColor
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.translation
                            font.pixelSize: fs.base
                            font.family: fs.family || undefined
                            color: Kirigami.Theme.disabledTextColor
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                        }
                    }
                }
            }
        }
    }

    // Floating cancel button (streaming)
    QQC2.Button {
        visible: pane.translating
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium
        icon.name: "dialog-cancel"
        flat: true
        Accessible.name: i18n("Cancel translation")
        QQC2.ToolTip {
            text: i18n("Cancel")
            delay: Kirigami.Units.toolTipDelay
            visible: hovered
        }
        onClicked: pane.cancelRequested()
    }

    // Floating action buttons (copy + refresh + delete)
    Row {
        visible: !pane.translating && pane.aiResult !== null
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: 0

        QQC2.Button {
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
            icon.name: "edit-copy"
            flat: true
            Accessible.name: i18n("Copy result as JSON")
            QQC2.ToolTip {
                text: i18n("Copy JSON")
                delay: Kirigami.Units.toolTipDelay
                visible: hovered
            }
            onClicked: {
                var json = JSON.stringify(pane.aiResult, null, 2)
                var te = Qt.createQmlObject('import QtQuick; TextEdit { visible: false }', pane)
                te.text = json
                te.selectAll()
                te.copy()
                te.destroy()
            }
        }

        QQC2.Button {
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
            icon.name: "view-refresh"
            flat: true
            Accessible.name: i18n("Re-translate")
            QQC2.ToolTip {
                text: i18n("Re-translate")
                delay: Kirigami.Units.toolTipDelay
                visible: hovered
            }
            onClicked: pane.refreshRequested()
        }

        QQC2.Button {
            implicitWidth: Kirigami.Units.iconSizes.medium
            implicitHeight: Kirigami.Units.iconSizes.medium
            icon.name: "edit-delete"
            flat: true
            Accessible.name: i18n("Delete this result")
            QQC2.ToolTip {
                text: i18n("Delete from history")
                delay: Kirigami.Units.toolTipDelay
                visible: hovered
            }
            onClicked: pane.deleteRequested()
        }
    }

    // Gray out bracketed parenthetical notes
    function grayBrackets(text) {
        return text
            .replace(/&lt;([^&]*?)&gt;/g,                  m => '<font color="gray">' + m + '</font>')
            .replace(/<([^>]{2,15})>/g,                   (m, c) => c === 'br' ? m : '<font color="gray">' + m + '</font>')
            .replace(/（[^）]*）/g,       m => '<font color="gray">' + m + '</font>')
            .replace(/\([^)]*\)/g,        m => '<font color="gray">' + m + '</font>')
            .replace(/【[^】]*】/g,       m => '<font color="gray">' + m + '</font>')
            .replace(/\[[^\]]*\]/g,       m => '<font color="gray">' + m + '</font>')
            .replace(/\{[^}]*\}/g,        m => '<font color="gray">' + m + '</font>')
            .replace(/\n/g, '<br>')
    }
}
