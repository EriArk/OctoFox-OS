import QtQuick

Item {
    id: root
    required property var flow
    Rectangle {
        anchors.fill: parent; color: Theme.surfaceColor("#70162723"); visible: root.flow.menu.length > 0
        MouseArea { anchors.fill: parent; onClicked: root.flow.menuAction(3) }
        Rectangle {
            objectName: "apps-actions-popup"
            anchors.centerIn: parent; width: Math.min(360,parent.width-32); height: Math.min(parent.height-24,84+root.flow.menu.length*48)
            radius: 18; color: Theme.paper; border.color: Theme.divider
            MouseArea { anchors.fill: parent }
            Text { x:24; y:20; text:"Application"; font.family:Theme.displayFamily; font.pixelSize:24; color:Theme.ink }
            SocialIconButton { anchors.right:parent.right; anchors.rightMargin:16; y:16; glyph:"close"; label:"Back"; onClicked:root.flow.menuAction(3) }
            ListView {
                id: actions; x:18; y:66; width:parent.width-36; height:parent.height-y-18; clip:true
                model:root.flow.menu; currentIndex:root.flow.menuIndex; keyNavigationEnabled:false
                onCurrentIndexChanged: if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
                delegate: ActivityRow {
                    required property var modelData; required property int index
                    objectName: "apps-menu-action-"+index
                    width:actions.width; height:48; flat:true; drillDown:false
                    label:modelData.label; glyph:index===0?"star":index===3?"back":"desktop"
                    selected:root.flow.menuIndex===index
                    onActivated:root.flow.menuAction(index)
                }
            }
        }
    }
}
