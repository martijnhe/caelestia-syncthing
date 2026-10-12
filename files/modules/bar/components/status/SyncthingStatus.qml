import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// Syncthing logo: full colour when branded, tinted to the bar colour when themed.
// Spins while syncing, dims when offline, and shows a dot for problems or pending requests.
Item {
    id: root

    required property color colour
    readonly property bool branded: Syncthing.settings.iconStyle === "branded"

    implicitWidth: sizer.implicitHeight
    implicitHeight: sizer.implicitHeight

    // Match the size of the other Material status icons
    MaterialIcon {
        id: sizer

        visible: false
        text: "sync"
    }

    Image {
        id: logo

        anchors.fill: parent
        anchors.margins: 1
        source: root.branded ? Syncthing.logo : Syncthing.logoMono
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: Syncthing.online ? 1 : 0.45

        layer.enabled: !root.branded
        layer.effect: Colouriser {
            sourceColor: "black"
            colorizationColor: root.colour
        }

        RotationAnimation on rotation {
            running: Syncthing.syncing
            from: 0
            to: 360
            duration: 2000
            loops: Animation.Infinite
            onStopped: logo.rotation = 0
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    StyledRect {
        visible: Syncthing.online && (Syncthing.problemCount > 0 || Syncthing.pendingCount > 0)
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: -1
        implicitWidth: parent.width * 0.38
        implicitHeight: implicitWidth
        radius: Tokens.rounding.full
        color: Syncthing.problemCount > 0 ? Colours.palette.m3error : Colours.palette.m3primary
        border.width: 1.5
        border.color: Colours.tPalette.m3surfaceContainer
    }
}
