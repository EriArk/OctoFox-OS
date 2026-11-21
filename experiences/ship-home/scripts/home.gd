# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const Art=preload("res://scripts/interior.gd")
const Exterior=preload("res://scripts/ship_exterior.gd")
const ExteriorScene=preload("res://exterior.tscn")
var cabin:=Node3D.new()
var exterior:=ExteriorScene.instantiate() as Exterior
var viewing_exterior:=false
var lift_shutter:=ColorRect.new()
const Walker=preload("res://scripts/walker.gd")
const Store=preload("res://scripts/layout_store.gd")
const AvatarClient=preload("res://scripts/workshop_client.gd")
var art=Art.new()
var flight=preload("res://scripts/egregore_flight.gd").new()
var studio=preload("res://scripts/studio.gd").new()
var dye=preload("res://scripts/dye_console.gd").new()
var parts=preload("res://scripts/look_parts.gd").new()
var cards=preload("res://scripts/look_cards.gd").new()
var fabricator=preload("res://scripts/fabricator.gd").new()
var fitting=preload("res://scripts/fitting_station.gd").new()
var riding=false
var outside:=false
var ride_platform:AnimatableBody3D
var lift_start=0.0
var lift_end=0.0
var ride_time=0.0
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
var dot:=Label.new()
var status:Label
var prompts=preload("res://scripts/ship_prompts.gd").new()
var helm_help:=Label.new()
var menu:PanelContainer
var message=""
var message_time=0.0
var profile=""

func _ready() -> void:
 Engine.max_fps=60
 _inputs()
 cabin.name="Cabin";add_child(cabin)
 for camera:Camera3D in get_tree().root.find_children("*","Camera3D",true,false):
  if camera.get_world_3d()==get_world_3d():Exterior.configure_camera(camera,false)
 get_tree().node_added.connect(_ship_visual_added)
 art.build(cabin,self);cabin.add_child(studio);studio.build_fixed(art);art.batch_static(cabin)
 studio.build_moving(self);art.moving_controls()
 exterior.local_ship=true;add_child(exterior)
 add_child(flight);flight.build(art)
 furnishings=Node3D.new();cabin.add_child(furnishings)
 walker=Walker.new();walker.helm=art;walker.position=Vector3(0,0.1,-0.55);add_child(walker)
 add_child(fitting);fitting.configure(walker,studio)
 Exterior.configure_camera(walker.pilot_camera,true);Exterior.configure_camera(fitting.camera,true)
 _load_profile("");_ui()
 avatar_client=AvatarClient.new();avatar_client.app_id="art.abysstail.octofox.ship-home"
 parts.client=avatar_client;parts.fitting=fitting
 cards.pieces_requested.connect(parts.open)
 avatar_client.recipe_resolved.connect(parts.resolved)
 avatar_client.recipe_failed.connect(parts.failed)
 avatar_client.parts_received.connect(parts.receive)
 avatar_client.looks_changed.connect(parts.sync)
 cards.fitting=fitting
 cards.appearance_requested.connect(_open_colours)
 fitting.selection_changed.connect(cards.refresh)
 avatar_client.looks_changed.connect(fitting.sync_looks)
 avatar_client.recipe_resolved.connect(fitting.resolved)
 avatar_client.recipe_failed.connect(fitting.resolve_failed)
 fitting.workshop=avatar_client
 avatar_client.workshop_changed.connect(fitting.restore_colors)
 fabricator.workshop=avatar_client;dye.workshop=avatar_client;dye.fitting=fitting
 avatar_client.workshop_changed.connect(fabricator.refresh)
 avatar_client.workshop_changed.connect(dye.refresh)
 fitting.changed.connect(dye.paint_preview)
 avatar_client.appearance_changed.connect(_appearance)
 avatar_client.unavailable.connect(_identity_lost)
 add_child(avatar_client);avatar_client.connect_host()
 get_tree().auto_accept_quit=false
 if DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _ship_visual_added(node:Node) -> void:
 if node is Camera3D and node.get_world_3d()==get_world_3d():
  # A second camera in the same world (including a spectator viewport) sees the hull.
  Exterior.configure_camera(node,false)
 elif node is VisualInstance3D and cabin.is_ancestor_of(node):
  node.layers=Exterior.CABIN_LAYER
  if node is Light3D:node.light_cull_mask=Exterior.CABIN_LAYER
 elif is_instance_valid(walker) and node is GeometryInstance3D and walker.is_ancestor_of(node):
  node.layers=1 if viewing_exterior else Exterior.CABIN_LAYER

