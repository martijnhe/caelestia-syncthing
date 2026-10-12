import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Inline confirmation card driven by Syncthing.confirm
StyledRect {
    id: root

    readonly property var spec: Syncthing.confirm

    visible: spec !== null
    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2
    radius: Tokens.rounding.medium
    color: Colours.palette.m3errorContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: root.spec?.title ?? ""
            color: Colours.palette.m3onErrorContainer
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: text
            text: root.spec?.body ?? ""
            color: Colours.palette.m3onErrorContainer
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Tokens.spacing.small

            TextButton {
                type: TextButton.Text
                text: Tr.tr("Cancel")
                onClicked: Syncthing.dismissConfirm()
            }

            TextButton {
                text: root.spec?.confirmText ?? Tr.tr("Confirm")
                onClicked: Syncthing.runConfirm()
            }
        }
    }
}
