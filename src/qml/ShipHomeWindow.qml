import QtQuick
import QtQuick.Window

Window {
    id: root
    required property var flow
    objectName: "ship-home-window"
    title: "OctoFox OS — Ship Home"
    flags: Qt.Window | Qt.FramelessWindowHint
    transientParent: null
    x: Screen.virtualX; y: Screen.virtualY; width: Screen.width; height: Screen.height
    color: Theme.chassisDark
    onVisibleChanged: if (visible) requestActivate()
    onClosing: function(event) { event.accepted = false; flow.control(0) }

    Item {
        anchors.centerIn: parent
        width: 960; height: 540
        scale: Math.min(root.width / width, root.height / height)
        Panel {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -13
            width: 886; height: 420; radius: 30
            surface: Qt.tint(Theme.paper, "#09c29948")
            Text {
                x: 31; y: 23
                text: qsTr("Home"); font.family: Theme.displayFamily; font.pixelSize: 28; color: Theme.ink
            }
            SocialIconButton {
                anchors.right: parent.right; anchors.rightMargin: 27; y: 22
                icon: "x"; label: qsTr("Return to ship"); onClicked: root.flow.control(0)
            }
            Rectangle {
                x: 31; y: 76; width: 444; height: 307
                radius: 15; color: Theme.chassisDark
                Image {
                    x: 6; y: 6; width: parent.width-12; height: 228
                    source: root.visible ? "qrc:/home-backdrops/ship-cabin.jpg" : ""
                    fillMode: Image.PreserveAspectCrop
                }
                MenuGlyph { x: 20; y: 254; width: 33; height: 33; glyph: "ship"; ink: "#fffaf0" }
                Text {
                    x: 65; y: 251; text: qsTr("Ship Home")
                    font.family: Theme.displayFamily; font.pixelSize: 29; color: "#fffaf0"
                }
            }
            Column {
                x: 501; y: 76; width: 353; spacing: 14
                Repeater {
                    model: [
                        { label: qsTr("Return to ship"), glyph: "play", tint: Theme.green },
                        { label: qsTr("Minimize"), glyph: "desktop", tint: Theme.blue },
                        { label: qsTr("Save and exit"), glyph: "storage", tint: Theme.yellow }
                    ]
                    GameSettingTile {
                        required property var modelData; required property int index
                        objectName: "ship-home-action-" + index
                        width: parent.width; height: 71; compact: true
                        label: modelData.label; glyph: modelData.glyph; tint: modelData.tint
                        selected: root.flow.controlIndex === index
                        onActivated: root.flow.control(index)
                    }
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 16; color: Theme.muted
                    text: root.flow.status || qsTr("After saving, you’ll board again at your last berth.")
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            spacing: 26
            Hint { button: "↑↓"; label: qsTr("Choose"); tint: Theme.blue }
            Hint { button: "A"; label: qsTr("Select"); tint: Theme.yellow }
            Hint { button: "B"; label: qsTr("Return to ship"); tint: Theme.blue }
        }
    }
}
