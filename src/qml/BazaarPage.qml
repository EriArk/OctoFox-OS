import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var shell
    readonly property var catalogue: shell.bazaar
    readonly property bool takesFocus: visible && shell.pairedNavigationAvailable && !shell.notificationsOpen
    readonly property bool compact: width<850
    objectName: "bazaar-page"
    function restoreScroll() { grid.contentY=Math.max(0,Math.min(root.catalogue.scroll,grid.contentHeight-grid.height)) }
    onVisibleChanged: { if(visible)Qt.callLater(restoreScroll) }
    Item {
        anchors.fill: parent; anchors.margins: 12
        enabled: root.takesFocus
        BazaarCard {
            id: official; objectName: "bazaar-official"
            x: 0; y: 4; width: Math.floor(parent.width*.43); height: parent.height-8
            official: true; compact: root.compact
            entry: ({title:"Official Bazaar",cover:"qrc:/bazaar/official.png"})
            selected: root.takesFocus && root.catalogue.selection==="official"
            onActivated: root.catalogue.activate("official")
        }
        Item {
            id: players; x: official.width+16; y: 4; width: parent.width-x; height: parent.height-8
            Row {
                id: toolbar; width: parent.width; height: 32; spacing: 7
                CapButton {
                    objectName: "bazaar-search"; width: parent.width-filter.width-create.width-14; height: 29
                    label: root.catalogue.search || "Search bazaars…"; textSize: root.compact ? 11 : 12
                    tint: Theme.blue; claimsFocus: false; flat: true; contentInset: 7
                    selected: root.takesFocus && root.catalogue.selection==="search"
                    onActivated: root.catalogue.editSearch()
                }
                CapButton {
                    id: filter; objectName: "bazaar-filter"; width: root.compact ? 90 : 100; height: 29
                    label: root.catalogue.favoritesOnly ? "★ Favorites" : "All bazaars"; textSize: root.compact ? 10 : 11
                    tint: Theme.green; claimsFocus: false; flat: true; contentInset: 6
                    selected: root.takesFocus && root.catalogue.selection==="filter"
                    onActivated: root.catalogue.activate("filter")
                }
                CapButton {
                    id: create; objectName: "bazaar-create"; width: root.compact ? 97 : 110; height: 29
                    label: root.catalogue.account.owned && root.catalogue.account.owned.id ? "My bazaar" : "+ Create  ✦"; textSize: 12; tint: Theme.yellow; claimsFocus: false; contentInset: 8
                    selected: root.takesFocus && root.catalogue.selection==="create"
                    onActivated: root.catalogue.activate("create")
                }
            }
            GridView {
                id: grid; objectName: "bazaar-player-grid"
                y: toolbar.height+10; width: parent.width; height: parent.height-y
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: root.catalogue.rooms
                cellWidth: width/2; cellHeight: Math.max(root.compact ? 130 : 146,Math.floor(height/2.15))
                currentIndex: root.catalogue.selectedIndex
                cacheBuffer: cellHeight
                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight>grid.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    onPressedChanged: { if(!pressed)root.catalogue.scroll=Math.max(0,grid.contentY) }
                }
                onMovementEnded: { root.catalogue.scroll=Math.max(0,contentY); if(root.catalogue.more && contentY+height>=contentHeight-50)root.catalogue.refresh(true) }
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth; height: grid.cellHeight
                    BazaarCard {
                        objectName: "bazaar-room-"+modelData.id
                        width: parent.width-10; height: parent.height-10
                        entry: modelData; compact: root.compact
                        selected: root.takesFocus && root.catalogue.selection==="room:"+modelData.id
                        onActivated: root.catalogue.activate("room:"+modelData.id)
                        onFavoriteRequested: root.catalogue.toggleFavorite(modelData.id)
                    }
                }
                Connections {
                    target: root.catalogue
                    function onChanged() {
                        if(!root.visible || !root.takesFocus || root.catalogue.selectedIndex<0)return
                        grid.positionViewAtIndex(root.catalogue.selectedIndex,GridView.Contain)
                        root.catalogue.scroll=Math.max(0,grid.contentY)
                    }
                    function onRowsChanged() { Qt.callLater(root.restoreScroll) }
                }
            }
            Column {
                objectName: "bazaar-empty"; visible: root.catalogue.rooms.length===0
                x: 18; y: grid.y+Math.max(25,(grid.height-height)/2); width: parent.width-36; spacing: 10
                Text { width: parent.width; text: root.catalogue.search ? "No matching bazaars" : root.catalogue.favoritesOnly ? "No favorites yet" : "Player bazaars"; font.family: Theme.displayFamily; font.pixelSize: 21; color: Theme.ink; wrapMode: Text.WordWrap }
                Text { objectName: "bazaar-status"; width: parent.width; text: root.catalogue.search ? "Try another name or clear your search." : root.catalogue.favoritesOnly ? "Save a bazaar with its star to find it here." : root.catalogue.status; font.pixelSize: 13; color: Theme.muted; wrapMode: Text.WordWrap }
            }
        }
    }
    Rectangle {
        objectName: "bazaar-dialog"; anchors.fill: parent; visible: root.catalogue.dialog==="realms"
        color: "#880c2526"; z: 2
        enabled: !root.shell.menuOpen && !root.shell.serviceOpen && !root.shell.keyboard.open && !root.shell.notificationsOpen
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent; width: Math.min(440,parent.width-48); height: Math.min(parent.height-20,root.catalogue.dialog==="realms" && root.catalogue.realms.length ? 315 : 205)
            color: Theme.paper; radius: 13; border.color: Theme.divider
            Text { x: 18; y: 17; width: parent.width-60; text: root.catalogue.dialog==="realms" ? "Choose a realm" : "Create a bazaar"; font.family: Theme.displayFamily; font.pixelSize: 23; color: Theme.ink }
            CapButton { objectName: "bazaar-dialog-close"; anchors.right: parent.right; anchors.rightMargin: 9; y: 12; width: 34; height: 30; label: "×"; textSize: 22; centered: true; flat: true; claimsFocus: false; contentInset: 0; onActivated: root.catalogue.closeDialog() }
            Text {
                x: 20; y: 72; width: parent.width-40; font.pixelSize: 14; color: Theme.muted; wrapMode: Text.WordWrap
                visible: root.catalogue.dialog!=="realms" || !root.catalogue.realms.length
                text: root.catalogue.dialog==="realms" ? "The first official Bazaar is being prepared.\nNo realms are open yet." : "Your own place to meet and trade.\nCreation for Sparks will be available soon."
            }
            ListView {
                objectName: "bazaar-realms"; x: 18; y: 62; width: parent.width-36; height: parent.height-y-35; clip: true
                visible: root.catalogue.dialog==="realms" && root.catalogue.realms.length>0
                model: root.catalogue.realms; currentIndex: root.catalogue.realmIndex
                onCurrentIndexChanged: positionViewAtIndex(currentIndex,ListView.Contain)
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    objectName: "bazaar-realm-"+index
                    width: ListView.view.width; height: 45; radius: 7
                    color: index===root.catalogue.realmIndex ? Theme.selection : "transparent"
                    border.width: index===root.catalogue.realmIndex ? 2 : 0; border.color: Theme.focusGlow
                    readonly property real load: modelData.capacity>0 ? modelData.visitors/modelData.capacity : 1
                    Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 5; color: parent.load>=1 ? "#c45561" : parent.load>=.8 ? "#d49b29" : "#459774" }
                    Text { x: 33; anchors.verticalCenter: parent.verticalCenter; width: parent.width-125; text: modelData.name; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 16; elide: Text.ElideRight }
                    Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.visitors+"/"+modelData.capacity; font.pixelSize: 14; color: Theme.ink }
                    MouseArea { anchors.fill: parent; onClicked: root.catalogue.chooseRealm(index) }
                    Accessible.role: Accessible.Button; Accessible.name: modelData.name+", "+modelData.visitors+" of "+modelData.capacity
                    Accessible.onPressAction: root.catalogue.chooseRealm(index)
                }
            }
            Text { x: 20; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; text: "B  Back"; color: Theme.muted; font.pixelSize: 12 }
        }
    }
    BazaarDialog { anchors.fill: parent; shell: root.shell }

}
