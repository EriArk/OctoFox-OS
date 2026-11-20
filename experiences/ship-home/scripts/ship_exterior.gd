# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Standalone exterior for other ships. Only the owner's instance needs split-view layers and physics.
const Flight=preload("res://scripts/egregore_flight.gd")
const CABIN_LAYER:=1 << 17
const OWNER_HULL_LAYER:=1 << 18
const HULL_COLLISION:=16
var local_ship:=false
@onready var undercarriage:Node3D=$LandingGear

static func configure_camera(camera:Camera3D,aboard:bool) -> void:
 camera.set_cull_mask_value(18,aboard)
 camera.set_cull_mask_value(19,not aboard)

func _ready() -> void:
 if not local_ship:return
 _local_hull()
 var drop:=undercarriage.position.y-Flight.GROUND_Y
 for index in 3:
  var angle:=index*TAU/3.0
  var radial:=Vector3(sin(angle),0,-cos(angle))
  var mount:=radial*1.92
  var foot:=radial*2.95+Vector3.DOWN*(drop-0.12)
  # Walkers sense this layer only ashore, with the gear fully deployed.
  var body:=StaticBody3D.new();body.collision_layer=Flight.WALK_LAYER;body.collision_mask=0
  add_child(body);body.position=undercarriage.position
  var capsule:=CapsuleShape3D.new();capsule.radius=0.16;capsule.height=mount.distance_to(foot)+0.17
  var collider:=CollisionShape3D.new();collider.shape=capsule;body.add_child(collider)
  collider.position=(mount+foot)*0.5;collider.quaternion=Quaternion(Vector3.UP,(mount-foot).normalized())

func set_gear_deployment(amount:float) -> void:
 var deployed:=clampf(amount,0.0,1.0)
 undercarriage.visible=deployed>0.01
 undercarriage.scale.y=lerpf(0.2,1.0,deployed)
 undercarriage.position.y=lerpf(-1.65,-2.79,deployed)

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
