# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Scale the original Bazaar residents to deck height and keep their authored idle.
static func dress(keeper:Node3D,model:String,uniform:Color) -> void:
 var visual:=(load("res://assets/residents/"+model+".glb") as PackedScene).instantiate() as Node3D
 keeper.add_child(visual)
 var bounds:=AABB()
 for part:MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
  var box: AABB=(visual.global_transform.affine_inverse()*part.global_transform)*part.get_aabb()
  bounds=bounds.merge(box) if bounds.has_volume() else box
  # Match the skin/eyes treatment of the Bazaar resident cast.
  var palette={"Skin":Color("bf8869"),"Face":Color("352a26"),"Shirt":uniform}
  for surface in part.mesh.get_surface_count():
   var base=part.mesh.surface_get_material(surface)
   if base is StandardMaterial3D and palette.has(base.resource_name):
    var material:StandardMaterial3D=base.duplicate();material.albedo_color=palette[base.resource_name]
    material.roughness=0.83;part.set_surface_override_material(surface,material)
 var factor:=1.56/maxf(bounds.size.y,0.01)
 visual.scale=Vector3.ONE*factor;visual.position.y=-bounds.position.y*factor
 var animator:AnimationPlayer=visual.find_child("AnimationPlayer",true,false)
 animator.get_animation("Idle").loop_mode=Animation.LOOP_LINEAR;animator.play("Idle")
