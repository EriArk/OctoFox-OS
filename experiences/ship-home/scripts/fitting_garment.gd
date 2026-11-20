# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Each authored mesh is one fitting slot in the SDK standing pose.
const STYLES := ["traveller","mage","merchant"]
const SLOTS := ["Top","Bottom","Boots","Hat"]
const MODELS := {
	"traveller":preload("res://assets/outfits/traveller.glb"),
	"mage":preload("res://assets/outfits/mage.glb"),
	"merchant":preload("res://assets/outfits/merchant.glb")
}
const NAMES := {
	"traveller":["Trail cloak","Trail trousers","Ranger boots","Feather cap"],
	"mage":["Starweave coat","Indigo leggings","Rune boots","Astral hat"],
	"merchant":["Apron & vest","Market breeches","Guild shoes","Market beret"]
}
var head_attachment: BoneAttachment3D

static func full_set(style: String) -> Dictionary:
	var look := {}
	if style in STYLES:
		for slot in SLOTS:look[slot]=style
	return look

func build(look: Dictionary, skeleton: Skeleton3D) -> void:
	for style in STYLES:
		if style not in look.values():continue
		var model: Node3D=MODELS[style].instantiate()
		for slot in SLOTS:
			if look.get(slot)!=style:continue
			var piece := model.get_node(NodePath(slot)) as MeshInstance3D
			piece.owner=null
			model.remove_child(piece)
			add_child(piece)
			if slot=="Hat" and skeleton!=null:
				var head := skeleton.find_bone("head")
				if head>=0:
					head_attachment=BoneAttachment3D.new()
					skeleton.add_child(head_attachment)
					head_attachment.bone_idx=head
					var rest := skeleton.global_transform*skeleton.get_bone_global_rest(head)
					var offset := rest.affine_inverse()*piece.global_transform
					piece.reparent(head_attachment,false)
					piece.transform=offset
		model.free()

func release() -> void:
	if is_instance_valid(head_attachment):
		head_attachment.hide()
		head_attachment.queue_free()
		head_attachment=null

static func surface_channel(slot:String, material_name:String) -> String:
	if slot=="Bottom":return "primary"
	if material_name in ["brass","silver","gem","saffron","lilac"]:return "accent"
	if material_name in ["sole","hide","ink","wine"]:return "trim"
	if slot=="Boots" and material_name in ["umber","indigo"]:return "primary"
	if material_name in ["tan","umber","fern","teal","oat","plum"]:return "secondary"
	return "primary"

static var channels_by_piece:Dictionary={}

static func channels(style:String,slot:String) -> Array:
	var key:=style+"."+slot
	if channels_by_piece.has(key):return channels_by_piece[key]
	var model:Node3D=MODELS[style].instantiate()
	var piece:MeshInstance3D=model.get_node(NodePath(slot))
	var found:Array=[]
	for i in piece.mesh.get_surface_count():
		var channel:=surface_channel(slot,piece.mesh.surface_get_material(i).resource_name)
		if channel not in found:found.append(channel)
	model.free()
	var ordered:Array=[]
	for channel in ["primary","secondary","trim","accent"]:
		if channel in found:ordered.append(channel)
	channels_by_piece[key]=ordered
	return ordered

func tint(slot:String, choices:Dictionary, palette:Dictionary) -> void:
	var piece:=get_node_or_null(NodePath(slot)) as MeshInstance3D
	if not piece and is_instance_valid(head_attachment):piece=head_attachment.get_node_or_null(NodePath(slot))
	if not piece:return
	for i in piece.mesh.get_surface_count():
		var original:=piece.mesh.surface_get_material(i) as StandardMaterial3D
		if not original:continue
		var key:String=choices.get(surface_channel(slot,original.resource_name),"")
		var color:Dictionary=palette.get(key,{})
		if color.is_empty():
			piece.set_surface_override_material(i,null);continue
		var finish:String=color.finish
		var shade:=lerpf(0.72,1.0,original.albedo_color.v)
		var pigment:=Color.from_string(color.hex,Color.WHITE).darkened(1.0-shade)
		if finish in ["iridescent","pearlescent"]:
			var coated:=ShaderMaterial.new();coated.shader=preload("res://shaders/pearlescent.gdshader")
			coated.set_shader_parameter("pigment",pigment)
			coated.set_shader_parameter("edge",Color("#76e6bf") if finish=="iridescent" else Color("#f2d5ec"))
			coated.set_shader_parameter("sheen",0.95 if finish=="iridescent" else 0.65)
			piece.set_surface_override_material(i,coated)
		else:
			var dyed:=original.duplicate() as StandardMaterial3D
			dyed.albedo_color=pigment
			if finish=="metallic":
				dyed.metallic=maxf(original.metallic,0.87)
				dyed.roughness=minf(original.roughness,0.3)
			elif finish=="satin":dyed.roughness=lerpf(original.roughness,0.45,0.35)
			elif finish=="matte":dyed.roughness=lerpf(original.roughness,0.85,0.35)
			piece.set_surface_override_material(i,dyed)
