import QtQuick
import QtQuick.Controls

Item {
    id: root
    objectName: "profile-inventory-page"
    required property var shell
    readonly property var inventory: shell.inventory
    readonly property var view: inventory.view
    readonly property var selected: view.selected || ({})
    readonly property bool compact: height < 400
    readonly property color accent: Theme.dark ? "#a6e0c9" : "#356f60"
    enabled: shell.profileContentActive

    Text {
        id: title; width: parent.width - 160
        text: root.view.detail ? "Item details" : "Inventory"
        font.family: Theme.displayFamily; font.pixelSize: root.compact ? 30 : 38; color: Theme.ink
    }
    Text {
        anchors.right: parent.right; y: 9; text: "FREE WITH YOUR PROFILE"
        font.pixelSize: 10; font.bold: true; color: root.accent
    }
    Text {
        y: title.height + 3; width: parent.width
        text: root.view.preview ? "DESIGN PREVIEW · SAMPLE ITEMS, NOT OWNED" : "Your collection, beyond a single adventure."
        font.pixelSize: 12; color: root.view.preview ? Theme.ink : Theme.muted
    }

    Rectangle {
        id: empty; objectName: "inventory-empty"
        y: title.height + 30; width: parent.width; height: parent.height - y - 44
        visible: root.view.items.length === 0
        radius: 18; color: Theme.surface; border.color: Theme.divider
        Item {
            width: parent.width * .29; height: parent.height
            Rectangle {
                anchors.centerIn: parent; width: Math.min(parent.width - 20, 130); height: width; radius: 24
                color: Theme.dark ? "#284e47" : "#d6eadd"; rotation: -9
            }
            MenuGlyph { anchors.centerIn: parent; width: 64; height: 64; glyph: "boxes"; ink: root.accent }
        }
        Column {
            x: parent.width * .29; width: parent.width - x - 22; anchors.verticalCenter: parent.verticalCenter
            spacing: root.compact ? 8 : 14
            Text { width: parent.width; text: "Your inventory starts here"; wrapMode: Text.WordWrap; font.family: Theme.displayFamily; font.pixelSize: root.compact ? 23 : 30; color: Theme.ink }
            Text { width: parent.width; text: "A home for collectibles from supported games and future Bazaar purchases. You won't need your own bazaar."; wrapMode: Text.WordWrap; font.pixelSize: root.compact ? 12 : 15; color: Theme.muted }
            Text { text: "UNDER DEVELOPMENT"; font.pixelSize: 12; font.bold: true; color: root.accent }
            Text { width: parent.width; text: "Game transfers and trading aren't available yet. Nothing has been moved from your saves."; wrapMode: Text.WordWrap; font.pixelSize: root.compact ? 12 : 14; color: Theme.ink }
        }
    }

    GridView {
        id: grid; objectName: "inventory-grid"
        y: title.height + 30; width: parent.width; height: parent.height - y - 44; clip: true
        visible: root.view.items.length > 0 && !root.view.detail
        model: root.view.items; cellWidth: width / 3; cellHeight: root.compact ? 133 : 166
        ScrollBar.vertical: ScrollBar { policy: grid.contentHeight > grid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
        currentIndex: root.view.index
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
        onVisibleChanged: if (visible) positionViewAtIndex(currentIndex, GridView.Contain)
        delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            objectName: "inventory-item-" + index
            width: grid.cellWidth - 10; height: grid.cellHeight - 10; radius: 12
            color: index === root.view.index ? Theme.selection : Theme.surface
            border.width: index === root.view.index ? 2 : 1
            border.color: index === root.view.index ? Theme.focus : Theme.divider
            Image { x: 10; y: 10; width: root.compact ? 60 : 80; height: width; source: card.modelData.image || ""; fillMode: Image.PreserveAspectFit }
            Text { anchors.right: parent.right; anchors.rightMargin: 10; y: 14; text: card.modelData.subtitle || ""; textFormat: Text.PlainText; font.pixelSize: 12; color: Theme.ink }
            Text { x: 10; y: root.compact ? 75 : 96; width: parent.width - 20; text: card.modelData.title; textFormat: Text.PlainText; font.pixelSize: 16; font.bold: true; color: Theme.ink; elide: Text.ElideRight }
            Text { x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: parent.width - 20; text: card.modelData.state === "listed" ? "On sale" : card.modelData.game; textFormat: Text.PlainText; font.pixelSize: 10; color: root.accent; elide: Text.ElideRight }
            MouseArea { anchors.fill: parent; onClicked: root.shell.activate(card.index, "profile") }
            Accessible.role: Accessible.Button
            Accessible.name: modelData.title + ", " + modelData.game
            Accessible.onPressAction: root.shell.activate(index, "profile")
        }
    }

    Flickable {
        id: details; objectName: "inventory-details"
        y: title.height + 30; width: parent.width; height: parent.height - y - 44
        visible: root.view.detail; clip: true; contentWidth: width; contentHeight: Math.max(portrait.height, facts.height)
        onVisibleChanged: if (visible) contentY = 0
        Connections { target: root.inventory; function onScrollRequested(delta) { details.contentY = Math.max(0, Math.min(details.contentY + delta, details.contentHeight - details.height)) } }
        ScrollBar.vertical: ScrollBar { policy: details.contentHeight > details.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: portrait; width: parent.width * .33; spacing: 4
            Image { anchors.horizontalCenter: parent.horizontalCenter; width: root.compact ? 105 : 155; height: width; source: root.selected.image || ""; fillMode: Image.PreserveAspectFit }
            Text { width: parent.width; text: root.selected.title || ""; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.family: Theme.displayFamily; font.pixelSize: 25; color: Theme.ink }
            Text { width: parent.width; text: root.selected.game || ""; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11; color: root.accent }
            Text { width: parent.width; text: root.selected.state === "listed" ? "ON SALE" : "IN INVENTORY"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 10; font.bold: true; color: root.accent }
        }
        Column {
            id: facts; x: parent.width * .36; width: parent.width - x - 10; spacing: root.compact ? 7 : 10
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: root.selected.facts || []
                    delegate: Rectangle {
                        required property var modelData
                        width: (facts.width - 8) / 2; height: root.compact ? 40 : 54; radius: 7; color: Theme.surface
                        Column { x: 10; y: 6; width: parent.width - 20; spacing: 3
                            Text { text: modelData.label; textFormat: Text.PlainText; font.pixelSize: 10; color: Theme.muted }
                            Text { width: parent.width; text: modelData.value; textFormat: Text.PlainText; font.pixelSize: 13; color: Theme.ink; elide: Text.ElideRight }
                        }
                    }
                }
            }
            Text { text: "MOVES"; visible: (root.selected.moves || []).length > 0; font.pixelSize: 10; font.bold: true; color: root.accent }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: root.selected.moves || []
                    delegate: Text { required property string modelData; width: (facts.width - 8) / 2; text: modelData; textFormat: Text.PlainText; font.pixelSize: 12; color: Theme.ink; elide: Text.ElideRight }
                }
            }
            Text { width: parent.width; text: root.selected.state === "listed" ? "An item on sale must be withdrawn before returning it to a game." : "Items will be transferable only to compatible games with room to receive them."; wrapMode: Text.WordWrap; font.pixelSize: 11; color: Theme.muted }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 35; width: parent.width; height: 1; color: Theme.divider }
    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 9; width: parent.width
        text: root.view.detail ? "↑↓  Read   ·   B  Inventory     |     Transfers and trading are not available yet" : root.view.items.length ? "↑↓ ←→  Choose   ·   A  Details   ·   B  Profile     |     Transfers are not available yet" : "Transfer from game · Not available yet     |     No Sparks required"
        font.pixelSize: 11; color: Theme.muted; wrapMode: Text.WordWrap
    }
}
