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

// Folder errors, sync conflicts and installation details
StyledFlickable {
    id: root

    readonly property list<var> errorFolders: Object.keys(Syncthing.folderErrors).map(id => ({
                id,
                label: Syncthing.folderLabel(id),
                errors: Syncthing.folderErrors[id]
            }))

    implicitWidth: column.implicitWidth
    implicitHeight: Math.min(column.implicitHeight, 480)
    contentHeight: column.implicitHeight
    clip: true
    flickableDirection: Flickable.VerticalFlick

    ColumnLayout {
        id: column

        width: root.width
        spacing: Tokens.spacing.small

        // Errors
        StSection {
            text: Tr.tr("Folder errors")
        }

        StyledText {
            visible: root.errorFolders.length === 0
            text: Syncthing.problemCount > 0 ? Tr.tr("A folder is in an error state; see its status under Folders") : Tr.tr("No errors")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        Repeater {
            model: root.errorFolders

            ColumnLayout {
                id: errFolder

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: errFolder.modelData.label
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }

                Repeater {
                    model: errFolder.modelData.errors.slice(0, 10)

                    StEntry {
                        required property var modelData

                        icon: "error"
                        iconColour: Colours.palette.m3error
                        title: modelData.path
                        subtitle: modelData.error
                        subtitleColour: Colours.palette.m3error
                    }
                }
            }
        }

        // Conflicts
        StSection {
            text: Tr.tr("Sync conflicts")

            IconButton {
                type: IconButton.Text
                icon: "search"
                disabled: Syncthing.conflictScanRunning || Syncthing.folders.length === 0
                onClicked: Syncthing.scanConflicts()
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall
            text: Syncthing.conflictScanRunning ? Tr.tr("Searching folders…") : !Syncthing.conflictScanDone ? Tr.tr("Select search to look for .sync-conflict files") : Syncthing.conflicts.length === 0 ? Tr.tr("No conflicts found") : Tr.trN("%n conflict file. Keep the right version and delete the other.", "%n conflict files. Keep the right version and delete the others.", Syncthing.conflicts.length)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.Wrap
        }

        Repeater {
            model: Syncthing.conflicts.slice(0, 30)

            StEntry {
                required property string modelData

                icon: "difference"
                iconColour: Colours.palette.m3tertiary
                title: modelData.split("/").pop()
                subtitle: Syncthing.displayPath(modelData.split("/").slice(0, -1).join("/"))
                clickable: true
                onTitleClicked: Syncthing.openFolder(modelData.split("/").slice(0, -1).join("/"))
            }
        }

        // Installation
        StSection {
            text: Tr.tr("Installation")
        }

        Repeater {
            model: [
                [Tr.tr("Syncthing"), Syncthing.installed ? (Syncthing.version || Tr.tr("installed")) : Tr.tr("not installed")],
                [Tr.tr("Service"), Syncthing.externallyManaged ? Tr.tr("running, managed outside the user service") : Syncthing.serviceState],
                [Tr.tr("API"), Syncthing.baseUrl],
                [Tr.tr("Config"), Syncthing.displayPath(Syncthing.configPath)],
                [Tr.tr("Folders"), `${Syncthing.folders.length}`],
                [Tr.tr("Devices"), Tr.tr("%1 of %2 connected").arg(Syncthing.connectedCount).arg(Syncthing.devices.length)]
            ]

            RowLayout {
                id: info

                required property var modelData

                Layout.fillWidth: true
                Layout.rightMargin: Tokens.padding.extraSmall

                StyledText {
                    Layout.preferredWidth: 72
                    text: info.modelData[0]
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: info.modelData[1]
                    font: Tokens.font.body.small
                    elide: Text.ElideMiddle
                }
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: !Syncthing.installed
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            disabled: Syncthing.busy
            text: Tr.tr("Install Syncthing")
            icon: "download"
            onClicked: Syncthing.install()
        }
    }
}
