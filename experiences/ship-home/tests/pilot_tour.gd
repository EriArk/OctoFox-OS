# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var home
var out:String
func _initialize() -> void:call_deferred("run")
func capture(name:String) -> void:
 await create_timer(0.65).timeout;await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 var appearance:Dictionary={}
 var descriptor=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():
  appearance=JSON.parse_string(FileAccess.get_file_as_string(descriptor));appearance["profile"]="ship-capture";home._appearance(appearance)
 out=OS.get_environment("SHIP_CAPTURE_DIR")
 if out.is_empty():out="/tmp/ship-pilot"
 DirAccess.make_dir_recursive_absolute(out)
 await create_timer(1).timeout;home._pause(false)
 if not appearance.is_empty():
  assert(is_instance_valid(home.walker.motion) and home.walker.motion.ready_to_animate)
  home.walker.position=Vector3(0,0.08,3.8);home.walker.yaw=0
  Input.action_press("walk_forward")
  for i in 30:await physics_frame
  assert(home.walker.motion.current=="Walk")
  Input.action_press("walk_run")
  for i in 20:await physics_frame
  assert(home.walker.motion.current=="Jog_Fwd")
  Input.action_release("walk_run");Input.action_release("walk_forward")
  for i in 35:await physics_frame
  assert(home.walker.motion.current=="Idle")
 home.walker.position=Vector3(0,0.08,-2.4);home.walker.yaw=0;home.walker.pitch=-0.10
 home.message_time=0;await capture("approach")
 var event=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;root.push_input(event,true)
 event=InputEventKey.new();event.physical_keycode=KEY_F;root.push_input(event,true)
 assert(home.walker.seated);home.message_time=0
 assert(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
 var motion=InputEventMouseMotion.new();motion.relative=Vector2(20,-10)
 var previous_yaw=home.walker.yaw;root.push_input(motion,true);await process_frame
 assert(home.walker.yaw<previous_yaw)
 home.walker.yaw=0;home.walker.pitch=-0.07
 await capture("pilot-forward")
 if not appearance.is_empty():
  home._appearance(appearance)
  assert(home.walker.seated and home.walker.pilot_camera.current and not home.walker.visual.visible)
  assert(is_instance_valid(home.walker.skeleton))
  var thigh=home.walker.joints["thigh.L"]
  assert(home.walker.skeleton.get_bone_pose_rotation(thigh[0]).angle_to(thigh[1])>1.0)
 home.walker.yaw=0.85;home.walker.pitch=-0.15;await capture("pilot-left")
 home.walker.yaw=-0.85;home.walker.pitch=-0.15;await capture("pilot-right")
 assert(home._leave_pilot());home.message_time=0;await capture("back-on-deck")
 print("SHIP PILOT TOUR PASSED");quit()
