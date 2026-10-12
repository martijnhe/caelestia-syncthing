import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Section header with optional trailing action buttons
RowLayout {
    id: root

    property alias text: label.text
    default property alias actions: actionRow.data

    Layout.fillWidth: true
    Layout.topMargin: Tokens.spacing.small
    Layout.rightMargin: Tokens.padding.extraSmall
    spacing: Tokens.spacing.small

    StyledText {
        id: label

        Layout.fillWidth: true
        color: Colours.palette.m3primary
        font: Tokens.font.body.small
    }

    RowLayout {
        id: actionRow

        spacing: 0
    }
}
