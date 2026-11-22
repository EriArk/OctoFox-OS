// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var shell
    readonly property var flow: shell.gamePreparation
    readonly property bool takesFocus: visible && !shell.menuOpen && !shell.homeMenuOpen && !shell.quickAppsOpen && !shell.notificationsOpen && !shell.notice.length
    objectName: "emulator-launcher"
    Item {
        anchors.fill: parent; anchors.margins: Theme.panelInset; anchors.topMargin: Theme.contentTopInset
        PageHeader { id: header; compact: true; title: "Emulators" }
        CapButton {
            anchors.right: parent.right; y: 4; width: 84; height: 36
            label: "Back"; flat: true; enabled: root.takesFocus
            onActivated: root.flow.close()
        }
        ListView {
            id: list
            anchors { top: header.bottom; bottom: status.top; left: parent.left; right: parent.right; margins: 10 }
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: root.flow.emulators; currentIndex: root.flow.emulatorIndex
            onCurrentIndexChanged: if(currentIndex>=0) positionViewAtIndex(currentIndex,ListView.Contain)
            ScrollBar.vertical: SettingsScrollBar {}
            delegate: SettingsRow {
                required property int index
                required property var modelData
                objectName: "emulator-"+modelData.id; width: list.width-12; height: implicitHeight
                title: modelData.title; detail: modelData.detail
                selected: root.takesFocus && index===list.currentIndex
                enabled: root.takesFocus && (!root.flow.busy || (root.flow.setupRunning && index===list.currentIndex))
                onActivated: root.flow.launchEmulator(index)
            }
            Text {
                anchors.centerIn: parent; width: parent.width-32; visible: list.count===0
                text: "No installed emulator has a standalone interface."
                color: Theme.muted; font.pixelSize: 16; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
            }
        }
        Text {
            id: status; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 }
            height: text.length ? implicitHeight : 0
            text: root.flow.status; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 14; wrapMode: Text.WordWrap
        }
    }
}
