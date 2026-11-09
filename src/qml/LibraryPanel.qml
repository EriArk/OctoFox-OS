import QtQuick

Item {
    id: root
    required property var shell
    readonly property var manager: shell.libraryManager
    readonly property var files: manager.files
    readonly property bool compactImport: manager.importing && height < 320
    readonly property var fieldIds: manager.importing ? [0, 3, 4, 5] : [0, 1, 2, 3, 4, 5]
    readonly property bool takesFocus: visible && !shell.menuOpen && !shell.keyboard.open && shell.notice.length === 0
    // The main chassis owns the recessed surface for pages and services alike.
    Item {
        anchors.fill: parent; anchors.margins: Theme.panelInset
        anchors.topMargin: Theme.contentTopInset; clip: true
        PageHeader {
            id: libraryHeader; compact: true; subtitleElide: Text.ElideMiddle
            title: root.manager.route === "files" ? "Choose an Adventure file" : root.manager.title
            subtitle: root.manager.route === "files" ? root.files.path : root.manager.route === "result" ? "Your game stays in its original location." : root.manager.saving ? "Saving… You can leave; the submitted save will finish." : root.manager.importing ? "Choose a file, check its platform, then import. The file stays in its current location." : "Link your own file. Supported play setups are applied automatically."
        }
        MountedPanel { x: 0; y: libraryHeader.height; width: parent.width; height: parent.height - y; color: Theme.surfaceColor("#d4e2d6") }
        Item {
            anchors.fill: parent; visible: root.manager.route === "list"
            ControllerList {
                x: 24; y: libraryHeader.height + 11; width: parent.width - 48; height: 216
                model: root.manager.rows; currentIndex: root.manager.rowIndex; namePrefix: "manage-row-"
                takesFocus: root.takesFocus && parent.visible && root.manager.zone === "list"
                onActivated: function(row) { root.shell.activate(row, "list") }
            }
            Text { x: 30; y: 128; visible: root.manager.rows.length === 0; text: "A new library, ready for your Adventures."; font.pixelSize: 24; color: Theme.ink }
            MountedPanel {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: root.compactImport ? 48 : 72; color: Theme.surfaceColor("#bfd6c8")
                Row {
                    x: 30; y: 16; spacing: 18
                    Repeater {
                        model: ["Add Adventure", "Back to system menu"]
                        delegate: CapButton {
                            required property int index; required property string modelData
                            objectName: "manage-action-" + index
                            width: 330; height: 43; label: modelData; tint: index === 0 ? Theme.yellow : Theme.blue
                            selected: root.takesFocus && root.manager.route === "list" && root.manager.zone === "actions" && root.manager.focusIndex === index
                            onActivated: root.shell.activate(index, "actions")
                        }
                    }
                }
            }
        }
        Item {
            anchors.fill: parent; visible: root.manager.route === "edit"
            Grid {
                x: 30; y: libraryHeader.height + (root.compactImport ? 2 : 17); width: parent.width - 60; columns: 2; columnSpacing: 18; rowSpacing: root.compactImport ? 6 : 13
                Repeater {
                    model: root.fieldIds
                    delegate: CapButton {
                        required property int index; required property int modelData
                        readonly property var field: root.manager.fields[modelData]
                        objectName: "adventure-field-" + modelData
                        width: (parent.width - parent.columnSpacing) / 2; height: root.compactImport ? 38 : 52; textSize: root.compactImport ? 15 : 17; label: field.title; detail: field.value
                        tint: Theme.tabColors[index % Theme.tabColors.length]
                        selected: root.takesFocus && root.manager.route === "edit" && root.manager.focusIndex === modelData
                        onActivated: root.shell.activate(modelData)
                    }
                }
            }
            MountedPanel {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: root.compactImport ? 48 : 72; color: Theme.surfaceColor("#bfd6c8")
                CapButton {
                    objectName: "adventure-save"; x: 30; y: root.compactImport ? 4 : 16; width: (parent.width - 78) / 2; height: root.compactImport ? 36 : 43
                    label: root.manager.saving ? "Saving…" : root.manager.importing ? "Import ROM" : "Save Adventure"
                    selected: root.takesFocus && root.manager.route === "edit" && root.manager.focusIndex === 6
                    onActivated: root.shell.activate(6)
                }
                CapButton {
                    objectName: "adventure-cancel"; x: parent.width / 2 + 9; y: root.compactImport ? 4 : 16; width: (parent.width - 78) / 2; height: root.compactImport ? 36 : 43; tint: Theme.pink
                    label: root.manager.saving ? "Back to library" : "Cancel changes"
                    selected: root.takesFocus && root.manager.route === "edit" && root.manager.focusIndex === 7
                    onActivated: root.shell.activate(7)
                }
            }
        }
        Item {
            anchors.fill: parent; visible: root.manager.route === "result"
            Flickable {
                id: resultText; x: 30; y: libraryHeader.height + 6; width: parent.width - 60
                height: Math.max(0, parent.height - y - 56)
                contentHeight: resultCopy.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: resultCopy; width: parent.width; spacing: 5
                    Text {
                        objectName: "import-result-status"; width: parent.width
                        text: root.manager.result.state === "checking" ? "Checking…" : root.manager.result.state === "ready" ? "Ready to launch" : root.manager.result.state === "review" ? "Setup needs review" : "Setup needed"
                        color: Theme.ink; font.pixelSize: root.compactImport ? 18 : 21; font.bold: true
                    }
                    Text {
                        objectName: "import-result-detail"; width: parent.width; text: root.manager.result.detail || ""
                        textFormat: Text.PlainText; color: Theme.muted; font.pixelSize: 13; wrapMode: Text.Wrap
                    }
                }
                Connections {
                    target: root.manager
                    function onScrollRequested(direction) { resultText.contentY = Math.max(0, Math.min(resultText.contentHeight-resultText.height, resultText.contentY+direction*48)) }
                }
            }
            Grid {
                x: 30; y: parent.height - 48; width: parent.width - 60; columns: 4; spacing: 10
                Repeater {
                    model: [root.manager.result.state === "review" ? "Try game" : "Play", root.manager.result.repair === "software" ? "Software setup" : root.manager.result.repair === "file" ? "Choose game file" : "Prepare game", "Check again", "Done"]
                    delegate: CapButton {
                        required property int index; required property string modelData
                        objectName: "import-result-action-" + index
                        width: (parent.width - parent.spacing*(parent.columns-1)) / parent.columns; height: 36; textSize: root.compactImport ? 12 : 15; label: modelData
                        enabled: index === 3 || (root.manager.result.state !== "checking" && (index !== 0 || !!root.manager.result.canPlay))
                        selected: root.takesFocus && parent.parent.visible && root.manager.focusIndex === index
                        onActivated: root.shell.activate(index)
                    }
                }
            }
        }
        ControllerList {
            x: 24; y: libraryHeader.height + 11; width: parent.width - 48; height: Math.max(0, parent.height - y - 12)
            visible: root.manager.route === "world" || root.manager.route === "extras" || root.manager.route === "edition"
            model: root.manager.choices.map(function(choice) { return {id: choice.id, title: (choice.selected ? "●  " : "") + choice.title, subtitle: choice.selected ? "Selected" : ""} })
            currentIndex: root.manager.focusIndex; namePrefix: "manage-choice-"; tint: Theme.blue
            takesFocus: root.takesFocus && visible
            onActivated: function(row) { root.shell.activate(row) }
        }
        Text {
            objectName: "adventure-error"; x: 30; y: parent.height - (root.compactImport ? 68 : 94); width: parent.width - 60; elide: Text.ElideRight; color: Theme.textColor("#853b24"); font.pixelSize: 14
            visible: root.manager.route !== "files" && root.manager.route !== "result"; text: root.manager.error; textFormat: Text.PlainText
        }
    }
    ChatFilePicker { anchors.fill: parent; picker: root.files; title: "Choose a game file" }

}
