import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var shell
    required property var flow
    required property var session
    readonly property bool selecting: !flow.connections && !flow.service.length
    readonly property bool trainer: flow.stage === "trainer"
    readonly property bool comfort: flow.stage === "preferences"
    readonly property bool takesFocus: visible && !shell.keyboard.open
    readonly property bool saving: flow.busy || shell.settings.saving || (trainer && shell.trainerSetup.busy)
    Row {
        x: Theme.brandWidth + 12; y: 26; width: parent.width-x-24
        Repeater {
            model: root.flow.stepLabels
            Item {
                required property int index
                required property string modelData
                width: parent.width/root.flow.stepLabels.length; height: 45
                Rectangle { x: 10; y: 8; width: parent.width; height: 2; color: index<root.flow.step ? Theme.accent : Theme.divider; visible: index<root.flow.stepLabels.length-1 }
                Rectangle {
                    width: 19; height: 19; radius: 10; color: index<=root.flow.step ? Theme.yellow : Theme.selection
                    Text { anchors.centerIn: parent; text: index<root.flow.step ? "✓" : index+1; font.pixelSize: 10; color: Theme.ink }
                }
                Text { x: -4; y: 24; width: parent.width; text: modelData; color: index===root.flow.step ? Theme.ink : Theme.muted; font.pixelSize: 11; font.bold: index===root.flow.step; elide: Text.ElideRight }
            }
        }
    }
    Item {
        x: 24; y: 84; width: parent.width-48; height: parent.height-y-83
        visible: root.selecting
        Rectangle { anchors.fill: parent; color: Theme.paper; radius: 12 }
        Rectangle { id: side; width: parent.width*0.28; height: parent.height; color: Theme.selection; radius: 12 }
        Text { x: 18; y: 20; width: side.width-36; text: root.trainer ? "YOUR TRAINER" : "YOUR ADVENTURE KIT"; font.family: Theme.brandFamily; font.pixelSize: 12; color: Theme.muted; wrapMode: Text.WordWrap }
        SetupIllustration {
            x: 5; anchors.verticalCenter: parent.verticalCenter; width: side.width-10; height: width*272/320
            visible: !root.trainer; stage: root.flow.stage
        }
        Column {
            x: 16; width: side.width-32; anchors.verticalCenter: parent.verticalCenter; spacing: 18; visible: root.trainer
            TrainerEmblem { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(126,parent.width-24); height: width; emblem: root.shell.trainerSetup.emblem }
            Text { width: parent.width; text: root.shell.trainerSetup.name || "Your name"; textFormat: Text.PlainText; font.pixelSize: 22; font.family: Theme.displayFamily; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WrapAnywhere; color: Theme.ink }
            Text { width: parent.width; text: "LOCAL PROFILE"; font.pixelSize: 11; font.letterSpacing: 1; horizontalAlignment: Text.AlignHCenter; color: Theme.muted }
        }
        Item {
            x: side.width+24; y: 18; width: parent.width-x-24; height: parent.height-34
            Text { id: heading; width: parent.width; text: root.flow.title; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 28; wrapMode: Text.WordWrap }
            Text { id: subtitle; y: heading.height+8; width: parent.width; text: root.flow.description; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
            Item {
                y: subtitle.y+subtitle.height+14; width: parent.width; height: parent.height-y-(status.text.length?38:0)
                StorageChoices { anchors.fill: parent; flow: root.flow; visible: root.flow.stage==="storage"; takesFocus: root.takesFocus }
                ListView {
                    id: choices; anchors.fill: parent; clip: true; spacing: 4
                    visible: root.flow.stage!=="storage"
                    model: root.trainer ? root.shell.trainerSetup.rows : root.flow.rows
                    currentIndex: root.trainer ? root.shell.trainerSetup.focusIndex : root.flow.focusIndex; keyNavigationEnabled: false
                    function reveal() { if(count)positionViewAtIndex(currentIndex,ListView.Contain) }
                    onCurrentIndexChanged: Qt.callLater(reveal)
                    onCountChanged: Qt.callLater(reveal)
                    onHeightChanged: Qt.callLater(reveal)
                    ScrollBar.vertical: SettingsScrollBar {}
                    delegate: SettingsRow {
                        required property int index
                        required property var modelData
                        objectName: "setup-choice-"+index; width: choices.width-8
                        height: Math.max(54,implicitHeight)
                        title: modelData.label
                        detail: primary ? "" : root.comfort && index===0 ? (root.shell.settings.theme==="dark"?"Dark":"Light")
                            : root.comfort && index===1 ? (root.shell.settings.interfaceScale===100?"Normal":root.shell.settings.interfaceScale===120?"Large":root.shell.settings.interfaceScale+"%")
                            : root.flow.stage==="accounts" && index===0 ? (root.shell.backendAccount.loginState==="connected" && root.shell.social.account.state==="connected" ? "Connected · " : "")+modelData.detail
                            : root.flow.stage==="accounts" && index===1 ? (root.shell.hall.account.connected?"Connected · ":"")+modelData.detail
                            : root.flow.stage==="accounts" && index===2 ? (root.shell.scraper.accountVerified?"Connected · ":"")+modelData.detail
                            : modelData.detail
                        kind: root.comfort && index<2 ? "stepper" : "action"
                        primary: index===choices.count-1 && root.flow.stage!=="ready" || root.flow.stage==="ready" && index===0
                        selected: root.takesFocus && index===choices.currentIndex && !root.saving
                        enabled: !root.saving && modelData.enabled!==false
                        onActivated: root.trainer ? root.shell.trainerSetup.activate(index) : root.flow.activate(index)
                        onAdjustmentRequested: direction => root.flow.adjustComfort(index,direction)
                    }
                }
            }
            Text {
                id: status; anchors.bottom: parent.bottom; width: parent.width; height: 32
                text: root.trainer ? (root.shell.trainerSetup.busy?"Saving your Trainer…":root.shell.trainerSetup.error || root.flow.error)
                    : root.flow.busy?"Preparing your library…":root.flow.error || (root.comfort?root.shell.settings.error:"")
                textFormat: Text.PlainText; color: Theme.textColor("#853b24"); font.pixelSize: 13; wrapMode: Text.WordWrap
            }
        }
    }
    FirstRunServicePanel {
        x: 24; y: 84; width: parent.width-48; height: parent.height-y-83
        visible: root.flow.service.length>0
        shell: root.shell; flow: root.flow; session: root.session
    }
    ConnectionsPane { x: 40; y: 83; width: parent.width-80; height: parent.height-y-85; shell: root.shell; onboarding: true; visible: root.flow.connections }
    CapButton {
        objectName: "setup-back"; x: 26; anchors.bottom: parent.bottom; anchors.bottomMargin: 34; width: 170; height: 38
        visible: root.flow.stage!=="welcome"
        enabled: !root.saving && !root.shell.keyboard.open
        label: "Back"; textSize: 16; onActivated: root.session.backInSetup()
    }
}
