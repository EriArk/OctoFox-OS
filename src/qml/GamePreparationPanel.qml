import QtQuick

Item {
    id: root
    required property var shell
    readonly property var flow: shell.gamePreparation
    readonly property bool takesFocus: visible && !shell.menuOpen && shell.notice.length === 0 && !flow.picker.open
    readonly property string platformId: flow.group
    onPlatformIdChanged: Qt.callLater(resetDetails)
    function resetDetails() { if(details) details.contentY=0 }
    function focusItem(item) { if(item) item.forceActiveFocus(Qt.OtherFocusReason) }
    function reveal(item) {
        if(!item || !body || !details)return
        const pos=item.mapToItem(body,0,0).y
        if(pos<details.contentY)details.contentY=pos
        else if(pos+item.height>details.contentY+details.height)details.contentY=pos+item.height-details.height
    }
    component Mark: Canvas {
        property string kind: "partial"
        width: 20; height: 20
        onKindChanged: requestPaint()
        onPaint: {
            const c=getContext("2d");c.reset();c.lineWidth=2.2;c.lineCap="round";c.lineJoin="round"
            c.strokeStyle=kind==="ready"?"#328355":kind==="missing"?"#c35d59":"#b98524"
            if(kind==="ready"){c.beginPath();c.moveTo(4,10);c.lineTo(8,14);c.lineTo(16,5);c.stroke()}
            else if(kind==="missing"){c.beginPath();c.moveTo(5,5);c.lineTo(15,15);c.moveTo(15,5);c.lineTo(5,15);c.stroke()}
            else {c.beginPath();c.moveTo(10,2);c.lineTo(19,18);c.lineTo(1,18);c.closePath();c.stroke();c.beginPath();c.moveTo(10,7);c.lineTo(10,11);c.stroke();c.fillStyle=c.strokeStyle;c.fillRect(9,14,2,2)}
        }
    }
    Item {
        anchors.fill: parent; anchors.margins: Theme.panelInset; anchors.topMargin: Theme.contentTopInset
        PageHeader { id: header; compact: true; title: "Game preparation" }
        Row {
            id: tools; x: 10; y: header.height+2; width: parent.width-20; spacing: 12
            CapButton { objectName: "game-preparation-pack"; width: 190; height: 38; label: "Import BIOS pack"; textSize: 14; tint: Theme.blue; selected: root.takesFocus && flow.focusIndex===0; onActivated: flow.choosePack() }
            Text { width: parent.width-370; height: 42; text: "Put all your BIOS files in one archive.\nTrainerOS will sort them into the right places."; wrapMode: Text.Wrap; font.pixelSize: 12; color: Theme.muted; verticalAlignment: Text.AlignVCenter }
            CapButton { width: 76; height: 38; label: flow.busy?"Cancel":"Recheck"; textSize: 12; selected: root.takesFocus && flow.focusIndex===1; onActivated: flow.activate(1) }
            CapButton { width: 62; height: 38; label: "Back"; textSize: 12; tint: Theme.pink; selected: root.takesFocus && flow.focusIndex===2; onActivated: flow.close() }
        }
        Rectangle {
            id: platformsPane; x: 8; y: tools.y+54; width: parent.width*0.31; height: parent.height-y-31
            color: Theme.surfaceColor("#e8efe5"); radius: 9
            ListView {
                id: platforms; anchors.fill: parent; anchors.margins: 5; clip: true; spacing: 2; model: flow.platforms
                currentIndex: flow.focusIndex>=100 && flow.focusIndex<1000?flow.focusIndex-100:-1
                onCurrentIndexChanged: if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
                delegate: Item {
                    id: systemRow
                    required property int index; required property var modelData
                    readonly property bool selected: root.takesFocus && flow.focusIndex===100+index
                    width: platforms.width; height: 48
                    objectName: "game-preparation-platform-"+modelData.id
                    onSelectedChanged: if(selected)Qt.callLater(root.focusItem,systemRow)
                    Accessible.role: Accessible.Button; Accessible.name: modelData.title+", "+modelData.detail
                    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 7; color: flow.group===systemRow.modelData.id?Theme.surfaceColor("#d3e4d9"):"transparent"; border.color: systemRow.selected?Theme.focus:"transparent"; border.width: 2 }
                    Text { x: 11; y: 7; width: parent.width-66; text: systemRow.modelData.title; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 14; font.bold: flow.group===systemRow.modelData.id; elide: Text.ElideRight }
                    Text { x: 11; y: 26; width: parent.width-66; text: systemRow.modelData.detail; color: Theme.muted; font.pixelSize: 10; elide: Text.ElideRight }
                    Mark { x: parent.width-(systemRow.modelData.onlineWarning && systemRow.modelData.state==="missing"?50:25); y: 14; kind: systemRow.modelData.onlineWarning && systemRow.modelData.state==="ready"?"partial":systemRow.modelData.state }
                    Mark { x: parent.width-25; y: 14; kind: "partial"; visible: !!systemRow.modelData.onlineWarning && systemRow.modelData.state==="missing" }
                    MouseArea { anchors.fill: parent; onClicked: flow.selectPlatform(systemRow.index) }
                }
            }
        }
        Flickable {
            id: details; x: platformsPane.x+platformsPane.width+20; y: platformsPane.y+2; width: parent.width-x-12; height: platformsPane.height-4
            clip: true; contentWidth: width; contentHeight: body.implicitHeight; boundsBehavior: Flickable.StopAtBounds
            Connections { target: root.flow; function onScrollRequested(direction) { details.contentY=Math.max(0,Math.min(Math.max(0,details.contentHeight-details.height),details.contentY+direction*40)) } }
            Column {
                id: body; width: details.width; spacing: 7
                Text { width: parent.width; text: flow.platformTitle || "Choose a platform"; color: Theme.ink; font.pixelSize: 19; font.bold: true; textFormat: Text.PlainText }
                Text { width: parent.width; text: "You can import a mixed archive here — TrainerOS sorts the files."; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap }
                Repeater {
                    model: flow.files
                    delegate: Item {
                        id: fileRow
                        required property int index; required property var modelData
                        width: body.width; height: 43
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.divider }
                        Mark { x: 0; y: 12; kind: fileRow.modelData.checked?"ready":fileRow.modelData.present?"partial":"missing" }
                        Text { x: 29; y: 5; width: parent.width-145; text: fileRow.modelData.name; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 14; elide: Text.ElideMiddle }
                        Text { x: 29; y: 25; width: parent.width-145; text: (fileRow.modelData.checked?"Installed":fileRow.modelData.present?"Needs attention":"Missing")+(fileRow.modelData.optional?" · Optional":""); color: Theme.muted; font.pixelSize: 10; elide: Text.ElideRight }
                        CapButton {
                            objectName: "game-preparation-import-"+fileRow.index
                            anchors.right: parent.right; anchors.rightMargin: 4; y: 7; width: 104; height: 32
                            label: fileRow.modelData.checked?"Installed":"Import"; textSize: 12; tint: Theme.blue
                            enabled: !flow.busy && !!fileRow.modelData.importable
                            selected: root.takesFocus && flow.focusIndex===1000+fileRow.index
                            onSelectedChanged: if(selected)Qt.callLater(root.reveal,fileRow)
                            onActivated: flow.importRequirement(fileRow.index)
                        }
                    }
                }
                Text { width: parent.width; visible: flow.platformNote.length>0; text: flow.platformNote; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                Column {
                    width: parent.width; spacing: 5; visible: flow.hasOnline
                    Text { text: "Online"; color: Theme.ink; font.pixelSize: 17; font.bold: true }
                    Repeater {
                        model: flow.hasOnline?root.shell.settings.onlineControls.slice(1):[]
                        delegate: SettingControl {
                            id: onlineRow
                            required property int index; required property var modelData
                            objectName: "game-preparation-online-"+index
                            width: body.width; height: 43; flat: true; title: modelData.title; detail: modelData.detail; kind: "action"
                            selected: root.takesFocus && flow.focusIndex===2000+index
                            onSelectedChanged: if(selected)Qt.callLater(root.reveal,onlineRow)
                            onActivated: flow.onlineAction(index)
                        }
                    }
                    Text { width: parent.width; text: root.shell.settings.onlineServiceStatus || flow.onlineStatus; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                }
                Text { width: parent.width; visible: flow.report.length>0; text: flow.report; color: Theme.ink; font.pixelSize: 11; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                Item { width: 1; height: 6 }
            }
        }
        Text { x: 12; y: parent.height-24; width: parent.width-24; height: 22; text: flow.status; font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight; textFormat: Text.PlainText }
    }
    ChatFilePicker { anchors.fill: parent; picker: flow.picker; title: "Import BIOS or firmware"; subtitle: "Choose a file or a mixed BIOS archive. TrainerOS will find the right destination." }
}
