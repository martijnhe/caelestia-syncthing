pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.small

    StSection {
        text: Tr.tr("This device")
    }

    StEntry {
        icon: "computer"
        iconColour: Colours.palette.m3primary
        title: Syncthing.myName || Tr.tr("This device")
        subtitle: Syncthing.myId

        IconButton {
            type: IconButton.Text
            icon: "content_copy"
            onClicked: Syncthing.copyId(Syncthing.myId)
        }
    }

    // Devices asking to connect
    StSection {
        visible: Syncthing.pendingDevices.length > 0
        text: Tr.tr("Wants to connect")
    }

    Repeater {
        model: ScriptModel {
            values: Syncthing.pendingDevices
        }

        StEntry {
            id: pending

            required property var modelData

            icon: "device_unknown"
            iconColour: Colours.palette.m3primary
            title: modelData.name
            subtitle: `${modelData.id.slice(0, 23)}…${modelData.address ? " · " + modelData.address : ""}`

            IconButton {
                type: IconButton.Text
                icon: "check"
                onClicked: Syncthing.acceptPendingDevice(pending.modelData)
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: Syncthing.askConfirm({
                    title: Tr.tr("Ignore %1?").arg(pending.modelData.name),
                    body: Tr.tr("Device %1 will be dismissed until it tries to connect again.").arg(pending.modelData.id.slice(0, 7)),
                    confirmText: Tr.tr("Ignore"),
                    action: () => Syncthing.dismissPendingDevice(pending.modelData.id)
                })
            }
        }
    }

    StSection {
        text: Tr.tr("Remote devices")

        IconButton {
            type: IconButton.Text
            icon: Syncthing.devices.length > 0 && Syncthing.devices.every(d => d.paused) ? "play_arrow" : "pause"
            visible: Syncthing.devices.length > 1
            onClicked: Syncthing.setAllPaused(!Syncthing.devices.every(d => d.paused))
        }

        IconButton {
            type: IconButton.Text
            icon: "add"
            onClicked: Syncthing.startAddDevice()
        }
    }

    StyledText {
        visible: Syncthing.devices.length === 0
        text: Tr.tr("No remote devices. Select + to add one by its ID.")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(deviceColumn.implicitHeight, 320)
        contentHeight: deviceColumn.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: deviceColumn

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: ScriptModel {
                    values: [...Syncthing.devices].sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
                    objectProp: "id"
                }

                StEntry {
                    id: device

                    required property var modelData
                    readonly property int sharedCount: Syncthing.folders.filter(f => f.devices.includes(modelData.id)).length

                    icon: modelData.connected ? "devices" : "devices_off"
                    iconColour: modelData.paused ? Colours.palette.m3outline : modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    title: modelData.name
                    subtitle: {
                        const shared = Tr.trN("%n folder", "%n folders", sharedCount);
                        if (modelData.paused)
                            return Tr.tr("Paused · %1").arg(shared);
                        if (!modelData.connected)
                            return Tr.tr("Disconnected · %1").arg(shared);
                        if (modelData.completion >= 0 && modelData.completion < 100)
                            return Tr.tr("Connected · %1% synced · %2").arg(Math.floor(modelData.completion)).arg(shared);
                        return Tr.tr("Connected · up to date · %1").arg(shared);
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "folder_shared"
                        onClicked: Syncthing.openForm("deviceFolders", device.modelData.id)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: device.modelData.paused ? "play_arrow" : "pause"
                        onClicked: Syncthing.setDevicePaused(device.modelData.id, !device.modelData.paused)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "content_copy"
                        onClicked: Syncthing.copyId(device.modelData.id)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "delete"
                        onClicked: Syncthing.askConfirm({
                            title: Tr.tr("Remove %1?").arg(device.modelData.name),
                            body: Tr.tr("Stops syncing with this device and unshares its folders. No files are deleted."),
                            confirmText: Tr.tr("Remove"),
                            action: () => Syncthing.removeDevice(device.modelData.id)
                        })
                    }
                }
            }
        }
    }
}
