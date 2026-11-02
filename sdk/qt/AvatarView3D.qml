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
    function supportsExpression(name){return renderer.supportsExpression(name)}
    function supportsAction(name){return renderer.supportsClip(actions[name] || name)}
    function clearIdentity(){source="";action="";expression="neutral";face=({});pose=({})}
    AvatarScene { id:renderer;clip:root.actions[root.action] || root.action }
    Repeater3D {
        model:renderer.parts
        delegate:Model {
            required property var modelData
            geometry:modelData.geometry
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
