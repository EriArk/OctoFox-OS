import QtQuick

Item {
    id: root
    required property var shell
    readonly property var hall: shell.hall
    enabled: !shell.drawerOpen
    readonly property bool takesFocus: visible && !shell.adapterMenuOpen && !shell.drawerOpen && !hall.editor.open && !hall.account.open && !shell.menuOpen && !shell.keyboard.open && shell.notice.length === 0
    readonly property bool detailOpen: hall.route === "archive-detail" || hall.route === "achievement-detail"
    Item {
    anchors.fill: parent; visible: !root.hall.overview
    PageHeader { id: hallHeader; title: root.hall.archive ? "Hall of Fame" : "RetroAchievements"; trailing: root.hall.archive ? "Every journey leaves a story" : "Your account's achievements" }
    MountedPanel {
        x: 0; y: hallHeader.height; width: parent.width; height: root.height < 350 ? 52 : 68; visible: !root.detailOpen; color: Theme.surfaceColor("#d2dcd6")
        Rectangle { x: 0; y: -parent.y; width: 6; height: parent.y; color: parent.color }
        Rectangle { anchors.right: parent.right; y: -parent.y; width: 6; height: parent.y; color: parent.color }
        Text { x: 24; y: 5; text: root.hall.archive ? "Adventure memories" : "Account collection · All matched Adventures"; color: Theme.ink; font.pixelSize: 21; font.weight: Font.DemiBold }
        Text { x: 24; y: 30; width: 495; text: root.hall.status; elide: Text.ElideRight; color: Theme.muted; font.pixelSize: 14 }
    }
    Item {
        anchors.fill: parent; visible: !root.detailOpen
        Rectangle {
            x: 0; y: hallHeader.height + (root.height < 350 ? 52 : 68); width: root.width * .57; height: Math.max(0, root.height - 71 - y); color: Theme.surfaceColor("#e2e7de")
            // Reveal the complete focused row above the attached action panel.
            ControllerList {
                objectName: "hall-list"
                x: 19; y: 0; width: parent.width - 38; height: parent.height
                model: root.hall.rows; currentIndex: root.hall.rowIndex
                rowTints: !root.hall.archive
                namePrefix: "hall-row-"; tint: root.hall.archive ? "#c6b4df" : Theme.green
                takesFocus: root.takesFocus && !root.hall.overview && !root.detailOpen && root.hall.zone === "list"
                onActivated: row => root.shell.activate(row, "list")
            }
            Text {
                x: 28; y: 34; width: parent.width - 56; text: root.hall.emptyMessage; textFormat: Text.PlainText
                wrapMode: Text.WordWrap; color: Theme.ink; font.pixelSize: 21
                visible: root.hall.rows.length === 0
            }
        }
        Rectangle {
            x: root.width * .57; y: hallHeader.height + (root.height < 350 ? 52 : 68); width: parent.width - x; height: Math.max(0, root.height - 71 - y); color: Theme.surfaceColor("#edf0df")
            TrainerEmblem { x: 18; y: 12; width: 66; height: 66; emblem: "compass" }
            Text { x: 96; y: 22; width: parent.width - 110; wrapMode: Text.WordWrap; text: root.hall.archive ? "A JOURNEY\nREMEMBERED" : "ACHIEVEMENT\nRECORDS"; color: Theme.muted; font.pixelSize: 13; font.letterSpacing: 1.3 }
            Text { x: 18; y: 84; width: parent.width - 46; text: root.hall.detail.title; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 22; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { x: 18; y: 115; width: parent.width - 46; text: root.hall.detail.summary; wrapMode: Text.WordWrap; maximumLineCount: 1; elide: Text.ElideRight; color: Theme.muted; font.pixelSize: 15 }
        }
    }
    Item {
        anchors.fill: parent; visible: root.detailOpen
        Text { x: 28; y: hallHeader.height + 8; width: parent.width - 56; text: root.hall.detail.title; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 27; font.weight: Font.DemiBold; elide: Text.ElideRight }
        Rectangle {
            x: 0; y: hallHeader.height + 51; width: root.width * .55; height: Math.max(0,root.height-y-76); color: Theme.surfaceColor("#e2e7de")
            Grid {
                id: teamGrid; x: 12; y: 8; width: parent.width-24; columns: 3; spacing: 9; visible: root.hall.archive
                Repeater {
                    model: root.hall.team
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: (teamGrid.width-18)/3; height: Math.min(51,(teamGrid.parent.height-25)/2); radius: 12; color: Theme.surfaceColor("#f5f4e9"); border.color: Theme.surfaceColor("#bacbbd")
                        Rectangle {
                            x: 8; y: 8; width: 22; height: 22; radius: 11; color: modelData.known ? Theme.yellow : Theme.surfaceColor("#d6dfd5")
                            Text { anchors.centerIn: parent; text: index + 1; color: Theme.ink; font.pixelSize: 12; font.bold: true }
                        }
                        Text { x: 35; y: 6; width: parent.width-41; text: modelData.name; color: Theme.ink; font.pixelSize: 14; elide: Text.ElideRight }
                        Text { x: 35; y: parent.height-17; text: modelData.level; color: Theme.muted; font.pixelSize: 12 }
                    }
                }
            }
            Item {
                anchors.fill: parent; visible: !root.hall.archive
                Rectangle {
                    x: 26; y: 12; width: 122; height: 122; radius: 61
                    color: root.hall.detail.earnedState === "earned" ? Theme.yellow : root.hall.detail.earnedState === "locked" ? Theme.surfaceColor("#c8d3d0") : Theme.surfaceColor("#d9cfdf")
                    border.width: 3; border.color: Theme.surfaceColor("#829687")
                    Text { anchors.centerIn: parent; text: root.hall.detail.earnedState === "earned" ? "✓" : root.hall.detail.earnedState === "locked" ? "—" : "?"; font.pixelSize: 54; font.bold: true; color: Theme.ink }
                }
                Text { x: 170; y: 22; width: 297; text: root.hall.detail.summary; wrapMode: Text.WordWrap; color: Theme.ink; font.pixelSize: 23; font.weight: Font.DemiBold }
                Text { x: 170; y: 91; width: 297; text: root.hall.detail.time; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: 14 }
            }
        }
        Column {
            x: root.width * .55 + 18; y: hallHeader.height + 51; width: root.width-x-18; spacing: 5
            Text { width: parent.width; text: root.hall.detail.world + (root.hall.archive ? " · " + root.hall.detail.time : ""); color: Theme.ink; font.pixelSize: 17; elide: Text.ElideRight }
            Text { width: parent.width; text: root.hall.detail.date; color: Theme.muted; font.pixelSize: 13; elide: Text.ElideRight }
            Text { width: parent.width; text: root.hall.detail.description; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 15; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
            Text { width: parent.width; text: root.hall.detail.source; color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
        }
    }
    MountedPanel {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 71; color: Theme.surfaceColor("#ccdcd1")
        Row {
            x: root.shell.chooseAdventureAvailable ? Theme.adventureCutoutWidth : 24; y: 19; spacing: 14
            Repeater {
                model: root.hall.actions
                delegate: CapButton {
                    required property int index
                    required property var modelData
                    objectName: "hall-action-" + index
                    width: 274; height: 42; label: modelData.label
                    tint: index === 0 ? Theme.blue : Theme.yellow
                    enabled: modelData.enabled; opacity: enabled ? 1 : 0.5
                    selected: root.takesFocus && !root.hall.overview && root.hall.zone === "actions" && root.hall.focusIndex === index && enabled
                    onActivated: root.shell.activate(index, "actions")
                }
            }
        }
        Text {
            anchors { right: parent.right; rightMargin: 25 }
            y: 2; width: 270
            text: root.detailOpen ? ""
                : root.hall.rows.length > 0 ? root.hall.rows.length + " records"
                : "No records to display"
            color: Theme.muted; font.pixelSize: 13; horizontalAlignment: Text.AlignRight
        }
    }
    }
    JourneyPanel { anchors.fill: parent; shell: root.shell; visible: root.hall.overview; takesFocus: root.takesFocus && root.hall.overview }
    ArchiveEditorPanel { anchors.fill: parent; shell: root.shell; visible: root.hall.editor.open }
    AchievementAccountPanel { anchors.fill: parent; shell: root.shell; visible: root.hall.account.open }
}
