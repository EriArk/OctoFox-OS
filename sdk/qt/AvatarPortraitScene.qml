// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick3D
import TrainerOS

Item {
    id:root
    property url modelSource
    property int ticket:0
    signal captured(var result,int ticket)
    View3D {
        id:scene;anchors.fill:parent
        environment:SceneEnvironment {backgroundMode:SceneEnvironment.Transparent;antialiasingMode:SceneEnvironment.MSAA;antialiasingQuality:SceneEnvironment.High}
        camera: portraitCamera
        PerspectiveCamera {id:portraitCamera;position:Qt.vector3d(0,0.81,1.2);fieldOfView:28;clipNear:0.01;clipFar:10}
        DirectionalLight {eulerRotation:Qt.vector3d(-25,-25,0);brightness:1.4;ambientColor:"#888888"}
        DirectionalLight {eulerRotation:Qt.vector3d(-15,150,0);brightness:0.7}
        AvatarView3D {id:model;gpuSkinning:false;source:root.modelSource;onReadyChanged:if(ready)settle.restart();onErrorChanged:if(error.length)root.captured(null,root.ticket)}
    }
    Timer {id:settle;interval:250;onTriggered:{var generation=root.ticket;scene.grabToImage(function(result){root.captured(result,generation)},Qt.size(256,256))}}
    Timer {running:true;interval:10000;onTriggered:root.captured(null,root.ticket)}
}
