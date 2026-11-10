import QtQuick
import QtQuick.Controls
Item {
    id: root
    property bool flat: false
    required property var shell
    property bool onboarding: false
    property bool quick: false
    readonly property var network: shell.network
    readonly property bool focused: (quick || onboarding || shell.settings.controlsFocused) && (quick || !shell.menuOpen) && !shell.keyboard.open && !shell.notice.length
    function enter() { if(!quick && !onboarding && !shell.settings.controlsFocused) shell.settings.selectCategory(10,true) }
    Row {
        x: 0; y: 10; width: parent.width; spacing: 8
        Text { visible: root.quick; width: root.quick?root.width-132:0; height: 38; verticalAlignment: Text.AlignVCenter; text: root.network.bluetooth ? "Nearby & paired devices" : "Available networks"; color: Theme.muted; font.pixelSize: 14 }
        Repeater { model: root.quick?[]:["Wi-Fi", "Bluetooth"]
            CapButton { flat: root.flat;
                required property int index; required property string modelData
                width: (root.width-140)/2; height: 43; label: modelData; textSize: 18
                tint: root.network.bluetooth===(index===1) ? Theme.yellow : Theme.blue
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: Theme.accent; visible: root.flat && root.network.bluetooth===(index===1) }
                onActivated: { root.enter();root.network.selectFace(index===1) }
            }
        }
        CapButton { flat: root.flat;
            width: 124; height: root.quick?32:43; textSize: 15
            objectName: "connection-radio"
            readonly property var radio: root.shell.device.radios[root.network.bluetooth?1:0]
            label: radio.detail; tint: radio.level===1 ? Theme.green : Theme.pink
            enabled: radio.level>=0 && !root.network.busy && !root.network.prompt.length
            onActivated: { root.enter();root.network.toggleRadio() }
        }
    }
    // Shared Wi-Fi flow in Settings, Start and first run; Bluetooth keeps its pairing prompt.
    ListView {
        ScrollBar.vertical: SettingsScrollBar {}
        id: list; objectName: "connection-list"
        x: 0; y: root.quick?52:68; width: parent.width; height: parent.height-y-(root.network.status.length || root.shell.device.error.length ? 100 : 60)
        clip: true; spacing: 7; model: root.visible && visible ? root.network.rows : []
        visible: !root.network.prompt.length && !root.network.detailsOpen
        currentIndex: root.network.focusIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex,ListView.Contain)
        onCountChanged: positionViewAtIndex(currentIndex,ListView.Contain)
        delegate: Item {
            id: entry
            required property int index; required property var modelData
            objectName: "connection-"+index
            width: list.width-5; height: root.quick?48:57
            enabled: !root.network.busy
            ActivityRow { flat: root.flat; width: parent.width-(root.network.bluetooth?0:36); height: parent.height; visible: true
                label: entry.modelData.title; detail: entry.modelData.detail; glyph: root.network.bluetooth ? "bluetooth" : "wifi"
                accent: entry.modelData.connected?Theme.green:entry.modelData.saved?Theme.blue:Theme.paper
                selected: root.focused && root.network.focusIndex===entry.index
                onActivated: {root.enter();root.network.activate(entry.index)}
            }
            SocialIconButton {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                visible: !root.network.bluetooth; glyph: "info"; label: "Network details"
                onClicked: {root.enter();root.network.showDetails(entry.index)}
            }
        }
        Text {
            x: 18; y: 28; width: parent.width-36; wrapMode: Text.WordWrap
            visible: list.count===0 && !root.network.busy
            text: root.network.bluetooth ? "No devices found. Turn on pairing mode and search nearby." : "No networks found. Check Wi-Fi and search again."
            color: Theme.muted; font.pixelSize: 18
        }
    }
    Item {
        id: details; objectName: "wifi-details"
        x: 0; y: root.quick?52:68; width: parent.width; height: parent.height-y-12
        visible: root.network.detailsOpen && !root.network.prompt.length
        readonly property var info: root.network.networkInfo
        SocialIconButton { x: 0; y: 0; glyph: "back"; label: "Back to networks"; onClicked: root.network.back() }
        Text { x: 40; y: 0; width: parent.width-46; text: details.info.title || "Network"; textFormat: Text.PlainText; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 22; elide: Text.ElideRight }
        Text { x: 40; y: 28; width: parent.width-46; text: [details.info.detail || "Hidden network",details.info.address || ""].filter(Boolean).join(" · "); textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
        Text {
            id: connectionError; x: 8; y: 51; width: parent.width-16
            text: root.network.failed || root.network.busy ? root.network.status : ""; textFormat: Text.PlainText
            color: root.network.failed ? Theme.ink : Theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap
        }
        ListView {
            ScrollBar.vertical: SettingsScrollBar {}
            id: detailList; objectName: "wifi-detail-actions"
            x: 0; y: 56+connectionError.height; width: parent.width; height: parent.height-y; clip: true; spacing: 2
            model: root.visible && details.visible ? root.network.detailActions : []; currentIndex: root.network.detailFocus
            onCurrentIndexChanged: if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
            delegate: ActivityRow {
                flat: root.flat;
                required property var modelData; required property int index
                width: detailList.width-4; height: 46; label: modelData.title; detail: modelData.detail
                glyph: modelData.id==="autojoin"?"wifi":modelData.id==="password"?"key":modelData.id==="forget"?"close":"chevron"
                accent: modelData.id==="forget"?Theme.pink:Theme.blue
                selected: root.focused && index===root.network.detailFocus; enabled: !root.network.busy
                onActivated: root.network.activateDetail(modelData.id)
            }
        }
    }
    Rectangle {
        x: 0; y: root.quick?52:68; width: parent.width; height: parent.height-y-88
        visible: root.network.prompt.length>0; radius: 12; color: root.flat ? "transparent" : Theme.surfaceColor("#edf2e7"); border.color: Theme.divider
        Text {
            x: 22; y: root.quick?12:24; width: parent.width-44; height: parent.height-(root.quick?70:110)
            text: root.network.prompt; textFormat: Text.PlainText; wrapMode: Text.WordWrap
            font.pixelSize: root.quick?18:23; color: Theme.ink
        }
        CapButton { flat: root.flat;
            objectName: "connection-confirm"
            x: 22; anchors.bottom: parent.bottom; anchors.bottomMargin: root.quick?12:20
            width: (parent.width-52)/2; height: root.quick?32:43; label: root.network.confirmLabel
            visible: root.network.confirmLabel!=="Wait"
            tint: Theme.yellow; selected: root.focused
            onActivated: root.network.activate(0)
        }
        CapButton { flat: root.flat; objectName: "connection-cancel"
            anchors.right: parent.right; anchors.rightMargin: 22; anchors.bottom: parent.bottom; anchors.bottomMargin: root.quick?12:20
            width: (parent.width-52)/2; height: root.quick?32:43; label: "Cancel"; tint: Theme.paper
            onActivated: root.network.back()
        }
    }
    Text {
        x: 4; anchors.bottom: parent.bottom; anchors.bottomMargin: root.flat ? 56 : 42
        width: parent.width-8; height: 40; wrapMode: Text.WordWrap; elide: Text.ElideRight
        text: root.network.detailsOpen ? "" : root.network.status || root.shell.device.error; textFormat: Text.PlainText
        color: root.network.failed ? Theme.ink : Theme.muted; font.pixelSize: 13
    }
    CapButton { flat: root.flat; visible: !root.network.prompt.length && !root.network.detailsOpen; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        objectName: "connection-search"
        width: 100; height: root.flat ? 44 : 30; textSize: 13; label: root.network.busy ? "Cancel" : "Search"; centered: true; tint: Theme.paper
        enabled: !root.network.prompt.length
        onActivated: root.network.busy ? root.network.back() : root.network.search()
    }
    CapButton { flat: true; visible: !root.network.bluetooth && !root.network.prompt.length && !root.network.detailsOpen
        objectName: "connection-hidden"; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        width: 205; height: root.flat ? 44 : 30; textSize: 13; label: "Other network · "+Theme.buttonLabel("L3"); tint: Theme.paper; enabled: !root.network.busy
        onActivated: {root.enter();root.network.otherNetwork()}
    }
    CapButton { flat: root.flat; visible: root.quick && root.network.bluetooth && root.network.canForget && !root.network.prompt.length
        objectName: "connection-forget"; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        width: 160; height: root.flat ? 44 : 30; textSize: 13; label: root.network.bluetooth ? "Forget device" : "Forget network"; tint: Theme.paper
        enabled: !root.network.busy
        onActivated: root.network.forget()
    }
}
