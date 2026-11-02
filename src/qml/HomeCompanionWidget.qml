import QtQuick
import QtQuick.Effects
import QtQuick.Window
import TrainerOS

Item {
    id: root
    required property var shell
    property bool selected: false
    property string assetBase: "qrc:/home-pet/"
    readonly property var pet: shell.dashboard.companion
    readonly property bool live: visible && shell.unobstructed && !shell.quickAppsOpen && !shell.drawerOpen && !shell.keyboard.open
    readonly property bool compact: height < 170
    readonly property var labels: ["Feed", "Playtime · 60 min = 100%", pet.activity === "rest" ? "Wake up" : "Rest"]
    objectName: "home-companion"
    clip: true
    // One bounded surface for the background, 3D render and overlays. The static
    // mask never follows animation; the whole effect dies with the Home loader.
    layer.enabled: true
    property size surfaceSize: Qt.size(width,height)
    function syncSurfaceSize() {
        var a=mapToItem(null,0,0), b=mapToItem(null,width,height)
        surfaceSize=Qt.size(Math.max(1,Math.ceil(Math.abs(b.x-a.x)*Screen.devicePixelRatio)),
                            Math.max(1,Math.ceil(Math.abs(b.y-a.y)*Screen.devicePixelRatio)))
    }
    layer.textureSize: surfaceSize
    layer.smooth: true
    onWidthChanged:Qt.callLater(syncSurfaceSize)
    onHeightChanged:Qt.callLater(syncSurfaceSize)
    Connections {
        target:root.Window.window
        function onWidthChanged(){Qt.callLater(root.syncSurfaceSize)}
        function onHeightChanged(){Qt.callLater(root.syncSurfaceSize)}
    }
    layer.effect: MultiEffect { maskEnabled:true; maskSource:roundedMask }
    Rectangle {
        id:roundedMask; anchors.fill:parent; radius:10; color:"white"
        visible:false; layer.enabled:true; layer.textureSize:root.surfaceSize; layer.smooth:true; antialiasing:true
    }
    function updateLive() { pet.active = live; if (live) pet.setNotifications(shell.notifications) }
    function use(index) { shell.dashboard.select("widget"); pet.perform(index) }
    onLiveChanged: updateLive()
    Component.onCompleted: {updateLive();Qt.callLater(syncSurfaceSize)}
    Component.onDestruction: pet.active = false
    Connections { target:root.shell; function onNotificationsChanged(){if(root.live)root.pet.setNotifications(root.shell.notifications)} }
    Image { anchors.fill:parent; source:root.assetBase+"backgrounds/"+root.pet.background+".png"; sourceSize:Qt.size(768,576); fillMode:Image.PreserveAspectCrop; asynchronous:true }
    Rectangle { x:parent.width*.39; y:parent.height*.88; width:parent.width*.24; height:root.compact?3:5; radius:height/2; color:"#26000000" }
    Loader {
        id:actor
        anchors.fill:parent; anchors.topMargin:root.compact?27:36; anchors.bottomMargin:8
        active:root.live && root.shell.trainer.avatarRendererAvailable && !!root.shell.trainer.avatarModel.toString()
        source:"HomeCompanionScene.qml"
        onLoaded: {
            item.pet=root.pet
            item.assetBase=Qt.binding(function(){return root.assetBase})
            item.modelSource=Qt.binding(function(){return root.shell.trainer.avatarModel})
            item.animate=Qt.binding(function(){return root.live})
        }
    }
    Text {
        anchors.centerIn:parent; width:parent.width-24; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.WordWrap
        visible:!root.shell.trainer.avatarModel.toString() || actor.status===Loader.Error || (actor.item && actor.item.error)
        text:root.shell.trainer.avatarBusy?"Getting your avatar…":"Avatar unavailable"
        color:"#fff8e9"; style:Text.Outline; styleColor:"#77563e"; font.pixelSize:12
    }
    MouseArea { anchors.fill:parent; onClicked:{root.shell.dashboard.select("widget");root.pet.begin()} }
    Row {
        x:8; y:7; spacing:root.compact?6:8
        Repeater {
            model:[{icon:"food",value:root.pet.needs.food,color:"#ffc65a"},{icon:"game",value:root.pet.needs.mood,color:"#ff91b1"},{icon:"rest",value:root.pet.needs.energy,color:"#7ce0ed"}]
            delegate:Item {
                id:dial
                required property var modelData
                required property int index
                width:root.compact?29:35; height:width
                readonly property bool focused:root.selected && root.pet.interacting && !root.pet.menuOpen && root.pet.focus===index
                Rectangle { anchors.fill:parent; anchors.margins:2; radius:width/2; color:"#49304436" }
                Canvas {
                    id:ring; anchors.fill:parent
                    onPaint: {
                        const c=getContext("2d"),r=width/2-3
                        c.reset();c.lineWidth=2.5;c.lineCap="round"
                        c.strokeStyle="#35ffffff";c.beginPath();c.arc(width/2,height/2,r,0,Math.PI*2);c.stroke()
                        c.strokeStyle=dial.modelData.color;c.beginPath();c.arc(width/2,height/2,r,-Math.PI/2,-Math.PI/2+Math.PI*2*Math.max(.001,dial.modelData.value/100));c.stroke()
                        if(dial.focused){c.lineWidth=1;c.strokeStyle="#fff1b9";c.beginPath();c.arc(width/2,height/2,width/2-.5,0,Math.PI*2);c.stroke()}
                    }
                    Connections { target:dial; function onModelDataChanged(){ring.requestPaint()} function onFocusedChanged(){ring.requestPaint()} }
                    onWidthChanged:requestPaint()
                }
                Image { anchors.centerIn:parent; width:parent.width*.47; height:width; sourceSize:Qt.size(48,48); source:"qrc:/home-pet/ui/"+dial.modelData.icon+".svg" }
                MouseArea { anchors.fill:parent; onClicked:if(dial.index!==1)root.use(dial.index) }
                Accessible.role:index===1?Accessible.ProgressBar:Accessible.Button
                Accessible.name:root.labels[index]+", "+modelData.value+" percent"
                Accessible.onPressAction:if(index!==1)root.use(index)
            }
        }
    }
    Rectangle {
        anchors.right:parent.right; anchors.top:parent.top; anchors.margins:7
        width:root.compact?27:31; height:width; radius:width/2
        color:root.pet.menuOpen?"#cc314137":"#49304436"
        border.width:root.selected && root.pet.interacting && root.pet.focus===6?1:0; border.color:"#fff1b9"
        Image { anchors.centerIn:parent; width:15; height:15; source:"qrc:/home-pet/ui/menu.svg" }
        MouseArea { anchors.fill:parent; onClicked:{root.shell.dashboard.select("widget");root.pet.toggleMenu()} }
        Accessible.role:Accessible.Button; Accessible.name:"Companion menu"; Accessible.onPressAction:root.pet.toggleMenu()
    }
    Rectangle {
        anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:6
        width:actionLabel.implicitWidth+18; height:19; radius:9; color:"#85314137"
        visible:root.selected && root.pet.interacting && !root.pet.menuOpen && (root.pet.focus===0 || root.pet.focus===2) && !root.pet.bubble
        Text { id:actionLabel; anchors.centerIn:parent; text:root.labels[root.pet.focus] || ""; color:"#fff7e5"; font.pixelSize:10; font.bold:true }
    }
    Rectangle {
        anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:6
        width:Math.min(parent.width-16,190); height:message.implicitHeight+10; radius:8
        visible:!!root.pet.bubble && !root.pet.menuOpen; color:"#eafff6dc"
        Text { id:message; x:6; y:5; width:parent.width-12; text:root.pet.bubble; textFormat:Text.PlainText; wrapMode:Text.WordWrap; font.pixelSize:root.compact?10:12; color:"#3d473a" }
        MouseArea { anchors.fill:parent; onClicked:root.pet.openHint() }
        Accessible.role:Accessible.Button; Accessible.name:root.pet.bubble; Accessible.onPressAction:root.pet.openHint()
    }
    Item {
        anchors.fill:parent; visible:root.pet.menuOpen
        MouseArea { anchors.fill:parent; onClicked:root.pet.toggleMenu() }
        Rectangle {
            anchors.right:parent.right; anchors.rightMargin:root.compact?40:7
            y:root.compact?5:44; width:root.compact?170:180; height:options.height+12
            radius:11; color:"#ed293b32"; border.color:"#607b8d70"
            Column {
                id:options; x:6; y:6; width:parent.width-12; spacing:2
                Repeater {
                    model:[{id:3,label:"Change scenery"},{id:4,label:root.pet.quiet?"Hints: quiet":"Hints: on"},{id:5,label:"Notifications"},{id:7,label:"Change widget"}]
                    delegate:Rectangle {
                        required property var modelData
                        width:options.width; height:root.compact?22:27; radius:6
                        color:root.selected && root.pet.focus===modelData.id?"#566b4c":"transparent"
                        Text { x:9; anchors.verticalCenter:parent.verticalCenter; text:modelData.label; color:"#fff4d9"; font.pixelSize:11 }
                        MouseArea { anchors.fill:parent; onClicked:root.use(modelData.id) }
                        Accessible.role:Accessible.Button; Accessible.name:modelData.label; Accessible.onPressAction:root.use(modelData.id)
                    }
                }
            }
        }
    }
    Rectangle { anchors.fill:parent; color:"transparent"; radius:10; border.width:root.selected?1.5:0; border.color:Theme.focusGlow }
}
