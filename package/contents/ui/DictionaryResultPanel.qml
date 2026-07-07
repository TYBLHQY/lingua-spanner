// Free Dictionary API result panel (extracted from main.qml)
// Renders English dictionary definitions, phonetics, origin, and audio.

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtMultimedia

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Rectangle {
    id: pane

    // --- public properties ---
    property var result: null

    FontStyle { id: fs }

    // --- layout ---
    visible: pane.result !== null
    Layout.fillWidth: true
    radius: Kirigami.Units.smallSpacing
    color: Kirigami.Theme.backgroundColor
    border.color: Kirigami.Theme.focusColor
    border.width: 1
    implicitHeight: dictCol.implicitHeight + Kirigami.Units.smallSpacing * 2

    ColumnLayout {
        id: dictCol
        anchors {
            fill: parent
            margins: Kirigami.Units.smallSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        // No result / error notice
        PlasmaComponents3.Label {
            visible: pane.result && (
                pane.result.error ||
                pane.result.exp.length === 0)
            text: pane.result && pane.result.error
                ? pane.result.error
                : i18n("No dictionary results found.")
            color: pane.result && pane.result.error
                ? Kirigami.Theme.negativeTextColor
                : Kirigami.Theme.disabledTextColor
            font.italic: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Phonetic text
        PlasmaComponents3.Label {
            visible: pane.result && pane.result.phonetic
                && pane.result.phonetic.length > 0
            text: pane.result.phonetic
            font.bold: true
            color: Kirigami.Theme.neutralTextColor
            font.pixelSize: fs.large
            Layout.fillWidth: true
        }

        // Origin / etymology
        PlasmaComponents3.Label {
            visible: pane.result && pane.result.origin
                && pane.result.origin.length > 0
            text: i18n("Origin: %1", pane.result.origin)
            font.italic: true
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            font.pixelSize: fs.secondary
            Layout.fillWidth: true
        }

        // Audio bar
        Rectangle {
            visible: pane.result && pane.result.audio
                && pane.result.audio.length > 0
            Layout.fillWidth: true
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: Kirigami.Units.smallSpacing
            implicitHeight: dictAudioRow.implicitHeight + Kirigami.Units.smallSpacing

            RowLayout {
                id: dictAudioRow
                anchors {
                    fill: parent
                    leftMargin: Kirigami.Units.smallSpacing
                    rightMargin: Kirigami.Units.smallSpacing
                }
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: pane.result ? pane.result.audio : []

                    delegate: QQC2.Button {
                        id: dictAudioBtn
                        required property var modelData
                        text: modelData.text ? modelData.text : i18n("Play")
                        icon.name: "media-playback-start"
                        flat: true
                        Accessible.name: i18n("Play pronunciation")
                        Layout.fillWidth: true
                        onClicked: {
                            dictAudioPlayer.source = modelData.url
                            dictAudioPlayer.play()
                        }
                    }
                }
            }

            MediaPlayer {
                id: dictAudioPlayer
                audioOutput: AudioOutput {}
                onErrorOccurred: console.log("dictAudioPlayer error:", error, errorString)
            }
        }

        // Definitions (exp)
        Repeater {
            model: pane.result ? pane.result.exp : []

            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // Part of speech label
                PlasmaComponents3.Label {
                    visible: modelData.po.length > 0
                    text: modelData.po
                    font.bold: true
                    color: Kirigami.Theme.neutralTextColor
                    font.pixelSize: fs.base
                }


                // Definitions
                Repeater {
                    model: modelData.tr

                    delegate: Rectangle {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.backgroundColor
                        radius: Kirigami.Units.smallSpacing
                        implicitHeight: dictTrEdit.height + Kirigami.Units.smallSpacing

                        TextEdit {
                            id: dictTrEdit
                            anchors {
                                left: parent.left
                                right: parent.right
                                margins: Kirigami.Units.smallSpacing
                            }
                            text: pane.grayBrackets(modelData)
                            textFormat: TextEdit.RichText
                            wrapMode: TextEdit.WordWrap
                            font.pixelSize: fs.secondary
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
