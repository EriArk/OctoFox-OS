# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
signal changed
const Garment = preload("res://scripts/fitting_garment.gd")
const LOOKS = ["Profile outfit", "Traveller", "Mage", "Merchant"]
var workshop
var selected_pieces:Dictionary={}
var active := false
var current := 0
var requested := 0
var closure := 0.0
var returning := false
var hold := 0.0
var camera := Camera3D.new()
var garment: Node3D
var hidden: Array[MeshInstance3D] = []
var walker: ShipWalker
var studio
var previous := Vector3.ZERO
var facing := 0.0

func configure(character: ShipWalker, interior) -> void:
 walker=character;studio=interior
 add_child(camera);camera.near=0.05;camera.fov=43
 camera.position=ShipInterior.BOOTH+Vector3(-1.31,1.45,-2.06)
 camera.look_at(ShipInterior.BOOTH+Vector3.UP*0.88)

func enter() -> void:
 previous=walker.position;facing=walker.visual.rotation.y
 active=true;walker.stationary=true;walker.velocity=Vector3.ZERO
 walker.position=ShipInterior.BOOTH+Vector3.UP*0.082
 walker.visual.rotation.y=atan2(camera.position.x-walker.position.x,camera.position.z-walker.position.z)
 walker.visual.show();camera.current=true
 if is_instance_valid(walker.skeleton):walker.skeleton.reset_bone_poses()
 if is_instance_valid(workshop):workshop.refresh_workshop()

func cycle(step: int) -> void:
 if not returning:requested=posmod(requested+step,LOOKS.size())

func leave() -> void:
 returning=true;requested=0

func clear_garment() -> void:
 if is_instance_valid(garment):
  garment.release();garment.free()
 garment=null
 for part in hidden:
  if is_instance_valid(part):part.show()
 hidden.clear()

func change() -> void:
 clear_garment()
 current=requested
 if current==0:return
 var skin_names=walker.worn_items.duplicate()
 skin_names.append_array(["shirt","shoes","racing-gloves","rose-racing-gloves"])
 for mesh in walker.visual.find_children("*","MeshInstance3D",true,false):
  if mesh.visible and str(mesh.name) in skin_names:
   mesh.hide();hidden.append(mesh)
 garment=Garment.new();walker.visual.add_child(garment)
 if not is_instance_valid(walker.skeleton):garment.scale=Vector3.ONE*1.43
 var style:String=LOOKS[current].to_lower()
 garment.build(Garment.full_set(style),walker.skeleton)
 restore_colors()
 changed.emit()

func restore_colors() -> void:
 if not is_instance_valid(garment) or not is_instance_valid(workshop) or current==0:return
 var style:String=LOOKS[current].to_lower()
 var pieces:Dictionary={}
 for item in workshop.garments:
  if not str(item.sku).begins_with(style+"."):continue
  if not pieces.has(item.sku) or selected_pieces.get(item.sku)==item.id:pieces[item.sku]=item
 for slot in Garment.SLOTS:
  var sku:String=style+"."+slot.to_lower()
  garment.tint(slot,pieces.get(sku,{}).get("colors",{}),workshop.inventory.get("colors",{}))

func update(delta: float) -> void:
 if not active:return
 hold=maxf(0,hold-delta)
 if current!=requested:
  # Keep a fully closed frame before changing the visible meshes.
  if closure<1:
   closure=move_toward(closure,1,delta*2.7)
  elif hold<=0:
   change();hold=0.13
 else:
  if hold<=0:closure=move_toward(closure,0,delta*2.7)
  if returning and closure==0:
   finish();return
 studio.drape.set_shader_parameter("closure",smoothstep(0,1,closure))

func finish() -> void:
 if not active:return
 clear_garment();active=false;returning=false;current=0;requested=0;hold=0;closure=0
 studio.drape.set_shader_parameter("closure",0.0)
 walker.position=previous;walker.visual.rotation.y=facing
 walker.velocity=Vector3.ZERO;walker.stationary=false;walker.camera.current=true
 if is_instance_valid(walker.motion):walker.motion.current=""
