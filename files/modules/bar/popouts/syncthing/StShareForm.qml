pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Checklist form. shareFolder: pick devices for a folder.
// deviceFolders: pick folders shared with a device.
ColumnLayout {
    id: root

    readonly property bool forFolder: Syncthing.form === "shareFolder"
    readonly property var folder: Syncthing.folders.find(f => f.id === Syncthing.formTarget) ?? null
    readonly property var device: Syncthing.devices.find(d => d.id === Syncthing.formTarget) ?? null
    readonly property list<var> options: forFolder ? Syncthing.devices.map(d => ({
                id: d.id,
                name: d.name,
                icon: d.connected ? "devices" : "devices_off"
            })) : Syncthing.folders.map(f => ({
                id: f.id,
                name: f.label,
                icon: f.paused ? "folder_off" : "folder"
            }))

    spacing: Tokens.spacing.small

    StSection {
        text: root.forFolder ? Tr.tr("Share “%1” with").arg(root.folder?.label ?? "") : Tr.tr("Folders shared with %1").arg(root.device?.name ?? "")

        IconButton {
            type: IconButton.Text
            icon: "close"
            onClicked: Syncthing.closeForm()
        }
    }

    StyledText {
        visible: root.options.length === 0
        text: root.forFolder ? Tr.tr("Add a remote device first") : Tr.tr("No folders yet")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    Repeater {
        model: root.options

        RowLayout {
            id: option

            required property var modelData

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall

            MaterialIcon {
                text: option.modelData.icon
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: option.modelData.name
                elide: Text.ElideRight
            }

            StyledSwitch {
                checked: Syncthing.shareDraft.includes(option.modelData.id)
                onToggled: Syncthing.toggleShare(option.modelData.id)
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        text: Tr.tr("Unsharing keeps local files on both devices.")
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
            text: Tr.tr("Cancel")
            onClicked: Syncthing.closeForm()
        }

        TextButton {
            text: Tr.tr("Save")
            disabled: root.options.length === 0
            onClicked: {
                if (root.forFolder)
                    Syncthing.setFolderDevices(Syncthing.formTarget, Syncthing.shareDraft);
                else
                    Syncthing.setDeviceFolders(Syncthing.formTarget, Syncthing.shareDraft);
            }
        }
    }
}
