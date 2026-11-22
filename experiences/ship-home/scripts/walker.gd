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
var motion:Node
var skeleton:Skeleton3D
var camera_occludes_avatar=false
var stationary=false
var worn_items:Array=[]
var seated=false
var helm:ShipInterior
var pose=preload("res://scripts/pilot_pose.gd").new()
var last_axes:=Vector2(INF,INF)
var last_power:=INF
var guest_arms:Array[Node3D]=[]
var guest_forearms:Array[Node3D]=[]
var pilot_pivot:Node3D
var pilot_camera:Camera3D
var standing_position=Vector3.ZERO
var standing_yaw=0.0
var standing_pitch=0.0
const PILOT_ORIGIN=Vector3(0,0.02,-3.40)+ShipInterior.SEAT_RAIL
const PILOT_EYE=Vector3(0,1.14,0.0)

func _ready() -> void:
 collision_layer=4;collision_mask=3;floor_snap_length=0.3
 var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=0.25;capsule.height=1.3
 shape.shape=capsule;shape.position.y=0.65;add_child(shape)
 pivot=Node3D.new();pivot.position.y=1.25;add_child(pivot)
 arm=SpringArm3D.new();arm.spring_length=2.1;arm.margin=0.2;arm.collision_mask=3
 var probe=SphereShape3D.new();probe.radius=0.14;arm.shape=probe;arm.add_excluded_object(get_rid());pivot.add_child(arm)
 camera=Camera3D.new();camera.fov=68;camera.near=0.06;camera.far=2400;arm.add_child(camera);camera.current=true
 pilot_pivot=Node3D.new();pilot_pivot.position=PILOT_EYE;add_child(pilot_pivot)
 pilot_camera=Camera3D.new();pilot_camera.fov=78;pilot_camera.near=0.20;pilot_camera.far=2400;pilot_pivot.add_child(pilot_camera)
 anonymous()

func anonymous() -> void:
 worn_items.clear();guest_arms.clear();guest_forearms.clear()
 if is_instance_valid(motion):motion.free()
 motion=null;skeleton=null
 if is_instance_valid(visual):visual.queue_free()
 visual=Node3D.new();visual.rotation.y=PI;add_child(visual)
 var art=ShipInterior.new()
 art.cylinder(visual,Vector3(0,0.7,0),0.22,0.53,Color("648c85"),0.17)
 var head=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=0.18;sphere.height=0.36
 head.mesh=sphere;head.position.y=1.17;head.material_override=art.material(Color("ceac83"));visual.add_child(head)
 for side in [-1,1]:
  art.box(visual,Vector3(side*0.11,0.25,0),Vector3(0.16,0.5,0.19),Color("394d5b"))
  guest_arms.append(art.box(visual,Vector3(side*0.29,0.70,0),Vector3(0.13,0.48,0.15),Color("648c85")))
  art.box(visual,Vector3(side*0.07,1.20,0.16),Vector3(0.025,0.025,0.025),Color("273e3b"))

 if seated:_seat_pose()

func install_avatar(descriptor:Dictionary) -> bool:
 var presenter=load("res://addons/avatar/avatar_presenter.gd").from_descriptor(descriptor)
 if presenter==null:return false
 worn_items.clear()
 var appearance=descriptor.get("appearance",descriptor.get("recipe",{}).get("appearance",{}))
 for slot in ["top","bottom","socks","shoes","gloves","headwear"]:
  worn_items.append(str(appearance.get(slot,"")))
 var facing=visual.rotation.y if is_instance_valid(visual) else PI
 if is_instance_valid(motion):motion.free()
 motion=null
 if is_instance_valid(visual):visual.queue_free()
 visual=presenter;visual.rotation.y=facing;add_child(visual)
 visual.scale=Vector3.ONE*(1.15/max(presenter.eye_height,0.5))
 var rigs=presenter.find_children("*","Skeleton3D",true,false)
 skeleton=rigs[0] if not rigs.is_empty() else null
 motion=load("res://addons/avatar/avatar_locomotion.gd").new();add_child(motion)
 if not motion.bind(presenter):
  motion.free();motion=null;push_warning("Shared avatar locomotion is unavailable for this rig.")
 if skeleton!=null:pose.bind(skeleton)
 if seated:_seat_pose()
 return true

