import QtQuick

Item {
    id: root
    required property var shell
    visible: shell.menuOpen || shell.notice.length > 0
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: -Theme.screenBounds.y
        anchors.leftMargin: -Theme.screenBounds.x
        color: Theme.surfaceColor("#70102927")
        visible: !root.shell.downloads.open && !root.shell.scraper.open
    }
    ControlsPanel { anchors.centerIn: parent; width: Math.min(implicitWidth,parent.width-32); height: Math.min(implicitHeight,parent.height-24); shell: root.shell; visible: root.shell.menuOpen && !root.shell.powerMenu && !root.shell.notice.length }
    Rectangle {
        id: powerPopup; objectName: "power-popup"
        visible: root.shell.powerMenu && !root.shell.notice.length
        anchors.centerIn: parent
        width: Math.min(420,parent.width-32)
        height: Math.min(parent.height-24,100+root.shell.menuItems.length*52+(powerError.visible?40:0))
        radius: 18; color: Theme.paper; border.color: Theme.divider
        Text { x:24; y:20; text:"Power"; font.family:Theme.displayFamily; font.pixelSize:26; color:Theme.ink }
        SocialIconButton { anchors.right:parent.right; anchors.rightMargin:18; y:18; glyph:"close"; label:"Back"; onClicked:root.shell.activate(4) }
        Text { x:24; y:56; width:parent.width-48; text:root.shell.powerControl.busy?"Preparing sleep…":"Sleep, restart or shut down"; color:Theme.muted; font.pixelSize:12 }
        ListView {
            id: powerActions; x:20; y:82; width:parent.width-40; height:parent.height-y-(powerError.visible?50:18)
            model:root.shell.menuItems; currentIndex:root.shell.focusIndex; clip:true; keyNavigationEnabled:false
            onCurrentIndexChanged: if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
            delegate: ActivityRow {
                required property int index; required property string modelData
                objectName:"menu-"+index; width:powerActions.width; height:52
                flat:true; drillDown:false
                label:index===1?"Keep awake · "+(root.shell.powerControl.keepAwake?"On":"Off"):modelData
                detail:index===1?"Keep downloads running with the lid closed":""
                glyph:["power","sun","power","power","back","close"][index]||"power"
                selected:root.shell.focusIndex===index
                enabled:index>1 || (root.shell.powerControl.available&&!root.shell.powerControl.busy)
                onActivated:root.shell.activate(index)
            }
        }
        Text { id:powerError; x:24; anchors.bottom:parent.bottom; anchors.bottomMargin:14; width:parent.width-48; height:32; visible:text.length>0; text:root.shell.powerControl.error; wrapMode:Text.WordWrap; maximumLineCount:2; elide:Text.ElideRight; font.pixelSize:12; color:Theme.ink }
    }
    // Existing guarded confirmations keep their own surface.
    Rectangle {
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
        visible: root.shell.notice.length > 0
        width: root.shell.notice.length > 0 || root.shell.powerMenu ? 376 : 420; color: Theme.chassis
        Panel {
            anchors.fill: parent; anchors.margins: 8
            PageHeader {
                y: 4; compact: true
                title: root.shell.modeConfirmation ? "Before you go" : root.shell.notice.length > 0 ? "TrainerOS" : root.shell.powerMenu ? "Power" : "System menu"
            }
            MountedPanel {
                x: 9; y: root.shell.powerMenu ? 65 : 48; width: parent.width - 18; height: parent.height - y - 9
                color: Theme.surfaceColor("#d1e0d6")
                visible: root.shell.notice.length === 0
                Column { x: 18; y: 25; width: parent.width-36; spacing: 13
                    Repeater { model: root.shell.powerMenu ? root.shell.menuItems : []
                        CapButton { required property int index; required property string modelData
                            objectName: "menu-"+index; width: parent.width; height: 43; textSize: 18
                            label: modelData; warning: index<2; tint: index<2?Theme.pink:Theme.green
                            selected: root.shell.focusIndex===index; onActivated: root.shell.activate(index)
                        }
                    }
                }
            }

            Text {
                x: 28; y: 88; width: parent.width - 56; visible: root.shell.notice.length > 0
                height: parent.height - y - 95
                text: root.shell.notice; wrapMode: Text.WordWrap; color: Theme.ink; font.pixelSize: 19; lineHeight: 1.2
            }
            MountedPanel {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 9 }
                height: 74; color: Theme.surfaceColor("#ccdcd0"); visible: root.shell.notice.length > 0
                CapButton {
                    objectName: "notice-close"
                    x: 18; y: 15; width: 160; height: 42; label: root.shell.modeConfirmation ? "Continue" : "Got it"
                    selected: root.shell.notice.length > 0
                    onActivated: root.shell.activate(0)
                }
            }
        }
    }
    MouseArea { anchors.fill: parent; z: -1 } // Block pointer activation beneath the modal.
}
