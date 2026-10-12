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

    readonly property list<var> visibleFolders: Syncthing.folders.filter(f => {
        const q = Syncthing.query.trim().toLowerCase();
        if (q && !f.label.toLowerCase().includes(q) && !f.path.toLowerCase().includes(q) && !f.id.toLowerCase().includes(q))
            return false;
        switch (Syncthing.filter) {
        case "syncing":
            return !f.paused && (Syncthing.isBusyState(f.state) || f.needFiles > 0);
        case "problems":
            return !f.paused && (f.state === "error" || f.errors > 0);
        case "paused":
            return f.paused;
        }
        return true;
    }).sort((a, b) => a.label.localeCompare(b.label))

    function folderStatus(f: var): string {
        if (f.paused)
            return Tr.tr("Unlinked · sync paused");
        if (f.state === "error" || f.errors > 0)
            return Tr.trN("%n error", "%n errors", Math.max(f.errors, 1));
        if (f.state === "syncing" || f.state === "sync-preparing")
            return Tr.tr("Syncing · %1 left").arg(Syncthing.formatBytes(f.needBytes));
        if (f.state === "scanning")
            return Tr.tr("Scanning");
        if (f.state === "cleaning")
            return Tr.tr("Cleaning up");
        if (f.state.endsWith("-waiting"))
            return Tr.tr("Waiting");
        if (f.needFiles > 0)
            return Tr.trN("Out of sync · %n item", "Out of sync · %n items", f.needFiles);
        if (f.state === "idle") {
            const shared = f.devices.length === 0 ? Tr.tr("local only") : Tr.trN("%n device", "%n devices", f.devices.length);
            return Tr.tr("Up to date · %1 · %2").arg(Syncthing.formatBytes(f.globalBytes)).arg(shared);
        }
        return f.state;
    }

    spacing: Tokens.spacing.small

    // Search and filters
    StyledTextField {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        visible: Syncthing.folders.length > 3 || Syncthing.query
        verticalPadding: Tokens.padding.small
        leadingIcon: "search"
        placeholderText: Tr.tr("Search folders")
        text: Syncthing.query
        onTextEdited: Syncthing.query = text
    }

    Flow {
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: [
                {
                    id: "all",
                    label: Tr.tr("All")
                },
                {
                    id: "syncing",
                    label: Tr.tr("Syncing")
                },
                {
                    id: "problems",
                    label: Tr.tr("Problems")
                },
                {
                    id: "paused",
                    label: Tr.tr("Unlinked")
                }
            ]

            StChip {
                required property var modelData

                text: modelData.label
                checked: Syncthing.filter === modelData.id
                badge: modelData.id === "problems" ? Syncthing.problemCount : 0
                onClicked: Syncthing.filter = modelData.id
            }
        }
    }

    // Incoming folder offers
    StSection {
        visible: Syncthing.pendingFolders.length > 0
        text: Tr.tr("Folder offers")
    }

    Repeater {
        model: ScriptModel {
            values: Syncthing.pendingFolders
        }

        StEntry {
            id: offer

            required property var modelData

            icon: "create_new_folder"
            iconColour: Colours.palette.m3primary
            title: modelData.label
            subtitle: modelData.encrypted ? Tr.tr("From %1 · encrypted, use the web UI").arg(Syncthing.deviceName(modelData.deviceId)) : Tr.tr("From %1 · %2").arg(Syncthing.deviceName(modelData.deviceId)).arg(modelData.id)

            IconButton {
                type: IconButton.Text
                icon: "check"
                visible: !offer.modelData.encrypted
                onClicked: Syncthing.acceptPendingFolder(offer.modelData)
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: Syncthing.askConfirm({
                    title: Tr.tr("Ignore offer for “%1”?").arg(offer.modelData.label),
                    body: Tr.tr("The offer is dismissed until %1 shares it again.").arg(Syncthing.deviceName(offer.modelData.deviceId)),
                    confirmText: Tr.tr("Ignore"),
                    action: () => Syncthing.dismissPendingFolder(offer.modelData.id, offer.modelData.deviceId)
                })
            }
        }
    }

    StSection {
        text: Tr.tr("Folders")

        IconButton {
            type: IconButton.Text
            icon: "add"
            onClicked: Syncthing.startAddFolder()
        }
    }

    StyledText {
        visible: root.visibleFolders.length === 0
        Layout.rightMargin: Tokens.padding.extraSmall
        text: Syncthing.folders.length === 0 ? Tr.tr("No folders yet. Select + to add one.") : Tr.tr("No folders match")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(folderColumn.implicitHeight, 360)
        contentHeight: folderColumn.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: folderColumn

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: ScriptModel {
                    values: root.visibleFolders
                    objectProp: "id"
                }

                StEntry {
                    id: folder

                    required property var modelData
                    readonly property bool problem: !modelData.paused && (modelData.state === "error" || modelData.errors > 0)

                    icon: modelData.paused ? "folder_off" : problem ? "folder_supervised" : Syncthing.isBusyState(modelData.state) ? "sync" : "folder"
                    iconSpin: !modelData.paused && Syncthing.isBusyState(modelData.state)
                    iconColour: problem ? Colours.palette.m3error : modelData.paused ? Colours.palette.m3outline : Colours.palette.m3onSurface
                    title: modelData.label
                    subtitle: `${root.folderStatus(modelData)}\n${Syncthing.displayPath(modelData.path)}`
                    subtitleColour: problem ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    clickable: true
                    onTitleClicked: Syncthing.openFolder(modelData.path)

                    IconButton {
                        type: IconButton.Text
                        icon: "share"
                        onClicked: Syncthing.openForm("shareFolder", folder.modelData.id)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "refresh"
                        disabled: folder.modelData.paused || folder.modelData.state === "scanning"
                        onClicked: Syncthing.rescan(folder.modelData.id)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: folder.modelData.paused ? "link" : "link_off"
                        onClicked: Syncthing.setFolderPaused(folder.modelData.id, !folder.modelData.paused)
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "delete"
                        visible: folder.modelData.paused
                        onClicked: Syncthing.askConfirm({
                            title: Tr.tr("Forget “%1”?").arg(folder.modelData.label),
                            body: Tr.tr("Removes it from Syncthing. Files in %1 are kept.").arg(Syncthing.displayPath(folder.modelData.path)),
                            confirmText: Tr.tr("Forget"),
                            action: () => Syncthing.forgetFolder(folder.modelData.id)
                        })
                    }
                }
            }
        }
    }
}
