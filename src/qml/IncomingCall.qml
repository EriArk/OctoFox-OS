import QtQuick

Item {
    id: root
    objectName: "incoming-call-banner"
    required property var social
    property bool ready: true
    property real bottomEdge: height-48
    readonly property var call: social.incomingCall
    visible: !!call.id
    function respond(accept) {
        if (!ready || call.callBusy || (accept && !call.answerable)) return
        social.respondToIncomingCall(call.id, accept)
    }
    function dismiss() { if (ready) social.dismissIncomingCall(call.id) }
    Rectangle {
        id: card; objectName: "incoming-call-card"
        x: parent.width-width-14; y: root.bottomEdge-height
        width: Math.min(360,parent.width-28); height: 154
        radius: 16; color: Theme.paper; border.color: Theme.divider; border.width: 1
        Rectangle { anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: -3; radius: parent.radius; color: "#20000000"; z: -1 }
        AccountAvatar { x: 16; y: 17; width: 42; height: 42; name: root.call.name || ""; source: root.call.avatar || "" }
        Text { x: 70; y: 15; width: parent.width-114; text: root.call.name || ""; textFormat: Text.PlainText; font.family: Theme.displayFamily; font.pixelSize: 22; elide: Text.ElideRight; color: Theme.ink }
        Text { x: 70; y: 42; text: "Incoming call"; font.pixelSize: 13; color: Theme.muted }
        // Swipe the header away. Buttons retain independent touch targets.
        MouseArea {
            x: 0; y: 0; width: parent.width-42; height: 70
            property real startX; property real startY; property string channel
            onPressed: mouse => { startX=mouse.x; startY=mouse.y; channel=root.call.id }
            onReleased: mouse => { if (root.ready && channel===root.call.id && (Math.abs(mouse.x-startX)>55 || mouse.y-startY>40)) root.dismiss() }
        }
        SocialIconButton { anchors.right: parent.right; anchors.rightMargin: 7; y: 8; icon: "x"; label: "Hide call in notifications"; enabled: root.ready; onClicked: root.dismiss() }
        Text { x: 16; y: 72; width: parent.width-32; text: root.call.callBusy ? "Declining…" : root.call.callError || (!root.ready ? "Release the controls" : root.call.answerable ? "Microphone starts muted" : (root.social.account.voice || {}).channel ? "Already in another call" : "Voice is unavailable"); elide: Text.ElideRight; font.pixelSize: 12; color: Theme.muted }
        Row { x: 16; y: 103; spacing: 12
            CapButton { objectName: "incoming-call-answer"; actionIdentity: root.call.id || ""; width: (card.width-44)/2; height: 36; label: "Answer"; centered: true; textSize: 17; tint: Theme.green; claimsFocus: false; enabled: root.ready && !root.call.callBusy && !!root.call.answerable; onActivated: root.respond(true) }
            CapButton { objectName: "incoming-call-decline"; actionIdentity: root.call.id || ""; width: (card.width-44)/2; height: 36; label: "Decline"; centered: true; textSize: 17; tint: Theme.pink; claimsFocus: false; enabled: root.ready && !root.call.callBusy; onActivated: root.respond(false) }
        }
    }
}
