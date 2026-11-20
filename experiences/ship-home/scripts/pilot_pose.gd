# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Analytic two-link IK in skeleton coordinates. No bone translations or scaling.
var rig:Skeleton3D
var bones:Dictionary

func bind(skeleton:Skeleton3D) -> void:
 rig=skeleton;bones.clear()
 for i in rig.get_bone_count():bones[String(rig.get_bone_name(i))]=i

func point(bone:int) -> Vector3:return rig.get_bone_global_pose(bone).origin

func aim(bone:int,child:int,target:Vector3) -> void:
 var pose:=rig.get_bone_global_pose(bone)
 var current:=(point(child)-pose.origin).normalized()
 var next:=(target-pose.origin).normalized()
 if current.is_zero_approx() or next.is_zero_approx():return
 var parent:=rig.get_bone_global_pose(rig.get_bone_parent(bone)).basis.get_rotation_quaternion()
 var turn:=Quaternion(current,next)*pose.basis.get_rotation_quaternion()
 rig.set_bone_pose_rotation(bone,(parent.inverse()*turn).normalized())

func reach(a:int,b:int,c:int,world:Vector3,pole_world:Vector3) -> void:
 var origin:=point(a)
 var towards:=rig.to_local(world)-origin
 var axis:=towards.normalized()
 var upper:=point(a).distance_to(point(b));var lower:=point(b).distance_to(point(c))
 var span:=clampf(towards.length(),absf(upper-lower)+0.0001,upper+lower-0.0001)
 var along:=(upper*upper-lower*lower+span*span)/(2.0*span)
 var bend:=(rig.global_basis.inverse()*pole_world).slide(axis).normalized()
 aim(a,b,origin+axis*along+bend*sqrt(maxf(0,upper*upper-along*along)))
 aim(b,c,origin+axis*span)

func grip(side:String,sign_side:float,handle:Marker3D) -> void:
 var palm:=handle.global_position
 var forward:=handle.global_basis*Vector3(-sign_side*0.35,-0.42,-0.84).normalized()
 var hand:int=bones["hand."+side];var middle:int=bones["middle.01."+side]
 var length:=rig.to_global(point(hand)).distance_to(rig.to_global(point(middle)))
 var wrist:=palm-forward*length*0.76
 reach(bones["upper_arm."+side],bones["forearm."+side],hand,wrist,Vector3(sign_side,-1,0.9))
 aim(hand,middle,point(hand)+rig.global_basis.inverse()*forward)
 for finger in ["index","middle","ring","pinky"]:
  for j in range(1,4):
   var id:int=bones["%s.%02d.%s"%[finger,j,side]]
   var rest:=rig.get_bone_rest(id).basis.get_rotation_quaternion()
   rig.set_bone_pose_rotation(id,rest*Quaternion(Vector3.BACK,-sign_side*(0.52 if j==1 else 0.92)))
 var cap:int=bones.get("shoulder_blend."+side,-1)
 if cap>=0:
  var upper:int=bones["upper_arm."+side]
  var rotation:=rig.get_bone_rest(upper).basis.get_rotation_quaternion().inverse()*rig.get_bone_pose_rotation(upper)
  rig.set_bone_pose_rotation(cap,rig.get_bone_rest(cap).basis.get_rotation_quaternion()*Quaternion.IDENTITY.slerp(rotation,0.5))

func apply(helm:ShipInterior) -> void:
 rig.reset_bone_poses()
 var spine:int=bones["spine"]
 rig.set_bone_pose_rotation(spine,rig.get_bone_rest(spine).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,0.11))
 for side in ["L","R"]:
  var s:float=-1 if side=="L" else 1
  var ankle:=helm.helm_root.to_global(Vector3(s*0.13,0.248,0.017))
  reach(bones["thigh."+side],bones["shin."+side],bones["foot."+side],ankle,Vector3(s*0.12,0,-1))
  var foot:int=bones["foot."+side];var toes:int=bones["toes."+side]
  aim(foot,toes,rig.to_local(ankle+Vector3(0,-0.040,-0.080)))
  grip(side,s,helm.left_grip if s<0 else helm.right_grip)
