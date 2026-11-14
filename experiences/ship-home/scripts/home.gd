# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Art=preload("res://scripts/interior.gd")
const Walker=preload("res://scripts/walker.gd")
const Store=preload("res://scripts/layout_store.gd")
const AvatarClient=preload("res://addons/avatar/avatar_client.gd")
var art=Art.new()
var walker:ShipWalker
var store=Store.new()
var avatar_client:Node
var furnishings:Node3D
var rows:Array=[]
var undo_rows:Array=[]
var has_undo=false
var editing=false
var item_index=0
var angle=0.0
var ghost:Node3D
var placement=Vector3.ZERO
var placement_valid=false
var moving_index=-1
var paused=false
var status:Label
var title:Label
var hints:Label
var menu:PanelContainer
var message=""
var message_time=0.0
var profile=""

func _ready() -> void:
 Engine.max_fps=60
 _inputs();art.build(self);art.batch_static(self)
 furnishings=Node3D.new();add_child(furnishings)
 walker=Walker.new();walker.position=Vector3(0,0.1,-2.7);add_child(walker)
 _load_profile("");_ui()
 avatar_client=AvatarClient.new();avatar_client.app_id="art.abysstail.octofox.ship-home"
 avatar_client.appearance_changed.connect(_appearance)
 avatar_client.unavailable.connect(_identity_lost)
 add_child(avatar_client);avatar_client.connect_host()
 get_tree().auto_accept_quit=false
 if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _inputs() -> void:
 for action in ["walk_left","walk_right","walk_forward","walk_back","look_left","look_right","look_up","look_down","walk_run","decorate","confirm_place","cancel_ship","next_item","previous_item","rotate_left","rotate_right","pick_item","undo_place","interact","pause_ship"]:
  if not InputMap.has_action(action):InputMap.add_action(action,0.18)
 var keys={"walk_left":KEY_A,"walk_right":KEY_D,"walk_forward":KEY_W,"walk_back":KEY_S,"walk_run":KEY_SHIFT,"decorate":KEY_TAB,"confirm_place":KEY_ENTER,"cancel_ship":KEY_ESCAPE,"next_item":KEY_BRACKETRIGHT,"previous_item":KEY_BRACKETLEFT,"rotate_left":KEY_Q,"rotate_right":KEY_E,"pick_item":KEY_Y,"undo_place":KEY_Z,"interact":KEY_F,"pause_ship":KEY_P}
 for action in keys:
  var key=InputEventKey.new();key.physical_keycode=keys[action];InputMap.action_add_event(action,key)
 var pads={"decorate":JOY_BUTTON_X,"confirm_place":JOY_BUTTON_A,"cancel_ship":JOY_BUTTON_B,"next_item":JOY_BUTTON_RIGHT_SHOULDER,"previous_item":JOY_BUTTON_LEFT_SHOULDER,"rotate_left":JOY_BUTTON_DPAD_LEFT,"rotate_right":JOY_BUTTON_DPAD_RIGHT,"pick_item":JOY_BUTTON_Y,"interact":JOY_BUTTON_A,"pause_ship":JOY_BUTTON_START,"walk_run":JOY_BUTTON_LEFT_STICK}
 for action in pads:
  var button=InputEventJoypadButton.new();button.button_index=pads[action];InputMap.action_add_event(action,button)
 var axes={"walk_left":[JOY_AXIS_LEFT_X,-1],"walk_right":[JOY_AXIS_LEFT_X,1],"walk_forward":[JOY_AXIS_LEFT_Y,-1],"walk_back":[JOY_AXIS_LEFT_Y,1],"look_left":[JOY_AXIS_RIGHT_X,-1],"look_right":[JOY_AXIS_RIGHT_X,1],"look_up":[JOY_AXIS_RIGHT_Y,-1],"look_down":[JOY_AXIS_RIGHT_Y,1]}
 for action in axes:
  var axis=InputEventJoypadMotion.new();axis.axis=axes[action][0];axis.axis_value=axes[action][1];InputMap.action_add_event(action,axis)

func _load_profile(id:String) -> void:
 profile=id;rows=store.load_home(id);undo_rows=[];has_undo=false;moving_index=-1
 _draw_furniture()
 if not store.error.is_empty():notify(store.error)

func _appearance(descriptor:Dictionary) -> void:
 var id=str(descriptor.get("profile",""))
 if id.is_empty():_identity_lost("No active profile");return
 if id!=profile:
  if editing:_edit(false)
  _load_profile(id)
 if not walker.install_avatar(descriptor):notify("Your character could not be loaded.")

func _identity_lost(reason:String) -> void:
 walker.anonymous()
 if not profile.is_empty():
  if editing:_edit(false)
  _load_profile("");_pause(true)
 notify("Guest home · "+reason)

