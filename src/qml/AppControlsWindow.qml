import QtQuick
import QtQuick.Window

Window {
    id: root
    required property var flow
    required property var bridge
    objectName: "app-controls-window"
    title: "OctoFox OS — Home"
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    transientParent: null
    x: Screen.virtualX; y: Screen.virtualY; width: Screen.width; height: Screen.height
    visible: bridge.ready && flow.current.length > 0 && flow.controlsOpen
    readonly property real unit: Math.min(Theme.uiScale, width/460, height/410)
    readonly property var hitRegions: [0,1,2].map(i => ({id:"control-"+i,rect:Qt.rect(card.x+20*unit,card.y+(114+i*58)*unit,380*unit,52*unit)})).concat([
        {id:"menu",rect:Qt.rect(card.x,card.y,card.width*unit,card.height*unit)}
    ])
    onHitRegionsChanged: bridge.setRegions(hitRegions)
    Component.onCompleted: {bridge.attach(root);bridge.setRegions(hitRegions)}
    onClosing: event => {event.accepted=false;flow.control(0)}
    property string pressed: ""
    onVisibleChanged: pressed=""
    Connections {
        target: root.bridge
        function onPointer(target,phase,position) {
            if(phase==="press")root.pressed=target
            if(phase==="release") {
                const region=root.hitRegions.find(r=>r.id===target)
                if(root.pressed===target && target.indexOf("control-")===0 && region
                    && position.x>=region.rect.x && position.x<region.rect.x+region.rect.width
                    && position.y>=region.rect.y && position.y<region.rect.y+region.rect.height)
                    root.flow.control(Number(target.slice(8)))
                root.pressed=""
            }
        }
    }
    Rectangle {
        id: card; objectName: "app-home-menu"
        width: 420; height: root.flow.status.length ? 382 : 330
        x: (root.width-width*root.unit)/2; y: (root.height-height*root.unit)/2
        scale: root.unit; transformOrigin: Item.TopLeft
        radius: 18; color: Theme.paper; border.color: Theme.rim; border.width: 1
        Text {x:24;y:20;text:"Home";font.family:Theme.displayFamily;font.pixelSize:26;color:Theme.ink}
        Text {x:24;y:58;width:parent.width-48;text:root.flow.currentName;elide:Text.ElideRight;textFormat:Text.PlainText;font.pixelSize:20;color:Theme.ink}
        Text {x:24;y:87;text:"Your application stays open.";font.pixelSize:12;color:Theme.muted}
        Repeater {
            model: [{label:"Return",glyph:"play"},{label:"Minimize",glyph:"desktop"},{label:"Close application",glyph:"close"}]
            ActivityRow {
                required property var modelData;required property int index
                objectName: "app-home-action-"+index
                x:20;y:114+index*58;width:380;height:52
                flat:true;drillDown:false;label:modelData.label;glyph:modelData.glyph
                selected:root.flow.controlIndex===index
                onActivated:root.flow.control(index)
            }
        }
        Text {x:24;y:294;width:parent.width-48;visible:root.flow.status.length>0;text:root.flow.status;wrapMode:Text.WordWrap;textFormat:Text.PlainText;font.pixelSize:12;color:Theme.ink;maximumLineCount:3;elide:Text.ElideRight}
        Text {x:24;anchors.bottom:parent.bottom;anchors.bottomMargin:13;text:"A · Select     B / Home · Return";font.pixelSize:12;color:Theme.muted}
    }
}
