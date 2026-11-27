import QtQuick

Rectangle {
    id: cover
    required property string caption
    color: Theme.paper
    Accessible.role: Accessible.StaticText
    Accessible.name: caption

    MouseArea { anchors.fill: parent }
    Column {
        anchors.centerIn: parent
        spacing: 10
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32; height: 3; radius: 2; color: Theme.chassisTop
        }
        Text {
            text: cover.caption
            color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 16
        }
    }
}
