// Lingua Spanner configuration — Display & Behavior

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

KCMUtils.SimpleKCM {
    id: page

    // KConfig XT bindings — shortcuts
    property string cfg_shortcutOpen: "Meta+1"
    property string cfg_shortcutOpenDefault: "Meta+1"
    property string cfg_shortcutPick: "Meta+2"
    property string cfg_shortcutPickDefault: "Meta+2"

    // KConfig XT binding — auto translate on selection
    property alias cfg_autoTranslateOnSelection: autoTranslateSwitch.checked
    property bool cfg_autoTranslateOnSelectionDefault: true

    // KConfig XT bindings — display
    property alias cfg_fontSizeBase: fontSizeSpin.value
    property int cfg_fontSizeBaseDefault: 14
    property string cfg_fontFamily: ""
    property string cfg_fontFamilyDefault: ""

    // UI
    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // Display settings
        Kirigami.Heading {
            level: 3
            text: i18n("Display")
            Layout.fillWidth: true
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

                    property bool _ready: false

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

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        Kirigami.Heading {
            level: 3
            text: i18n("Behavior")
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Switch {
                id: autoTranslateSwitch
                Accessible.name: i18n("Auto translate on selection")
            }
            PlasmaComponents3.Label {
                text: i18n("Auto look up text selection when panel opens via shortcut")
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item { Layout.fillHeight: true }
    }
}
