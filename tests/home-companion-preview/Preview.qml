import QtQuick
import QtQuick.Window
import TrainerOS
Window {
    id: root
    width:600;height:470;visible:true;color:"#c2cabc"
    property real uiScale:2
    property bool compact:false
    QtObject {
        id: mockShell
        property bool unobstructed:true
        property bool quickAppsOpen:false
        property bool drawerOpen:false
        property var keyboard:QtObject{property bool open:false}
        property var notifications:[]
        property var dashboard:QtObject {property var companion:care;function select(key){}}
        property var trainer:QtObject {property url avatarModel:resolvedModel;property bool avatarRendererAvailable:true;property bool avatarBusy:false}
    }
    Loader {
        id: slot
        anchors.centerIn:parent;width:root.compact?216:269;height:root.compact?121:208;scale:2
        Component.onCompleted:setSource(sourceRoot+"/src/qml/HomeCompanionWidget.qml",{"shell":mockShell,"selected":true})
    }
    function hideScene(){mockShell.unobstructed=false}
    function showScene(){mockShell.unobstructed=true}
}
