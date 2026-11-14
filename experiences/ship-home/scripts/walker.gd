# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipWalker
extends CharacterBody3D
var pivot:Node3D
var arm:SpringArm3D
var camera:Camera3D
var visual:Node3D
var walking=true
var yaw=0.0
var pitch=-0.18
var is_moving=false
var moving_action=false
var skeleton:Skeleton3D
var joints:Dictionary={}
var stride=0.0
var walk_blend=0.0

func _ready() -> void:
 collision_layer=4;collision_mask=3;floor_snap_length=0.3
 var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=0.25;capsule.height=1.3
 shape.shape=capsule;shape.position.y=0.65;add_child(shape)
 pivot=Node3D.new();pivot.position.y=1.25;add_child(pivot)
 arm=SpringArm3D.new();arm.spring_length=3.0;arm.margin=0.2;arm.collision_mask=3
 var probe=SphereShape3D.new();probe.radius=0.14;arm.shape=probe;arm.add_excluded_object(get_rid());pivot.add_child(arm)
 camera=Camera3D.new();camera.fov=68;camera.near=0.06;camera.far=600;arm.add_child(camera);camera.current=true
 anonymous()

func anonymous() -> void:
 skeleton=null;joints.clear()
 if is_instance_valid(visual):visual.queue_free()
 visual=Node3D.new();visual.rotation.y=PI;add_child(visual)
 var art=ShipInterior.new()
 art.cylinder(visual,Vector3(0,0.7,0),0.22,0.53,Color("648c85"),0.17)
 var head=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=0.18;sphere.height=0.36
 head.mesh=sphere;head.position.y=1.17;head.material_override=art.material(Color("ceac83"));visual.add_child(head)
 for side in [-1,1]:
  art.box(visual,Vector3(side*0.11,0.25,0),Vector3(0.16,0.5,0.19),Color("394d5b"))
  art.box(visual,Vector3(side*0.29,0.70,0),Vector3(0.13,0.48,0.15),Color("648c85"))
  art.box(visual,Vector3(side*0.07,1.20,0.16),Vector3(0.025,0.025,0.025),Color("273e3b"))
 moving_action=false

func install_avatar(descriptor:Dictionary) -> bool:
 var presenter=load("res://addons/avatar/avatar_presenter.gd").from_descriptor(descriptor)
 if presenter==null:return false
 var facing=visual.rotation.y if is_instance_valid(visual) else PI
 if is_instance_valid(visual):visual.queue_free()
 visual=presenter;visual.rotation.y=facing;add_child(visual);moving_action=false
 visual.scale=Vector3.ONE*(1.15/max(presenter.eye_height,0.5))
 var rigs=presenter.find_children("*","Skeleton3D",true,false)
 skeleton=rigs[0] if not rigs.is_empty() else null
 joints.clear()
 if skeleton!=null:
  for name in ["thigh.L","thigh.R","shin.L","shin.R","upper_arm.L","upper_arm.R","forearm.L","forearm.R","chest"]:
   var bone=skeleton.find_bone(name)
   if bone>=0:joints[name]=[bone,skeleton.get_bone_pose_rotation(bone)]
 return true

func _unhandled_input(event:InputEvent) -> void:
 if walking and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  yaw-=event.relative.x*0.003;pitch=clamp(pitch-event.relative.y*0.0025,-0.75,0.45)

func _physics_process(delta:float) -> void:
 var direction=Vector3.ZERO
 if walking:
  var look=Input.get_vector("look_left","look_right","look_up","look_down",0.20)
  yaw-=look.x*delta*2.2;pitch=clamp(pitch-look.y*delta*1.7,-0.75,0.45)
  var v=Input.get_vector("walk_left","walk_right","walk_forward","walk_back",0.18)
  direction=Basis(Vector3.UP,yaw)*Vector3(v.x,0,v.y)
 pivot.rotation=Vector3(pitch,yaw,0)
 var speed=4.3 if Input.is_action_pressed("walk_run") else 2.7
 velocity.x=move_toward(velocity.x,direction.x*speed,delta*14)
 velocity.z=move_toward(velocity.z,direction.z*speed,delta*14)
 if not is_on_floor():velocity.y-=14*delta
 else:velocity.y=0
 move_and_slide()
 is_moving=Vector2(velocity.x,velocity.z).length()>0.1
 if is_moving and is_instance_valid(visual):visual.rotation.y=lerp_angle(visual.rotation.y,atan2(velocity.x,velocity.z),min(delta*12,1.0))
 _locomotion(delta)

func _locomotion(delta:float) -> void:
 # Game-owned presentation on the shared rig. No appearance/asset writes.
 if not is_instance_valid(skeleton):return
 var speed=Vector2(velocity.x,velocity.z).length()
 walk_blend=move_toward(walk_blend,min(speed/2.7,1.0),delta*5)
 stride+=speed*delta*3.8
 for side in ["L","R"]:
  var wave=sin(stride+(0 if side=="L" else PI))*walk_blend
  _joint("thigh."+side,Vector3(wave*0.48,0,0))
  _joint("shin."+side,Vector3(max(0,-wave)*0.65,0,0))
  _joint("upper_arm."+side,Vector3(-wave*0.30,0,0))
  _joint("forearm."+side,Vector3(-0.12*walk_blend,0,0))
 _joint("chest",Vector3(0,sin(stride)*0.035*walk_blend,0))

func _joint(name:String,rotation_offset:Vector3) -> void:
 if joints.has(name):
  var joint=joints[name]
  skeleton.set_bone_pose_rotation(joint[0],joint[1]*Quaternion.from_euler(rotation_offset))