func attend(world_target: Variant) -> void:
 if not is_instance_valid(visual) or not visual.has_method("set_attention"):return
 var aim:=Vector2.ZERO
 if world_target is Vector3:
  var ray:Vector3=visual.to_local(world_target)-Vector3.UP*visual.eye_height
  # Let a station behind the shoulders go instead of snapping between sides.
  var horizontal:=Vector2(ray.x,ray.z).length()
  if horizontal>0.001 and ray.z>0:
   aim=Vector2(atan2(ray.x,ray.z)/0.85,atan2(ray.y,horizontal)/0.6)
   aim=aim.limit_length(1.0)*smoothstep(0.0,0.3,ray.z/horizontal)
 visual.set_attention(aim)

func sit() -> void:
 if seated:return
 standing_position=position;standing_yaw=yaw;standing_pitch=pitch
 seated=true;velocity=Vector3.ZERO;position=PILOT_ORIGIN;yaw=0;pitch=-0.055
 collision_layer=0;collision_mask=0
 pilot_pivot.rotation=Vector3(pitch,yaw,0);pilot_camera.current=true
 if is_instance_valid(skeleton):skeleton.reset_bone_poses()
 _seat_pose()

func stand(at:Vector3) -> void:
 if not seated:return
 seated=false;position=at;velocity=Vector3.ZERO;yaw=standing_yaw;pitch=standing_pitch
 collision_layer=4;collision_mask=3;camera.current=true
 if is_instance_valid(visual):visual.position=Vector3.ZERO
 if not is_instance_valid(skeleton):anonymous()
 if helm:helm.deflect(Vector2.ZERO,0)
 if is_instance_valid(skeleton):skeleton.reset_bone_poses()
 if is_instance_valid(motion):motion.current="";motion.advance(0.0,0.0,false)
 camera_occludes_avatar=false
 if is_instance_valid(visual):visual.show()

func can_stand(at:Vector3) -> bool:
 var query=PhysicsShapeQueryParameters3D.new();var shape=CapsuleShape3D.new()
 shape.radius=0.25;shape.height=1.3;query.shape=shape
 query.transform=Transform3D(Basis.IDENTITY,at+Vector3(0,0.65,0));query.collision_mask=3
 query.exclude=[get_rid()]
 return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _seat_pose() -> void:
 if not is_instance_valid(visual) or helm==null:return
 visual.rotation.y=PI;visual.position=Vector3.ZERO;visual.show()
 pilot_pivot.position=PILOT_EYE
 if is_instance_valid(skeleton):
  skeleton.reset_bone_poses()
  var hip:int=pose.bones["pelvis"]
  var anchor:=helm.helm_root.to_global(Vector3(0,0.615,0.38))
  visual.global_position+=anchor-skeleton.to_global(pose.point(hip))
  pilot_pivot.position=to_local(visual.to_global(Vector3.UP*visual.eye_height))
 else:
  # The anonymous guest has a rigid mannequin. Fold its legs over the seat.
  visual.position=Vector3(0,0.0,0.025)
  for child in visual.get_children():
   if child is MeshInstance3D and is_equal_approx(child.position.y,0.25):
    child.rotation.x=-PI/2;child.position.y=0.55;child.position.z=0.19
  for side in [-1,1]:
   var shin:=helm.box(visual,Vector3(side*0.11,0.38,0.37),Vector3(0.14,0.31,0.14),Color("394d5b"))
   shin.rotation.x=-0.13
   guest_forearms.append(helm.box(visual,Vector3.ZERO,Vector3(0.11,0.16,0.11),Color("ceac83")))
 # Offset the near plane past the face as the head turns, keeping the torso visible.
 pilot_camera.position=Vector3(0,0,-0.095)
 last_axes=Vector2(INF,INF);steer(Vector2.ZERO,0.0)

