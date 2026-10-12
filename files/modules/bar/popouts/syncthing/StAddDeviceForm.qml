import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    readonly property var draft: Syncthing.deviceDraft

    function update(changes: var): void {
        Syncthing.deviceDraft = Object.assign({}, Syncthing.deviceDraft, changes);
    }

    spacing: Tokens.spacing.small

    StSection {
        text: Tr.tr("Add remote device")

        IconButton {
            type: IconButton.Text
            icon: "close"
            onClicked: Syncthing.closeForm()
        }
    }

    StyledTextField {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        verticalPadding: Tokens.padding.small
        placeholderText: Tr.tr("Device ID")
        supportingText: Tr.tr("Find it under Actions → Show ID on the other device")
        text: root.draft.id
        onTextEdited: root.update({
            id: text
        })
        Component.onCompleted: forceActiveFocus()
    }

    StyledTextField {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        verticalPadding: Tokens.padding.small
        placeholderText: Tr.tr("Name (optional)")
        text: root.draft.name
        onTextEdited: root.update({
            name: text
        })
        onAccepted: Syncthing.submitDevice()
    }

    StyledText {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        text: Tr.tr("After adding, share folders with the folder icon on the device. The other device must add this one too.")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.small

        TextButton {
            type: TextButton.Text
            text: Tr.tr("Copy my ID")
            onClicked: Syncthing.copyId(Syncthing.myId)
        }

        TextButton {
            text: Tr.tr("Add device")
            disabled: !root.draft.id.trim()
            onClicked: Syncthing.submitDevice()
        }
    }
}
