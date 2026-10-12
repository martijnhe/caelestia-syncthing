pragma ComponentBehavior: Bound

import "./syncthing"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts

    width: 400
    implicitWidth: 400
    spacing: Tokens.spacing.small
    focus: true

    Component.onCompleted: forceActiveFocus()

    // r rescan all, w web UI, p start/stop, s settings, q/esc back or close
    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        switch (event.key) {
        case Qt.Key_R:
            Syncthing.rescanAll();
            break;
        case Qt.Key_W:
            Syncthing.openWebUi();
            break;
        case Qt.Key_P:
            Syncthing.toggleRunning();
            break;
        case Qt.Key_S:
            Syncthing.page = Syncthing.page === "settings" ? "folders" : "settings";
            break;
        case Qt.Key_Q:
        case Qt.Key_Escape:
            if (Syncthing.confirm)
                Syncthing.dismissConfirm();
            else if (Syncthing.form)
                Syncthing.closeForm();
            else if (Syncthing.page === "settings")
                Syncthing.page = "folders";
            else
                root.popouts.hasCurrent = false;
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.padding.medium
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.small

        Image {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.rightMargin: Tokens.spacing.extraSmall
            source: Syncthing.logo
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: Syncthing.online ? 1 : 0.45
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: "Syncthing"
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (Syncthing.busy)
                        return Tr.tr("Working…");
                    if (!Syncthing.installed)
                        return Tr.tr("Not installed; see More");
                    if (!Syncthing.online)
                        return Syncthing.apiKey ? Tr.tr("Not running") : Tr.tr("No Syncthing config found");
                    const parts = [Tr.tr("%1 of %2 devices").arg(Syncthing.connectedCount).arg(Syncthing.devices.length)];
                    if (Syncthing.syncingCount > 0)
                        parts.push(Tr.trN("%n syncing", "%n syncing", Syncthing.syncingCount));
                    if (Syncthing.problemCount > 0)
                        parts.push(Tr.trN("%n problem", "%n problems", Syncthing.problemCount));
                    return parts.join(" · ");
                }
                color: Syncthing.problemCount > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
        }

        IconButton {
            type: IconButton.Text
            icon: "settings"
            onClicked: Syncthing.page = Syncthing.page === "settings" ? "folders" : "settings"
        }

        StyledSwitch {
            checked: Syncthing.online
            disabled: Syncthing.busy || !Syncthing.installed
            onToggled: Syncthing.setRunning(checked)
        }
    }

    // Tabs
    RowLayout {
        Layout.fillWidth: true
        visible: Syncthing.online && Syncthing.page !== "settings" && !Syncthing.form
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: [
                {
                    id: "folders",
                    label: Tr.tr("Folders"),
                    badge: Syncthing.pendingFolders.length
                },
                {
                    id: "devices",
                    label: Tr.tr("Devices"),
                    badge: Syncthing.pendingDevices.length
                },
                {
                    id: "activity",
                    label: Tr.tr("Activity"),
                    badge: 0
                },
                {
                    id: "more",
                    label: Tr.tr("More"),
                    badge: Object.keys(Syncthing.folderErrors).length
                }
            ]

            StChip {
                required property var modelData

                text: modelData.label
                badge: modelData.badge
                checked: Syncthing.page === modelData.id
                onClicked: Syncthing.page = modelData.id
            }
        }
    }

    // Error banner
    StyledRect {
        Layout.fillWidth: true
        visible: Syncthing.lastError !== ""
        implicitHeight: errorRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.medium
        color: Colours.palette.m3errorContainer

        RowLayout {
            id: errorRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "error"
                color: Colours.palette.m3onErrorContainer
            }

            StyledText {
                Layout.fillWidth: true
                text: Syncthing.lastError
                color: Colours.palette.m3onErrorContainer
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
            }

            IconButton {
                type: IconButton.Text
                icon: "close"
                onClicked: Syncthing.lastError = ""
            }
        }
    }

    StConfirm {}

    // Page body
    Loader {
        Layout.fillWidth: true
        sourceComponent: {
            if (Syncthing.page === "settings")
                return settingsPage;
            if (!Syncthing.online)
                return Syncthing.installed ? null : morePage;
            if (Syncthing.form === "addFolder")
                return addFolderForm;
            if (Syncthing.form === "addDevice")
                return addDeviceForm;
            if (Syncthing.form === "shareFolder" || Syncthing.form === "deviceFolders")
                return shareForm;
            switch (Syncthing.page) {
            case "devices":
                return devicesPage;
            case "activity":
                return activityPage;
            case "more":
                return morePage;
            }
            return foldersPage;
        }
    }

    // Footer
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        spacing: Tokens.spacing.small

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            disabled: !Syncthing.online
            text: Tr.tr("Web UI")
            icon: "open_in_new"
            onClicked: Syncthing.openWebUi()
        }

        IconTextButton {
            Layout.fillWidth: true
            type: IconTextButton.Tonal
            verticalPadding: Tokens.padding.extraSmall
            disabled: !Syncthing.online
            text: Tr.tr("Rescan all")
            icon: "refresh"
            onClicked: Syncthing.rescanAll()
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Tr.tr("r rescan · w web UI · p start/stop · s settings · esc close")
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
    }

    Component {
        id: foldersPage

        StFoldersPage {}
    }

    Component {
        id: devicesPage

        StDevicesPage {}
    }

    Component {
        id: activityPage

        StActivityPage {}
    }

    Component {
        id: morePage

        StMorePage {}
    }

    Component {
        id: settingsPage

        StSettingsPage {}
    }

    Component {
        id: addFolderForm

        StAddFolderForm {}
    }

    Component {
        id: addDeviceForm

        StAddDeviceForm {}
    }

    Component {
        id: shareForm

        StShareForm {}
    }
}
