// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick3D
import TrainerOS

// Reusable scene node. The host owns camera, lights, activity and identity lifetime.
Node {
    id: root
    property alias source: renderer.source
    property alias running: renderer.running
    property alias expression: renderer.expression
    property alias face: renderer.face
    property alias pose: renderer.pose
    property alias clipPosition: renderer.clipPosition
    property var actions: ({})
    property string action: ""
    readonly property bool ready: renderer.ready
    readonly property string error: renderer.error
    readonly property var sockets: renderer.sockets
    readonly property int vertexCount: renderer.vertexCount
    readonly property int geometryUploads: renderer.geometryUploads
    property alias gpuSkinning: renderer.gpuSkinning
    property var jointNodes: []
    property var skinObjects: []
    function rebuildRig() {
        skinObjects.forEach(function(s){s.destroy()})
        skinObjects=[]
        // Destroy only scene roots; Qt owns their descendants.
        jointNodes.forEach(function(n){if(n && n.parent===root)n.destroy()})
        jointNodes=[]
        if(!renderer.gpuSkinning || !renderer.ready)return
        var poses=renderer.nodePoses, nodes=[]
        function joint(i) {
            if(nodes[i])return nodes[i]
            var p=poses[i], owner=p.parent>=0?joint(p.parent):root
            nodes[i]=jointFactory.createObject(owner,{position:p.position,rotation:p.rotation,scale:p.scale})
            return nodes[i]
        }
        for(var i=0;i<poses.length;++i)joint(i)
        jointNodes=nodes
        skinObjects=renderer.rigs.map(function(rig){return skinFactory.createObject(root,
            {joints:rig.joints.map(function(i){return nodes[i]}),inverseBindPoses:rig.inverse})})
    }
    function applyPose() {
        var updates=renderer.nodePoseUpdates
        for(var i=0;i<updates.length;++i){
            var pose=updates[i], joint=jointNodes[pose.index]
            if(!joint)continue
            joint.position=pose.position
            joint.rotation=pose.rotation
            joint.scale=pose.scale
        }
    }
    function supportsExpression(name){return renderer.supportsExpression(name)}
    function supportsAction(name){return renderer.supportsClip(actions[name] || name)}
    function clearIdentity(){source="";action="";expression="neutral";face=({});pose=({})}
    AvatarScene { id:renderer;gpuSkinning:true;clip:root.actions[root.action] || root.action }
    Component { id:jointFactory; Node {} }
    Component { id:skinFactory; Skin {} }
    Connections {
        target:renderer
        function onModelChanged(){root.rebuildRig()}
        function onFrameChanged(){root.applyPose()}
    }
    Repeater3D {
        model:renderer.parts
        delegate:Model {
            required property var modelData
            geometry:modelData.geometry
            skin:modelData.skin>=0?(root.skinObjects[modelData.skin] || null):null
            materials:PrincipledMaterial {
                baseColor:modelData.color
                baseColorMap:modelData.texture?colorMap:null
                Texture{id:colorMap;source:modelData.texture;flipV:true;generateMipmaps:true;mipFilter:Texture.Linear}
                vertexColorsEnabled:true
                roughness:modelData.roughness;metalness:modelData.metalness
                cullMode:modelData.doubleSided?Material.NoCulling:Material.BackFaceCulling
                alphaMode:modelData.alphaMode==="MASK"?PrincipledMaterial.Mask:modelData.alphaMode==="BLEND"?PrincipledMaterial.Blend:PrincipledMaterial.Opaque
                alphaCutoff:modelData.alphaCutoff
            }
        }
    }
}
