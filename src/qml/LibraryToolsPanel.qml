import QtQuick

Item {
    id: root
    required property var shell
    readonly property var tools: shell.libraryTools
    readonly property bool takesFocus: visible && !shell.keyboard.open && !shell.menuOpen && !shell.notice.length && (!tools.busy || tools.canCancel)
    readonly property bool reviews: tools.route === "reviews"
    readonly property bool gameMenu: tools.route === "game"
    Rectangle { anchors.fill: parent; color: Theme.surfaceColor("#660d2525") }
    TapHandler { onTapped: {} }
    Rectangle {
        visible: root.gameMenu
        anchors.centerIn: parent; width: Math.min(790,parent.width-40); height: Math.min(464,parent.height-36)
        radius: 28; color: Theme.paper; border.color: Theme.divider; border.width: 1
        SocialIconButton { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 15; glyph: "close"; label: "Close"; onClicked: root.tools.close() }
        Rectangle {
            x: 24; y: 26; width: 202; height: parent.height-52; radius: 19
            color: Qt.rgba(Theme.green.r,Theme.green.g,Theme.green.b,.10)
            Image {
                x: 16; y: 16; width: parent.width-32; height: Math.min(226,parent.height-170)
                source: root.tools.gameSummary.cover || ""; fillMode: Image.PreserveAspectFit
                asynchronous: true; sourceSize: Qt.size(340,452)
                MenuGlyph { anchors.centerIn: parent; width: 56; height: 56; glyph: "game-controller"; visible: parent.source.toString().length===0 || parent.status===Image.Error; opacity: .4 }
            }
            Column {
                x: 16; y: parent.height-146; width: parent.width-32; spacing: 8
                Text { width: parent.width; text: root.tools.gameSummary.platform || "Game"; color: Theme.muted; font.pixelSize: 11; font.letterSpacing: 1; elide: Text.ElideRight }
                Text { width: parent.width; text: root.tools.title; textFormat: Text.PlainText; color: Theme.ink; font.family: Theme.displayFamily; font.pixelSize: 23; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                Text { width: parent.width; text: root.tools.gameSummary.multiplayer || ""; textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
            }
        }
        Item {
            x: 250; y: 30; width: parent.width-x-28; height: parent.height-y-24
            Row {
                id: sections; height: 42; spacing: 24
                Repeater {
                    model: root.tools.hasView ? ["Game","Library","View"] : ["Game","Library"]
                    delegate: Item {
                        required property int index; required property string modelData
                        width: sectionText.implicitWidth+4; height: 38
                        Text { id: sectionText; anchors.horizontalCenter: parent.horizontalCenter; y: 4; text: modelData; font.pixelSize: 17; font.family: Theme.displayFamily; color: root.tools.section===index?Theme.ink:Theme.muted }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: Theme.ink; visible: root.tools.section===index }
                        MouseArea { anchors.fill: parent; onClicked: root.tools.selectSection(index) }
                    }
                }
            }
            ListView {
                id: gameActions; y: 55; width: parent.width; height: parent.height-y-32
                clip: true; spacing: 2; model: root.gameMenu?root.tools.rows:[]
                currentIndex: root.tools.focusIndex; keyNavigationEnabled: false
                onCurrentIndexChanged: if(count)positionViewAtIndex(currentIndex,ListView.Contain)
                delegate: Item {
                    required property int index; required property var modelData
                    readonly property bool selected: root.takesFocus && root.tools.focusIndex===index
                    objectName: "library-game-action-"+index
                    function claimFocus() { if(selected && visible) forceActiveFocus(Qt.OtherFocusReason) }
                    onSelectedChanged: Qt.callLater(claimFocus)
                    onVisibleChanged: Qt.callLater(claimFocus)
                    Component.onCompleted: Qt.callLater(claimFocus)
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    width: gameActions.width; height: root.tools.section===0?69:49
                    opacity: modelData.enabled?1:.38
                    Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 11; color: root.takesFocus&&root.tools.focusIndex===index?Qt.rgba(Theme.green.r,Theme.green.g,Theme.green.b,.15):"transparent"; border.width: root.takesFocus&&root.tools.focusIndex===index?2:0; border.color: Theme.focusGlow }
                    MenuGlyph { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 23; height: 23; glyph: modelData.glyph || "info"; ink: modelData.id==="remove"?Theme.textColor("#a65246"):Theme.ink }
                    Column {
                        x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width-x-28; spacing: 3
                        Text { width: parent.width; text: modelData.label; color: Theme.ink; font.pixelSize: 16; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.detail || ""; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    MenuGlyph { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 13; glyph: "chevron"; opacity: .45 }
                    MouseArea { anchors.fill: parent; enabled: modelData.enabled && !root.tools.busy; onClicked: root.shell.activate(index) }
                }
            }
            Text { anchors.bottom: parent.bottom; text: root.tools.error; color: Theme.muted; font.pixelSize: 10; width: parent.width; wrapMode: Text.Wrap }
        }
    }
    Rectangle {
        visible: !root.gameMenu
        anchors.centerIn: parent; width: root.reviews ? Math.min(970,parent.width-36) : tools.route==="properties" || tools.route==="multiplayer" ? Math.min(660,parent.width-36) : Math.min(480,parent.width-36)
        height: Math.min(parent.height-24, header.implicitHeight+(body.text.length?body.implicitHeight:0)+list.height+(error.text.length?error.implicitHeight:0)+44)
        radius: 25; color: Theme.paper; border.color: Theme.divider; border.width: 1
        SocialIconButton { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; glyph: "back"; label: "Back"; onClicked: root.tools.back() }
        Column {
            x: 20; y: 18; width: parent.width-40; spacing: 8
            Text { id: header; width: parent.width-40; text: root.tools.title; textFormat: Text.PlainText; font.family: Theme.displayTypeface.name; font.pixelSize: 26; font.bold: true; color: Theme.ink; elide: Text.ElideRight }
            Text { id: body; width: parent.width; visible: text.length>0; text: root.tools.detail; textFormat: Text.PlainText; font.pixelSize: 16; color: Theme.muted; wrapMode: Text.Wrap; maximumLineCount: tools.route==="properties" ? 3 : 7; elide: Text.ElideMiddle }
            Item {
                width: parent.width; height: root.reviews ? 285 : Math.max(80,Math.min(root.tools.route==="multiplayer"?330:232,list.contentHeight,root.height-header.implicitHeight-(body.visible?body.implicitHeight:0)-(error.visible?error.implicitHeight:0)-100))
            ListView {
                id: list; width: root.reviews ? parent.width*0.36 : parent.width; height: parent.height; clip: true; spacing: 6
                interactive: true; keyNavigationEnabled: false
                model: root.tools.rows; currentIndex: root.tools.focusIndex
                function reveal() {if(count)positionViewAtIndex(currentIndex,ListView.Contain)}
                onCurrentIndexChanged: Qt.callLater(reveal)
                onCountChanged: Qt.callLater(reveal)
                delegate: Item {
                    required property int index; required property var modelData
                    readonly property bool selected: root.takesFocus && root.tools.focusIndex===index
                    function claimFocus() { if(selected && visible) forceActiveFocus(Qt.OtherFocusReason) }
                    onSelectedChanged: Qt.callLater(claimFocus)
                    onVisibleChanged: Qt.callLater(claimFocus)
                    Component.onCompleted: Qt.callLater(claimFocus)
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    objectName: "library-tool-"+index
                    readonly property bool groupStart: !!modelData.group && (index===0 || root.tools.rows[index-1].group!==modelData.group)
                    width: list.width; height: rowBody.height+(groupStart?25:0)
                    opacity: modelData.enabled ? 1 : 0.42
                    Text { visible: parent.groupStart; x: 12; y: 4; text: modelData.group || ""; color: Theme.muted; font.pixelSize: 11; font.bold: true }
                    Item {
                    id: rowBody; y: parent.groupStart?25:0; width: parent.width; height: modelData.detail?50:38
                    Rectangle { anchors.fill: parent; radius: 9; color: "transparent"; border.width: root.takesFocus && root.tools.focusIndex===index?2:0; border.color: Theme.focusGlow }
                    Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.checked?"✓":""; font.pixelSize: 18; color: Theme.ink }
                    Column {
                        x: root.tools.route==="multiplayer"?38:12; anchors.verticalCenter: parent.verticalCenter; width: parent.width-x-12; spacing: 3
                        Text { width: parent.width; text: modelData.label; color: root.tools.route==="remove"&&index===1?Theme.textColor("#a65246"):Theme.ink; font.pixelSize: 16; elide: Text.ElideRight }
                        Text { visible: !!modelData.detail; width: parent.width; text: modelData.detail || ""; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight }
                    }
                    MouseArea { anchors.fill: parent; enabled: modelData.enabled && !root.tools.busy; onClicked: root.shell.activate(index) }
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right; width: 3; radius: 1.5; color: Theme.muted; opacity: .4
                visible: !root.reviews && list.contentHeight>list.height
                height: Math.max(20,list.height*list.height/Math.max(1,list.contentHeight))
                y: Math.max(0,Math.min(parent.height-height,list.contentY*(parent.height-height)/Math.max(1,list.contentHeight-list.height)))
            }
            Rectangle {
                visible: root.reviews; anchors.left: list.right; anchors.right: parent.right; anchors.leftMargin: 18; height: parent.height
                color: Theme.surfaceColor("#fff5d7"); radius: 12; border.color: Theme.surfaceColor("#b9a985")
                Column {
                    x: 18; y: 16; width: parent.width-36; spacing: 10
                    Text { width: parent.width; text: root.tools.selectedReview.name || "Adventure Reviews"; textFormat: Text.PlainText; color: Theme.ink; font.family: Theme.displayTypeface.name; font.pixelSize: 24; font.bold: true; elide: Text.ElideRight }
                    Text { width: parent.width; text: (root.tools.selectedReview.date || "").slice(0,10); visible: text.length>0; color: Theme.muted; font.pixelSize: 15 }
                    Flickable {
                        id: reviewText; width: parent.width; height: 200; clip: true; contentHeight: reviewBody.implicitHeight
                        Text { id: reviewBody; width: parent.width; text: root.tools.selectedReview.text || "Share a little of your adventure."; textFormat: Text.PlainText; color: Theme.ink; font.pixelSize: 17; wrapMode: Text.Wrap; onTextChanged: reviewText.contentY=0 }
                    }
                }
            }
            }
            Text { id: error; width: parent.width; visible: text.length>0; text: root.tools.busy&&!root.tools.canCancel?"Saving…":root.tools.error; textFormat: Text.PlainText; font.pixelSize: 16; color: Theme.textColor("#803724"); wrapMode: Text.WordWrap }
        }
    }
    Connections { target: root.tools; function onScrollReview(direction) { reviewText.contentY=Math.max(0,Math.min(Math.max(0,reviewText.contentHeight-reviewText.height),reviewText.contentY+direction*140)) } }
}
