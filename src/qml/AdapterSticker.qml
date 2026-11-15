import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string glyph: ""
    property url artwork: ""
    property color tint: "#9edcc3"
    property real tilt: -5
    readonly property bool artworkReady: illustration.status === Image.Ready
    MenuGlyph { id: paths; visible: false; glyph: root.glyph }
    Image {
        id: illustration; anchors.fill: parent; source: root.artwork
        fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize: Qt.size(256,256)
    }
    Item {
        visible: illustration.status !== Image.Ready
        anchors.centerIn: parent; width: 28; height: 28
        scale: Math.min(root.width,root.height)/30; rotation: root.tilt
        Shape {
            x: 2; y: 4
            ShapePath {
                strokeColor: "#30243e39"; strokeWidth: 5; fillColor: "#30243e39"
                joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                PathSvg { path: paths.paths[root.glyph] || paths.paths["game-controller"] }
            }
        }
        Shape {
            x: 2; y: 1
            ShapePath {
                strokeColor: "#fffdf4"; strokeWidth: 5; fillColor: "#fffdf4"
                joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                PathSvg { path: paths.paths[root.glyph] || paths.paths["game-controller"] }
            }
            ShapePath {
                strokeColor: "#274b48"; strokeWidth: 1.4; fillColor: root.tint
                joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
                PathSvg { path: paths.paths[root.glyph] || paths.paths["game-controller"] }
            }
        }
        Rectangle { x: 23; y: 1; width: 3; height: 3; rotation: 45; radius: .6; color: "#ffe087"; border.color: "#fffdf4"; border.width: .7 }
    }
}
