import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    required property var shell
    readonly property var catalogue: shell.bazaar
    readonly property string kind: catalogue.dialog
    visible: kind.length>0 && kind!=="realms"
    color: "#880c2526"; z: 3
    enabled: !shell.menuOpen && !shell.serviceOpen && !shell.keyboard.open && !shell.notificationsOpen
    MouseArea { anchors.fill: parent }
    Rectangle {
        anchors.centerIn: parent; width: Math.min(550,parent.width-32); height: Math.min(335,parent.height-14)
        radius: 12; color: Theme.paper; border.color: Theme.divider
        Text {
            x: 16; y: 12; width: parent.width-62; font.family: Theme.displayFamily; font.pixelSize: 21; color: Theme.ink
            text: root.kind==="create"?"Create a bazaar":root.kind==="manage"?"My bazaar":root.kind==="review"?"Review creation":root.kind==="details"?"Bazaar details":"Bazaar menu"
            elide: Text.ElideRight
        }
        CapButton { objectName: "bazaar-menu-close"; anchors.right: parent.right; anchors.rightMargin: 8; y: 8; width: 36; height: 30; label: "×"; textSize: 22; centered: true; flat: true; claimsFocus: false; contentInset: 0; onActivated: root.catalogue.closeDialog() }
        Text {
            id: summary; x: 17; y: 42; width: parent.width-34; height: root.catalogue.summary.length ? 32 : 0
            text: root.catalogue.summary; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 11
            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        ListView {
            id: actions; objectName: "bazaar-menu-actions"
            x: 14; y: summary.y+summary.height+5; width: parent.width-28; height: parent.height-y-51
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: root.catalogue.dialogRows; currentIndex: root.catalogue.dialogIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex,ListView.Contain)
            ScrollBar.vertical: ScrollBar { policy: actions.contentHeight>actions.height?ScrollBar.AsNeeded:ScrollBar.AlwaysOff }
            delegate: Rectangle {
                required property var modelData
                required property int index
                objectName: "bazaar-action-"+modelData.id
                width: actions.width-4; height: 38; radius: 6
                color: index===root.catalogue.dialogIndex ? Theme.selection : "transparent"
                border.width: index===root.catalogue.dialogIndex?2:0; border.color: Theme.focusGlow
                opacity: modelData.enabled?1:0.48
                Text {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; width: modelData.value.length?Math.min(164,parent.width*.4):parent.width-20
                    text: modelData.label; textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.ink; font.pixelSize: 12
                }
                Text {
                    x: Math.min(178,parent.width*.4+14); width: parent.width-x-12; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.value; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; enabled: modelData.enabled; onClicked: root.catalogue.dialogAction(modelData.id) }
                Accessible.role: Accessible.Button; Accessible.name: modelData.label+" "+modelData.value
                Accessible.onPressAction: root.catalogue.dialogAction(modelData.id)
            }
        }
        Text {
            x: 17; anchors.bottom: parent.bottom; anchors.bottomMargin: 9; width: parent.width-34; height: 32
            text: root.catalogue.message || ((root.kind==="create"||root.kind==="manage"||root.kind==="review") ? root.catalogue.account.status : "B  Back")
            textFormat: Text.PlainText; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; font.pixelSize: 11; color: Theme.muted
        }
    }
}
