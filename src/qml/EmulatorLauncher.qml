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
        PageHeader { id: header; title: "Emulators" }
        CapButton {
            anchors.right: parent.right; anchors.rightMargin: Theme.pageMargin
            anchors.verticalCenter: header.verticalCenter; width: 84; height: 36
            label: "Back"; flat: true; enabled: root.takesFocus
            onActivated: root.flow.close()
        }
        GridView {
            id: grid
            anchors { top: header.bottom; bottom: status.top; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; topMargin: 4 }
            clip: true; boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / root.flow.emulatorColumns; cellHeight: 155
            model: root.flow.emulators; currentIndex: root.flow.emulatorIndex
            onCurrentIndexChanged: if(currentIndex>=0) positionViewAtIndex(currentIndex,GridView.Contain)
            ScrollBar.vertical: SettingsScrollBar {}
            delegate: Item {
                id: tile
                required property int index
                required property var modelData
                readonly property bool selected: root.takesFocus && grid.currentIndex===index
                objectName: "emulator-"+modelData.id; width: grid.cellWidth; height: grid.cellHeight
                enabled: root.takesFocus && (!root.flow.busy || (root.flow.setupRunning && grid.currentIndex===index))
                Accessible.role: Accessible.Button
                Accessible.name: modelData.title+", "+modelData.detail
                Accessible.onPressAction: if(enabled) root.flow.launchEmulator(index)
                Rectangle {
                    anchors.fill: parent; anchors.margins: 4; radius: 12
                    color: tile.selected ? Theme.selection : "transparent"
                    border.width: tile.selected ? 2 : 0; border.color: Theme.accent
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 9; width: 90; height: 90
                    source: "image://desktop-app/emulator/"+encodeURIComponent(tile.modelData.id)+"/"+encodeURIComponent(tile.modelData.platform)
                    sourceSize: Qt.size(192,192); fillMode: Image.PreserveAspectFit
                }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 101; width: 34; height: 3; radius: 2; color: Theme.focusGlow; visible: tile.selected }
                Text {
                    y: 107; width: parent.width-12; anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.modelData.title; font.family: Theme.displayFamily; font.pixelSize: 19; font.bold: true
                    color: Theme.ink; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                }
                Text {
                    y: 133; width: parent.width-12; anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.modelData.detail; font.pixelSize: 13; color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; onClicked: root.flow.launchEmulator(tile.index) }
            }
            Text {
                anchors.centerIn: parent; width: parent.width-32; visible: grid.count===0
                text: "No installed emulator has a standalone interface."
                color: Theme.muted; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            }
        }
        Text {
            id: status; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
            height: text.length ? implicitHeight : 0
            text: root.flow.status; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 14; wrapMode: Text.WordWrap
        }
    }
}
