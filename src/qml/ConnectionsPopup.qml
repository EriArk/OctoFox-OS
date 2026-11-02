import QtQuick

Item {
    id: root
    required property var shell
    property point origin: Qt.point(-1,-1)
    property real preferredHeight: 380
    property real maximumHeight: height-24
    readonly property bool anchored: origin.y >= 0
    property string popupName: "start-network-popup"
    Rectangle { anchors.fill: parent; color: Theme.surfaceColor("#68182b29") }
    MouseArea { anchors.fill: parent; onClicked: root.shell.closeControlsNetwork(); onWheel: wheel => wheel.accepted=true }
    Rectangle {
        id: panel; objectName: root.popupName
        width: Math.min(490,root.width-32)
        height: Math.min(root.preferredHeight,root.maximumHeight,root.anchored?root.origin.y-20:root.maximumHeight)
        x: root.anchored ? Math.max(12,Math.min(root.width-width-12,root.origin.x-width+22)) : (root.width-width)/2
        y: root.anchored ? root.origin.y-height-10 : (root.height-height)/2
        radius: 18; color: Theme.paper; border.color: Theme.divider
        MouseArea { anchors.fill: parent }
        Text { x: 22; y: 18; text: root.shell.network.bluetooth ? "Bluetooth" : "Wi-Fi"; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 22 }
        SocialIconButton { objectName: "start-network-close"; anchors.right: parent.right; anchors.rightMargin: 15; y: 13; glyph: "close"; label: "Close connections"; onClicked: root.shell.closeControlsNetwork() }
        ConnectionsPane { x: 22; y: 47; width: parent.width-44; height: parent.height-y-12; shell: root.shell; quick: true; flat: true }
    }
}
