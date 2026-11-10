import QtQuick
import QtQuick.Controls.Basic

ScrollBar {
    padding: 0
    visible: size < 1
    active: true
    width: 4
    policy: ScrollBar.AsNeeded
    background: null
    contentItem: Rectangle { implicitWidth: 4; implicitHeight: 24; radius: 2; color: Theme.muted; opacity: 0.55 }
}
