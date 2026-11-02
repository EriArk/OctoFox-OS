import QtQuick

Rectangle {
    id: root
    required property var notice
    signal dismissed()
    width: Theme.television ? 380 : 330
    height: Math.max(72,contents.implicitHeight + 28)
    radius: 16; color: Theme.paper; border.color: Theme.divider; border.width: 1
    // Dismiss by touch without stealing controller focus.
    MenuGlyph { x: 16; y: 16; width: 21; height: 21; glyph: "bell"; ink: Theme.muted }
    Column {
        id: contents; x: 49; y: 14; width: parent.width - 87; spacing: 5
        Text { width: parent.width; text: root.notice.title || ""; textFormat: Text.PlainText; elide: Text.ElideRight; font.family: Theme.displayFamily; font.pixelSize: Theme.television ? 23 : 18; color: Theme.ink }
        Text { width: parent.width; visible: !!text; text: root.notice.detail || ""; textFormat: Text.PlainText; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; font.pixelSize: Theme.television ? 18 : 13; color: Theme.muted }
    }
    SocialIconButton { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4; icon: "x"; label: "Dismiss notification"; onClicked: root.dismissed() }
}
