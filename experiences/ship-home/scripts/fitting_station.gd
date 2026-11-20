# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
signal changed
const Garment = preload("res://scripts/fitting_garment.gd")
const LOOKS = ["Profile outfit", "Traveller", "Mage", "Merchant"]
signal selection_changed
var live_descriptor:Dictionary={}
var preview_installed:=false
var selected_id:=""
var editing_parts:=false
var resolved_key:=""
var render_key:=""
var preview_error:=""
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
 if is_instance_valid(workshop):
  workshop.look_notice=""
  workshop.refresh_workshop();workshop.refresh_looks()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 selection_changed.emit()

func saved_rows() -> Array:
 return workshop.saved_looks.filter(func(row):return not row.worn) if is_instance_valid(workshop) else []

func selected_look(index:int) -> Dictionary:
 var rows:=saved_rows()
 var i:=index-LOOKS.size()
 return rows[i] if i>=0 and i<rows.size() else {}

func select(index:int) -> void:
 if returning or not active:return
 var next:=clampi(index,0,LOOKS.size()+saved_rows().size()-1)
 if requested==next:return
 requested=next
 selected_id=selected_look(requested).get("id","")
 selection_changed.emit()

func sync_looks() -> void:
 if not active:return
 # A wardrobe refresh may reorder the list or move the worn set to the first card.
 if requested>=LOOKS.size() and selected_id!="":
  var rows:=saved_rows()
  requested=0
  for i in rows.size():
   if rows[i].id==selected_id:requested=LOOKS.size()+i;break
  if current>=LOOKS.size() and requested>=LOOKS.size() and resolved_key==selected_id:
   current=requested if render_key==recipe_key(selected_look(requested)) else -1
 requested=clampi(requested,0,LOOKS.size()+saved_rows().size()-1)
 selected_id=selected_look(requested).get("id","")
 selection_changed.emit()

func restore_avatar() -> void:
 if preview_installed:
  walker.install_avatar(live_descriptor)
 preview_installed=false;resolved_key="";render_key="";preview_error=""

func recipe_key(row:Dictionary) -> String:
 return str(row.id)+"/"+JSON.stringify(row.recipe).sha256_text()

func resolve_selected() -> void:
 var row:=selected_look(current)
 if row.is_empty() or not is_instance_valid(workshop):return
 if workshop.resolving_key.is_empty() and not workshop.resolve_recipe(row.recipe,recipe_key(row)):
  preview_error="Preview unavailable"

func resolved(key:String,descriptor:Dictionary) -> void:
 if editing_parts or not active or returning or current!=requested:return
 var row:=selected_look(requested)
 if row.is_empty():return
 if recipe_key(row)!=key:resolve_selected();return
 preview_installed=walker.install_avatar(descriptor)
 if preview_installed:resolved_key=row.id;render_key=key;preview_error=""
 else:preview_error="Preview unavailable"
 selection_changed.emit()

func resolve_failed(key:String,reason:String) -> void:
 if editing_parts or not active or current!=requested:return
 var row:=selected_look(requested)
 if row.is_empty():return
 if recipe_key(row)!=key:resolve_selected();return
 preview_error=reason.replace("_"," ").capitalize();selection_changed.emit()


func leave() -> void:
 returning=true;requested=0;selected_id=""

func clear_garment() -> void:
 if is_instance_valid(garment):
  garment.release();garment.free()
 garment=null
 for part in hidden:
  if is_instance_valid(part):part.show()
 hidden.clear()

func change() -> void:
 clear_garment();restore_avatar()
 current=requested
 if current>=LOOKS.size():
  resolve_selected();selection_changed.emit();return
 if current==0:
  selection_changed.emit();return
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
 if not is_instance_valid(garment) or not is_instance_valid(workshop) or current==0 or current>=LOOKS.size():return
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
 if not returning:
  walker.visual.rotation.y-=Input.get_axis("look_left","look_right")*delta*2.6
 if editing_parts:return
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
 clear_garment();restore_avatar();selected_id="";active=false;returning=false;current=0;requested=0;hold=0;closure=0
 studio.drape.set_shader_parameter("closure",0.0)
 walker.position=previous;walker.visual.rotation.y=facing
 walker.velocity=Vector3.ZERO;walker.stationary=false;walker.camera.current=true
 if is_instance_valid(walker.motion):walker.motion.current=""
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 selection_changed.emit()
