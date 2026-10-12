import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A list row: icon, title, subtitle and trailing action buttons
RowLayout {
    id: root

    property string icon
    property color iconColour: Colours.palette.m3onSurface
    property bool iconSpin
    property string title
    property string subtitle
    property color subtitleColour: Colours.palette.m3onSurfaceVariant
    property bool clickable
    default property alias actions: actionRow.data

    signal titleClicked

    Layout.fillWidth: true
    Layout.rightMargin: Tokens.padding.extraSmall
    spacing: Tokens.spacing.small

    MaterialIcon {
        id: icon

        text: root.icon
        color: root.iconColour
        fill: 1

        RotationAnimation on rotation {
            running: root.iconSpin
            from: 360
            to: 0
            duration: 1500
            loops: Animation.Infinite
            onStopped: icon.rotation = 0
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.spacing.extraSmall
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideMiddle
            font.underline: root.clickable && titleArea.containsMouse

            MouseArea {
                id: titleArea

                anchors.fill: parent
                enabled: root.clickable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.titleClicked()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text
            text: root.subtitle
            color: root.subtitleColour
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    RowLayout {
        id: actionRow

        spacing: 0
    }
}