func _set_ship_view(at_dock:bool) -> void:
 Exterior.configure_camera(walker.camera,not at_dock)
 if viewing_exterior!=at_dock:
  viewing_exterior=at_dock
  for mesh:GeometryInstance3D in walker.find_children("*","GeometryInstance3D",true,false):
   mesh.layers=1 if at_dock else Exterior.CABIN_LAYER
 walker.arm.collision_mask=(flight.WALK_LAYER|Exterior.HULL_COLLISION) if at_dock else 3

func _inputs() -> void:
 for action in ["walk_left","walk_right","walk_forward","walk_back","look_left","look_right","look_up","look_down","fly_up","fly_down","fly_left","fly_right","walk_run","decorate","confirm_place","cancel_ship","next_item","previous_item","rotate_left","rotate_right","pick_item","undo_place","interact","pause_ship"]:
  if not InputMap.has_action(action):InputMap.add_action(action,0.18)
 var keys={"fly_up":KEY_R,"fly_down":KEY_C,"fly_left":KEY_Z,"fly_right":KEY_X,"walk_left":KEY_A,"walk_right":KEY_D,"walk_forward":KEY_W,"walk_back":KEY_S,"walk_run":KEY_SHIFT,"decorate":KEY_TAB,"confirm_place":KEY_ENTER,"cancel_ship":KEY_ESCAPE,"next_item":KEY_BRACKETRIGHT,"previous_item":KEY_BRACKETLEFT,"rotate_left":KEY_Q,"rotate_right":KEY_E,"pick_item":KEY_Y,"undo_place":KEY_Z,"interact":KEY_F,"pause_ship":KEY_P}
 for action in keys:
  var key=InputEventKey.new();key.physical_keycode=keys[action];InputMap.action_add_event(action,key)
 var pads={"fly_up":JOY_BUTTON_DPAD_UP,"fly_down":JOY_BUTTON_DPAD_DOWN,"decorate":JOY_BUTTON_X,"confirm_place":JOY_BUTTON_A,"cancel_ship":JOY_BUTTON_B,"next_item":JOY_BUTTON_RIGHT_SHOULDER,"previous_item":JOY_BUTTON_LEFT_SHOULDER,"rotate_left":JOY_BUTTON_DPAD_LEFT,"rotate_right":JOY_BUTTON_DPAD_RIGHT,"pick_item":JOY_BUTTON_Y,"interact":JOY_BUTTON_A,"pause_ship":JOY_BUTTON_START,"walk_run":JOY_BUTTON_LEFT_STICK}
 for action in pads:
  var button=InputEventJoypadButton.new();button.button_index=pads[action];InputMap.action_add_event(action,button)
 var axes={"fly_left":[JOY_AXIS_TRIGGER_LEFT,1],"fly_right":[JOY_AXIS_TRIGGER_RIGHT,1],"walk_left":[JOY_AXIS_LEFT_X,-1],"walk_right":[JOY_AXIS_LEFT_X,1],"walk_forward":[JOY_AXIS_LEFT_Y,-1],"walk_back":[JOY_AXIS_LEFT_Y,1],"look_left":[JOY_AXIS_RIGHT_X,-1],"look_right":[JOY_AXIS_RIGHT_X,1],"look_up":[JOY_AXIS_RIGHT_Y,-1],"look_down":[JOY_AXIS_RIGHT_Y,1]}
 for action in axes:
  var axis=InputEventJoypadMotion.new();axis.axis=axes[action][0];axis.axis_value=axes[action][1];InputMap.action_add_event(action,axis)

func _load_profile(id:String) -> void:
 if is_instance_valid(walker) and walker.seated:
  # Profile changes return to the reserved central approach before replacing furniture.
  walker.stand(Vector3(0,0.08,-2.1))
 if outside or riding or walker.position.y< -0.4:
  walker.position=Vector3(0,0.08,-0.55);walker.velocity=Vector3.ZERO
 walker.stationary=false;riding=false;ride_platform=null
 _outside(false)
 studio.lift.position.y=0;studio.set_exit_height(Art.LOWER_Y);exterior.set_propulsion(1.0,0.0)
 if parts.is_inside_tree():parts.close()
 if dye.is_inside_tree() and dye.visible:dye.close()
 if fabricator.is_inside_tree():fabricator.close()
 fitting.selected_pieces.clear()
 profile=id;rows=store.load_home(id);undo_rows=[];has_undo=false;moving_index=-1
 flight.reset(store.berth)
 _draw_furniture()
 if not store.error.is_empty():notify(store.error)