func _ui() -> void:
 var layer=CanvasLayer.new();add_child(layer)
 var overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(overlay)
 title=Label.new();title.position=Vector2(28,22);title.add_theme_font_size_override("font_size",26);title.add_theme_color_override("font_color",Color("f4e4bd"));overlay.add_child(title)
 status=Label.new();status.position=Vector2(28,58);status.add_theme_font_size_override("font_size",18);overlay.add_child(status)
 hints=Label.new();hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);hints.offset_left=28;hints.offset_top=-42;hints.offset_bottom=-12;hints.add_theme_font_size_override("font_size",17);overlay.add_child(hints)
 var dot=Label.new();dot.text="·";dot.add_theme_font_size_override("font_size",28);dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER);overlay.add_child(dot)
 menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER);menu.offset_left=-240;menu.offset_right=240;menu.offset_top=-200;menu.offset_bottom=200;overlay.add_child(menu)
 var style=StyleBoxFlat.new();style.bg_color=Color("203e42");style.set_corner_radius_all(20);style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=24;style.content_margin_bottom=24;menu.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);menu.add_child(column)
 var heading=Label.new();heading.text="Your ship";heading.add_theme_font_size_override("font_size",28);column.add_child(heading)
 for entry in [["Return",func():_pause(false)],["Decorate",func():_pause(false);_edit(true)],["Undo last arrangement",func():_undo()],["Remove selected furniture",func():_remove()],["Save and exit",func():_quit()]]:
  var b=Button.new();b.text=entry[0];b.custom_minimum_size.y=44;b.pressed.connect(entry[1]);column.add_child(b)
 menu.visible=false

func _pause(value:bool) -> void:
 paused=value;walker.walking=not value;menu.visible=value
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
 if value:menu.get_child(0).get_child(1).grab_focus()

func _unhandled_input(event:InputEvent) -> void:
 if event.is_action_pressed("pause_ship"):
  _pause(not paused);get_viewport().set_input_as_handled();return
 if event.is_action_pressed("cancel_ship"):
  if paused:_pause(false)
  elif editing:_edit(false)
  else:_pause(true)
  get_viewport().set_input_as_handled();return
 if paused:return
 if event.is_action_pressed("decorate"):_edit(not editing)
 elif event.is_action_pressed("undo_place"):_undo()
 elif editing:
  if event.is_action_pressed("next_item"):_cycle(1)
  elif event.is_action_pressed("previous_item"):_cycle(-1)
  elif event.is_action_pressed("rotate_left"):angle=wrapf(angle+PI/12,-PI,PI)
  elif event.is_action_pressed("rotate_right"):angle=wrapf(angle-PI/12,-PI,PI)
  elif event.is_action_pressed("confirm_place"):_place()
  elif event.is_action_pressed("pick_item"):_pick()
  elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:_place()
 elif event.is_action_pressed("interact"):_interact()

func _process(delta:float) -> void:
 message_time=max(0.0,message_time-delta)
 var room="Passage"
 for key in Art.ROOMS:
  if Art.ROOMS[key].has_point(Vector2(walker.position.x,walker.position.z)):room=key;break
 title.text=room+"  /  "+("Guest home" if profile.is_empty() else "Your ship")
 if editing:
  _aim();status.text=("Move " if moving_index>=0 else "Place ")+Art.ITEMS[item_index].replace("-"," ")+"  ·  "+("Ready" if placement_valid else "Keep doors and walkways clear")
  hints.text="LS / WASD Move   RS / Mouse Look   A / Enter Place   LB/RB / [ ] Item   D-pad / Q E Rotate   Y Move nearby   B Cancel"
 else:
  status.text=message if message_time>0 else "A / F  Interact nearby"
  hints.text="LS / WASD Move    RS / Mouse Look    X / Tab Decorate    Start / Esc Menu"

func notify(text:String) -> void:message=text;message_time=6

func _draw_furniture() -> void:
 for node in furnishings.get_children():furnishings.remove_child(node);node.queue_free()
 for i in rows.size():
  var r=rows[i];var node=art.furniture(r.item);node.position=Vector3(r.x,0,r.z);node.rotation.y=r.angle;node.set_meta("row",i);furnishings.add_child(node)

func _edit(value:bool) -> void:
 if value and not store.writable:notify(store.error);return
 editing=value;moving_index=-1
 if is_instance_valid(ghost):remove_child(ghost);ghost.queue_free()
 ghost=null
 if value:_ghost()

func _ghost() -> void:
 if is_instance_valid(ghost):remove_child(ghost);ghost.queue_free()
 ghost=art.furniture(Art.ITEMS[item_index],false);add_child(ghost)
 for mesh in ghost.get_children():
  if mesh is MeshInstance3D:
   var m=StandardMaterial3D.new();m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color=Color(0.4,0.9,0.7,0.55);mesh.material_override=m

func _cycle(step:int) -> void:
 moving_index=-1;item_index=posmod(item_index+step,Art.ITEMS.size());_ghost()

