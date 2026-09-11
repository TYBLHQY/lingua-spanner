// Youdao dictionary result panel (extracted from main.qml)
// Renders dictionary definitions, exam types, and word forms.
// Content only — no frame or background of its own.

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: pane

    // --- public properties ---
    property var result: null

    FontStyle { id: fs }

    readonly property var _flatModel: {
        if (!pane.result || !pane.result.exp) return []
        var m = []
        var exp = pane.result.exp
        for (var i = 0; i < exp.length; i++) {
            var trs = exp[i].tr || []
            if (trs.length === 0) continue
            m.push({ role: "po", text: exp[i].po || "" })
            m.push({ role: "tr", text: pane.grayBrackets(trs[0]) })
            for (var j = 1; j < trs.length; j++) {
                m.push({ role: "padding", text: "" })
                m.push({ role: "tr", text: pane.grayBrackets(trs[j]) })
            }
        }
        return m
    }

    readonly property bool _hasPo: {
        if (!pane.result || !pane.result.exp) return false
        for (var i = 0; i < pane.result.exp.length; i++) {
            if (pane.result.exp[i].po && pane.result.exp[i].po.length > 0)
                return true
        }
        return false
    }

    // --- layout ---
    visible: pane.result !== null
    Layout.fillWidth: true
    implicitHeight: youdaoCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: youdaoCol
        anchors {
            fill: parent
            margins: Kirigami.Units.smallSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        // No result notice
        PlasmaComponents3.Label {
            visible: pane.result && pane.result.exp.length === 0
            text: i18n("No dictionary results found.")
            color: Kirigami.Theme.disabledTextColor
            font.italic: true
            Layout.fillWidth: true
        }

        // Exam type tags
        Flow {
            visible: pane.result && pane.result.examType && pane.result.examType.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: pane.result ? pane.result.examType : []

                delegate: PlasmaComponents3.Label {
                    required property string modelData
                    text: modelData
                    color: Kirigami.Theme.linkColor
                    font.pixelSize: fs.small
                }
            }
        }

        // Forms
        Flow {
            visible: pane.result && pane.result.form && pane.result.form.length > 0
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: pane.result ? pane.result.form : []

                delegate: Rectangle {
                    required property var modelData
                    color: "transparent"
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1
                    radius: Kirigami.Units.smallSpacing
                    implicitHeight: formLabel.implicitHeight + Kirigami.Units.smallSpacing
                    implicitWidth: formLabel.implicitWidth + Kirigami.Units.smallSpacing + 10

                    PlasmaComponents3.Label {
                        id: formLabel
                        anchors.centerIn: parent
                        text: modelData.form + " " + modelData.type
                        font.pixelSize: fs.small
                    }
                }
            }
        }

        // Definitions (exp)
        ColumnLayout {
            visible: pane.result && pane.result.exp && pane.result.exp.length > 0
            Layout.fillWidth: true
            spacing: 2

            // With POS → 2-column grid
            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true
                visible: pane._hasPo

                // Headers
                PlasmaComponents3.Label {
                    text: i18n("词性")
                    font.bold: true
                    font.pixelSize: fs.small
                    color: Kirigami.Theme.disabledTextColor
                }
                PlasmaComponents3.Label {
                    text: i18n("释义")
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
                    model: pane._flatModel

                    delegate: PlasmaComponents3.Label {
                        text: modelData.role === "padding" ? "" : modelData.text
                        font.bold: modelData.role === "po"
                        font.pixelSize: modelData.role === "po" ? fs.small : fs.base
                        font.family: fs.family || undefined
                        color: modelData.role === "po" ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                        textFormat: modelData.role === "tr" ? Text.StyledText : Text.PlainText
                        wrapMode: modelData.role === "tr" ? Text.WordWrap : Text.NoWrap
                        Layout.fillWidth: modelData.role === "tr"
                        Layout.alignment: modelData.role === "po" ? Qt.AlignTop : Qt.AlignVCenter
                    }
                }
            }

            // No POS → simple list
            ColumnLayout {
                visible: !pane._hasPo
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: pane.result ? pane.result.exp : []

                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true

                        Repeater {
                            model: modelData.tr

                            delegate: TextEdit {
                                required property string modelData
                                Layout.fillWidth: true
                                text: pane.grayBrackets(modelData)
                                textFormat: TextEdit.RichText
                                wrapMode: TextEdit.WordWrap
                                font.pixelSize: fs.base
                                font.family: fs.family || undefined
                                color: Kirigami.Theme.textColor
                                readOnly: true
                                selectByMouse: true
                                height: contentHeight
                            }
                        }
                    }
                }
            }
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
