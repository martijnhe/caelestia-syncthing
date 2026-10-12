import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.small

    StSection {
        text: Tr.tr("Settings")

        IconButton {
            type: IconButton.Text
            icon: "close"
            onClicked: Syncthing.page = "folders"
        }
    }

    Toggle {
        label: Tr.tr("Branded bar icon")
        description: Tr.tr("Syncthing blue instead of the bar colour")
        checked: Syncthing.settings.iconStyle === "branded"
        onToggled: value => Syncthing.settings.iconStyle = value ? "branded" : "themed"
    }

    Toggle {
        label: Tr.tr("Notifications")
        description: Tr.tr("Toasts for errors, offers and new devices")
        checked: Syncthing.settings.notifications
        onToggled: value => Syncthing.settings.notifications = value
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Activity entries kept")
        }

        StyledSpinBox {
            from: 5
            to: 200
            stepSize: 5
            value: Syncthing.settings.activityLimit
            onValueModified: Syncthing.settings.activityLimit = value
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        type: IconTextButton.Tonal
        verticalPadding: Tokens.padding.extraSmall
        text: Tr.tr("Open settings file")
        icon: "edit"
        onClicked: Syncthing.openSettingsFile()
    }

    component Toggle: RowLayout {
        id: toggle

        required property string label
        property string description
        property alias checked: sw.checked

        signal toggled(value: bool)

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: toggle.label
            }

            StyledText {
                Layout.fillWidth: true
                text: toggle.description
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
            }
        }

        StyledSwitch {
            id: sw

            onToggled: toggle.toggled(checked)
        }
    }
}