func _appearance(descriptor:Dictionary) -> void:
 var id=str(descriptor.get("profile",""))
 if id.is_empty():_identity_lost("No active profile");return
 if id!=profile:
  parts.close()
  if editing:_edit(false)
  fitting.finish()
  _load_profile(id)
 fitting.live_descriptor=descriptor
 if fitting.active and id==profile and not fitting.returning:
  fitting.clear_garment();fitting.preview_installed=false;fitting.current=-1
  walker.install_avatar(descriptor);return
 if dye.visible:dye.close()
 fitting.finish()
 if not walker.install_avatar(descriptor):notify("Your character could not be loaded.")

func _identity_lost(reason:String) -> void:
 parts.close()
 if dye.visible:dye.close()
 fabricator.close()
 fitting.finish()
 fitting.live_descriptor={}
 walker.anonymous()
 if not profile.is_empty():
  if editing:_edit(false)
  _load_profile("");_pause(true)
 notify("Guest home · "+reason)

func _ui() -> void:
 var layer=CanvasLayer.new();add_child(layer)
 lift_shutter.color=Color("101c22");lift_shutter.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(lift_shutter);lift_shutter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);lift_shutter.hide()
 var overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(overlay)
 status=Label.new();status.hide();status.position=Vector2(24,20);status.add_theme_constant_override("outline_size",4);status.add_theme_color_override("font_outline_color",Color("#13292c"));status.add_theme_font_size_override("font_size",18);overlay.add_child(status)
 dot.hide();dot.text="·";dot.add_theme_font_size_override("font_size",28);dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER);overlay.add_child(dot)
 menu=PanelContainer.new();menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER);menu.offset_left=-240;menu.offset_right=240;menu.offset_top=-200;menu.offset_bottom=200;overlay.add_child(menu)
 var style=StyleBoxFlat.new();style.bg_color=Color("203e42");style.set_corner_radius_all(20);style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=24;style.content_margin_bottom=24;menu.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);menu.add_child(column)
 var heading=Label.new();heading.text="Your ship";heading.add_theme_font_size_override("font_size",28);column.add_child(heading)
 for entry in [["Return",func():_pause(false)],["Decorate",func():_pause(false);_edit(true)],["Undo last arrangement",func():_undo()],["Remove selected furniture",func():_remove()],["Save and exit",func():_quit()]]:
  var b=Button.new();b.text=entry[0];b.custom_minimum_size.y=44;b.pressed.connect(entry[1]);column.add_child(b)
 helm_help.add_theme_font_size_override("font_size",17);column.add_child(helm_help);helm_help.hide()
 menu.visible=false
 layer.add_child(cards);layer.add_child(dye);layer.add_child(parts)
 layer.add_child(fabricator);fabricator.dismissed.connect(_close_fabricator)
 layer.add_child(prompts)
 prompts.used.connect(func(id:String):
  if not paused and not riding and not editing and not fitting.active and not fabricator.visible and not walker.seated and id==_station():_interact())

func _open_colours() -> void:
 if not fitting.returning:
  dye.open();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _pause(value:bool) -> void:
 if value:
  parts.close();prompts.clear_world();prompts.actions([])
 if value and dye.visible:dye.close()
 if value:fabricator.close()
 cards.visible=fitting.active and not value and not dye.visible
 helm_help.visible=value and walker.seated
 if helm_help.visible:
  helm_help.text=("LS   Pitch / roll       RS   Look\nD-pad   Yaw / lift       Triggers   Strafe\nLB / RB   Throttle       X   Brake" if prompts.gamepad else "W S   Pitch       A D   Roll       Mouse   Look\nQ E   Yaw       R C   Lift       Z X   Strafe\n[ ]   Throttle       Tab   Brake")
 exterior.set_process(not value)
 paused=value;walker.walking=not value;menu.visible=value
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value or fitting.active else Input.MOUSE_MODE_CAPTURED
 if value:menu.get_child(0).get_child(1).grab_focus()

