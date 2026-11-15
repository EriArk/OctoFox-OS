import QtQuick
import QtQuick.Controls

Item {
    id: root
    objectName: "profile-inventory-page"
    required property var shell
    readonly property var inventory: shell.inventory
    readonly property var view: inventory.view
    readonly property var selected: view.selected || ({})
    readonly property color accent: Theme.dark ? "#a6e0c9" : "#356f60"
    readonly property string statusText: view.preview ? "SAMPLE ITEMS" : view.busy ? "Loading inventory…" : view.message ||
        (view.state === "signed_out" ? "Connect your TrainerOS account to view your items." :
         view.state === "offline" ? "Reconnect your TrainerOS account to load your inventory." :
         view.state === "ready" ? (view.hasMore ? "Search and filters apply to loaded items. Load more to see the rest." : "Inventory up to date.") : "Inventory is being prepared.")
    enabled: shell.profileContentActive

    component Tool: Rectangle {
        required property int action
        required property string label
        height: 29; radius: 5
        color: root.view.control === action ? Theme.selection : Theme.surface
        border.color: root.view.control === action ? Theme.focus : Theme.divider
        opacity: enabled ? 1 : .45
        Text { x: 9; width: parent.width - 18; anchors.verticalCenter: parent.verticalCenter; text: parent.label; textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.ink; font.pixelSize: 12 }
        MouseArea { anchors.fill: parent; onClicked: root.inventory.control(parent.action) }
        Accessible.role: Accessible.Button; Accessible.name: label
        Accessible.onPressAction: root.inventory.control(action)
    }
    Row {
        id: toolbar; width: parent.width; height: 30; spacing: 7
        Text { width: 90; height: 29; verticalAlignment: Text.AlignVCenter; text: "Inventory"; font.family: Theme.displayFamily; font.pixelSize: 21; color: Theme.ink }
        Tool { objectName: "inventory-search"; width: Math.max(100, root.width - 421); action: 0; label: root.view.search || "Search…  R3" }
        Tool { objectName: "inventory-filter"; width: 76; action: 1; label: root.view.filter + " ↻" }
        Tool { objectName: "inventory-sort"; width: 82; action: 2; label: root.view.sort + " ↻" }
        Tool { objectName: "inventory-more"; width: 100; action: 3; label: root.view.loaded + " / " + root.view.total + (root.view.hasMore ? " ↓" : ""); enabled: root.view.hasMore && !root.view.busy; Accessible.name: "Load more items" }
        Tool { objectName: "inventory-refresh"; width: 38; action: 4; label: "↻"; enabled: root.view.connected && !root.view.busy && !root.view.preview; Accessible.name: "Refresh inventory" }
    }
    GridView {
        id: grid; objectName: "inventory-grid"
        y: 40; width: Math.floor(root.width * .61); height: root.height - y - 42; clip: true
        model: Math.max(30, root.view.items.length)
        cellWidth: (width - 9) / 6; cellHeight: height / 5
        currentIndex: root.view.index
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: grid.contentHeight > grid.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        onCountChanged: Qt.callLater(function() { grid.positionViewAtIndex(grid.currentIndex, GridView.Contain) })
        HoverHandler {
            id: gridHover
            readonly property point pointerScenePosition: point.scenePosition
            onPointerScenePositionChanged: {
                const position = grid.mapFromItem(null, pointerScenePosition.x, pointerScenePosition.y)
                if (position.x >= 0 && position.x < grid.width && position.y >= 0 && position.y < grid.height)
                    root.inventory.activate(grid.indexAt(position.x + grid.contentX, position.y + grid.contentY))
            }
        }
        delegate: Rectangle {
            id: slot
            required property int index
            readonly property var record: root.view.items[index] || ({})
            readonly property bool occupied: !!record.id
            readonly property bool chosen: occupied && index === root.view.index
            objectName: "inventory-slot-" + index
            width: grid.cellWidth - 4; height: grid.cellHeight - 4; radius: 5
            color: chosen ? Theme.selection : Theme.surface
            border.width: chosen ? 2 : 1; border.color: chosen ? Theme.focus : Theme.divider
            Image { anchors.centerIn: parent; width: Math.min(parent.width - 8, parent.height - 4); height: width; source: slot.record.image || ""; fillMode: Image.PreserveAspectFit }
            MenuGlyph { anchors.centerIn: parent; width: Math.min(parent.width - 18, parent.height - 16); height: width; visible: slot.occupied && !slot.record.image; glyph: slot.record.icon === "inventory" ? "boxes" : slot.record.icon === "gamepad" ? "game-controller" : slot.record.icon === "map" ? "journey" : slot.record.icon || "boxes"; ink: root.accent }
            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 4; text: slot.record.subtitle || ""; textFormat: Text.PlainText; font.pixelSize: 10; color: Theme.ink; style: Text.Outline; styleColor: slot.color }
            Rectangle {
                visible: slot.record.state === "listed"; x: 4; y: 4; width: 16; height: 16; radius: 4; color: Theme.yellow
                MenuGlyph { anchors.centerIn: parent; width: 12; height: 12; glyph: "shop"; ink: "#203c38" }
            }
            MouseArea {
                anchors.fill: parent; enabled: slot.occupied
                onClicked: root.inventory.activate(slot.index)
            }
            Accessible.role: Accessible.Button
            Accessible.name: occupied ? record.title + ", " + record.subtitle + (record.state === "listed" ? ", on sale" : "") : "Empty slot"
            Accessible.onPressAction: if (occupied) root.inventory.activate(index)
        }
    }
    Rectangle { x: grid.width + 5; y: grid.y; width: 1; height: grid.height; color: Theme.divider }
    Item {
        id: inspector; objectName: "inventory-inspector"
        x: grid.width + 17; y: grid.y; width: parent.width - x; height: grid.height
        Column {
            id: empty; objectName: "inventory-empty"; visible: !root.selected.id
            width: parent.width - 8; spacing: 12
            Text { width: parent.width; text: root.view.loaded ? "No matches" : root.view.busy ? "Loading inventory" : root.view.state === "ready" ? "Your inventory is empty" : root.view.state === "signed_out" ? "Your profile inventory" : "Inventory unavailable"; wrapMode: Text.WordWrap; font.family: Theme.displayFamily; font.pixelSize: 22; color: Theme.ink }
            Text { width: parent.width; text: root.view.loaded ? "Try another name, change the filter or load more items." : root.view.state === "ready" ? "Collectibles from supported games will appear here. You won't need your own bazaar." : root.statusText; textFormat: Text.PlainText; wrapMode: Text.WordWrap; font.pixelSize: 13; color: Theme.muted }
            Text { width: parent.width; visible: !root.view.total; text: "Transfers and trading are not available yet. Nothing has been moved from your saves."; wrapMode: Text.WordWrap; font.pixelSize: 12; color: root.accent }
            CapButton { objectName: "inventory-clear-search"; visible: !!root.view.search; width: 150; height: 30; label: "Clear search"; textSize: 12; onActivated: root.inventory.clearSearch() }
        }
        Flickable {
            id: details; objectName: "inventory-details"; width: parent.width; height: parent.height - 43
            visible: !!root.selected.id; contentWidth: width; contentHeight: detailBody.height; clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: details.contentHeight > details.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
            Connections { target: root.inventory; function onScrollRequested(delta) { details.contentY = Math.max(0, Math.min(details.contentY + delta, details.contentHeight - details.height)) } }
            property string selectedId: root.selected.id || ""
            onSelectedIdChanged: contentY = 0
            Column {
                id: detailBody; width: parent.width - 10; spacing: 8
                Column {
                    width: parent.width; spacing: 3
                    Text { objectName: "inventory-selected-name"; width: parent.width; text: root.selected.title || ""; textFormat: Text.PlainText; font.family: Theme.displayFamily; font.pixelSize: 23; color: Theme.ink; elide: Text.ElideRight }
                    Text { width: parent.width; text: (root.selected.game || "") + (root.selected.state === "listed" ? " · On sale" : ""); textFormat: Text.PlainText; font.pixelSize: 11; color: root.accent; elide: Text.ElideRight }
                }
                Flow {
                    width: parent.width; spacing: 5
                    Repeater {
                        model: root.selected.facts || []
                        delegate: Column {
                            required property var modelData
                            width: (detailBody.width - 5) / 2; height: 32; spacing: 2
                            Text { width: parent.width; text: modelData.label; textFormat: Text.PlainText; font.pixelSize: 10; color: Theme.muted; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.value; textFormat: Text.PlainText; font.pixelSize: 13; color: Theme.ink; elide: Text.ElideRight }
                        }
                    }
                }
                Text { text: "MOVES"; visible: (root.selected.moves || []).length > 0; font.pixelSize: 10; font.bold: true; color: root.accent }
                Flow {
                    width: parent.width; spacing: 5
                    Repeater { model: root.selected.moves || []; delegate: Text { required property string modelData; width: (detailBody.width - 5) / 2; text: modelData; textFormat: Text.PlainText; font.pixelSize: 12; color: Theme.ink; elide: Text.ElideRight } }
                }
            }
        }
        Row {
            visible: !!root.selected.id; anchors.bottom: parent.bottom; width: parent.width; height: 33; spacing: 6
            Repeater {
                model: ["To game", root.selected.state === "listed" ? "Withdraw" : "List for sale"]
                delegate: Rectangle {
                    required property string modelData
                    width: (inspector.width - 6) / 2; height: 30; radius: 5; color: Theme.surface; border.color: Theme.divider; opacity: .5
                    Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: Theme.ink }
                    Accessible.role: Accessible.Button; Accessible.name: modelData + ", not available yet"; Accessible.ignored: false
                    enabled: false
                }
            }
        }
    }
    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18; width: parent.width; font.pixelSize: 11; color: root.accent; elide: Text.ElideRight
        text: root.statusText; textFormat: Text.PlainText
    }
    Text {
        anchors.bottom: parent.bottom; width: parent.width; font.pixelSize: 10; color: Theme.muted; elide: Text.ElideRight
        text: (root.view.preview ? "SAMPLE ITEMS · " : "") + "↑↓←→ Select · R3 Search · Select Controls · RS Read · B Profile     |     Transfers / trading unavailable"
    }
}
