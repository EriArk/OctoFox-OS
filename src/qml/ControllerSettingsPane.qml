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
            SettingsRow { objectName: "settings-control-0"; anchors.bottom: parent.bottom; width: parent.width; height: implicitHeight; title: "Calibrate sticks & triggers"; compact: true; selected: root.takesFocus&&root.settings.rowFocus===0; onActivated: root.settings.activateRow(0) }
        }
        Flickable {
            ScrollBar.vertical: SettingsScrollBar {}
            id: choices; x: parent.width*.46; y: 43; width: parent.width-x-8; height: parent.height-y-40
            clip: true; contentHeight: rows.height; boundsBehavior: Flickable.StopAtBounds
            function follow() {
                const item=controls.itemAt(root.settings.rowFocus-1)
                if(!item || !root.takesFocus)return
                contentY=Math.max(0,Math.min(Math.max(0,contentHeight-height),item.y<contentY?item.y:item.y+item.height>contentY+height?item.y+item.height-height:contentY))
            }
            Connections { target: root.settings; function onChanged(){Qt.callLater(choices.follow)} }
            Column { id: rows; width: parent.width; onPositioningComplete: Qt.callLater(choices.follow)
                Repeater { id: controls; model: 7
                    SettingsRow {
                        required property int index; objectName: "settings-control-"+(index+1)
                        width: parent.width; height: implicitHeight; compact: true
                        title: root.settings.controls[index+1]?.title || ""; detail: root.settings.controls[index+1]?.detail || ""
                        kind: (index===3 || index===4)&&root.input?.connected?"toggle":root.settings.controls[index+1]?.kind || "status"
                        checked: index===3?root.input?.profile.invertX || false:root.input?.profile.invertY || false
                        selected: root.takesFocus&&root.settings.rowFocus===index+1
                        onActivated: root.settings.activateRow(index+1)
                        onAdjustmentRequested: direction => root.settings.adjustDisplay(index+1,direction)
                    }
                }
            }
        }
        Text { x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; width: parent.width-24; text: root.input?.profileError || "Saved for this controller"; color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
    }
    ControllerCalibration { anchors.fill: parent; input: root.input; visible: root.calibrationOpen }
    CapButton { flat: true; anchors.right: parent.right; y: 0; width: 80; height: 44; visible: root.calibrationOpen; label: "Back"; textSize: 13; onActivated: {root.input.cancelCapture();root.calibrationOpen=false} }
    Connections { target: root.input; function onCaptureChanged(){root.calibrationOpen=["center","range"].includes(root.input.captureMode)} }
}
