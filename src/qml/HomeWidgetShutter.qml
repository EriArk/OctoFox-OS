import QtQuick

// Close before releasing the expensive presentation; reopen only when ready.
Item {
    id:root
    property bool requested:false
    property bool windowRenderable:Qt.application.state===Qt.ApplicationActive || Qt.application.state===Qt.ApplicationInactive
    property bool contentReady:false
    property bool retainContent:false
    property real progress:1
    objectName:"home-widget-shutter"
    z:100
    function move(to) {
        if(progress===to){if(to===1&&!requested)retainContent=false;return}
        if(motion.running&&motion.to===to)return
        motion.stop();motion.to=to;motion.start()
    }
    function reconcile() {
        if(!visible||!windowRenderable){motion.stop();progress=1;retainContent=false;return}
        if(requested){retainContent=true;move(contentReady?0:1)}
        else if(retainContent)move(1)
        else {motion.stop();progress=1}
    }
    onRequestedChanged:reconcile()
    onContentReadyChanged:reconcile()
    onVisibleChanged:reconcile()
    onWindowRenderableChanged:reconcile()
    Component.onCompleted:reconcile()
    NumberAnimation {
        id:motion;target:root;property:"progress";duration:190;easing.type:Easing.InOutCubic
        onStopped:if(root.progress>=.999&&!root.requested)root.retainContent=false
    }
    onProgressChanged:doors.requestPaint()
    Canvas {
        id:doors;width:root.width*2;height:root.height*2;scale:.5;transformOrigin:Item.TopLeft;visible:root.progress>0
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{
            var c=getContext("2d"),w=root.width,h=root.height,r=10,p=root.progress
            c.reset();c.clearRect(0,0,canvasSize.width,canvasSize.height);c.scale(2,2);c.save()
            c.beginPath();c.moveTo(r,0);c.arcTo(w,0,w,h,r);c.arcTo(w,h,0,h,r);c.arcTo(0,h,0,0,r);c.arcTo(0,0,w,0,r);c.closePath();c.clip()
            function panel(x,right) {
                var g=c.createLinearGradient(x,0,x+w/2,h);g.addColorStop(0,"#354c59");g.addColorStop(.48,"#1c303b");g.addColorStop(1,"#10232c")
                c.fillStyle=g;c.fillRect(x,0,w/2+1,h)
                c.strokeStyle="#4c6978";c.lineWidth=1;c.strokeRect(x+5,6,w/2-10,h-12)
                var seam=right?x+3:x+w/2-3
                c.fillStyle="#7ce5e0";c.fillRect(seam,12,2,h-24)
                c.fillStyle="#516a77"
                for(var i=0;i<3;++i)c.fillRect(x+w/4-12+i*9,h*.72,5,13)
                c.strokeStyle="#263e4a";c.lineWidth=3
                c.beginPath();c.moveTo(x+10,h*.22);c.lineTo(x+w/2-12,h*.42);c.stroke()
            }
            panel(-w/2*(1-p),false);panel(w/2+w/2*(1-p),true);c.restore()
        }
    }
    MouseArea {anchors.fill:parent;enabled:root.progress>0}
}
