import QtQuick

Rectangle {
    id: root
    required property var entry
    property bool official: false
    property bool horizontal: false
    property bool selected: false
    property bool compact: false
    signal activated()
    signal favoriteRequested()
    radius: 8; color: Theme.paper
    border.width: selected ? 3 : 1
    border.color: selected ? Theme.focusGlow : Theme.divider
    readonly property real captionHeight: official ? (compact ? 120 : 136) : (compact ? 53 : 61)
    Accessible.role: Accessible.Button
    Accessible.name: (entry.title || "Bazaar") + ", " + (official ? "Official" : (entry.ownerName || "")) + (entry.preview===true ? ", test placeholder, in development" : "")
    Accessible.onPressAction: root.activated()
    Item {
        id: art; x: 4; y: 4; width: root.horizontal ? Math.floor(parent.width*.44) : parent.width-8; height: root.horizontal ? parent.height-8 : Math.max(24,parent.height-root.captionHeight-5); clip: true
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
            visible: !root.official; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
            width: 30; height: 30; radius: 8; color: Theme.paper
            MenuGlyph { anchors.centerIn: parent; width: 22; height: 22; glyph: root.entry.badge || "shop"; ink: Theme.ink }
        }
        Rectangle {
            visible: root.official; x: 9; y: 9; width: 88; height: 24; radius: 3; color: Theme.paper
            Text { anchors.centerIn: parent; text: "OFFICIAL ISLAND"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.7; color: Theme.ink }
        }
    }
    Column {
        visible: !root.horizontal
        x: root.official ? 18 : 12; y: art.y+art.height+(root.official ? 13 : 8); width: parent.width-(root.official ? 36 : 24); spacing: root.official ? 7 : 4
        Text {
            width: parent.width-(root.official ? 0 : 18); text: root.entry.title || "Bazaar"; textFormat: Text.PlainText
            font.family: Theme.displayFamily; font.pixelSize: root.official ? (root.compact ? 26 : 30) : (root.compact ? 14 : 16)
            color: Theme.ink; elide: Text.ElideRight
        }
        Text {
            visible: root.official; width: parent.width
            text: root.entry.walkthrough ? "Lanterns, little shops and familiar faces." : "The island market is taking shape."; font.pixelSize: root.compact ? 11 : 12; color: Theme.muted
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
                text: root.official ? (root.entry.walkthrough ? "EXPLORE THE ISLAND   →" : "IN DEVELOPMENT") : (root.entry.visitors===undefined || root.entry.visitors===null ? (root.entry.access==="closed"?"Closed":"Not open yet") : root.entry.visitors+" visiting")
                font.pixelSize: root.official ? 12 : 11; font.bold: root.official; color: root.official ? Theme.ink : Theme.muted
            }
        }
    }
    Rectangle {
        visible: root.horizontal && root.entry.preview===true
        x: art.x+8; y: art.y+art.height-29; width: 100; height: 21; radius: 4; color: "#e31b393b"
        Text { anchors.centerIn:parent; text:"TEST BAZAAR"; color:"#ffffff";font.pixelSize:10;font.bold:true;font.letterSpacing:0.5 }
    }
    Item {
        visible: root.horizontal
        x:art.x+art.width+14; y:14; width:parent.width-x-14; height:parent.height-28
        Column {
            width:parent.width;spacing:7
            Text { width:parent.width-24; text:root.entry.title || "Bazaar";textFormat:Text.PlainText;font.family:Theme.displayFamily;font.pixelSize:root.compact?20:23;color:Theme.ink;elide:Text.ElideRight }
            Row {
                spacing:6
                Rectangle { width:20;height:20;radius:10;color:Theme.green
                    Text { anchors.centerIn:parent;text:(root.entry.ownerName || "?").slice(0,1).toUpperCase();font.pixelSize:11;font.bold:true;color:Theme.ink;textFormat:Text.PlainText }
                }
                Text { height:20;verticalAlignment:Text.AlignVCenter;text:root.entry.ownerName || "Player";textFormat:Text.PlainText;font.pixelSize:12;color:Theme.muted }
            }
            Text { width:parent.width;text:root.entry.description || "A player-owned place to meet and trade.";textFormat:Text.PlainText;font.pixelSize:root.compact?11:12;color:Theme.muted;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight }
        }
        Row {
            anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;spacing:6
            Text { width:parent.width-58;text:root.entry.preview===true?"IN DEVELOPMENT":root.entry.visitors===undefined || root.entry.visitors===null?(root.entry.access==="closed"?"Closed":"Not open yet"):root.entry.visitors+" visiting";font.pixelSize:root.compact?10:11;font.bold:root.entry.preview===true;color:Theme.muted;elide:Text.ElideRight }
            Text { text:root.entry.preview===true?"Preview →":"Details →";font.pixelSize:11;font.bold:true;color:Theme.ink }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.activated() }
    Item {
        visible: !root.official; x: parent.width-35; y: root.horizontal ? 10 : art.height+7; width: 31; height: 30
        Text { anchors.centerIn: parent; text: root.entry.favorite ? "★" : "☆"; color: root.entry.favorite ? Theme.accent : Theme.muted; font.pixelSize: 21 }
        MouseArea { anchors.fill: parent; onClicked: root.favoriteRequested() }
        Accessible.role: Accessible.Button; Accessible.name: root.entry.favorite ? "Remove favorite" : "Add favorite"
        Accessible.onPressAction: root.favoriteRequested()
    }
}