func steer(axes:Vector2,power:float) -> void:
 if not seated or helm==null or (last_axes==axes and is_equal_approx(last_power,power)):return
 last_axes=axes;last_power=power;helm.deflect(axes,power)
 if is_instance_valid(skeleton):pose.apply(helm)
 else:
  for i in guest_arms.size():
   var left:=i==1;var side:=1 if left else -1
   var end:=visual.to_local(helm.left_grip.global_position if left else helm.right_grip.global_position)
   var upper:=Vector3(side*0.21,0.90,0.0)
   var elbow:=Vector3(side*0.27,0.74,0.018)
   set_segment(guest_arms[i],upper,elbow,0.48)
   set_segment(guest_forearms[i],elbow,end,0.16)

func set_segment(limb:Node3D,start:Vector3,end:Vector3,length:float) -> void:
 limb.position=(start+end)*0.5
 limb.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
 limb.scale.y=start.distance_to(end)/length

func _process(_delta:float) -> void:
 # Wall retraction must not turn the screen into the inside of the avatar's head.
 # Hide only our own presentation near the camera, with hysteresis at the boundary.
 var distance=arm.get_hit_length()
 if distance<0.85:camera_occludes_avatar=true
 elif distance>1.05:camera_occludes_avatar=false
 if is_instance_valid(visual):visual.visible=seated or stationary or not camera_occludes_avatar

func _unhandled_input(event:InputEvent) -> void:
 if walking and not stationary and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  yaw-=event.relative.x*0.003;pitch=clamp(pitch-event.relative.y*0.0025,-1.10 if seated else -0.75,0.45)

func _physics_process(delta:float) -> void:
 if stationary:
  velocity=Vector3.ZERO;is_moving=false;return
 var direction=Vector3.ZERO
 if walking:
  var look=Input.get_vector("look_left","look_right","look_up","look_down",0.20)
  if seated:look=Vector2.ZERO
  yaw-=look.x*delta*2.2;pitch=clamp(pitch-look.y*delta*1.7,-1.10 if seated else -0.75,0.45)
  var v=Input.get_vector("walk_left","walk_right","walk_forward","walk_back",0.18)
  direction=Basis(Vector3.UP,yaw)*Vector3(v.x,0,v.y)
 if seated:
  yaw=clamp(yaw,-1.4,1.4);pitch=clamp(pitch,-1.10,0.45)
  pilot_pivot.rotation=Vector3(pitch,yaw,0);velocity=Vector3.ZERO;is_moving=false
  return
 pivot.rotation=Vector3(pitch,yaw,0)
 var speed=4.3 if Input.is_action_pressed("walk_run") else 2.7
 velocity.x=move_toward(velocity.x,direction.x*speed,delta*14)
 velocity.z=move_toward(velocity.z,direction.z*speed,delta*14)
 if not is_on_floor():velocity.y-=14*delta
 else:velocity.y=0
 var before=position
 move_and_slide()
 var travel=Vector2(position.x-before.x,position.z-before.z).length()/max(delta,0.00001)
 is_moving=travel>0.1
 if is_moving and is_instance_valid(visual):visual.rotation.y=lerp_angle(visual.rotation.y,atan2(velocity.x,velocity.z),min(delta*12,1.0))
 _locomotion(delta,travel)

func _locomotion(delta:float,travel:float) -> void:
 # One SDK animator owns idle/walk/run; cadence follows travel after collisions.
 if is_instance_valid(motion):
  motion.advance(delta,travel,walking,false,is_on_floor(),"run" if travel>3.2 else "walk")
