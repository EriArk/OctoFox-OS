# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Standalone exterior for other ships. Only the owner's instance needs split-view layers and physics.
const Flight=preload("res://scripts/egregore_flight.gd")
const CABIN_LAYER:=1 << 17
const OWNER_HULL_LAYER:=1 << 18
const HULL_COLLISION:=16
var local_ship:=false
const EMITTERS = ["GravityForePort", "GravityForeStarboard", "GravityAftPort", "GravityAftStarboard"]
const EXHAUSTS = ["ExhaustPort", "ExhaustStarboard"]
const RINGS_PER_EMITTER := 4
var gravity := MultiMeshInstance3D.new()
var exhaust := MultiMeshInstance3D.new()
var ring_material := ShaderMaterial.new()
var plume_material := ShaderMaterial.new()
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

 var jet:=CylinderMesh.new()
 jet.bottom_radius=0.36;jet.top_radius=0.055;jet.height=1;jet.radial_segments=28;jet.rings=1
 jet.cap_top=false;jet.cap_bottom=false
 plume_material.shader=preload("res://shaders/drive_exhaust.gdshader")
 var jets:=MultiMesh.new();jets.transform_format=MultiMesh.TRANSFORM_3D;jets.mesh=jet
 jets.instance_count=EXHAUSTS.size()
 for i in EXHAUSTS.size():
  var nozzle:Node3D=$Hull.find_child(EXHAUSTS[i],true,false)
  jets.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,PI/2),to_local(nozzle.global_position)))
 jets.custom_aabb=AABB(Vector3(-4.3,0.9,6.8),Vector3(8.6,1.1,2.4))
 exhaust.multimesh=jets;exhaust.material_override=plume_material
 exhaust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(exhaust)
 set_propulsion(1.0,0.0)
 if local_ship:_local_hull()

func set_propulsion(hover:float,forward_thrust:float) -> void:
 var strength:=clampf(hover,0,1)
 if hover_amount!=strength:
  hover_amount=strength
  ring_material.set_shader_parameter("travel",lerpf(1.08,-1.49-Flight.GROUND_Y-0.06,strength))
 var power:=clampf(forward_thrust,0,1)
 if drive_power!=power:
  drive_power=power
  plume_material.set_shader_parameter("power",power)

# Older exterior callers supply only a landing fraction.
func set_gear_deployment(amount:float) -> void:
 set_propulsion(amount,maxf(0.0,drive_power))

func _process(delta:float) -> void:
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
