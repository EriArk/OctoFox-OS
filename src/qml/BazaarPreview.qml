import QtQuick

Rectangle {
    id: root
    required property var shell
    readonly property bool official: shell.bazaar.dialog==="preview-official"
    readonly property bool compact: width<900
    objectName: "bazaar-world-preview"
    color: "#102e3b"
    enabled: !shell.menuOpen && !shell.homeMenuOpen && !shell.drawerOpen && !shell.quickAppsOpen && !shell.notificationsOpen && !shell.serviceOpen
    Image {
        anchors.fill: parent; source: root.official?"qrc:/bazaar/official.png":"qrc:/bazaar/grove.png"
        fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1600
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#fa102938" }
            GradientStop { position: .53; color: "#df102938" }
            GradientStop { position: 1; color: "#15102938" }
        }
    }
    MouseArea { anchors.fill: parent }
    Row {
        x: 30; y: 24; spacing: 12
        Rectangle {
            width: root.compact?170:192; height: 34; radius: 8; color: "#ffda74"
            Text { anchors.centerIn: parent; text: "PLACEHOLDER"; font.pixelSize: 19; font.bold: true; color: "#163641" }
        }
        Text { height:34;verticalAlignment:Text.AlignVCenter;text:"UNDER DEVELOPMENT";font.pixelSize:root.compact?18:21;font.bold:true;color:"#ffffff" }
    }
    CapButton {
        objectName: "bazaar-preview-back"; anchors.right: parent.right; anchors.top: parent.top; anchors.margins:24
        width:root.compact?102:120;height:36;label:"B  Back";textSize:16;tint:"#ffda74";centered:true;claimsFocus:false
        onActivated:root.shell.bazaar.closeDialog()
    }
    Column {
        x:32;y:root.compact?80:92;width:parent.width*.64;spacing:root.compact?9:14
        Text {
            objectName:"bazaar-preview-title";width:parent.width
            text:root.official?"Official Bazaar":"Player Bazaars";color:"#ffffff";font.family:Theme.displayFamily;font.pixelSize:root.compact?43:52
            font.bold:true;wrapMode:Text.WordWrap
        }
        Text {
            width:parent.width; text:root.official?"A fantasy town made for meeting up.":"A place of your own, shared with others."
            color:"#ffda74";font.pixelSize:root.compact?21:25;wrapMode:Text.WordWrap
        }
        Text {
            width:parent.width; text:root.official?"Walk between lively squares, meet other players and discover places to trade.":"Build a personal gathering space, welcome visitors and rent out trading stalls."
            color:"#eef5f1";font.pixelSize:root.compact?16:19;wrapMode:Text.WordWrap
        }
    }
    Column {
        anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:30;spacing:root.compact?10:14
        Text { text:"WHAT'S PLANNED";color:"#ffda74";font.pixelSize:14;font.bold:true }
        Row {
            width:parent.width;spacing:12;height:root.compact?70:88
            Repeater {
                model:root.official?[
                    {title:"Town squares",detail:"Different spaces & activities",glyph:"community",tint:"#ffda74"},
                    {title:"Meet & explore",detail:"Walk around as your character",glyph:"companion",tint:"#90ded2"},
                    {title:"Parallel realms",detail:"Choose a less crowded town",glyph:"guide",tint:"#c6adf4"}
                ]:[
                    {title:"Your own space",detail:"Personal bazaars to shape",glyph:"community",tint:"#90ded2"},
                    {title:"Trading stalls",detail:"Places for players to rent",glyph:"shop",tint:"#ffda74"},
                    {title:"Shared visits",detail:"Gather and explore together",glyph:"companion",tint:"#c6adf4"}
                ]
                delegate:Rectangle {
                    required property var modelData
                    width:(parent.width-24)/3;height:parent.height;radius:12;color:"#f4f6ec";border.color:modelData.tint;border.width:2
                    Rectangle {x:12;y:12;width:root.compact?30:36;height:width;radius:9;color:parent.modelData.tint
                        MenuGlyph {anchors.centerIn:parent;width:22;height:22;glyph:modelData.glyph;ink:"#163641"}
                    }
                    Column {x:root.compact?51:59;y:12;width:parent.width-x-10;spacing:4
                        Text {width:parent.width;text:modelData.title;color:"#12343c";font.pixelSize:root.compact?16:19;font.bold:true;wrapMode:Text.WordWrap}
                        Text {width:parent.width;text:modelData.detail;color:"#34525a";font.pixelSize:root.compact?11:13;wrapMode:Text.WordWrap}
                    }
                }
            }
        }
        Rectangle {
            width:parent.width;height:root.compact?62:70;radius:10;color:"#f0102938";border.color:"#8ecfc9"
            Column {x:16;y:10;width:parent.width-32;spacing:4
                Text {text:"NOT A PLAYABLE WORLD YET";font.pixelSize:root.compact?18:21;font.bold:true;color:"#ffffff"}
                Text {width:parent.width;text:"Purchases and rentals are disabled. No Sparks can be spent here.";font.pixelSize:root.compact?13:15;color:"#ade9dc";wrapMode:Text.WordWrap}
            }
        }
    }
}
