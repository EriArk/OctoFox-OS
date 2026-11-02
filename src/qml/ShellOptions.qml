import QtQuick

Panel {
    id: root
    required property var shell
    readonly property var live: shell.liveGame
    radius: 30
    surface: Qt.tint(Theme.paper,"#09c29948")
    patterned: true
    Text { x: 27; y: 20; text: "Now"; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 29 }
    Text { x: 103; y: 32; text: root.shell.homeMenuCaption; color: Theme.muted; font.pixelSize: 14 }
    SocialIconButton { anchors.right: parent.right; anchors.rightMargin: 20; y: 19; icon: "x"; label: "Close"; onClicked: root.shell.closeHomeMenu() }
    Item {
        id: activity; x: 25; y: 77; width: parent.width-50; height: parent.height-y-25
        Rectangle { anchors.fill: parent; radius: 16; color: Theme.surfaceColor("#b5fffef9"); border.color: Theme.surfaceColor("#6694a899") }
        Text { id: title; x: 17; y: 15; width: parent.width-34; text: root.live.title || (root.shell.social.homeLobby.title ? "Together" : "Your activity"); color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 23; elide: Text.ElideRight; textFormat: Text.PlainText }
        ListView { id: actions; x: 12; y: 61; width: parent.width-24; height: parent.height-y-12; clip: true; spacing: 7
            model: root.shell.homeMenuActions; currentIndex: root.shell.homeMenuFocus
            onCurrentIndexChanged: if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
            delegate: ActivityRow { required property int index; required property var modelData
                width: actions.width; label: modelData.label; detail: modelData.detail || ""; selected: root.shell.homeMenuFocus===index
                glyph: modelData.id==="call" || modelData.id.indexOf("voice-")===0 ? "speaker" : modelData.id==="live-options" ? "settings" : modelData.id==="live-return" ? "play" : "party"
                accent: modelData.id==="live-return"?Theme.green:Theme.blue; enabled: modelData.enabled!==false
                onActivated: root.shell.activateHomeAction(modelData.id)
            }
        }
        Column { anchors.centerIn: parent; width: parent.width-56; spacing: 16; visible: actions.count===0
            MenuGlyph { anchors.horizontalCenter: parent.horizontalCenter; width: 46; height: 46; glyph: "play"; ink: Theme.rim }
            Text { width: parent.width; text: "A little breathing room"; font.family: Theme.displayFamily; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.ink }
            Text { width: parent.width; text: "Your running game, lobby and call will be here."; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.muted }
        }
    }
}
