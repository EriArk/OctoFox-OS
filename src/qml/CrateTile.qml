import QtQuick

Item {
    id: root
    required property var entry
    property bool featured: false
    property bool selected: false
    property bool opening: false
    signal activated()
    objectName: "crate-tile-" + entry.id
    readonly property var artNames: ["new", "workshop", "adventure", "arcade", "strategy", "tools"]
    readonly property string artName: artNames[Math.max(0, Math.min(5, Number(entry.art) || 0))]
    readonly property bool artReady: chest.status === Image.Ready
    readonly property real labelHeight: featured ? 48 : 31
    readonly property real imageHeight: Math.max(1, featured ? height - 8 : height - labelHeight)
    readonly property real textLeft: featured ? width * 0.44 : 8
    // Catalogue renders come from the same low-poly mesh used for opening.
    // No live 3D view, idle timer or full-screen effects are needed per tile.
    Rectangle {
        anchors.fill: parent; radius: 15
        color: root.selected ? Theme.surfaceColor("#16d5b155") : "transparent"
        border.width: root.selected ? 2 : 0; border.color: Theme.focus
    }
    Image {
        id: chest
        objectName: "crate-art-" + root.entry.id
        x: root.featured ? 5 : (parent.width - width) / 2
        y: root.featured ? 0 : -8
        width: root.featured ? parent.width * 0.43 : Math.min(parent.width - 12, root.imageHeight * 1.6)
        height: root.featured ? root.imageHeight : root.imageHeight + 12
        source: "qrc:/crates/low-poly/" + root.artName + ".png"
        sourceSize: Qt.size(512, 448)
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
            frameWidth: 256; frameHeight: 224; frameCount: 6
            frameDuration: 30; loops: 1; running: true; interpolate: false
            finishBehavior: AnimatedSprite.FinishAtFinalFrame
            // Match PreserveAspectFit on the closed image, including its baseline.
            width: Math.min(parent.width, parent.height * 512 / 448)
            height: width * 448 / 512
            anchors.centerIn: parent
          }
        }
    }
    Text {
        x: root.textLeft; y: root.featured ? parent.height * 0.40 : parent.height - root.labelHeight
        width: parent.width - x - 8
        height: root.featured ? 27 : 29
        text: root.entry.title; color: Theme.ink
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        font.family: Theme.displayFamily; font.pixelSize: root.featured ? 24 : 17
        font.weight: Font.Medium; fontSizeMode: Text.Fit; minimumPixelSize: 13
        elide: Text.ElideRight
    }
    Text {
        visible: root.featured
        x: root.textLeft; y: parent.height * 0.40 + 31; width: parent.width - x - 10
        text: root.entry.subtitle; color: Theme.muted; font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
    }
    MouseArea { anchors.fill: parent; onClicked: root.activated(); cursorShape: Qt.PointingHandCursor }
    Accessible.role: Accessible.Button
    Accessible.name: entry.title
    Accessible.onPressAction: root.activated()
}
