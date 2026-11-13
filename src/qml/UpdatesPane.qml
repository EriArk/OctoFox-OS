import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var flow
    property bool takesFocus: false
    Text { x: 8; y: 10; text: root.flow.notesOpen ? "What's new" : root.flow.recoveryOpen ? "Recovery & maintenance" : "Software updates"; color: Theme.ink; font.pixelSize: 24; font.weight: Font.DemiBold }
    Flickable {
        ScrollBar.vertical: SettingsScrollBar {}
        id: page; x: 0; y: 51; width: parent.width; height: parent.height-y; clip: true
        visible: !root.flow.notesOpen; interactive: !root.flow.confirming
        contentHeight: content.height+12; boundsBehavior: Flickable.StopAtBounds
        function followFocus() {
            if (!root.takesFocus || !visible || root.flow.confirming) return
            for(let i=0;i<buttons.count;++i) {
                const item=buttons.itemAt(i)
                if(!item || item.modelData.index!==root.flow.focusIndex)continue
                const top=item.mapToItem(content,0,0).y, bottom=top+item.height+8
                contentY=Math.max(0,Math.min(Math.max(0,contentHeight-height),top<contentY?top:bottom>contentY+height?bottom-height:contentY))
                if(i===0)contentY=0
            }
        }
        onHeightChanged: Qt.callLater(followFocus)
        Connections { target: root.flow; function onChanged() { Qt.callLater(page.followFocus) } }
        Column {
            id: content; x: 4; width: parent.width-12; spacing: 0
            Column {
                x: 8; width: parent.width-16; spacing: 7; bottomPadding: 16
                visible: !root.flow.recoveryOpen
                Text { objectName: "updates-installed"; width: parent.width; text: "OctoFox OS  ·  "+root.flow.installedVersion; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Theme.muted; font.pixelSize: 13 }
                Text { width: parent.width; visible: root.flow.version.length>0; text: root.flow.version+(root.flow.sizeText.length?"  ·  "+root.flow.sizeText:""); textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Theme.ink; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { objectName: "updates-status"; width: parent.width; text: root.flow.confirming ? "Ready for your confirmation." : root.flow.message; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: root.flow.status==="error" || root.flow.status==="blocked" ? Theme.textColor("#853b24") : Theme.muted; font.pixelSize: 14 }
                Rectangle { width: parent.width; height: 4; radius: 2; color: Theme.divider; visible: root.flow.busy || root.flow.status==="paused"
                    Rectangle { width: parent.width*(root.flow.progress>=0?root.flow.progress:0.2); height: parent.height; radius: 2; color: Theme.accent }
                }
                Text { width: parent.width; visible: root.flow.lastChecked.length>0; text: "Last checked: "+root.flow.lastChecked; color: Theme.muted; font.pixelSize: 12 }
            }
            Text { x: 8; width: parent.width-16; bottomPadding: 16; visible: root.flow.recoveryOpen; text: "Check or restore your OctoFox OS installation. Restarting requires a separate confirmation."; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
            Text { x: 8; width: parent.width-16; bottomPadding: 12; visible: root.flow.recoveryOpen; text: root.flow.message; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
            Repeater {
                id: buttons; model: root.flow.confirming ? [] : root.flow.pageActions
                SettingsRow {
                    required property int index; required property var modelData
                    objectName: "updates-"+modelData.id
                    width: parent.width; height: implicitHeight
                    title: modelData.label
                    detail: modelData.id==="channel" ? "Alpha is available. Beta and Stable are coming later." : modelData.id==="background" ? "Notify when an update is available. Download and install manually." : modelData.id==="recovery" ? "Previous version, repair and installed files" : ""
                    kind: !modelData.enabled ? "unavailable" : modelData.id==="background" ? "toggle" : "action"
                    checked: root.flow.backgroundChecks
                    primary: index===0 && !root.flow.recoveryOpen
                    selected: root.takesFocus && root.flow.focusIndex===modelData.index
                    onActivated: root.flow.activate(modelData.index)
                }
            }
            Text { x: 8; width: parent.width-16; topPadding: 16; visible: !root.flow.recoveryOpen; text: "Host system updates are managed separately. App updates are in Apps › Crates."; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: 12 }
            onPositioningComplete: Qt.callLater(page.followFocus)
        }
    }
    Flickable {
        ScrollBar.vertical: SettingsScrollBar {}
        id: notes; x: 8; y: 52; width: parent.width-16; height: parent.height-y-56; clip: true
        visible: root.flow.notesOpen; contentHeight: noteText.height; boundsBehavior: Flickable.StopAtBounds
        onVisibleChanged: if(visible)contentY=0
        Text { id: noteText; width: parent.width; text: root.flow.notes; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: Theme.ink; font.pixelSize: 16 }
        Connections { target: root.flow; function onNotesScrollRequested(direction) { notes.contentY=Math.max(0,Math.min(Math.max(0,notes.contentHeight-notes.height),notes.contentY+direction*80)) } }
    }
    SettingsRow { objectName: "updates-notes-back"; x: 4; y: parent.height-48; width: parent.width-12; height: 48; visible: root.flow.notesOpen; title: "Back to Updates"; selected: visible && root.takesFocus; onActivated: root.flow.closeNotes() }
    Rectangle {
        anchors.fill: parent; visible: root.flow.confirming; color: Theme.surface; z: 5
        MouseArea { anchors.fill: parent }
        Column {
            x: 24; width: parent.width-48; anchors.verticalCenter: parent.verticalCenter; spacing: 18
            Text { width: parent.width; text: "Restart OctoFox OS?"; color: Theme.ink; font.pixelSize: 24; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: root.flow.message; color: Theme.muted; font.pixelSize: 16; wrapMode: Text.WordWrap }
            Column { width: parent.width; spacing: 8
                Repeater { model: root.flow.confirming ? root.flow.pageActions : []
                    SettingsRow {
                        required property var modelData; required property int index
                        objectName: "updates-"+modelData.id; width: parent.width; height: implicitHeight
                        title: index===0 ? "Cancel" : "Confirm and restart"; primary: index===1
                        selected: root.takesFocus && root.flow.focusIndex===modelData.index
                        onActivated: root.flow.activate(modelData.index)
                    }
                }
            }
        }
    }
}
