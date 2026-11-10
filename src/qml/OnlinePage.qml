import QtQuick

Item {
    id: root
    required property var shell
    objectName: "online-page"
    readonly property bool chats: shell.onlineFace === "chats"
    readonly property var account: shell.social.account
    readonly property string connectionStatus: root.chats && (account.state === "connecting" || account.state === "connected") && account.status !== "Connected" ? (account.status || (account.state === "connecting" ? "Reconnecting…" : "")) : ""
    Binding { target: root.shell.social; property: "lobbyBrowseVisible"; value: root.visible && !root.chats && root.shell.onlineFace === "lobby" && root.shell.social.surfaceAvailable }
    Row {
        id: sections
        visible: root.chats
        height: 32; spacing: 24; x: 14
        Repeater {
            model: [{id:"chats",name:"Messages"},{id:"communities",name:"Communities"},{id:"friends",name:"Search"}]
            delegate: Item {
                required property var modelData
                objectName: "online-chat-" + modelData.id
                width: label.implicitWidth + 12; height: 29
                Rectangle {
                    anchors.fill: parent; radius: 5; color: "transparent"
                    border.width: 2; border.color: Theme.focusGlow
                    visible: root.shell.chatNavigationFocused && root.shell.socialFace === modelData.id
                }
                Text {
                    id: label; anchors.centerIn: parent; text: modelData.name
                    font.pixelSize: 13; font.bold: root.shell.socialFace === modelData.id
                    color: root.shell.socialFace === modelData.id ? Theme.ink : Theme.muted
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: root.shell.chatNavigationFocused ? 3 : 1
                    color: Theme.focusGlow; visible: root.shell.socialFace === modelData.id
                }
                MouseArea { anchors.fill: parent; onClicked: root.shell.selectChatFace(modelData.id) }
            }
        }
    }
    Rectangle { id: connectionBanner; objectName: "online-connection-status"
        x: 12; y: sections.height+2; width: parent.width-24; height: visible ? statusText.implicitHeight+16 : 0
        visible: root.connectionStatus.length>0; radius: 5; color: Theme.selection
        Text { id: statusText; x: 10; y: 8; width: parent.width-20; text: root.connectionStatus; font.pixelSize: 12; color: Theme.ink; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
    }
    SocialPage {
        anchors { fill: parent; topMargin: root.chats ? sections.height+connectionBanner.height+6 : 0 }
        shell: root.shell
        visible: root.shell.onlineFace === "lobby" || root.chats
    }
    Item {
        anchors.fill: parent; visible: root.shell.onlineFace === "bazaar"
        Column {
            anchors.centerIn: parent; width: Math.min(parent.width - 64, 530); spacing: 18
            Text { width: parent.width; text: "Bazaar"; font.family: Theme.displayFamily; font.pixelSize: 32; color: Theme.ink }
            Rectangle { width: 52; height: 3; radius: 1; color: Theme.yellow }
            Text { width: parent.width; text: "A place to meet, explore and trade."; font.pixelSize: 18; color: Theme.ink; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: "Worlds and player rooms are not available in this build yet."; font.pixelSize: 14; color: Theme.muted; wrapMode: Text.WordWrap }
        }
    }
}
