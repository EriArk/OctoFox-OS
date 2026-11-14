import QtQuick

Item {
    id: root
    required property var entry
    property bool selected: false
    property bool opening: false
    signal activated()
    objectName: "crate-tile-" + entry.id
    readonly property var artNames: ["new", "workshop", "adventure", "arcade", "strategy", "tools"]
    readonly property string artName: artNames[Math.max(0, Math.min(5, Number(entry.art) || 0))]
    readonly property bool artReady: chest.status === Image.Ready
    readonly property real labelHeight: 29
    Rectangle {
        anchors.fill: parent; radius: 14
        color: root.selected ? Theme.surfaceColor("#16d5b155") : "transparent"
        border.width: root.selected ? 2 : 0; border.color: Theme.focus
    }
    Image {
        id: chest
        objectName: "crate-art-" + root.entry.id
        x: 8; y: 3; width: parent.width - 16
        height: Math.max(1,parent.height - root.labelHeight - 3)
        source: "qrc:/crates/low-poly/" + root.artName + ".png"
        sourceSize: Qt.size(512,320)
        fillMode: Image.PreserveAspectFit; asynchronous: true
        visible: !animationLoader.active || !animationLoader.item
    }
    Loader {
        id: animationLoader
        objectName: "crate-opening-" + root.entry.id
        anchors.fill: chest
        active: root.visible && root.opening && !Theme.reducedMotion
        sourceComponent: Item {
            AnimatedSprite {
                objectName: "crate-opening-sprite"
                source: "qrc:/crates/low-poly/" + root.artName + "-opening.png"
                frameWidth: 256; frameHeight: 160; frameCount: 6
                frameDuration: 30; loops: 1; running: true; interpolate: false
                finishBehavior: AnimatedSprite.FinishAtFinalFrame
                width: Math.min(parent.width,parent.height * 1.6)
                height: width / 1.6
                anchors.centerIn: parent
            }
        }
    }
    Text {
        x: 8; y: parent.height - root.labelHeight; width: parent.width - 16
        height: root.labelHeight - 2
        text: root.entry.title; color: Theme.ink
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        font.family: Theme.displayFamily; font.pixelSize: 21; font.weight: Font.Medium
        fontSizeMode: Text.Fit; minimumPixelSize: 15; elide: Text.ElideRight
    }
    MouseArea { anchors.fill: parent; onClicked: root.activated(); cursorShape: Qt.PointingHandCursor }
    Accessible.role: Accessible.Button
    Accessible.name: entry.title
    Accessible.description: entry.subtitle || ""
    Accessible.onPressAction: root.activated()
}
