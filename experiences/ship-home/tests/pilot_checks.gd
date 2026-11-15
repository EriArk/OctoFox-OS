# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:Array[String]=[]
func check(value:bool,message:String) -> void:
 if not value:failures.append(message);push_error(message)
func key(action:String) -> void:
 var codes={"interact":KEY_F,"pause_ship":KEY_P,"cancel_ship":KEY_ESCAPE,"decorate":KEY_TAB}
 for pressed in [true,false]:
  var event=InputEventKey.new();event.physical_keycode=codes[action];event.pressed=pressed
  root.push_input(event,true)
func pad(button:int) -> void:
 for pressed in [true,false]:
  var event=InputEventJoypadButton.new();event.button_index=button;event.pressed=pressed
  root.push_input(event,true)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var home=load("res://main.tscn").instantiate();root.add_child(home)
 # These checks own synthetic profiles; a live handheld host must not replace them.
 home.avatar_client.appearance_changed.disconnect(home._appearance)
 home.avatar_client.unavailable.disconnect(home._identity_lost)
 home.avatar_client.queue_free()
 home.store.directory="user://pilot-checks-"+str(Time.get_ticks_usec());home._load_profile("pilot")
 home._pause(false)
 for i in 5:await physics_frame
 home.walker.position=Vector3(0,0.08,0);key("interact");await process_frame
 check(not home.walker.seated,"Cannot sit from across the room")
 home.walker.position=Vector3(0,0.08,-2.4);home.walker.velocity=Vector3.ZERO;key("interact")
 for i in 3:await physics_frame
 check(home.walker.seated,"Interact enters pilot seat")
 check(home.walker.pilot_camera.current and not home.walker.camera.current,"Seating selects first-person camera")
 check(home.walker.pilot_camera.global_position.distance_to(ShipWalker.PILOT_ORIGIN+ShipWalker.PILOT_EYE)<0.01,"View starts at pilot eye")
 check(not home.walker.visual.visible,"First person does not show inside avatar head")
 var fixed=home.walker.position;Input.action_press("walk_forward");Input.action_press("look_right")
 for i in 25:await physics_frame
 Input.action_release("walk_forward");Input.action_release("look_right")
 check(home.walker.position.distance_to(fixed)<0.001,"Walking input cannot move seated pilot")
 check(home.walker.yaw< -0.2,"Right stick looks around while seated")
 # Dummy/headless display cannot capture a mouse. pilot_tour verifies the real
 # captured-pointer route under Xvfb instead of manufacturing a headless result.
 home.walker.yaw=5;home.walker.pitch=5;await physics_frame;await physics_frame
 check(home.walker.yaw<=1.4 and home.walker.pitch<=0.45,"Seated look stays within head-turn limits")
 key("pause_ship");var paused_yaw=home.walker.yaw;Input.action_press("look_left")
 for i in 10:await physics_frame
 Input.action_release("look_left")
 check(home.paused and home.walker.seated and home.walker.yaw==paused_yaw,"Pause keeps seat and freezes input")
 key("cancel_ship");check(not home.paused and home.walker.seated,"Back from menu resumes seated view")
 key("decorate");home._edit(true);check(not home.editing,"Seated pilot cannot decorate")
 key("cancel_ship")
 for i in 3:await physics_frame
 check(not home.walker.seated and home.walker.camera.current,"Back exits to third person")
 check(home.walker.can_stand(home.walker.position+Vector3(0,0.08,0)),"Exit has a clear collision volume")
 pad(JOY_BUTTON_A);await physics_frame
 check(home.walker.seated,"Controller A enters seat")
 pad(JOY_BUTTON_B);await physics_frame
 check(not home.walker.seated,"Controller B leaves seat")
 pad(JOY_BUTTON_A);await physics_frame
 var barriers=[]
 for pos in [Vector3(0,0.65,-2.3),Vector3(-1.5,0.65,-2.5),Vector3(1.5,0.65,-2.5)]:
  var blocker=home.art.box(home,pos,Vector3(1.0,1.3,1.1),ShipInterior.TRIM,true);barriers.append(blocker)
 for i in 3:await physics_frame
 check(not home._leave_pilot() and home.walker.seated,"Blocked exit does not teleport through furniture")
 for blocker in barriers:blocker.queue_free()
 for i in 3:await physics_frame
 check(home._leave_pilot(),"Exit succeeds when a safe space is available")
 home.walker.position=Vector3(0,0.08,-2.4);key("interact");await physics_frame
 home._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(home.walker.seated and home.paused and Engine.max_fps==10,"Focus loss pauses seated controls and reduces rendering")
 home._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);home._pause(false)
 home._identity_lost("test disconnect")
 check(not home.walker.seated and home.walker.camera.current and home.paused and home.profile.is_empty(),"Identity loss returns to paused guest deck")
 home.queue_free();await process_frame
 print("SHIP PILOT CHECKS: ","PASSED" if failures.is_empty() else str(failures));quit(0 if failures.is_empty() else 1)
