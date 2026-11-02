import QtQuick

Item {
    id: root
    required property var shell
    property bool selected: false
    property bool presentationActive: true
    readonly property var flow: shell.dashboard
    readonly property bool picking: flow.widgetPicking
    readonly property bool storageVisible: visible && !picking && flow.widget.id==="storage"
        && shell.unobstructed && !shell.quickAppsOpen && !shell.drawerOpen && !shell.keyboard.open
    property bool storageRequested: false
    function refreshStorage() {
        if(!storageVisible)storageRequested=false
        else if(!storageRequested){storageRequested=true;shell.systemAction("home-widget-refresh")}
    }
    onStorageVisibleChanged: Qt.callLater(refreshStorage)
    Component.onCompleted: Qt.callLater(refreshStorage)
    objectName: "home-widget-slot"
    function claimFocus() { if(visible && (selected || picking))forceActiveFocus(Qt.OtherFocusReason) }
    onSelectedChanged: Qt.callLater(claimFocus)
    onPickingChanged: Qt.callLater(claimFocus)
    onVisibleChanged: Qt.callLater(claimFocus)
    QtObject {
        id: homeBoard
        readonly property string selected: root.selected ? root.flow.widget.id || "" : ""
        readonly property bool editing: false
        readonly property bool moving: false
        readonly property bool adjusting: false
        function select(id) {}
        function activate(id) { root.shell.activateDashboard("widget") }
    }
    Loader {
        anchors.fill: parent
        active: root.visible && !root.picking && !!root.flow.widget.id && !root.flow.widget.renderer
        sourceComponent: ControlWidget {
            shell: root.shell; board: homeBoard
            modelData: ({ id: root.flow.widget.id || "", title: root.flow.widget.title || "", w: 4, h: root.height >= 180 ? 4 : 2 })
        }
    }
    Loader {
        id:companionLoader
        objectName: "home-companion-loader"
        anchors.fill:parent
        active:shutter.retainContent
        sourceComponent:HomeCompanionWidget {shell:root.shell;selected:root.selected;assetBase:root.flow.widget.assetBase || "";presentationActive:shutter.retainContent}
    }
    HomeWidgetShutter {
        id:shutter;anchors.fill:parent
        visible:!root.picking && root.flow.widget.renderer==="avatar-care-v1"
        requested:root.visible && root.presentationActive && visible
        contentReady:!!companionLoader.item && companionLoader.item.presentationReady
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.flow.widget.id || root.picking
        radius: 10; color: Qt.alpha(Theme.ink,.025)
        border.color: root.selected || root.picking ? Theme.focusGlow : Qt.alpha(Theme.divider,.5)
        border.width: root.selected || root.picking ? 1.5 : 1
    }
    Item {
        anchors.fill: parent; visible: !root.flow.widget.id && !root.picking
        Column {
            anchors.centerIn: parent; spacing: 8
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+"; color: Theme.muted; font.pixelSize: 30 }
            Text { text: "Choose widget"; color: Theme.muted; font.pixelSize: 13 }
        }
        MouseArea { anchors.fill: parent; onClicked: root.shell.editHomeWidget() }
        Accessible.role: Accessible.Button; Accessible.name: "Choose Home widget"
        Accessible.onPressAction: root.shell.editHomeWidget()
    }
    SocialIconButton {
        objectName: "home-widget-edit"
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
        visible: !!root.flow.widget.id && !root.flow.widget.renderer && !root.picking
        icon: "dots-three"; label: "Change widget"
        onClicked: root.shell.editHomeWidget()
    }
    Item {
        anchors.fill: parent; anchors.margins: 7; visible: root.picking
        Text { x: 5; y: 4; text: "Home widget"; font.family: Theme.displayFamily; font.pixelSize: 16; color: Theme.ink }
        SocialIconButton {
            anchors.right: parent.right; anchors.top: parent.top
            icon: "x"; label: "Close"; onClicked: root.flow.closeWidgetPicker()
        }
        ListView {
            objectName: "home-widget-choices"
            y: 32; width: parent.width; height: parent.height-y; clip: true
            model: root.flow.widgetChoices; currentIndex: root.flow.widgetChoiceIndex
            onCurrentIndexChanged: positionViewAtIndex(currentIndex,ListView.Contain)
            delegate: Rectangle {
                required property var modelData
                required property int index
                objectName: "home-widget-choice-"+(modelData.id || "none")
                function pressAction() { root.flow.chooseWidget(modelData.id) }
                width: ListView.view.width; height: 32; radius: 6
                color: index===root.flow.widgetChoiceIndex ? Theme.selection : "transparent"
                Text { x: 9; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; color: Theme.ink; font.pixelSize: 13 }
                Text { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "✓"; color: Theme.ink; visible: (root.flow.widget.id || "")===modelData.id }
                MouseArea { anchors.fill: parent; onClicked: parent.pressAction() }
                Accessible.role: Accessible.Button; Accessible.name: modelData.title
                Accessible.onPressAction: pressAction()
            }
        }
    }
}
