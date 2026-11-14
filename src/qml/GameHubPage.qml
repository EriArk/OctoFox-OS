import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var shell
    objectName: "gamehub"
    function hints(h) {
        if(shell.adapterMenuOpen) return [h("↑↓←→","Choose"),h("A","Open"),h("B","Home")]
        return presenter.hints(h) || [h("A","Open"),h("B","Adapter home")]
    }
    readonly property bool available: visible && !shell.serviceOpen && !shell.menuOpen
        && !shell.homeMenuOpen && !shell.drawerOpen && !shell.quickAppsOpen && !shell.keyboard.open && !shell.notice.length
    readonly property var colors: ["#9edcc3", "#afc9f3", "#f1ce82", "#f2b4bf", "#c3b1ec", "#a7d9ed", "#e8b891", "#bada95", "#efca6b"]
    Item {
        id: home; objectName: "adapter-home"; anchors.fill: parent; visible: root.shell.adapterMenuOpen
        Text {
            x: 16; y: 1; text: root.shell.primaryNames[2]; textFormat: Text.PlainText
            font.family: Theme.displayFamily; font.pixelSize: 26; color: Theme.ink
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 20; y: 12; text: "Choose a space"; color: Theme.muted; font.pixelSize: 12 }
        GridView {
            id: spaces; objectName: "adapter-screen-menu"
            x: 6; y: 39; width: parent.width - 12; height: parent.height - y - Theme.adventureCutoutHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            cellWidth: (width - 10) / 3; cellHeight: Math.max(112, height / 2)
            model: root.shell.adapterMenu; currentIndex: root.shell.adapterMenuFocus
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
            onVisibleChanged: if (visible) Qt.callLater(function(){ spaces.positionViewAtIndex(spaces.currentIndex, GridView.Contain) })
            ScrollBar.vertical: ScrollBar { policy: spaces.contentHeight > spaces.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                objectName: "adapter-screen-" + modelData.id
                width: spaces.cellWidth - 10; height: spaces.cellHeight - 7
                readonly property bool artworkReady: sticker.artworkReady
                readonly property bool focused: root.available && root.shell.adapterMenuFocus === index
                Rectangle {
                    anchors.fill: parent; anchors.margins: 2; radius: 18
                    color: tile.focused ? Theme.selection : (pointer.containsMouse ? Theme.surface : "transparent")
                    border.color: tile.focused ? Theme.focusGlow : "transparent"; border.width: 2
                }
                AdapterSticker {
                    id: sticker
                    anchors.horizontalCenter: parent.horizontalCenter; y: 5
                    width: Math.min(150, tile.height - 29); height: width
                    glyph: tile.modelData.icon; artwork: tile.modelData.artwork || ""
                    tint: root.colors[tile.index % root.colors.length]; tilt: tile.index % 2 ? 5 : -5
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 5; x: 8; width: parent.width - 16
                    text: tile.modelData.label; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.displayFamily; font.pixelSize: 17; font.bold: tile.focused; color: Theme.ink; elide: Text.ElideRight
                }
                MouseArea { id: pointer; anchors.fill: parent; enabled: root.available; hoverEnabled: true; onClicked: root.shell.selectAdapterScreen(tile.modelData.id) }
                Accessible.role: Accessible.Button; Accessible.name: modelData.label
                Accessible.onPressAction: if (root.available) root.shell.selectAdapterScreen(modelData.id)
            }
        }
    }
    Item {
        anchors.fill: parent; visible: !root.shell.adapterMenuOpen; enabled: root.available && visible; clip: true
        ExperienceHost { id: presenter; anchors.fill: parent; shell: root.shell }
        ExperienceHost { anchors.fill: parent; shell: root.shell; overlay: true }
    }
}
