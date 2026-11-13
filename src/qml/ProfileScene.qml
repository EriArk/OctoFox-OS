import QtQuick
import QtQuick.Window
import QtQuick.Shapes

Rectangle {
    id:root
    required property var profile
    property string appearance:""
    property bool showAvatar:true
    property bool thumbnail:false
    property real footerInset:0
    radius:12;clip:true
    gradient:Gradient { GradientStop {position:0;color:Theme.dark?"#182536":"#bdd9dc"} GradientStop {position:1;color:Theme.dark?"#293f40":"#dce8ce"} }
    Rectangle { visible:!root.appearance;x:parent.width*.50;y:parent.height*.08;width:parent.width*.42;height:width;radius:width/2;color:Theme.dark?"#b8c6ab":"#fff1c9";opacity:.7 }
    Canvas {
        anchors.fill:parent;visible:!root.appearance
        property bool night:Theme.dark
        onNightChanged:requestPaint()
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{let c=getContext("2d");c.reset();const w=width,h=height;c.fillStyle=night?"#293b47":"#96bab3";c.beginPath();c.moveTo(0,h*.47);c.bezierCurveTo(w*.38,h*.12,w*.52,h*.77,w,h*.34);c.lineTo(w,h);c.lineTo(0,h);c.fill();c.fillStyle=night?"#36504b":"#b9cdb1";c.beginPath();c.moveTo(0,h*.73);c.bezierCurveTo(w*.4,h*.4,w*.6,h*.6,w,h*.68);c.lineTo(w,h);c.lineTo(0,h);c.fill()}
    }
    Canvas {
        anchors.fill:parent;visible:!root.appearance&&!root.thumbnail
        property bool night:Theme.dark
        onNightChanged:requestPaint()
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{
            const c=getContext("2d"),w=width,h=height;c.reset();
            c.strokeStyle=night?"#567878":"#739e94";c.lineWidth=1;
            c.beginPath();c.arc(w*.5,h*.43,w*.41,Math.PI*.90,Math.PI*2.10);c.stroke();
            c.globalAlpha=.45;c.beginPath();c.arc(w*.5,h*.43,w*.46,Math.PI*1.04,Math.PI*1.96);c.stroke();
            c.globalAlpha=.7;
            for(let i=0;i<9;i++){const x=w*(.12+(i*37%76)/100),y=h*(.14+(i*13%39)/100),s=i%3===0?3:1.4;c.fillStyle=night?"#d8e7cd":"#fffae7";c.beginPath();c.moveTo(x,y-s);c.lineTo(x+s*.55,y);c.lineTo(x,y+s);c.lineTo(x-s*.55,y);c.closePath();c.fill();}
        }
    }
    Image {
        anchors.fill:parent;visible:!!root.appearance
        source:root.appearance?"qrc:/profile-scenes/"+root.appearance+".png":""
        sourceSize:root.thumbnail?Qt.size(120,180):Qt.size(768,1152)
        fillMode:Image.PreserveAspectCrop;asynchronous:true
    }
    Rectangle { visible:!root.appearance&&!root.thumbnail;anchors.horizontalCenter:parent.horizontalCenter;y:parent.height-root.footerInset-34;width:parent.width*.62;height:15;radius:width/2;color:Theme.dark?"#29413e":"#98b7a3";border.color:Theme.dark?"#8aa894":"#d8e3b9";border.width:1 }
    Loader {
        id:avatar;x:0;y:root.appearance?parent.height*.03:22;width:parent.width;height:(root.appearance?parent.height*.90:parent.height-37)-root.footerInset
        active:root.visible&&(!root.Window.window||root.Window.window.visible)&&root.showAvatar&&!root.thumbnail&&!!root.profile.avatarPreview&&root.profile.avatarRendererAvailable
        source:active?"AvatarPreview3D.qml":""
        onLoaded:item.modelSource=Qt.binding(function(){return root.profile.avatarPreview})
    }
    TrainerEmblem { anchors.centerIn:parent;width:Math.min(110,parent.width*.55);height:width;visible:root.showAvatar&&!avatar.active&&!root.thumbnail;emblem:root.profile.profile.emblem||"compass" }
    // Cover only the square corner wedges; keep image, avatar and pointer input intact.
    Shape {
        anchors.fill:parent;z:5
        ShapePath {
            strokeColor:"transparent";fillColor:Theme.paper;fillRule:ShapePath.OddEvenFill
            PathSvg { path:"M0 0H"+root.width+"V"+root.height+"H0Z M12 0H"+(root.width-12)+"Q"+root.width+" 0 "+root.width+" 12V"+(root.height-12)+"Q"+root.width+" "+root.height+" "+(root.width-12)+" "+root.height+"H12Q0 "+root.height+" 0 "+(root.height-12)+"V12Q0 0 12 0Z" }
        }
    }
}
