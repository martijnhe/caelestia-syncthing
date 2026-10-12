pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    readonly property var draft: Syncthing.folderDraft

    function update(changes: var): void {
        Syncthing.folderDraft = Object.assign({}, Syncthing.folderDraft, changes);
    }

    spacing: Tokens.spacing.small

    StSection {
        text: root.draft.fromOffer ? Tr.tr("Accept folder offer") : Tr.tr("Add folder")

        IconButton {
            type: IconButton.Text
            icon: "close"
            onClicked: Syncthing.closeForm()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.small

        StyledTextField {
            Layout.fillWidth: true
            verticalPadding: Tokens.padding.small
            placeholderText: Tr.tr("Path, e.g. ~/Sync")
            text: root.draft.path
            onTextEdited: root.update({
                path: text
            })
            Component.onCompleted: forceActiveFocus()
        }

        IconButton {
            type: IconButton.Tonal
            icon: "folder_open"
            onClicked: Syncthing.browseFolder()
        }
    }

    StyledTextField {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        verticalPadding: Tokens.padding.small
        placeholderText: Tr.tr("Label (optional)")
        text: root.draft.label
        onTextEdited: root.update({
            label: text
        })
    }

    StyledTextField {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        verticalPadding: Tokens.padding.small
        placeholderText: Tr.tr("Folder ID")
        supportingText: root.draft.fromOffer ? Tr.tr("Must match the ID on the other device") : Tr.tr("Generated; shared folders need the same ID everywhere")
        readOnly: root.draft.fromOffer ?? false
        text: root.draft.id
        onTextEdited: root.update({
            id: text
        })
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.small
        text: Syncthing.devices.length ? Tr.tr("Share with") : Tr.tr("No remote devices yet; the folder stays local only")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Repeater {
        model: Syncthing.devices

        RowLayout {
            id: deviceRow

            required property var modelData

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall

            MaterialIcon {
                text: deviceRow.modelData.connected ? "devices" : "devices_off"
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: deviceRow.modelData.name
                elide: Text.ElideRight
            }

            StyledSwitch {
                checked: root.draft.devices.includes(deviceRow.modelData.id)
                onToggled: {
                    const list = root.draft.devices.filter(d => d !== deviceRow.modelData.id);
                    root.update({
                        devices: checked ? [...list, deviceRow.modelData.id] : list
                    });
                }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        Layout.topMargin: Tokens.spacing.small
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.small

        TextButton {
            type: TextButton.Text
            text: Tr.tr("Cancel")
            onClicked: Syncthing.closeForm()
        }

        TextButton {
            text: Tr.tr("Add folder")
            disabled: !root.draft.path.trim()
            onClicked: Syncthing.submitFolder(false)
        }
    }
}
