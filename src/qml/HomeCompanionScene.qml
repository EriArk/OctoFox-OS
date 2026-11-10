import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils
import TrainerOS

View3D {
    id: root
    objectName: "home-companion-scene"
    property url modelSource
    property string assetBase: "qrc:/home-pet/"
    property var pet
    property bool animate: true
    // Kenney props use different source dimensions; scale to hand-sized food.
    readonly property real foodScale: ({"food-kit/apple.glb":.33,"food-kit/banana.glb":.16,
        "food-kit/burger.glb":.20,"food-kit/cookie-chocolate.glb":.45,
        "food-kit/cup-tea.glb":.25,"food-kit/cupcake.glb":.20})[pet?pet.prop:""] || .3
    readonly property bool ready: presenter.ready
    readonly property string error: presenter.error
    readonly property int vertices: presenter.vertexCount
    property real bite: 0
    property real greeting: 0
    readonly property bool celebrating: !!pet && pet.activity==="celebrate"
    property real awardLift:0
    onCelebratingChanged: {if(celebrating)lift.start();else {lift.stop();awardLift=0}}
    NumberAnimation {id:lift;target:root;property:"awardLift";from:0;to:1;duration:650;easing.type:Easing.OutCubic}
    readonly property point awardPoint: {
        var handR=presenter.sockets["hand.R"],handL=presenter.sockets["hand.L"]
        var p=handR&&handL?handR.position.plus(handL.position).times(.5):Qt.vector3d(0,1,0)
        p.y=Math.max(1.07,p.y+.10)
        p=Qt.vector3d(p.x,.64,.05).times(1-awardLift).plus(p.times(awardLift))
        var screen=mapFrom3DScene(presenter.mapPositionToScene(p))
        return Qt.point(Math.max(0,Math.min(width,screen.x)),Math.max(0,Math.min(height,screen.y)))
    }
    NumberAnimation on greeting { from:0;to:Math.PI*2;duration:900;loops:Animation.Infinite;running:root.animate && root.pet && root.pet.activity==="notify" }
    AvatarIdleDirector {
        id:idle; objectName:"companion-idle-director"
        enabled:root.animate && presenter.ready && !!root.pet && root.pet.activity==="idle" && !root.pet.menuOpen
        energy:root.pet?root.pet.needs.energy:80
        outdoors:root.pet && root.pet.background==="sunny-garden"
    }
    SequentialAnimation on bite {
        loops:Animation.Infinite;running:root.animate && root.pet && root.pet.activity==="feed"
        NumberAnimation {to:1;duration:650;easing.type:Easing.InOutSine}
        PauseAnimation {duration:450}
        NumberAnimation {to:0;duration:650;easing.type:Easing.InOutSine}
        PauseAnimation {duration:400}
    }
    environment: SceneEnvironment { backgroundMode: SceneEnvironment.Transparent; antialiasingMode: SceneEnvironment.MSAA; antialiasingQuality: SceneEnvironment.Medium }
    camera: PerspectiveCamera {
        position: root.celebrating?Qt.vector3d(0,.75,2.60):Qt.vector3d(0,.64,2.35)
        Behavior on position { Vector3dAnimation {duration:320} }
        eulerRotation.x:-5;fieldOfView:29;clipNear:.01;clipFar:10
    }
    DirectionalLight { eulerRotation: Qt.vector3d(-25,-30,0); brightness:1.1; ambientColor: root.pet && root.pet.background==="evening-nook"?"#66707f":"#888888" }
    DirectionalLight { eulerRotation: Qt.vector3d(-10,145,0); brightness:.45 }
    AvatarView3D {
        id: presenter
        source: root.modelSource
        running: root.animate
        expression: idle.expression || (root.pet ? root.pet.expression : "neutral")
        face:root.pet && root.pet.activity==="feed"?({"mouth_smile":.3,"mouth_open":root.bite*.6}):({})
        eulerRotation.y:-12+idle.yaw
        Behavior on eulerRotation { Vector3dAnimation { duration:220 } }
        position.x:root.celebrating?.22:0
        Behavior on position {Vector3dAnimation {duration:320}}
        action: !root.pet?"":root.pet.activity==="rest"?"Sit":root.pet.activity==="celebrate"?"Arms_Up":idle.action
        clipPosition: idle.action?idle.clipPosition:root.pet && (root.pet.activity==="rest"||root.celebrating)?.5:-1
        pose: root.pet && root.pet.activity==="feed"
              ? ({"upper_arm.R":Qt.vector3d(-30-root.bite*65,0,-35),"forearm.R":Qt.vector3d(-90-root.bite*15,0,-20),"head":Qt.vector3d(root.bite*7,0,0)})
              : root.pet && root.pet.activity==="notify"?idle.greetingPose(root.greeting,1)
              : root.celebrating?({"upper_arm.R":Qt.vector3d(0,0,40),"upper_arm.L":Qt.vector3d(0,0,-40)}):idle.pose
        RuntimeLoader {
            source: root.pet && root.pet.prop ? root.assetBase+root.pet.prop : idle.seated?root.assetBase+"furniture-kit/loungeChair.glb":""
            position: !root.pet?Qt.vector3d(0,0,0):root.pet.activity==="feed" && presenter.sockets["hand.R"] ? presenter.sockets["hand.R"].position.plus(Qt.vector3d(0,-.02,.02))
                      : root.pet.activity==="rest" || idle.seated ? Qt.vector3d(-.233,0,-.10) : Qt.vector3d(.18,.015,.23)
            scale: root.pet && root.pet.activity==="feed" ? Qt.vector3d(root.foodScale,root.foodScale,root.foodScale)
                   : (root.pet && root.pet.activity==="rest") || idle.seated ? Qt.vector3d(.95,.95,.95) : Qt.vector3d(.22,.22,.22)
        }
    }
    Component.onCompleted: {
        if("explicitTextureWidth" in root){
            root.explicitTextureWidth=Qt.binding(function(){return Math.min(768,Math.ceil(root.width*(Window.window?Window.window.uiScale||1:1)))})
            root.explicitTextureHeight=Qt.binding(function(){return Math.min(512,Math.ceil(root.height*(Window.window?Window.window.uiScale||1:1)))})
        }
    }
}