func _aim() -> void:
 var center=get_viewport().get_visible_rect().size/2
 var camera=walker.camera
 var hit=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(center),camera.project_ray_normal(center))
 placement=hit if hit!=null else walker.position-walker.pivot.global_basis.z*2
 placement.y=0
 if Vector2(placement.x-walker.position.x,placement.z-walker.position.z).length()>5:
  var offset=(placement-walker.position).normalized()*5;placement=walker.position+offset;placement.y=0
 placement.x=snappedf(placement.x,0.1);placement.z=snappedf(placement.z,0.1)
 ghost.position=placement;ghost.rotation.y=angle
 placement_valid=can_place(Art.ITEMS[item_index],placement,angle,moving_index)
 for mesh in ghost.get_children():
  if mesh is MeshInstance3D:mesh.material_override.albedo_color=Color(0.4,0.9,0.7,0.55) if placement_valid else Color(1,0.3,0.2,0.55)

func can_place(id:String,pos:Vector3,rotation_y:float,ignored:int=-1) -> bool:
 var f=art.footprint(id)
 var extent=Vector2(abs(cos(rotation_y))*f.x+abs(sin(rotation_y))*f.y,abs(sin(rotation_y))*f.x+abs(cos(rotation_y))*f.y)*0.5
 var area=Rect2(Vector2(pos.x,pos.z)-extent,extent*2)
 var in_room=false
 for room in Art.ROOMS:
  if room!="Passage" and Art.ROOMS[room].grow(-0.2).encloses(area):in_room=true
 if not in_room:return false
 # Entry routes and both ends of each door remain clear.
 for door in [Vector2(-2,3.5),Vector2(2,3.5),Vector2(-2,10.5),Vector2(2,10.5),Vector2(0,0)]:
  if area.intersects(Rect2(door-Vector2(1.4,1.4),Vector2(2.8,2.8))):return false
 if id=="rug":return true
 if area.grow(0.3).has_point(Vector2(walker.position.x,walker.position.z)):return false
 var query=PhysicsShapeQueryParameters3D.new();var shape=BoxShape3D.new();shape.size=Vector3(f.x-0.04,1.8,f.y-0.04)
 query.shape=shape;query.transform=Transform3D(Basis(Vector3.UP,rotation_y),Vector3(pos.x,0.92,pos.z));query.collision_mask=3
 var excluded:Array[RID]=[]
 if ignored>=0 and ignored<furnishings.get_child_count():
  for child in furnishings.get_child(ignored).get_children():
   if child is StaticBody3D:excluded.append(child.get_rid())
 query.exclude=excluded
 return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _commit(next:Array) -> bool:
 if not store.save(next):notify(store.error);return false
 undo_rows=rows.duplicate(true);has_undo=true;rows=next;_draw_furniture();notify("Home saved");return true

func _place() -> void:
 if not placement_valid:return
 if moving_index<0 and rows.size()>=Store.MAX_ITEMS:notify("This home has room for 48 movable pieces.");return
 var next=rows.duplicate(true);var row={"item":Art.ITEMS[item_index],"x":placement.x,"z":placement.z,"angle":angle}
 if moving_index>=0:next[moving_index]=row
 else:next.append(row)
 if _commit(next):moving_index=-1

func _nearest() -> int:
 var result=-1;var distance=3.0
 for i in rows.size():
  var d=Vector2(rows[i].x-walker.position.x,rows[i].z-walker.position.z).length()
  if d<distance:result=i;distance=d
 return result

func _pick() -> void:
 var i=_nearest()
 if i<0:notify("Move closer to a piece of furniture.");return
 moving_index=i;item_index=Art.ITEMS.find(rows[i].item);angle=rows[i].angle;_ghost()

func _remove() -> void:
 var i=moving_index if moving_index>=0 else _nearest()
 if i<0:notify("Move closer to a piece of furniture.");_pause(false);return
 var next=rows.duplicate(true);next.remove_at(i)
 if _commit(next):moving_index=-1
 _pause(false)

func _undo() -> void:
 if not has_undo:notify("Nothing to undo yet.");return
 var previous=undo_rows.duplicate(true)
 if _commit(previous):has_undo=false;moving_index=-1

func _interact() -> void:
 var p=Vector2(walker.position.x,walker.position.z)
 if p.distance_to(Vector2(0,-7.65))<2.7:notify("Navigation console · flight controls coming later.")
 elif p.distance_to(Vector2(-5.5,1))<2.2:notify("Workbench · crafting recipes will be connected here.")
 elif p.distance_to(Vector2(5.5,13))<2.6:notify("Wardrobe · your saved OctoFox appearance is shared with this home.")
 elif Art.ROOMS.Gallery.has_point(p):notify("Your gallery · reserved for cards and trophies you actually own.")
 elif p.distance_to(Vector2(-6.8,11.3))<2.5:notify("Your cabin · make room for your favourite things.")
 else:notify("X / Tab opens your furniture collection.")

func _quit() -> void:
 if store.writable and not store.save(rows):notify(store.error);return
 get_tree().quit()

func _notification(what:int) -> void:
 if what==NOTIFICATION_WM_CLOSE_REQUEST:_quit()
 elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(walker):
  # No input or simulation continues behind another application.
  _pause(true);Engine.max_fps=10
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:Engine.max_fps=60