func _close_fabricator() -> void:
 get_viewport().disable_3d=false
 walker.walking=not paused
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event:InputEvent) -> void:
 if event.is_action_pressed("pause_ship"):
  _pause(not paused);get_viewport().set_input_as_handled();return
 if event.is_action_pressed("cancel_ship"):
  if paused:_pause(false)
  elif fitting.active:fitting.leave()
  elif walker.seated:_leave_pilot()
  elif editing:_edit(false)
  else:_pause(true)
  get_viewport().set_input_as_handled();return
 if paused or riding:return
 if fitting.active:
  if dye.visible or parts.visible:return
  if event.is_action_pressed("decorate"):cards.open_parts()
  elif event.is_action_pressed("pick_item"):
   _open_colours()
  elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):cards.activate()
  elif event.is_action_pressed("next_item") or event.is_action_pressed("ui_down",true):cards.move(1)
  elif event.is_action_pressed("previous_item") or event.is_action_pressed("ui_up",true):cards.move(-1)
  get_viewport().set_input_as_handled();return
 if walker.seated:
  if event.is_action_pressed("interact"):
   flight.interact();get_viewport().set_input_as_handled()
  elif event.is_action_pressed("pick_item") and flight.mode==flight.Mode.FLYING:
   flight.destination=1-flight.destination;get_viewport().set_input_as_handled()
  return
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
 if not paused:flight.coast.animate(delta)
 if fabricator.visible:
  prompts.clear_world();prompts.actions(fabricator.action_hints());status.hide();dot.hide();return
 if not paused:
  if not viewing_exterior:studio.animate(delta)
  fitting.update(delta)
 var station = _station()
 var target=STATION_TARGETS.get(station)
 if station=="lift":target=studio.lift.position+Vector3.UP*0.12
 elif station=="dock_lift":target=studio.exit_lift.position+Vector3.UP*0.18
 walker.attend(null if paused or editing or fitting.active or riding or walker.seated else target)
 message_time=max(0.0,message_time-delta)
 var exploring:bool=not (paused or editing or fitting.active or riding or walker.seated)
 if exploring and target!=null:
  var caption:String=STATION_ACTIONS[station]
  if station=="dock_lift":caption="Board ship" if outside else "Exit to "+flight.NAMES[flight.berth]
  elif station=="lift":caption="Go below" if lift_destination_is_below() else "Go upstairs"
  prompts.show_world(station,caption,walker.camera,target+Vector3.UP*0.44,walker.position+Vector3.UP*1.48)
 else:prompts.clear_world()
 dot.visible=editing and not paused
 status.text=message if message_time>0 else ""
 if editing and not paused:
  _aim()
  if status.text.is_empty():
   status.text=("Move " if moving_index>=0 else "Place ")+Art.ITEMS[item_index].replace("-"," ")+("" if placement_valid else " · Keep the walkway clear")
 if walker.seated and not paused and status.text.is_empty():status.text=flight.readout()
 status.visible=not status.text.is_empty()
 if fitting.active:cards.visible=not paused and not dye.visible and not parts.visible and not fitting.returning
 prompts.actions(_action_hints())

func _action_hints() -> Array:
 if paused or riding:return []
 if fitting.active:
  if fitting.returning:return []
  if parts.visible:return parts.action_hints()
  if dye.visible:return dye.action_hints()
  var rows:Array=[["vertical","Outfit"]]
  if not cards.action.disabled:rows.append(["interact",cards.action.text])
  if cards.parts.visible and not cards.parts.disabled:rows.append(["decorate","Change piece"])
  if cards.action.disabled or cards.action.text!="Preview colours":rows.append(["pick_item","Colours"])
  if prompts.gamepad:rows.append(["turn","Turn"])
  rows.append(["cancel_ship","Leave"]);return rows
 if walker.seated:
  if flight.mode==flight.Mode.BERTH:return [["interact","Launch"],["cancel_ship","Stand up"]]
  if flight.mode!=flight.Mode.FLYING:return []
  var commands:Array=[["tab_pair","Throttle"],["decorate","Brake"],["pick_item","Target"]]
  if flight.clearance().is_empty():commands.append(["interact","Land"])
  return commands
 if editing:
  var rows:Array=[["tab_pair","Furniture"],["rotation","Rotate"]]
  if placement_valid:rows.append(["confirm_place","Place"])
  rows.append(["pick_item","Move nearby"]);rows.append(["cancel_ship","Done"]);return rows
 return []

func lift_destination_is_below() -> bool:return studio.lift.position.y>-1

func notify(text:String) -> void:message=text;message_time=6

