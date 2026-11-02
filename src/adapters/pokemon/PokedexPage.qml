import QtQuick
import TrainerOS

Item {
    id: root
    required property var shell
    readonly property var dex: shell.experienceModel.pokedex
    enabled: !shell.drawerOpen
    readonly property bool takesFocus: visible && !shell.adapterMenuOpen && !shell.quickAppsOpen && !shell.drawerOpen && !shell.menuOpen && !shell.keyboard.open && shell.notice.length === 0
    readonly property bool artOpen: dex.zone === "art"
    readonly property bool compactLayout: height < 420
    readonly property int railHeight: compactLayout ? 52 : 62
    readonly property bool pickerOpen: dex.zone === "picker"

    Item {
        anchors.fill: parent
        PageHeader { id: dexHeader; compact: true; title: "Field Guide"; trailing: root.dex.saveTotals; subtitle: root.dex.saveCaption }
        MountedPanel {
            x: 0; y: dexHeader.height; width: parent.width; height: root.railHeight; color: Theme.surfaceColor("#c4dcd5")
            Row {
                x: 14; y: 5; spacing: 8
                Repeater {
                    model: root.dex.rail
                    delegate: CapButton {
                        required property int index
                        required property var modelData
                        objectName: "dex-rail-" + index
                        width: (root.width - 84) / 8; height: root.railHeight - 12; textSize: 14; label: modelData.label; detail: modelData.value
                        tint: index === 0 ? Theme.yellow : index === 5 ? Theme.pink : Theme.blue
                        selected: root.takesFocus && root.dex.zone === "rail" && root.dex.focusIndex === index
                        onActivated: root.shell.activate(index, "rail")
                    }
                }
            }
            // Rail is physically joined to the top frame by the side uprights.
            Rectangle { x: 0; y: -parent.y; width: 6; height: parent.y; color: Theme.surfaceColor("#c4dcd5") }
            Rectangle { anchors.right: parent.right; y: -parent.y; width: 6; height: parent.y; color: Theme.surfaceColor("#c4dcd5") }
        }
        Rectangle {
            x: 0; y: dexHeader.height + root.railHeight; width: root.width * .36; height: root.height - y; color: Theme.surfaceColor("#dbe8dd")
            ListView {
                id: entries
                objectName: "dex-list"
                x: 19; y: 10; width: parent.width - 38; height: parent.height - 20 - (root.shell.chooseAdventureAvailable ? Theme.adventureCutoutHeight : 0)
                model: root.dex.entries; currentIndex: root.dex.entryIndex
                interactive: false; keyNavigationEnabled: false; clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0; cacheBuffer: 216
                function revealCurrent() {
                    if (count > 0) positionViewAtIndex(currentIndex, ListView.Contain);
                    // ListView may restore its focus scope after delegates are rebuilt.
                    // Reassert the actual control only once the current delegate exists.
                    if (root.takesFocus && root.dex.zone === "list" && currentItem)
                        currentItem.focusControl.forceActiveFocus(Qt.OtherFocusReason);
                }
                onCurrentIndexChanged: Qt.callLater(revealCurrent)
                onCurrentItemChanged: Qt.callLater(revealCurrent)
                onModelChanged: Qt.callLater(revealCurrent)
                onVisibleChanged: Qt.callLater(revealCurrent)
                onHeightChanged: Qt.callLater(revealCurrent)
                Connections { target: root; function onTakesFocusChanged() { Qt.callLater(entries.revealCurrent); } }
                delegate: Item {
                    required property int index
                    required property var modelData
                    property alias focusControl: entryButton
                    width: entries.width; height: 65
                    CapButton {
                        id: entryButton
                        objectName: "dex-entry-" + modelData.id
                        x: 5; y: 5; width: parent.width - 10; height: 52
                        label: modelData.number + "   " + modelData.name + (modelData.favorite ? "  ★" : "")
                        detail: modelData.types + "  ·  " + modelData.status
                        contentInset: 60; textSize: 14
                        tint: modelData.favorite ? Theme.yellow : Theme.green
                        selected: root.takesFocus && root.dex.zone === "list" && root.dex.entryIndex === index
                        onActivated: root.shell.activate(index, "list")
                        ClassicIllustration { x: 13; y: 2; width: 48; height: 48; art: modelData.art || ({}) }
                    }
                }
            }
            Text {
                x: 28; y: 31; width: parent.width - 56; wrapMode: Text.WordWrap
                visible: root.dex.entryCount === 0
                text: root.dex.emptyMessage; color: Theme.ink; font.pixelSize: 20; textFormat: Text.PlainText
            }
            CapButton {
                objectName: "dex-recovery"
                x: 24; y: 163; width: parent.width - 48; height: 48; tint: Theme.yellow
                visible: root.dex.entryCount === 0; label: root.dex.recoveryLabel
                selected: root.takesFocus && root.dex.zone === "recovery"
                onActivated: root.shell.activate(0, "recovery")
            }
        }
        Rectangle {
            id: preview
            objectName: "dex-list-preview"
            x: root.width * .36; y: dexHeader.height + root.railHeight; width: parent.width - x; height: root.height - y
            color: Theme.surfaceColor("#e6edde")
            readonly property bool hasEntry: root.dex.entryCount > 0
            readonly property var types: root.dex.detail.types ? root.dex.detail.types.split(" / ") : []
            function typeTint(type) {
                const colors = {Bug:Theme.surfaceColor("#cddd9c"), Dark:Theme.surfaceColor("#c6b9b0"), Dragon:Theme.surfaceColor("#bbbbe8"), Electric:Theme.surfaceColor("#f5dc83"),
                    Fairy:Theme.surfaceColor("#efc3df"), Fighting:Theme.surfaceColor("#e5b399"), Fire:Theme.surfaceColor("#f1b18a"), Flying:Theme.surfaceColor("#cad7ef"), Ghost:Theme.surfaceColor("#c8bde0"),
                    Grass:Theme.surfaceColor("#b8d999"), Ground:Theme.surfaceColor("#dec59e"), Ice:Theme.surfaceColor("#b5e0e0"), Normal:Theme.surfaceColor("#d7d4bc"), Poison:Theme.surfaceColor("#dbb5dc"),
                    Psychic:Theme.surfaceColor("#edb2c6"), Rock:Theme.surfaceColor("#d1c492"), Steel:Theme.surfaceColor("#c3d2d8"), Water:Theme.surfaceColor("#accfea")}
                return colors[type] || Theme.surfaceColor("#d7dfd0")
            }
            Text {
                id: speciesName
                x: 18; y: 8; width: parent.width - 185; height: 32
                text: root.dex.detail.name; textFormat: Text.PlainText
                color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 27; font.bold: true
                fontSizeMode: Text.Fit; minimumPixelSize: 18; elide: Text.ElideRight
            }
            Text { x: 19; y: root.compactLayout ? 36 : 42; width: parent.width * .47 - 20; text: root.dex.detail.number + "  ·  " + root.dex.detail.form; color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
            SpriteActor {
                objectName: "dex-idle-sprite"
                x: speciesName.x + Math.min(speciesName.width, speciesName.contentWidth) + 12
                y: 0; width: Math.max(86, parent.width - x - 9); height: 50
                visible: preview.hasEntry && !!root.dex.spritePreview.url
                clips: root.dex.spriteClips; playing: root.takesFocus && !root.pickerOpen && !root.artOpen
            }
            Row {
                x: 19; y: root.compactLayout ? 57 : 67; spacing: 6; visible: preview.hasEntry
                Repeater {
                    model: preview.types
                    delegate: Rectangle {
                        required property string modelData
                        width: Math.min(106,(preview.width * .49 - 30) / Math.max(1,preview.types.length)); height: 22; radius: 6; color: Theme.surfaceColor(preview.typeTint(modelData))
                        border.color: Qt.darker(color, 1.2)
                        Text { anchors.centerIn: parent; text: parent.modelData; color: Theme.ink; font.pixelSize: 12; font.bold: true }
                    }
                }
            }
            ClassicIllustration {
                objectName: "dex-detail-art"
                x: 10; y: root.compactLayout ? 83 : 94; width: parent.width * .46 - 10; height: parent.height - y - 35
                art: root.dex.detail.art || ({}); showLabel: true; visible: preview.hasEntry
            }
            Text { x: 19; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                text: root.dex.detail.height + "  ·  " + root.dex.detail.weight; color: Theme.muted; font.pixelSize: 14; visible: preview.hasEntry }
            Item {
                id: stats; objectName: "dex-stat-board"
                x: parent.width * .49; y: root.compactLayout ? 42 : 52; width: parent.width - x - 18; height: root.compactLayout ? 82 : 126; visible: preview.hasEntry
                Text { visible: !root.compactLayout; text: "BASE STATS"; color: Theme.muted; font.pixelSize: 10; font.letterSpacing: 1.5 }
                Grid {
                    y: root.compactLayout ? 0 : 22; width: parent.width; columns: 3; spacing: 8
                    Repeater {
                        model: root.dex.detail.stats
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            readonly property var tints: [Theme.surfaceColor("#efacb1"), Theme.surfaceColor("#f1bf88"), Theme.surfaceColor("#e9d185"), Theme.surfaceColor("#acc8ee"), Theme.surfaceColor("#b5d5a1"), Theme.surfaceColor("#cdb5e3")]
                            width: (stats.width - 16) / 3; height: root.compactLayout ? 37 : 47; radius: 9
                            color: Theme.surfaceColor(tints[index]); border.color: Qt.darker(color, 1.2)
                            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 7; color: "transparent"; border.color: "#60ffffff" }
                            Text { x: 5; y: 5; width: parent.width-10; elide: Text.ElideRight; text: modelData.label; color: Theme.muted; font.pixelSize: 11; font.bold: true }
                            Text { anchors.right: parent.right; anchors.rightMargin: 10; y: root.compactLayout ? 12 : 16; text: modelData.value; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: root.compactLayout ? 21 : 25; font.bold: true }
                        }
                    }
                }
            }
            Column {
                x: stats.x; y: stats.y + stats.height + 5; width: stats.width; spacing: 2; visible: preview.hasEntry
                Rectangle {
                    width: parent.width; height: root.compactLayout ? 21 : 25; radius: 6
                    color: root.dex.detail.status === "Caught" ? Theme.surfaceColor("#badc9c") : root.dex.detail.status === "Seen" ? Theme.surfaceColor("#f0d08c") : Theme.surfaceColor("#c7d9e4")
                    Text { x: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 16
                        text: root.dex.detail.speciesStatus + (root.dex.detail.favorite ? "  ★" : "")
                        textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight }
                }
                Text {
                    width:parent.width
                    text:"THIS FORM \u00b7 " + (root.dex.detail.collectionSource || "Last save").toUpperCase()
                    color:Theme.muted;font.pixelSize:10;font.letterSpacing:0.5
                }
                Row {
                    width:parent.width;spacing:8
                    Repeater {
                        model:[{label:"Party",count:root.dex.detail.partyCount || "\u2014",tint:Theme.surfaceColor("#aed3e5")},
                               {label:"Boxes",count:root.dex.detail.boxCount || "\u2014",tint:Theme.surfaceColor("#ceb9e4")}]
                        Rectangle {
                            required property var modelData
                            objectName:"dex-form-" + modelData.label.toLowerCase()
                            width:(stats.width-8)/2;height:root.compactLayout ? 25 : 30;radius:7;color:Theme.surfaceColor(modelData.tint)
                            border.color:Qt.darker(color,1.15)
                            Text {x:10;anchors.verticalCenter:parent.verticalCenter;text:modelData.label;color:Theme.ink;font.pixelSize:13}
                            Text {anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter
                                text:modelData.count;color:Theme.ink;font.family:Theme.displayFamily;font.pixelSize:22;font.bold:true}
                        }
                    }
                }
                Text { width: parent.width; text: root.dex.detail.family; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight }
            }
            Text { x: 20; y: 95; width: parent.width - 40; visible: !preview.hasEntry; text: "Try another trail through the guide."; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: 16 }
        }
    }
    Item {
        anchors.fill: parent; visible: root.pickerOpen
        Rectangle { anchors.fill: parent; color: "#80103935" }
        MouseArea { anchors.fill: parent }
        Rectangle {
            id: pickerTray
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.min(325,root.height); color: Theme.chassis; border.color: Theme.rim; border.width: 2
            Text { x: 22; y: 15; text: root.dex.pickerTitle; color: "#f3f4dd"; font.pixelSize: 24; font.weight: Font.DemiBold }
            Grid {
                x: 23; y: 58; columns: 5; spacing: 12
                Repeater {
                    model: root.dex.choices
                    delegate: CapButton {
                        required property int index
                        required property var modelData
                        objectName: "dex-choice-" + index
                        width: 164; height: 46; textSize: 16
                        label: (modelData.current ? "• " : "") + modelData.label
                        tint: modelData.id === "cancel" ? Theme.pink : modelData.current ? Theme.yellow : Theme.blue
                        focusColor: Theme.surfaceColor("#fff3b4")
                        selected: root.takesFocus && root.pickerOpen && root.dex.focusIndex === index
                        onActivated: root.shell.activate(index)
                    }
                }
            }
        }
    }
    ArtworkPanel { anchors.fill: parent; dex: root.dex; visible: root.artOpen; takesFocus: root.takesFocus && root.artOpen }
}
