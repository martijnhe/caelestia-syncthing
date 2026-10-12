import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Small selectable pill, used for tabs and filters
StyledRect {
    id: root

    property string text
    property bool checked
    property int badge

    signal clicked

    implicitWidth: label.implicitWidth + (badge > 0 ? badgeRect.implicitWidth + Tokens.spacing.extraSmall : 0) + Tokens.padding.medium * 2
    implicitHeight: label.implicitHeight + Tokens.padding.extraSmall * 2
    radius: Tokens.rounding.full
    color: checked ? Colours.palette.m3secondaryContainer : "transparent"
    border.width: checked ? 0 : 1
    border.color: Colours.palette.m3outlineVariant

    StateLayer {
        color: root.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        onClicked: root.clicked()
    }

    StyledText {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        text: root.text
        color: root.checked ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    StyledRect {
        id: badgeRect

        visible: root.badge > 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: label.right
        anchors.leftMargin: Tokens.spacing.extraSmall
        implicitWidth: Math.max(implicitHeight, badgeText.implicitWidth + Tokens.padding.extraSmall * 2)
        implicitHeight: badgeText.implicitHeight
        radius: Tokens.rounding.full
        color: Colours.palette.m3error

        StyledText {
            id: badgeText

            anchors.centerIn: parent
            text: root.badge
            color: Colours.palette.m3onError
            font: Tokens.font.label.small
        }
    }
}