func _draw_furniture() -> void:
 for node in furnishings.get_children():furnishings.remove_child(node);node.queue_free()
 for i in rows.size():
  var r=rows[i];var node=art.furniture(r.item);node.position=Vector3(r.x,0,r.z);node.rotation.y=r.angle;node.set_meta("row",i);furnishings.add_child(node)

func _edit(value:bool) -> void:
 if value and (fitting.active or riding or walker.position.y < -0.4):notify("Decorate on the studio deck.");return
 if value and walker.seated:notify("Stand up to decorate your ship.");return
 if value and not store.writable:notify(store.error);return
 editing=value;moving_index=-1
 if is_instance_valid(ghost):cabin.remove_child(ghost);ghost.queue_free()
 ghost=null
 if value:prompts.clear_world();_ghost()

func _ghost() -> void:
 if is_instance_valid(ghost):cabin.remove_child(ghost);ghost.queue_free()
 ghost=art.furniture(Art.ITEMS[item_index],false);cabin.add_child(ghost)
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
  if room not in ["Passage","Cockpit"] and Art.ROOMS[room].grow(-0.2).encloses(area):in_room=true
 if not in_room:return false
 # The rectangular room tags are clipped to the real curved pressure hull.
 for corner in [area.position,area.end,Vector2(area.position.x,area.end.y),Vector2(area.end.x,area.position.y)]:
  if not Art.inside_hull(corner,0.45):return false
 # Keep the spine and both ends of the compact hatches clear.
 if area.intersects(Rect2(-0.72,-2.1,1.44,8.7)):return false
 for keep_clear in [Rect2(Art.LIFT-Vector2(1,1),Vector2(2,2)),Rect2(Art.BOOTH.x-1.0,Art.BOOTH.z-1.0,2,2),Rect2(-1.95,5.10,3.9,1.18),Rect2(-3.65,0.96,1.60,1.00)]:
  if area.intersects(keep_clear):return false
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
 if fitting.active or riding or walker.position.y < -0.4:return
 if walker.seated:notify("Stand up to move furniture.");return
 var i=moving_index if moving_index>=0 else _nearest()
 if i<0:notify("Move closer to a piece of furniture.");_pause(false);return
 var next=rows.duplicate(true);next.remove_at(i)
 if _commit(next):moving_index=-1
 _pause(false)

func _undo() -> void:
 if fitting.active or riding or walker.position.y < -0.4:return
 if walker.seated:notify("Stand up to change the arrangement.");return
 if not has_undo:notify("Nothing to undo yet.");return
 var previous=undo_rows.duplicate(true)
 if _commit(previous):has_undo=false;moving_index=-1

func _near_pilot() -> bool:
 var p=Vector2(walker.position.x,walker.position.z)
 return p.y>Walker.PILOT_ORIGIN.z+0.10 and p.distance_to(Vector2(0,Walker.PILOT_ORIGIN.z+0.80))<1.0

func _leave_pilot() -> bool:
 if not walker.seated:return true
 if flight.mode!=flight.Mode.BERTH:
  notify("Land before leaving the helm.");return false
 var previous=walker.standing_position;previous.y=max(previous.y,0.08)
 for at in [previous,Vector3(0,0.08,-2.1),Vector3(-1.5,0.08,-2.5),Vector3(1.5,0.08,-2.5)]:
  if walker.can_stand(at):walker.stand(at);return true
 notify("There is no clear space to stand up.");return false

const STATION_TARGETS = {
 "pilot": Vector3(0,0.9,-3.4), "workbench": Vector3(-2.85,0.9,1.48),
 "wardrobe": Art.BOOTH+Vector3.UP*1.3, "cabin": Vector3(0,0.88,5.67),
 "lift": Vector3(Art.LIFT.x,0.12,Art.LIFT.y)
}
const STATION_ACTIONS={"pilot":"Sit at helm","workbench":"Use fabricator","wardrobe":"Open wardrobe","lift":"Use lift","dock_lift":"Dock lift","cabin":"Inspect shelves"}

func _station() -> String:
 var p=Vector2(walker.position.x,walker.position.z)
 if flight.mode==flight.Mode.BERTH and p.distance_to(studio.EXIT_CENTER)<studio.EXIT_RADIUS+0.09 and absf(walker.position.y-studio.exit_lift.position.y)<0.3:return "dock_lift"
 if outside:return ""
 if p.distance_to(Art.LIFT)<0.89 and abs(walker.position.y-studio.lift.position.y)<0.4:return "lift"
 if walker.position.y< -0.4:return ""
 if _near_pilot():return "pilot"
 if p.distance_to(Vector2(-2.85,1.48))<1.5:return "workbench"
 if p.distance_to(Vector2(Art.BOOTH.x,Art.BOOTH.z))<1.32:return "wardrobe"
 if p.distance_to(Vector2(0,5.67))<1.56:return "cabin"
 return ""

