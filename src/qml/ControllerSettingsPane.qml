import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var settings
    required property bool takesFocus
    readonly property var input: Theme.controller
    property bool calibrationOpen: false
    onVisibleChanged: if(!visible){calibrationOpen=false;input?.cancelCapture()}
    Item {
        anchors.fill: parent; visible: !root.calibrationOpen
        Text { x: 10; y: 10; width: parent.width-20; text: root.input?.deviceName || "Connect a controller"; color: Theme.ink; font.pixelSize: 20; font.weight: Font.DemiBold; elide: Text.ElideRight }
        Item { x: 3; y: 43; width: parent.width*.44; height: parent.height-78
            ControllerDiagram { objectName: "settings-controller-diagram"; x: 0; y: 8; width: parent.width; height: width*.72; interactive: false }
            Text { x: 4; y: parent.width*.72+18; width: parent.width-8; text: Theme.buttonLabel("A")+"  Select     "+Theme.buttonLabel("B")+"  Back"; color: Theme.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
        }
        Flickable {
            ScrollBar.vertical: SettingsScrollBar {}
            id: choices; x: parent.width*.46; y: 43; width: parent.width-x-8; height: parent.height-y-40
            clip: true; contentHeight: rows.height; boundsBehavior: Flickable.StopAtBounds
            function follow() {
                const item=controls.itemAt(root.settings.rowFocus)
                if(!item || !root.takesFocus)return
                contentY=Math.max(0,Math.min(Math.max(0,contentHeight-height),item.y<contentY?item.y:item.y+item.height>contentY+height?item.y+item.height-height:contentY))
            }
            Connections { target: root.settings; function onChanged(){Qt.callLater(choices.follow)} }
            Column { id: rows; width: parent.width; onPositioningComplete: Qt.callLater(choices.follow)
                Repeater { id: controls; model: root.settings.controls.length
                    SettingsRow {
                        required property int index; objectName: "settings-control-"+index
                        width: parent.width; height: implicitHeight; compact: true
                        title: root.settings.controls[index]?.title || ""; detail: root.settings.controls[index]?.detail || ""
                        kind: (index===5 || index===6)&&root.input?.connected?"toggle":root.settings.controls[index]?.kind || "status"
                        checked: index===5?root.input?.profile.invertX || false:root.input?.profile.invertY || false
                        selected: root.takesFocus&&root.settings.rowFocus===index
                        onActivated: root.settings.activateRow(index)
                        onAdjustmentRequested: direction => root.settings.adjustDisplay(index,direction)
                    }
                }
            }
        }
        Text { x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; width: parent.width-24; text: root.input?.profileError || (root.input?.connected ? "Ready to play" : "Connect a controller to choose its layout"); color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
    }
    ControllerCalibration { anchors.fill: parent; input: root.input; visible: root.calibrationOpen }
    CapButton { flat: true; anchors.right: parent.right; y: 0; width: 80; height: 44; visible: root.calibrationOpen; label: "Back"; textSize: 13; onActivated: {root.input.cancelCapture();root.calibrationOpen=false} }
    Connections { target: root.input; function onCaptureChanged(){root.calibrationOpen=["center","range"].includes(root.input.captureMode)} }
}
