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

// Live file activity. Blue: synced or added, red: deleted or failed,
// green: a remote device downloading from this one.
ColumnLayout {
    id: root

    readonly property color blue: Colours.palette.term4
    readonly property color red: Colours.palette.m3error
    readonly property color green: Colours.palette.m3success
    property real now: Date.now()

    function colourFor(kind: string): color {
        return kind === "delete" || kind === "error" ? red : kind === "upload" ? green : blue;
    }

    function iconFor(kind: string): string {
        return kind === "delete" ? "delete" : kind === "error" ? "error" : kind === "upload" ? "upload" : "sync";
    }

    spacing: Tokens.spacing.small

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        spacing: Tokens.spacing.medium

        Repeater {
            model: [
                {
                    c: root.blue,
                    t: Tr.tr("Synced / added")
                },
                {
                    c: root.red,
                    t: Tr.tr("Deleted")
                },
                {
                    c: root.green,
                    t: Tr.tr("Uploading")
                }
            ]

            RowLayout {
                id: legend

                required property var modelData

                spacing: Tokens.spacing.extraSmall

                StyledRect {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: legend.modelData.c
                }

                StyledText {
                    text: legend.modelData.t
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        IconButton {
            type: IconButton.Text
            icon: "clear_all"
            visible: Syncthing.activity.length > 0
            onClicked: Syncthing.activity = []
        }
    }

    StSection {
        visible: Syncthing.uploads.length > 0
        text: Tr.tr("Uploading now")
    }

    Repeater {
        model: ScriptModel {
            values: Syncthing.uploads
        }

        StEntry {
            required property var modelData

            icon: "upload"
            iconColour: root.green
            title: Tr.tr("%1 ← %2").arg(Syncthing.deviceName(modelData.device)).arg(Syncthing.folderLabel(modelData.folder))
            subtitle: modelData.files.length === 1 ? modelData.files[0] : Tr.trN("%n file", "%n files", modelData.files.length)
        }
    }

    StSection {
        text: Tr.tr("Recent changes")
    }

    StyledText {
        visible: Syncthing.activity.length === 0
        text: Syncthing.online ? Tr.tr("No file activity since the shell started") : Tr.tr("Syncthing is not running")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    StyledFlickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(activityColumn.implicitHeight, 380)
        contentHeight: activityColumn.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ColumnLayout {
            id: activityColumn

            width: parent.width
            spacing: Tokens.spacing.small

            Repeater {
                model: ScriptModel {
                    values: Syncthing.activity
                    objectProp: "key"
                }

                StEntry {
                    id: item

                    required property var modelData

                    icon: root.iconFor(modelData.kind)
                    iconColour: root.colourFor(modelData.kind)
                    title: modelData.path
                    subtitle: `${Syncthing.folderLabel(modelData.folder)} · ${modelData.detail} · ${root.now, Syncthing.relativeTime(modelData.time)}`
                    subtitleColour: modelData.kind === "error" ? root.red : Colours.palette.m3onSurfaceVariant
                    clickable: true
                    onTitleClicked: {
                        const folder = Syncthing.folders.find(f => f.id === modelData.folder);
                        if (folder) {
                            const parts = `${folder.path}/${modelData.path}`.split("/");
                            parts.pop();
                            Syncthing.openFolder(parts.join("/"));
                        }
                    }
                }
            }
        }
    }
}
