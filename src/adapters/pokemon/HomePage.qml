import QtQuick
import TrainerOS
Item {
    id: root
    required property var shell
    readonly property var currentAdventure: shell.home
    readonly property bool hasParty: shell.experienceModel.party.activities.hasParty
    readonly property bool compact: height < 210
    readonly property var badges: currentAdventure.badgeSlots || []
    clip: true
    Column {
        id: heading; objectName: "home-adapter-heading"
        width: parent.width; spacing: 2
        Text { width: parent.width; text: root.currentAdventure.world || "Your adventure"; color: "#c8dec7"; font.pixelSize: 11; elide: Text.ElideRight }
        Text { width: parent.width; text: root.currentAdventure.adventure || ""; color: "#fff4ce"; font.family: Theme.displayFamily; font.pixelSize: root.compact ? 22 : 26; elide: Text.ElideRight }
        Text { visible: !root.compact && text.length > 0; width: parent.width; text: root.currentAdventure.progressNote || ""; color: "#bfd6bf"; font.pixelSize: 10; elide: Text.ElideRight }
    }
    // A quiet progress strip leaves room for all six companions above host actions.
    Item {
        id: progress; objectName: "home-adapter-progress"
        y: heading.height + (root.compact ? 8 : 12)
        width: parent.width; height: root.compact ? 46 : 58
        Item {
            id: badgeStrip; objectName: "home-badge-tray"
            width: parent.width * .65; height: parent.height
            Text { text: "BADGES"; color: "#bfd6bf"; font.pixelSize: 10; font.letterSpacing: 1 }
            Text { anchors.right: parent.right; text: (root.currentAdventure.badges || "—") + (root.badges.length ? " / " + root.badges.length : ""); color: "#fff4ce"; font.pixelSize: 11; font.bold: true }
            Row {
                y: 17; width: parent.width; spacing: 4
                Repeater {
                    model: root.badges
                    LeagueBadge {
                        required property int index
                        required property var modelData
                        objectName: "home-badge-" + index
                        assetSource: modelData.image; badgeState: modelData.state
                        width: Math.max(0,(badgeStrip.width-(root.badges.length-1)*4)/Math.max(1,root.badges.length))
                        height: progress.height-17
                    }
                }
            }
            Text { y: 23; width: parent.width; visible: !root.badges.length; text: root.currentAdventure.badges === "—" ? "No badge data yet" : "Badge identities unavailable"; color: "#bfd6bf"; font.pixelSize: 10; elide: Text.ElideRight }
        }
        Rectangle { x: badgeStrip.width+12; width: 1; height: parent.height-2; color: "#40bfd6bf" }
        Column {
            x: badgeStrip.width+25; width: parent.width-x; spacing: root.compact ? 6 : 12
            Text { width: parent.width; text: "Caught  " + (root.currentAdventure.caught || "—"); color: "#fff4ce"; font.pixelSize: root.compact ? 12 : 14; elide: Text.ElideRight }
            Text { width: parent.width; text: root.currentAdventure.recordedTime || "—"; color: "#d2e3cc"; font.pixelSize: 11; elide: Text.ElideRight }
        }
    }
    HomeParty {
        objectName: "home-party"; anchors { left: parent.left; right: parent.right }
        y: progress.y+progress.height+6
        height: Math.max(0,root.height-y); activity: root.shell.experienceModel.party.activities
        visible: root.hasParty && height>=35
        playing: root.visible && !Theme.reducedMotion && shell.unobstructed && !shell.quickAppsOpen && !shell.drawerOpen
    }
    Text { y: progress.y+progress.height+12; width: parent.width; visible: !root.hasParty; text: root.currentAdventure.milestone || "Your team will appear after an in-game save."; color: "#c8dec7"; font.pixelSize: 11; elide: Text.ElideRight }
}
