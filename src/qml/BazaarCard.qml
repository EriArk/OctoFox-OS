import QtQuick

Rectangle {
    id: root
    required property var entry
    property bool official: false
    property bool selected: false
    property bool compact: false
    signal activated()
    signal favoriteRequested()
    radius: 11; color: Theme.paper
    border.width: selected ? 3 : 1
    border.color: selected ? Theme.focusGlow : Theme.divider
    readonly property real captionHeight: official ? (compact ? 91 : 105) : (compact ? 53 : 61)
    Accessible.role: Accessible.Button
    Accessible.name: (entry.title || "Bazaar") + ", " + (official ? "Official" : (entry.ownerName || ""))
    Accessible.onPressAction: root.activated()
    Item {
        id: art; x: 4; y: 4; width: parent.width-8; height: Math.max(24,parent.height-root.captionHeight-5); clip: true
        Rectangle { anchors.fill: parent; color: Theme.selection }
        Image {
            id: cover; anchors.fill: parent; source: root.entry.cover || ""
            sourceSize.width: root.official ? 800 : 420; sourceSize.height: root.official ? 700 : 260
            asynchronous: true; fillMode: Image.PreserveAspectCrop
        }
        MenuGlyph {
            anchors.centerIn: parent; width: 40; height: 40; glyph: "community"; ink: Theme.muted
            visible: cover.status!==Image.Ready
        }
        Rectangle {
            visible: root.official; x: 9; y: 9; width: 67; height: 21; radius: 6; color: Theme.yellow
            Text { anchors.centerIn: parent; text: "OFFICIAL"; font.pixelSize: 10; font.bold: true; color: Theme.ink }
        }
    }
    Column {
        x: 12; y: art.y+art.height+8; width: parent.width-24; spacing: root.official ? 6 : 4
        Text {
            width: parent.width-(root.official ? 0 : 18); text: root.entry.title || "Bazaar"; textFormat: Text.PlainText
            font.family: Theme.displayFamily; font.pixelSize: root.official ? (root.compact ? 22 : 25) : (root.compact ? 14 : 16)
            color: Theme.ink; elide: Text.ElideRight
        }
        Text {
            visible: root.official; width: parent.width
            text: "Squares, shops and shared adventures."; font.pixelSize: root.compact ? 11 : 12; color: Theme.muted
            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        Row {
            width: parent.width; spacing: 5
            Rectangle {
                visible: !root.official; width: 18; height: 18; radius: 9; color: Theme.green
                Text { anchors.centerIn: parent; text: (root.entry.ownerName || "?").slice(0,1).toUpperCase(); color: Theme.ink; font.pixelSize: 10; textFormat: Text.PlainText }
            }
            Text { visible: !root.official; width: Math.max(20,parent.width-105); text: root.entry.ownerName || "Player"; textFormat: Text.PlainText; font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight }
            Text {
                text: root.official ? "Opening soon" : (root.entry.visitors===undefined ? "— visiting" : root.entry.visitors+" visiting")
                font.pixelSize: root.official ? 12 : 11; color: Theme.muted
            }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.activated() }
    Item {
        visible: !root.official; x: parent.width-35; y: art.height+7; width: 31; height: 30
        Text { anchors.centerIn: parent; text: root.entry.favorite ? "★" : "☆"; color: root.entry.favorite ? Theme.accent : Theme.muted; font.pixelSize: 21 }
        MouseArea { anchors.fill: parent; onClicked: root.favoriteRequested() }
        Accessible.role: Accessible.Button; Accessible.name: root.entry.favorite ? "Remove favorite" : "Add favorite"
        Accessible.onPressAction: root.favoriteRequested()
    }
}
