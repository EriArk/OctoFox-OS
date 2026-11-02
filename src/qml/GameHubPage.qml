import QtQuick

Item {
    id: root
    required property var shell
    objectName: "gamehub"
    function hints(h) {
        if(shell.adapterMenuOpen) return [h("←→","Section"),h("A","Open"),h("B","Home")]
        return presenter.hints(h) || [h("A","Open"),h("B","Sections")]
    }
    readonly property bool available: visible && !shell.serviceOpen && !shell.menuOpen
        && !shell.drawerOpen && !shell.quickAppsOpen && !shell.keyboard.open && !shell.notice.length
    Row {
        id: sections
        objectName: "adapter-screen-menu"
        height: visible ? 32 : 0; spacing: 8
        visible: root.shell.adapterMenu.length > 1 || root.shell.adapterMenuOpen
        Repeater {
            model: root.shell.adapterMenu
            delegate: Item {
                required property var modelData
                required property int index
                objectName: "adapter-screen-" + modelData.id
                width: Math.min(190, caption.implicitWidth + 28); height: 29
                readonly property bool current: root.shell.adapterScreen === modelData.id
                readonly property bool focused: root.available && root.shell.adapterMenuOpen && root.shell.adapterMenuFocus === index
                Rectangle { anchors.fill: parent; radius: 8; color: parent.current ? Theme.selection : "transparent"; border.color: parent.focused ? Theme.focusGlow : "transparent"; border.width: 2 }
                Text { id: caption; anchors.centerIn: parent; text: modelData.label; color: parent.current ? Theme.ink : Theme.muted; font.pixelSize: 14; font.bold: parent.current }
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: root.shell.selectAdapterScreen(modelData.id)
                MouseArea { anchors.fill: parent; enabled: root.available; onClicked: root.shell.selectAdapterScreen(modelData.id) }
            }
        }
    }
    Item {
        x: 0; y: sections.height; width: parent.width; height: parent.height-y
        enabled: root.available && !root.shell.adapterMenuOpen
        clip: true
        ExperienceHost { id: presenter; anchors.fill: parent; shell: root.shell }
        ExperienceHost { anchors.fill: parent; shell: root.shell; overlay: true }
    }
}
