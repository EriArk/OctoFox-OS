# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures: Array[String]=[]
func check(value:bool, why:String) -> void:
 if not value:failures.append(why);push_error(why)
func _initialize() -> void:run.call_deferred()
func press(button:int) -> void:
 for down in [true,false]:
  var event:=InputEventJoypadButton.new()
  event.button_index=button;event.pressed=down;root.push_input(event,true)
func run() -> void:
 var home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.appearance_changed.disconnect(home._appearance)
 home.avatar_client.unavailable.disconnect(home._identity_lost)
 home.avatar_client.queue_free();home._pause(false)
 var desc:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not desc.is_empty():
  check(home.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(desc))),"SDK avatar loads")
 home.walker.position=Vector3(-2.55,0.1,2.45)
 press(JOY_BUTTON_A)
 var fab=home.fabricator
 check(home.studio.scan>0 and fab.visible and root.disable_3d and not home.walker.walking,"Station opens blueprint console")
 check(fab.heading.text=="Trail cloak" and fab.amounts[0].text=="— / 6","Inspect part without inventing a balance")
 for set_index in 3:
  if set_index>0:press(JOY_BUTTON_DPAD_DOWN)
  check(fab.blueprint==set_index,"Select a set with D-pad")
  press(JOY_BUTTON_A)
  for i in 4:
   if i>0:press(JOY_BUTTON_DPAD_RIGHT)
   check(fab.part==i and fab.heading.text==fab.Garment.NAMES[fab.Garment.STYLES[set_index]][i],"Inspect all four part recipes")
   check(fab.print_button.disabled,"Preview cannot authorize printing")
 press(JOY_BUTTON_RIGHT_SHOULDER)
 check(fab.page==1 and fab.heading.text=="Cotton","Open cartridge inventory")
 for i in 3:press(JOY_BUTTON_DPAD_DOWN)
 check(fab.heading.text=="Steel" and fab.rows[0].text=="Traveller","Inspect cartridge usage")
 press(JOY_BUTTON_LEFT_SHOULDER)
 check(fab.blueprint==2 and fab.part==3,"Returning from materials keeps the selected part")
 var motion:=InputEventJoypadMotion.new()
 motion.axis=JOY_AXIS_LEFT_X;motion.axis_value=0.9;root.push_input(motion,true)
 check(fab.part==0,"Stick wraps to the first piece")
 motion.axis_value=0.8;root.push_input(motion,true)
 check(fab.part==0,"Holding the stick does not skip multiple pieces")
 # Pointer and touch-emulated clicks follow the same Button route.
 for down in [true,false]:
  var click:=InputEventMouseButton.new()
  click.position=fab.parts[2].get_global_rect().get_center()
  click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
  root.push_input(click,true)
 check(fab.part==2,"Pointer selects a single piece")
 press(JOY_BUTTON_B);check(not fab.visible and not root.disable_3d and home.walker.walking and not home.paused,"Back restores ship input")
 press(JOY_BUTTON_A);press(JOY_BUTTON_START)
 check(home.paused and not fab.visible and not home.walker.walking,"Pause takes precedence over the fabricator")
 home._pause(false)
 home.walker.position=ShipInterior.BOOTH+Vector3(-0.65,0.08,-0.65)
 var approach:Vector3=home.walker.position
 var original_meshes=home.walker.visual.find_children("*","MeshInstance3D",true,false).filter(func(m):return m.visible)
 press(JOY_BUTTON_A);check(home.fitting.active and home.fitting.camera.current,"Enter fitting camera")
 for style in [1,2,3]:
  press(JOY_BUTTON_RIGHT_SHOULDER)
  var saw_closed:=false
  for i in 110:
   await physics_frame
   if home.fitting.closure>0.99:saw_closed=true
   if home.fitting.current==style:check(saw_closed,"Screen closes before garment changes")
  check(home.fitting.current==style and home.fitting.closure==0 and is_instance_valid(home.fitting.garment),"Full costume revealed")
 press(JOY_BUTTON_B)
 for i in 100:await physics_frame
 check(not home.fitting.active and home.walker.camera.current,"Restore exploration camera")
 check(home.walker.position.distance_to(approach)<0.14,"Return to booth entrance")
 for part in original_meshes:check(part.visible,"Original clothing restored")
 # Rapid selection and an appearance change must not strand the curtain or the camera.
 press(JOY_BUTTON_A);press(JOY_BUTTON_RIGHT_SHOULDER)
 for i in 29:await physics_frame
 press(JOY_BUTTON_RIGHT_SHOULDER)
 for i in 110:await physics_frame
 check(home.fitting.current==2 and home.fitting.closure==0,"Fast outfit changes finish")
 home._identity_lost("test");check(not home.fitting.active and not home.walker.stationary,"Identity change exits fitting")
 home._pause(false)
 var center:=ShipInterior.LIFT
 home.walker.position=Vector3(center.x,0.08,center.y)
 for i in 5:await physics_frame
 press(JOY_BUTTON_A)
 for i in 24:await physics_frame
 var midway:float=home.walker.position.y
 press(JOY_BUTTON_START)
 for i in 10:await physics_frame
 check(is_equal_approx(midway,home.walker.position.y),"Pause holds lift and rider together")
 press(JOY_BUTTON_START)
 for i in 120:await physics_frame
 check(absf(home.walker.position.y-ShipInterior.LOWER_Y)<0.12 and not home.riding,"Lift arrives below")
 home.walker.yaw=0
 Input.action_press("walk_forward")
 for i in 30:await physics_frame
 Input.action_release("walk_forward")
 for i in 8:await physics_frame
 check(home.walker.is_on_floor() and home._station().is_empty() and home.walker.position.z<center.y-1,"Walk on lower floor")
 Input.action_press("walk_back")
 for i in 35:await physics_frame
 Input.action_release("walk_back")
 check(home._station()=="lift","Return to lower lift on foot")
 press(JOY_BUTTON_A)
 for i in 125:await physics_frame
 check(absf(home.walker.position.y)<0.1 and not home.riding and not home.walker.stationary,"Return to studio")
 print("STUDIO ", "PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
