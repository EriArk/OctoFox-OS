// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Presentation-only activity director for trainer-humanoid-54-v1.
// The owner supplies eligibility/context. This never writes care or game state.
QtObject {
    id: root
    property bool enabled: false
    property bool automatic: true
    property real energy: 80
    property bool outdoors: false
    property int seed: Math.floor(Math.random()*2147483646)+1
    property string behavior: "pause"
    property real elapsed: 0
    property real duration: 2
    property real clock: 0
    property real direction: 1
    property var recent: []
    property real nextSeat: 0
    readonly property real envelope: Math.max(0,Math.min(1,elapsed/1.1,(duration-elapsed)/1.1))
    readonly property real strength: envelope*envelope*(3-2*envelope)
    readonly property bool seated: enabled && behavior==="sit"
    readonly property string action: !enabled?"":behavior==="sit"?"Sit":behavior==="stretch"?"Arms_Up":""
    readonly property real clipPosition: behavior==="wave"?Math.min(1,elapsed/duration):.5
    readonly property string expression: !enabled||behavior==="pause"?"":behavior==="stretch"||behavior==="sit"?"content":behavior==="wave"?"happy":energy<45?"tired":"neutral"
    readonly property real yaw: enabled?strength*direction*(behavior==="look"?19:behavior==="watch"?11:behavior==="sway"?Math.sin(elapsed*1.6)*8:0):0
    readonly property var pose: {
        if(!enabled)return ({})
        var p={"chest":Qt.vector3d(Math.sin(clock*1.5)*1.2,0,0)}, w=strength
        var x=0,y=Math.sin(clock*.6)*3,z=0
        if(behavior==="look"){x=-3*w;y+=Math.sin(elapsed*.85)*26*w;z=direction*5*w}
        if(behavior==="watch"){x=-23*w;y+=direction*13*w;z=-direction*7*w}
        if(behavior==="hands"){
            x=20*w;y=8*w
            p["upper_arm.R"]=Qt.vector3d(-85*w,0,-30*w)
            p["forearm.R"]=Qt.vector3d(-100*w,0,Math.sin(elapsed*1.3)*18*w)
            p["hand.R"]=Qt.vector3d(0,Math.sin(elapsed*1.5)*24*w,0)
        }
        if(behavior==="sway"){
            z=Math.sin(elapsed*1.6)*8*w
            p["chest"]=Qt.vector3d(0,Math.sin(elapsed*1.6)*7*w,-z*.45)
            p["upper_arm.R"]=Qt.vector3d(0,0,-8*w)
            p["upper_arm.L"]=Qt.vector3d(0,0,8*w)
        }
        if(behavior==="sit"){x=4+Math.sin(clock*.7)*3;y=Math.sin(clock*.45)*9}
        if(behavior==="wave"){
            var wave=greetingPose(elapsed*7,w)
            Object.keys(wave).forEach(function(k){p[k]=wave[k]})
            z=-7*w
        }
        p["head"]=Qt.vector3d(x,y,z)
        return p
    }
    property Timer ticker: Timer { interval:83;repeat:true;running:root.enabled&&root.automatic;onTriggered:root.advance(interval/1000) }
    function random() { seed=(Math.max(1,seed)*16807)%2147483647;return (seed-1)/2147483646 }
    function greetingPose(phase,weight) {
        return {"upper_arm.R":Qt.vector3d(0,0,115*weight),
                "forearm.R":Qt.vector3d(0,0,(45+Math.sin(phase)*25)*weight),
                "hand.R":Qt.vector3d(0,0,Math.cos(phase)*18*weight)}
    }
    function reset() { behavior="pause";elapsed=0;duration=1.6+random()*1.4;clock=0;recent=[];nextSeat=0 }
    onEnabledChanged: reset()
    function start(name) {
        if(!enabled||["pause","look","watch","hands","sway","stretch","wave","sit"].indexOf(name)<0)return false
        behavior=name;elapsed=0;direction=random()<.5?-1:1
        duration= name==="pause"?3+random()*4:name==="sit"?14+random()*8:name==="wave"?5:name==="stretch"?4.5:5+random()*3
        if(name!=="pause") { recent=recent.concat([name]).slice(-2);if(name==="sit")nextSeat=clock+65 }
        return true
    }
    function choose() {
        var options=["look","watch","hands","sway","wave"]
        if(energy>=45)options.push("stretch")
        if(clock>=nextSeat){options.push("sit");if(energy<45)options.push("sit","sit")}
        if(outdoors)options.push("watch")
        options=options.filter(function(n){return recent.indexOf(n)<0})
        start(options[Math.floor(random()*options.length)])
    }
    function advance(seconds) {
        if(!enabled||!isFinite(seconds)||seconds<=0)return
        var dt=Math.min(seconds,.25);clock+=dt;elapsed+=dt
        if(elapsed>=duration) { if(behavior==="pause")choose();else start("pause") }
    }
}