func _physics_process(delta:float) -> void:
 if paused:return
 if walker.seated:
  var mode_before=flight.mode
  var stick:=Input.get_vector("walk_left","walk_right","walk_forward","walk_back",0.18)
  flight.tick(delta,stick,Input.get_axis("rotate_left","rotate_right"),Input.get_axis("previous_item","next_item"),Vector2(Input.get_axis("fly_left","fly_right"),Input.get_axis("fly_down","fly_up")),Input.is_action_pressed("decorate"))
  match flight.mode:
   flight.Mode.DEPARTING:exterior.set_propulsion(1.0-flight.transition,flight.transition*0.30)
   flight.Mode.LANDING:exterior.set_propulsion(flight.transition,(1.0-flight.transition)*0.30)
   flight.Mode.BERTH:exterior.set_propulsion(1.0,0.0)
   flight.Mode.FLYING:exterior.set_propulsion(0.0,flight.throttle)
  walker.steer(stick if flight.mode==flight.Mode.BERTH else flight.stick,flight.throttle)
  if mode_before==flight.Mode.LANDING and flight.mode==flight.Mode.BERTH:
   store.berth=flight.berth
   if not store.save(rows):notify(store.error)
 if outside and not riding and walker.position.y<flight.GROUND_Y-1.6:
  walker.position=studio.exit_lift.position+Vector3.UP*0.06;walker.velocity=Vector3.ZERO
  notify("Back at the boarding lift.")
 if not riding:return
 ride_time=minf(1,ride_time+delta/1.75)
 var height:=lerpf(lift_start,lift_end,smoothstep(0,1,ride_time))
 if ride_platform==studio.exit_lift:
  studio.set_exit_height(height)
  var descent:=inverse_lerp(Art.LOWER_Y,flight.GROUND_Y,height)
  if viewing_exterior!=(descent>=0.5):_set_ship_view(descent>=0.5)
  var opacity:=1.0-smoothstep(0.05,0.29,absf(descent-0.5))
  lift_shutter.modulate.a=opacity;lift_shutter.visible=opacity>0
 else:ride_platform.position.y=height
 walker.position=ride_platform.position+Vector3.UP*0.045
 if ride_time>=1:
  if ride_platform==studio.exit_lift:
   _outside(is_equal_approx(lift_end,flight.GROUND_Y))
  walker.stationary=false;riding=false;ride_platform=null

func _outside(value:bool) -> void:
 outside=value
 walker.collision_mask=(flight.WALK_LAYER|Exterior.HULL_COLLISION) if value else 3
 _set_ship_view(value);lift_shutter.hide()
 walker.reset_physics_interpolation()

func _ride(platform:AnimatableBody3D,stop:float) -> void:
 ride_platform=platform;lift_start=platform.position.y;lift_end=stop
 ride_time=0;riding=true;walker.stationary=true;walker.velocity=Vector3.ZERO;message_time=0

func _interact() -> void:
 if walker.seated:
  _leave_pilot()
  return
 prompts.clear_world()
 match _station():
  "pilot":
   if editing:_edit(false)
   walker.sit()
  "workbench":
   studio.scan=2.4;walker.walking=false;walker.attend(null);fabricator.open()
   status.hide();prompts.actions(fabricator.action_hints())
   get_viewport().disable_3d=true
   Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  "wardrobe":fitting.enter()
  "cabin":notify("Display shelves · Figurines and awards")
  "lift":
   _ride(studio.lift,Art.LOWER_Y if lift_destination_is_below() else 0.0)
  "dock_lift":
   _ride(studio.exit_lift,Art.LOWER_Y if outside else flight.GROUND_Y)


func _quit() -> void:
 if store.writable and not store.save(rows):notify(store.error);return
 get_tree().quit()

func _notification(what:int) -> void:
 if what==NOTIFICATION_WM_CLOSE_REQUEST:_quit()
 elif what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(walker):
  # No input or simulation continues behind another application.
  _pause(true);Engine.max_fps=10
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:Engine.max_fps=60
