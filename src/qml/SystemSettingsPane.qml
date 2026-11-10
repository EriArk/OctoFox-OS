import QtQuick
import QtQuick.Controls

Flickable {
    ScrollBar.vertical: SettingsScrollBar {}
        id: root
    required property var shell
    property bool takesFocus: false
    readonly property var settings: shell.settings
    clip: true; contentHeight: content.height+12; boundsBehavior: Flickable.StopAtBounds
    function followFocus() {
        if(!takesFocus || !visible)return
        for(let i=0;i<actions.count;++i){
            const item=actions.itemAt(i)
            if(item.modelData!==settings.rowFocus)continue
            const top=item.y,bottom=top+item.height+8
            contentY=Math.max(0,Math.min(Math.max(0,contentHeight-height),top<contentY?top:bottom>contentY+height?bottom-height:contentY))
            if(i===0)contentY=0
        }
    }
    Connections { target: root.settings; function onChanged(){Qt.callLater(root.followFocus)} }
    onHeightChanged: Qt.callLater(followFocus)
    Column {
        id: content; x: 4; y: 10; width: parent.width-12; spacing: 0
        Text { x: 9; text: "System"; color: Theme.ink; font.pixelSize: 24; font.weight: Font.DemiBold; bottomPadding: 12 }
        Repeater { id: actions; model: [4,0,3,1,2]
            Column {
                required property int modelData
                width: parent.width
                Text { x: 13; visible: modelData===0; text: "DEVICE INFORMATION"; color: Theme.muted; font.pixelSize: 11; font.weight: Font.DemiBold; topPadding: 20; bottomPadding: 8 }
                Repeater { model: modelData===0 ? root.shell.device.status : []
                    SettingsRow { required property var modelData; width: parent.width; height: implicitHeight; title: modelData.title; detail: modelData.value || "Unavailable"; kind: "status" }
                }
                SettingsRow {
                    objectName: "settings-control-"+parent.modelData
                    width: parent.width; height: implicitHeight
                    title: parent.modelData===4?"Software updates":root.settings.controls[parent.modelData]?.title || ""
                    detail: parent.modelData===4 ? root.settings.updates.installedVersion+" · "+root.settings.updates.channel : parent.modelData===3 ? "Emulators, BIOS and support report" : ""
                    kind: "action"; selected: root.takesFocus && root.settings.rowFocus===parent.modelData
                    onActivated: root.settings.activateRow(parent.modelData)
                }
            }
        }
        Text { x: 13; width: parent.width-26; text: root.shell.device.error; visible: text.length>0; color: Theme.textColor("#853b24"); font.pixelSize: 13; wrapMode: Text.WordWrap; topPadding: 12 }
        onPositioningComplete: Qt.callLater(root.followFocus)
    }
}
