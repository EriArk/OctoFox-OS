import QtQuick
import QtQuick.Window
import TrainerOS
Window {
    id: root
    width:600;height:470;visible:true;color:dark?"#121c20":"#c2cabc"
    property bool dark:false
    onDarkChanged:Theme.themeId=dark?"dark":"light"
    property real uiScale:2
    property bool compact:false
    readonly property bool sceneRequested:mockShell.unobstructed
    readonly property bool sceneReady:!!slot.item && slot.item.presentationReady && shutter.progress===0
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
        active:shutter.retainContent
        Component.onCompleted:setSource(sourceRoot+"/src/qml/HomeCompanionWidget.qml",{"shell":mockShell,"selected":true,"assetBase":packageAssets,"presentationActive":Qt.binding(function(){return shutter.retainContent})})
    }
    HomeWidgetShutter {
        id:shutter;anchors.centerIn:parent;width:slot.width;height:slot.height;scale:2
        // Xvfb has no window manager. Focus is a controlled fixture input here.
        windowRenderable:true
        requested:mockShell.unobstructed
        contentReady:!!slot.item && slot.item.presentationReady
    }
    function hideScene(){mockShell.unobstructed=false}
    function showScene(){mockShell.unobstructed=true}
}
