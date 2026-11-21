# SPDX-License-Identifier: GPL-3.0-or-later
extends MultiMeshInstance3D
## One instanced draw, with both jets following the authored nozzle transforms.
const PORTS=["ExhaustPort","ExhaustStarboard"]
var plume_material:=ShaderMaterial.new()
var power:=-1.0

func mount(hull:Node3D) -> void:
 var jet:=CylinderMesh.new()
 jet.bottom_radius=0.34;jet.top_radius=0.025;jet.height=1.0
 jet.radial_segments=20;jet.rings=20;jet.cap_bottom=true;jet.cap_top=false
 var jets:=MultiMesh.new();jets.transform_format=MultiMesh.TRANSFORM_3D;jets.mesh=jet
 jets.instance_count=PORTS.size()
 var bounds:=AABB()
 for i in PORTS.size():
  var nozzle:Node3D=hull.find_child(PORTS[i],true,false)
  var pose:=global_transform.affine_inverse()*nozzle.global_transform
  var placement:=pose*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO)
  jets.set_instance_transform(i,placement)
  var envelope:=pose*AABB(Vector3(-0.52,-0.52,-0.06),Vector3(1.04,1.04,6.3))
  bounds=envelope if i==0 else bounds.merge(envelope)
 jets.custom_aabb=bounds;multimesh=jets
 plume_material.shader=preload("res://shaders/drive_exhaust.gdshader")
 material_override=plume_material;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 set_power(0)

func set_power(value:float) -> void:
 var strength:=clampf(value,0,1)
 if strength==power:return
 power=strength;visible=power>0.001
 plume_material.set_shader_parameter("power",power)
