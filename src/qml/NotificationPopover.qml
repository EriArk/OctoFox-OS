import QtQuick

Item {
    id: root
    required property var shell
    property real anchorX: 320
    property real anchorY: 74
    property bool above: false
    visible: shell.notificationsOpen
    property var originFocus: null
    onVisibleChanged: {
        if(visible) { originFocus=root.Window.window ? root.Window.window.activeFocusItem : null; forceActiveFocus() }
        else if(originFocus && originFocus.visible) originFocus.forceActiveFocus()
    }
    MouseArea { x: 0; y: Theme.brandHeight; width: parent.width; height: parent.height-y; onClicked: root.shell.closeHomeMenu(); onWheel: wheel => wheel.accepted=true }
    Rectangle { x: card.x; y: card.y+3; width: card.width; height: card.height; radius: card.radius; color: "#20000000" }
    Rectangle {
        id: card; objectName: "notification-popover"
        width: Math.min(330,root.width-24)
        height: Math.min(root.above ? root.anchorY-12 : root.height-root.anchorY-12,Math.max(186,100+notices.contentHeight))
        x: Math.max(12,Math.min(root.width-width-12,root.anchorX-width))
        y: root.above ? root.anchorY-height : root.anchorY
        radius: 16; color: Theme.paper; border.color: Theme.divider; border.width: 1
        MouseArea { anchors.fill: parent }
        MenuGlyph { x: 18; y: 20; width: 22; height: 22; glyph: "bell"; ink: Theme.muted }
        Text { x: 51; y: 16; text: "Notifications"; font.family: Theme.displayFamily; font.pixelSize: 22; color: Theme.ink }
        SocialIconButton { anchors.right: parent.right; anchors.rightMargin: 12; y: 12; icon: "x"; label: "Close notifications"; onClicked: root.shell.closeHomeMenu() }
        Text { x: 19; y: 47; text: "Home + "+Theme.buttonLabel(Theme.controller?.family==="nintendo"?"west":"north"); font.pixelSize: 11; color: Theme.muted }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 47; text: "Clear updates"; font.pixelSize: 12; color: Theme.muted; visible: notices.count>0
            MouseArea { anchors.fill: parent; anchors.margins: -7; onClicked: root.shell.dismissNotifications() }
        }
        Rectangle { x: 18; y: 72; width: parent.width-36; height: 1; color: Theme.divider }
        ListView {
            id: notices; x: 12; y: 81; width: parent.width-24; height: parent.height-y-12
            clip: true; spacing: 5; model: root.visible ? root.shell.notifications : []
            currentIndex: root.shell.notificationFocus
            onCurrentIndexChanged: if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
            delegate: Item {
                required property int index; required property var modelData
                width: notices.width; height: modelData.ringing ? 112 : 64
                ActivityRow { width: parent.width-(modelData.ringing?0:34); height: 64
                    label: modelData.name; detail: modelData.ringing ? modelData.callError || (modelData.callBusy ? "Declining…" : modelData.answerable ? "Incoming call" : (root.shell.social.account.voice || {}).channel ? "Already in another call" : "Voice is unavailable") : modelData.detail || ""
                    glyph: modelData.ringing?"bell":modelData.request?"party":modelData.provider==="achievements"?"bell":"chat"
                    accent: modelData.request?Theme.pink:Theme.blue
                    person: !!modelData.ringing; avatar: modelData.avatar || ""; drillDown: !modelData.ringing
                    selected: root.shell.notificationFocus===index
                    onActivated: root.shell.openNotificationById(modelData.id)
                }
                Row {
                    x: 10; y: 68; spacing: 10; visible: !!modelData.ringing
                    CapButton { objectName: "notification-call-answer"; width: (notices.width-30)/2; height: 36; label: "Answer"; centered: true; textSize: 16; tint: Theme.green; claimsFocus: false
                        actionIdentity: modelData.id || ""
                        enabled: !!modelData.answerable && !modelData.callBusy
                        onActivated: root.shell.answerNotificationCall(modelData.id,true)
                    }
                    CapButton { objectName: "notification-call-decline"; width: (notices.width-30)/2; height: 36; label: "Decline"; centered: true; textSize: 16; tint: Theme.pink; claimsFocus: false
                        actionIdentity: modelData.id || ""
                        enabled: !modelData.callBusy
                        onActivated: root.shell.answerNotificationCall(modelData.id,false)
                    }
                }
                SocialIconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; icon: "x"; label: "Remove notification"
                    visible: !modelData.ringing && !modelData.pending && modelData.provider!=="traineros-prizes"
                    onClicked: root.shell.dismissNotificationById(modelData.id)
                }
            }
        }
        Text { anchors.centerIn: notices; visible: notices.count===0; text: "All caught up"; color: Theme.muted; font.family: Theme.displayFamily; font.pixelSize: 21 }
    }
}
