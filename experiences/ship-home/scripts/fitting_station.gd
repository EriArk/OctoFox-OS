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
var loading_piece:=false
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

func owned_slots(index:int) -> Dictionary:
 var look:Dictionary={}
 if index<=0 or index>=LOOKS.size() or not is_instance_valid(workshop):return look
 var style:String=LOOKS[index].to_lower()
 for piece in workshop.garments:
  var sku:=str(piece.sku).split(".")
  if sku.size()==2 and sku[0]==style and sku[1].capitalize() in Garment.SLOTS:
   look[sku[1].capitalize()]=style
 return look

func inventory_changed() -> void:
 if not active:return
 if requested>0 and requested<LOOKS.size() and owned_slots(requested).is_empty():select(0)
 if current>0 and current<LOOKS.size() and current==requested:
  if is_instance_valid(garment) and garment.get_meta("slots",{})!=owned_slots(current):current=-1
  else:restore_colors()
 selection_changed.emit()

func select(index:int) -> void:
 if returning or not active:return
 var next:=clampi(index,0,LOOKS.size()+saved_rows().size()-1)
 if next>0 and next<LOOKS.size() and owned_slots(next).is_empty():return
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

# Resolved recipes have no identity of their own. Scope their preview cache
# to the live SDK session, which is revoked on profile switch/disconnect.
func install_preview(descriptor:Dictionary,selected:Callable) -> bool:
 var owner:=str(live_descriptor.get("profile",""))
 if owner.is_empty() or workshop.profile_id!=owner:return false
 while active and not returning and selected.call() and closure<1.0:
  await get_tree().process_frame
 if not active or returning or not selected.call():return false
 # Present the closed curtain before installing even a cached model on the main thread.
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 if not selected.call() or workshop.profile_id!=owner:return false
 var installed:=await walker.preview_avatar(descriptor,owner,selected)
 if installed and DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 return installed and selected.call()

func resolved(key:String,descriptor:Dictionary) -> void:
 if editing_parts or not active or returning or current!=requested:return
 var row:=selected_look(requested)
 if row.is_empty():return
 if recipe_key(row)!=key:resolve_selected();return
 var selected:=func():return active and not returning and not editing_parts and recipe_key(row)==key and selected_id==row.id and selected_look(requested)==row
 var ok:=await install_preview(descriptor,selected)
 if not selected.call():return
 if ok:
  preview_installed=true;resolved_key=row.id;render_key=key;preview_error=""
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
 clear_garment()
 current=requested
 if current>=LOOKS.size():
  preview_error="";resolved_key="";render_key=""
  resolve_selected();selection_changed.emit();return
 restore_avatar()
 if current==0:
  selection_changed.emit();return
 var owned:=owned_slots(current)
 if owned.is_empty():requested=0;current=0;selection_changed.emit();return
 var skin_names:Array=[]
 var appearance:Dictionary=live_descriptor.get("recipe",{}).get("appearance",{})
 for slot in owned:
  var field:String={"Top":"top","Bottom":"bottom","Boots":"shoes","Hat":"headwear"}[slot]
  skin_names.append(appearance.get(field,""))
  if slot=="Top":skin_names.append("shirt")
  if slot=="Boots":skin_names.append("shoes")
 for mesh in walker.visual.find_children("*","MeshInstance3D",true,false):
  if mesh.visible and str(mesh.name) in skin_names:
   mesh.hide();hidden.append(mesh)
 garment=Garment.new();walker.visual.add_child(garment)
 if not is_instance_valid(walker.skeleton):garment.scale=Vector3.ONE*1.43
 garment.set_meta("slots",owned)
 garment.build(owned,walker.skeleton)
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
 hold=maxf(0,hold-delta)
 var saved:=selected_look(current)
 var waiting:=loading_piece if editing_parts else not returning and not saved.is_empty() and render_key!=recipe_key(saved) and preview_error.is_empty()
 if editing_parts or (current==requested and waiting):
  closure=move_toward(closure,1.0 if waiting else 0.0,delta*2.7)
 elif current!=requested:
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
 loading_piece=false;editing_parts=false
 clear_garment();restore_avatar();selected_id="";active=false;returning=false;current=0;requested=0;hold=0;closure=0
 studio.drape.set_shader_parameter("closure",0.0)
 walker.position=previous;walker.visual.rotation.y=facing
 walker.velocity=Vector3.ZERO;walker.stationary=false;walker.camera.current=true
 if is_instance_valid(walker.motion):walker.motion.current=""
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 selection_changed.emit()
