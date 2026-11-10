import QtQuick
import QtQuick.Controls
import QtQuick.Window
Item {
    id: root
    // Keep page changes opaque on the software renderer, including Shape damage.
    layer.enabled: visible && GraphicsInfo.api === GraphicsInfo.Software
    layer.textureSize: Qt.size(Math.ceil(width*Theme.uiScale),Math.ceil(height*Theme.uiScale))
    layer.smooth: true
    Rectangle { anchors.fill: parent; color: Theme.surface; z: -1 }
    required property var shell
    readonly property var settings: shell.settings
    readonly property bool takesFocus: visible && !shell.menuOpen && !shell.notice.length && !shell.keyboard.open && !shell.libraryTools.open && !shell.scraper.open && !shell.downloads.open
    readonly property string localError: settings.category===4 && shell.trainer.editing ? shell.trainer.error
        : (settings.category===0 || settings.category===8 || settings.category===9) && settings.error.length ? settings.error
        : [0,1,5,10].includes(settings.category) ? shell.device.error : ""
    readonly property string statusText: settings.categoryId==="game-input" ? settings.gameInput.title+" / "+(settings.gameInput.status || "Choose a PC or native game. Home is reserved.") : settings.category===4 && shell.trainer.saving || settings.saving ? "Saving..."
        : settings.categoryId==="online-services" ? settings.onlineServiceStatus : localError || (shell.hall.account.open ? shell.hall.account.status : settings.category===8 ? settings.libraryStatus : "")

    Item {
        anchors.fill: parent; anchors.margins: 12
        PageHeader { id: heading; compact: true; title: "Settings"; height: 40 }
        Rectangle {
            y: heading.height; width: parent.width; height: parent.height-y; color: Theme.surface; radius: 8
            Rectangle { x: 181; y: 20; width: 1; height: parent.height-40; color: Theme.divider }
            Flickable {
                id: categoriesViewport; x: 10; y: 10; width: 168; height: parent.height-20; clip: true
                contentHeight: categoriesColumn.height; boundsBehavior: Flickable.StopAtBounds
                function followFocus() {
                    const top = root.settings.sectionIndex*49
                    contentY = Math.max(0, Math.min(Math.max(0,contentHeight-height), top < contentY ? top : top+45 > contentY+height ? top+45-height : contentY))
                }
                onHeightChanged: Qt.callLater(followFocus)
                Connections { target: root.settings; function onChanged() { Qt.callLater(categoriesViewport.followFocus) } }
                Column { id: categoriesColumn; x: 3; spacing: 4
                Repeater { model: root.settings.sections
                    Rectangle {
                        required property int index; required property var modelData
                        objectName: "settings-section-"+modelData.id
                        width: 160; height: 45; radius: 9
                        readonly property bool selected: root.takesFocus && !root.settings.controlsFocused && root.settings.sectionIndex===index
                        color: selected ? Theme.selection : "transparent"
                        Rectangle { x: 1; y: 13; width: 3; height: 22; radius: 1; color: Theme.accent; visible: root.settings.sectionIndex===index }
                        onSelectedChanged: if(selected && visible) forceActiveFocus(Qt.OtherFocusReason)
                        onVisibleChanged: if(selected && visible) forceActiveFocus(Qt.OtherFocusReason)
                        Component.onCompleted: if(selected && visible) forceActiveFocus(Qt.OtherFocusReason)
                        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; width: parent.width-28; wrapMode: Text.WordWrap; color: root.settings.sectionIndex===index ? Theme.ink : Theme.muted; font.pixelSize: 15; font.bold: root.settings.sectionIndex===index }
                        TapHandler { enabled: !root.shell.trainer.editing && !root.shell.hall.account.open && !root.settings.storage.busy && !root.settings.updates.confirming && !root.settings.updates.transitionPending; onTapped: root.settings.selectSection(index) }
                    }
                }
            }
            }
            Item { x: 195; y: 43; width: parent.width-x-16; height: parent.height-y-8
                Row { y: -39; spacing: 6
                    Repeater { model: root.settings.pages
                        Item { required property var modelData; width: Math.max(64,(root.width-243)/Math.max(1,root.settings.pages.length)-6); height: 36
                            Text { anchors.centerIn: parent; text: modelData.title; font.pixelSize: 13; color: root.settings.categoryId===modelData.id ? Theme.ink : Theme.muted; font.weight: root.settings.categoryId===modelData.id ? Font.DemiBold : Font.Normal }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: Theme.accent; visible: root.settings.categoryId===modelData.id }
                            TapHandler { enabled: !root.shell.trainer.editing && !root.shell.hall.account.open && !root.settings.storage.busy && !root.settings.updates.confirming && !root.settings.updates.transitionPending; onTapped: root.settings.selectPage(modelData.id) }
                        }
                    }
                }
                SystemSettingsPane { anchors.fill: parent; shell: root.shell; visible: root.settings.category===5 && !root.settings.updatesOpen; takesFocus: root.takesFocus && root.settings.controlsFocused }
                UpdatesPane { anchors.fill: parent; flow: root.settings.updates; visible: root.settings.updatesOpen; takesFocus: root.takesFocus && root.settings.controlsFocused }
                GameInputPane { anchors.fill: parent; flow: root.settings.gameInput; takesFocus: visible && root.takesFocus && root.settings.controlsFocused; visible: root.settings.categoryId==="game-input" }
                ControllerSettingsPane { anchors.fill: parent; settings: root.settings; takesFocus: visible && root.takesFocus && root.settings.controlsFocused; visible: root.settings.categoryId==="controller" }
                ScrapeSettingsPane { flat: true; anchors.fill: parent; flow: root.shell.scraper; visible: root.settings.category===14; takesFocus: root.takesFocus && root.settings.controlsFocused }
                CommunicationPane { flat: true; anchors.fill: parent; flow: root.settings.communication; visible: root.settings.category===13; takesFocus: root.takesFocus && root.settings.controlsFocused }
                ClockPane { flat: true; anchors.fill: parent; clock: root.settings.clock; visible: root.settings.category===11; takesFocus: root.takesFocus && root.settings.controlsFocused }
                ConnectionsPane { flat: true; anchors.fill: parent; shell: root.shell; visible: root.settings.category===10 }
                Item {
                    anchors.fill: parent; visible: root.settings.storage.open
                    Text { x: 5; y: 13; text: "Game storage"; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 25 }
                    Text { x: 5; y: 48; width: parent.width-10; text: "Choose where to look for games. Existing files stay in place."; color: Theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap }
                    StorageChoices { x: 0; y: 75; width: parent.width; height: parent.height-y-43; compact: true; flat: true; flow: root.settings.storage; takesFocus: root.takesFocus && root.settings.controlsFocused }
                    Text { x: 5; y: parent.height-37; width: parent.width-10; height: 33; text: root.settings.storage.busy ? "Preparing your library…" : root.settings.storage.error || root.settings.storage.rows[root.settings.storage.focusIndex]?.path || ""; textFormat: Text.PlainText; color: root.settings.storage.error.length ? Theme.textColor("#853b24") : Theme.muted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideMiddle }
                }
                Flickable {
                    ScrollBar.vertical: SettingsScrollBar {}
                    id: controlsViewport; visible: !root.settings.updatesOpen && root.settings.category!==5 && root.settings.categoryId!=="controller" && root.settings.categoryId!=="game-input" && root.settings.category!==6 && root.settings.category!==10 && root.settings.category!==11 && root.settings.category!==13 && root.settings.category!==14 && !root.settings.storage.open; x: 0; y: 10
                    width: parent.width; height: Math.max(0,parent.height-y-(root.statusText.length?64:10)); clip: true
                    contentHeight: controlsColumn.height+8; boundsBehavior: Flickable.StopAtBounds
                    function followFocus() {
                        if (!root.settings.controlsFocused) return
                        const index=root.shell.hall.account.open ? root.shell.hall.account.focusIndex : root.shell.trainer.editing ? root.shell.trainer.focusIndex : root.settings.rowFocus
                        const item=controlsRepeater.itemAt(index)
                        if (!item) return
                        const top=item.y, bottom=top+item.height+8
                        contentY=Math.max(0,Math.min(Math.max(0,contentHeight-height),top<contentY?top:bottom>contentY+height?bottom-height:contentY))
                    }
                    onHeightChanged: Qt.callLater(followFocus)
                    onContentHeightChanged: Qt.callLater(followFocus)
                    Connections { target: root.settings; function onChanged() { Qt.callLater(controlsViewport.followFocus) } }
                    Column { id: controlsColumn; x: 4; y: 4; width: parent.width-12; spacing: 0; visible: root.settings.categoryId!=="controller" && root.settings.categoryId!=="game-input" && root.settings.category!==6 && root.settings.category!==10 && root.settings.category!==11 && root.settings.category!==13 && root.settings.category!==14 && !root.settings.storage.open
                    // Rebuilt delegates have y=0 until the positioner's polish
                    // pass. Follow the controller's row after final geometry.
                    onPositioningComplete: controlsViewport.followFocus()
                    Repeater { id: controlsRepeater; model: root.shell.hall.account.open ? root.shell.hall.account.rows.map(r => ({title: r.label, detail: r.detail, kind: r.enabled ? "action" : "unavailable"})) : root.shell.trainer.editing ? root.shell.trainer.editRows : root.settings.controls
                        onItemAdded: Qt.callLater(controlsViewport.followFocus)
                        SettingsRow {
                            required property int index; required property var modelData
                            objectName: (root.shell.hall.account.open ? "achievement-account-" : "settings-control-")+index; width: parent.width; height: implicitHeight
                            title: root.settings.category===4 && !root.shell.trainer.editing && !root.shell.hall.account.open && index===0 ? (root.shell.trainer.exists ? "Edit Trainer" : "Create Trainer") : root.settings.category===4 && !root.shell.trainer.editing && !root.shell.hall.account.open && index===2 && root.shell.sampleLibrary ? "Preview registration & PIN" : modelData.title
                            detail: root.settings.category===0 && index===4 ? modelData.detail + (root.shell.settings.displayDensity(Screen.width,Screen.height,100000,100000,root.settings.displayProfile,root.settings.interfaceScale) > Theme.uiScale+.001 ? " · Limited by window" : "") : root.settings.category===4 && !root.shell.trainer.editing && !root.shell.hall.account.open && index===0 ? (root.shell.trainer.profile.name || "Give your journey a name") : root.settings.category===4 && !root.shell.trainer.editing && !root.shell.hall.account.open && index===2 && root.shell.sampleLibrary ? "Development preview only" : modelData.detail || ""
                            kind: root.settings.category===4 && !root.shell.trainer.editing && !root.shell.hall.account.open && index===2 && root.shell.sampleLibrary ? "action" : modelData.kind
                            checked: modelData.checked !== undefined ? !!modelData.checked : root.settings.category===9 ? root.settings.readOnlySaves : root.settings.category===8 ? root.settings.worldEditing : root.settings.category===2 ? root.settings.videoPreviews : root.settings.reducedMotion
                            level: kind==="volume" ? root.shell.device.rows[0].level : kind==="brightness" ? root.shell.device.rows[1].level : -1
                            muted: kind==="volume" && root.shell.device.rows[0].muted
                            selected: root.takesFocus && root.settings.controlsFocused && (root.shell.hall.account.open ? root.shell.hall.account.focusIndex : root.shell.trainer.editing ? root.shell.trainer.focusIndex : root.settings.rowFocus)===index
                            onActivated: { if(root.shell.trainer.editing || root.shell.hall.account.open) root.shell.activate(index); else root.settings.activateRow(index) }
                            onAdjustmentRequested: direction => { if(root.settings.category===0 && index===0) root.settings.cycleTheme(direction); else root.settings.adjustDisplay(index,direction) }
                            onLevelRequested: value => root.shell.device.setQuickLevel(kind==="volume"?0:1,value)
                        }
                    }
                }
                }
                Item { anchors.fill: parent; visible: root.settings.category===6
                Flickable { x: 12; y: 12; width: parent.width-24; height: parent.height-76; contentHeight: creditsText.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column { id: creditsText; spacing: 12; width: parent.width
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "Original creature and achievement art"; color: Theme.ink; font.pixelSize: 18; font.bold: true }
                    Text { text: "TrainerOS contributors"; color: Theme.ink; font.pixelSize: 18 }
                    Text { text: "GNU General Public License 3.0 or later"; color: Theme.muted; font.pixelSize: 14 }
                    Text { width: parent.width; text: "Cuboid creatures, animations and abstract league medallions are drawn from original geometry. Game names and progress identities remain separate from their artwork."; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap; lineHeight: 1.2 }
                }
                }

                    CapButton { flat: true; objectName: "credits-back"; x: 22; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; width: 240; height: 44; label: "Categories"; selected: root.takesFocus && root.settings.controlsFocused && root.settings.category===6; onActivated: root.settings.selectCategory(6,false) }
                }
                Text {
                    objectName: "settings-status"
                    visible: !root.settings.updatesOpen && root.settings.category!==5 && root.settings.categoryId!=="controller" && root.settings.categoryId!=="game-input" && root.settings.category!==10 && root.settings.category!==11 && root.settings.category!==13 && root.settings.category!==14 && !root.settings.storage.open
                    x: 5; y: parent.height-58; width: parent.width-10; height: 52
                    text: root.statusText; textFormat: Text.PlainText
                    font.pixelSize: 14; color: root.localError.length ? Theme.textColor("#853b24") : Theme.muted
                    wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                }
            }
        }
    }
}
