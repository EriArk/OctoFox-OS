import QtQuick

Item {
    id: root
    property real textInset: 13
    property string title
    property string detail
    property string kind: "action"
    property bool selected: false
    property bool checked: false
    property real level: -1
    property bool muted: false
    property bool compact: false
    property bool primary: false
    signal activated()
    signal adjustmentRequested(int direction)
    signal levelRequested(real value)
    implicitHeight: Math.max(compact ? 44 : 52, labels.implicitHeight+(compact?12:20))
    Accessible.role: slider ? Accessible.Slider : kind==="toggle" ? Accessible.CheckBox : Accessible.Button
    Accessible.name: title + (detail.length ? ", "+detail : "")
    Accessible.checked: checked
    onSelectedChanged: if(selected && visible)Qt.callLater(function(){if(root.selected && root.visible)root.forceActiveFocus(Qt.OtherFocusReason)})
    readonly property bool adjustable: kind === "stepper" || kind === "theme"
    readonly property bool slider: kind === "volume" || kind === "brightness"
    readonly property bool available: kind!=="unavailable" && kind!=="status" && enabled
    readonly property int trailingSpace: slider ? 132 : adjustable ? (compact?86:104) : kind==="toggle"?64:36
    Rectangle { anchors.fill: parent; anchors.bottomMargin: 1; radius: 5; color: root.primary && root.available ? Theme.accent : root.selected ? Theme.selection : "transparent"; border.width: root.selected?2:0; border.color: Theme.accent }
    Rectangle { x: 0; y: 10; width: 3; height: parent.height-20; radius: 1; color: root.primary ? Theme.ink : Theme.accent; visible: root.selected }
    Column {
        id: labels; x: root.textInset; anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0,parent.width-root.textInset-root.trailingSpace); spacing: 4
        Text { width: parent.width; text: root.title; textFormat: Text.PlainText; color: root.primary && root.available ? (Theme.dark?Theme.surface:Theme.accentInk) : root.kind==="unavailable" ? Theme.muted : Theme.ink; font.pixelSize: root.compact?12:15; font.weight: root.selected || root.primary ? Font.DemiBold : Font.Normal; wrapMode: Text.WordWrap }
        Text { width: parent.width; visible: text.length>0; text: root.detail; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: root.compact?11:12; wrapMode: Text.WrapAnywhere }
    }
    Rectangle { x: root.textInset; y: parent.height-1; width: parent.width-root.textInset; height: 1; color: Theme.divider; visible: !root.primary }
    MouseArea { anchors.fill: parent; enabled: root.available; onClicked: root.activated() }
    Row { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 4; visible: root.adjustable
        Repeater { model: ["−", "+"]
            Text { required property int index; required property string modelData; objectName: index?"settings-step-next":"settings-step-previous"; text: modelData; color: Theme.accent; font.pixelSize: 22; width: root.compact?38:44; height: 44; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                MouseArea { anchors.fill: parent; enabled: root.available; onClicked: root.adjustmentRequested(index?1:-1) }
            }
        }
    }
    Rectangle { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 22; radius: 11; visible: root.kind==="toggle"; color: root.checked ? Theme.accent : Theme.divider
        Rectangle { x: root.checked ? 18 : 3; y: 3; width: 16; height: 16; radius: 8; color: root.checked && Theme.dark ? Theme.surface : "#ffffff" }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; visible: root.kind==="action"; text: "›"; color: root.primary && root.available ? (Theme.dark?Theme.surface:Theme.accentInk) : Theme.muted; font.pixelSize: 22 }
    Item { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 100; height: 44; visible: root.slider
        Text { anchors.right: parent.right; y: 0; text: root.level<0?"Unavailable":root.muted?"Muted":Math.round(root.level)+"%"; color: Theme.muted; font.pixelSize: 11 }
        Rectangle { y: 28; width: parent.width; height: 4; radius: 2; color: Theme.divider
            Rectangle { width: parent.width*Math.min(100,Math.max(0,root.level))/100; height: 4; radius: 2; color: Theme.accent }
        }
        Rectangle { x: (parent.width-12)*Math.min(100,Math.max(0,root.level))/100; y: 24; width: 12; height: 12; radius: 6; color: Theme.accent; visible: root.level>=0 }
        MouseArea { anchors.fill: parent; enabled: root.level>=0; onPressed: mouse => root.levelRequested(Math.max(0,Math.min(100,Math.round(mouse.x/width*100)))); onPositionChanged: mouse => { if(pressed) root.levelRequested(Math.max(0,Math.min(100,Math.round(mouse.x/width*100)))) } }
    }
}
