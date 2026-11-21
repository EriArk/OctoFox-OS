# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Standalone exterior for other ships. Only the owner's instance needs split-view layers and physics.
const Flight=preload("res://scripts/egregore_flight.gd")
const CABIN_LAYER:=1 << 17
const OWNER_HULL_LAYER:=1 << 18
const HULL_COLLISION:=16
var local_ship:=false
var emitters:=MultiMeshInstance3D.new()
var hardpoint_travel:=0.0
var hardpoints_out:=false
const EMITTERS = ["GravityForePort", "GravityForeStarboard", "GravityAftPort", "GravityAftStarboard"]
const RINGS_PER_EMITTER := 4
var gravity := MultiMeshInstance3D.new()
var exhaust := preload("res://scripts/drive_plumes.gd").new()
var ring_material := ShaderMaterial.new()
var plume_material:ShaderMaterial:
 get:return exhaust.plume_material
var cycle := 0.0
var hover_amount := -1.0
var drive_power := -1.0

static func configure_camera(camera:Camera3D,aboard:bool) -> void:
 camera.set_cull_mask_value(18,aboard)
 camera.set_cull_mask_value(19,not aboard)

func _ready() -> void:
 var ring := TorusMesh.new()
 ring.inner_radius=0.45;ring.outer_radius=0.55;ring.rings=40;ring.ring_segments=8
 ring_material.shader=preload("res://shaders/gravity_rings.gdshader")
 var pulses:=MultiMesh.new()
 pulses.transform_format=MultiMesh.TRANSFORM_3D;pulses.use_custom_data=true;pulses.mesh=ring
 pulses.instance_count=EMITTERS.size()*RINGS_PER_EMITTER
 for e in EMITTERS.size():
  var port:Node3D=$Hull.find_child(EMITTERS[e],true,false)
  var origin:=to_local(port.global_position)
  for r in RINGS_PER_EMITTER:
   var index:=e*RINGS_PER_EMITTER+r
   pulses.set_instance_transform(index,Transform3D(Basis.IDENTITY,origin))
   pulses.set_instance_custom_data(index,Color((r+e*0.18)/RINGS_PER_EMITTER,0,0,1))
 # Include the shader-displaced rings and plumes in frustum culling.
 pulses.custom_aabb=AABB(Vector3(-5,Flight.GROUND_Y,-5),Vector3(10,4.1,10.4))
 gravity.multimesh=pulses;gravity.material_override=ring_material
 gravity.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(gravity)

 add_child(exhaust);exhaust.mount($Hull)
 set_propulsion(1.0,0.0)
 var pods:=MultiMesh.new();pods.transform_format=MultiMesh.TRANSFORM_3D
 var emitter:=CylinderMesh.new();emitter.top_radius=0.16;emitter.bottom_radius=0.27;emitter.height=2.2
 var brass:=StandardMaterial3D.new();brass.albedo_color=Color("ca9565");brass.metallic=0.64
 emitter.material=brass;pods.mesh=emitter;pods.instance_count=2
 emitters.multimesh=pods;emitters.visible=false;add_child(emitters)
 if local_ship:_local_hull()

func set_propulsion(hover:float,forward_thrust:float,plume_scale:=1.0) -> void:
 var strength:=clampf(hover,0,1)
 if hover_amount!=strength:
  hover_amount=strength
  ring_material.set_shader_parameter("travel",lerpf(1.08,-1.49-Flight.GROUND_Y-0.06,strength))
 drive_power=clampf(forward_thrust,0,1)
 exhaust.set_power(drive_power*plume_scale)

# Older exterior callers supply only a landing fraction.
func set_gear_deployment(amount:float) -> void:
 set_propulsion(amount,maxf(0.0,drive_power))

func _process(delta:float) -> void:
 var travel:=move_toward(hardpoint_travel,1.0 if hardpoints_out else 0.0,delta*1.4)
 if travel!=hardpoint_travel:
  hardpoint_travel=travel;emitters.visible=travel>0
  for i in 2:
   emitters.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3((2*i-1)*3.85,-0.38,-2.75-travel*2.6)))
 cycle=fmod(cycle+delta*0.46,1.0)
 ring_material.set_shader_parameter("cycle",cycle)

func _local_hull() -> void:
 for mesh:GeometryInstance3D in find_children("*","GeometryInstance3D",true,false):
  mesh.layers=OWNER_HULL_LAYER
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 # A coarse hull follows the belly and leaves the lift shaft open for its camera.
 var body:=StaticBody3D.new();body.collision_layer=HULL_COLLISION;body.collision_mask=0;add_child(body)
 var rings:=[Vector4(0.56,1.14,-2.69,0.86),Vector4(0,0.66,-2.45,2.70),
  Vector4(0,0.26,-1.42,4.60),Vector4(0,0.26,-0.68,6.38),Vector4(0,0.26,-0.42,6.38),
  Vector4(0,0.26,0.36,3.25),Vector4(0,-1.55,1.48,1.8),Vector4(0,-1.55,1.5,0.001)]
 var faces:=PackedVector3Array()
 for i in range(rings.size()-1):
  for j in 40:
   var a:=_point(rings[i],j);var b:=_point(rings[i],j+1)
   var c:=_point(rings[i+1],j);var d:=_point(rings[i+1],j+1)
   faces.append_array(PackedVector3Array([a,d,c,a,b,d]))
 var bounds:=ConcavePolygonShape3D.new();bounds.backface_collision=true;bounds.set_faces(faces)
 var shape:=CollisionShape3D.new();shape.shape=bounds;body.add_child(shape)
 var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-38,32,-12)
 key.light_color=Color("fff0d0");key.light_energy=0.87;key.layers=OWNER_HULL_LAYER;key.light_cull_mask=OWNER_HULL_LAYER;add_child(key)

func _point(row:Vector4,index:int) -> Vector3:
 var angle:=TAU*index/40
 return Vector3(row.x+row.w*sin(angle),row.z,row.y-row.w*1.025*cos(angle))
