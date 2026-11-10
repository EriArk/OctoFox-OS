import QtQuick

Item {
    id: root
    required property var shell
    objectName: "online-page"
    readonly property bool chats: shell.onlineFace === "chats"
    readonly property var account: shell.social.account
    readonly property string connectionStatus: root.chats && (account.state === "connecting" || account.state === "connected") && account.status !== "Connected" ? (account.status || (account.state === "connecting" ? "Reconnecting…" : "")) : ""
    Binding { target: root.shell.social; property: "lobbyBrowseVisible"; value: root.visible && !root.chats && root.shell.onlineFace === "lobby" && root.shell.social.surfaceAvailable }
    Item {
        id: sections; objectName: "chat-navigation-rail"
        visible: root.chats; x: 6; y: 5; width: 76
        height: parent.height-Theme.adventureCutoutHeight-10
        readonly property real rowHeight: Math.min(62,(height-22)/5)
        enabled: !root.shell.social.menu.length && !root.shell.keyboard.open && !root.shell.quickAppsOpen && !root.shell.notificationsOpen
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.divider }
        Rectangle { x: 16; y: sections.rowHeight+5; width: parent.width-32; height: 1; color: Theme.divider }
        Rectangle { x: 16; y: parent.height-sections.rowHeight-6; width: parent.width-32; height: 1; color: Theme.divider }
        Repeater {
            model: [{id:"friends",name:"Search",icon:"search"},{id:"chats",name:"Messages",icon:"chat"},
                {id:"groups",name:"Groups",icon:"group"},{id:"communities",name:"Communities",icon:"community"},
                {id:"contacts",name:"Friends",icon:"friend"}]
            delegate: Item {
                id: section; required property var modelData; required property int index
                objectName: "online-chat-" + modelData.id
                readonly property bool selected: root.shell.socialFace === modelData.id
                readonly property int unread: root.shell.social.sectionCounts[modelData.id] || 0
                x: 2; y: index===4 ? sections.height-height : index*height+(index>0?10:0)
                width: sections.width-7; height: sections.rowHeight
                Accessible.role: Accessible.Button; Accessible.name: modelData.name+(unread ? ", "+unread+" unread" : "")
                Accessible.onPressAction: root.shell.selectChatFace(modelData.id)
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2; radius: 8
                    color: section.selected || hover.containsMouse ? Theme.selection : "transparent"
                    border.width: root.shell.chatNavigationFocused && section.selected ? 2 : 0; border.color: Theme.focusGlow
                }
                MenuGlyph { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: section.selected ? -7 : 0
                    width: Math.min(32,section.height-16); height: width; glyph: section.modelData.icon
                    ink: section.selected ? Theme.ink : Theme.muted }
                Text { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 4 }
                    visible: section.selected; text: section.modelData.name; color: Theme.ink; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                Rectangle { objectName: "chat-badge-"+section.modelData.id; visible: section.unread>0
                    anchors.right: parent.right; anchors.rightMargin: 2; y: 2; width: badge.implicitWidth+8; height: 17; radius: 8; color: Theme.pink
                    Text { id: badge; anchors.centerIn: parent; text: section.unread>99 ? "99+" : section.unread; color: Theme.ink; font.pixelSize: 10; font.bold: true } }
                MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: root.shell.selectChatFace(section.modelData.id) }
            }
        }
    }
    Rectangle { id: connectionBanner; objectName: "online-connection-status"
        x: sections.x+sections.width+10; y: 4; width: parent.width-x-12; height: visible ? statusText.implicitHeight+16 : 0
        visible: root.connectionStatus.length>0; radius: 5; color: Theme.selection
        Text { id: statusText; x: 10; y: 8; width: parent.width-20; text: root.connectionStatus; font.pixelSize: 12; color: Theme.ink; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
    }
    SocialPage {
        anchors { fill: parent; leftMargin: root.chats ? sections.x+sections.width+6 : 0; topMargin: root.chats ? connectionBanner.height+6 : 0 }
        shell: root.shell
        visible: root.shell.onlineFace === "lobby" || root.chats
    }
    BazaarPage {
        anchors.fill: parent
        shell: root.shell
        visible: root.shell.onlineFace === "bazaar"
    }
}
