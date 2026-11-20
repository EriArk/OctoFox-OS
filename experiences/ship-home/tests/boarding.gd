# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var home
var errors:Array[String]=[]
func check(ok:bool,why:String) -> void:
 if not ok:errors.append(why);push_error(why)
func frames(n:int) -> void:
 for i in n:await physics_frame
func press(button:int) -> void:
 for down in [true,false]:
  var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=down
  root.push_input(event,true)
func xy() -> Vector2:return Vector2(home.walker.position.x,home.walker.position.z)
func walk_to(place:Vector2) -> void:
 var keys=["walk_left","walk_right","walk_forward","walk_back"]
 for i in 480:
  var gap:=place-xy()
  if gap.length()<0.085:break
  var step:=gap.normalized()
  for k in 4:
   var strength:float=[-step.x,step.x,-step.y,step.y][k]
   if strength>0:Input.action_press(keys[k],strength)
   else:Input.action_release(keys[k])
  await physics_frame
 for k in keys:Input.action_release(k)
 await frames(12)
 check(xy().distance_to(place)<0.40,"Walk to "+str(place)+"; reached "+str(home.walker.position))
func capture(label:String) -> void:
 var dir:=OS.get_environment("SHIP_CAPTURE_DIR")
 if dir.is_empty():return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(dir+"/"+label+".png")==OK,"Save screenshot")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.disconnect_host()
 home.store.directory="user://boarding-"+str(Time.get_ticks_usec());home._load_profile("test");home._pause(false)
 if not OS.get_environment("SHIP_TEST_DESCRIPTOR").is_empty():
  home.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SHIP_TEST_DESCRIPTOR"))))
 var w=home.walker;var f=home.flight
 for site in 2:
  f.reset(site);home.message_time=0
  w.position=Vector3(ShipInterior.LIFT.x,0.09,ShipInterior.LIFT.y);w.yaw=0
  await frames(8);press(JOY_BUTTON_A);await frames(120)
  check(home._station()=="lift" and not home.outside,"Original lift still serves the service deck")
  if site==0 and not OS.get_environment("SHIP_CAPTURE_DIR").is_empty():
   w.yaw=-0.68;w.pitch=-0.24;await frames(12);await capture("two-lifts");w.yaw=0
  await walk_to(home.studio.EXIT_CENTER)
  check(home._station()=="dock_lift","Separate physical exit lift")
  if site==0:await capture("service-lift")
  press(JOY_BUTTON_A);await frames(25)
  press(JOY_BUTTON_START);var height:float=home.studio.exit_lift.position.y;await frames(8)
  check(home.riding and home.studio.exit_lift.position.y==height,"Pause during disembarkation")
  press(JOY_BUTTON_START);await frames(120)
  check(home.outside and w.is_on_floor() and absf(w.position.y-f.GROUND_Y)<0.12,"Lands on "+f.NAMES[site])
  check(home._station()=="dock_lift" and not home.riding,"Exterior reboarding prompt")
  var away:=Vector2(9.75,2) if site==0 else Vector2(-10.5,0)
  await walk_to(away)
  check(w.is_on_floor() and absf(w.position.y-f.GROUND_Y)<0.12 and home._station()=="","Walk beyond landing circle at "+f.NAMES[site])
  w.yaw=PI*0.5 if site==0 else -PI*0.5;w.pitch=0.19
  Input.action_press("walk_forward");await frames(8);Input.action_release("walk_forward")
  await frames(20);await capture("station" if site==0 else "orchard")
  w.yaw=0;w.pitch=-0.18
  await walk_to(home.studio.EXIT_CENTER)
  press(JOY_BUTTON_A);await frames(120)
  check(not home.outside and home._station()=="dock_lift" and absf(w.position.y-ShipInterior.LOWER_Y)<0.12,"Reboard service room")
  await walk_to(ShipInterior.LIFT);press(JOY_BUTTON_A);await frames(120)
  check(absf(w.position.y)<0.12 and home._station()=="lift","Return to cabin")
 w.position=home.studio.exit_lift.position+Vector3.UP*0.05
 for mode in [f.Mode.FLYING,f.Mode.DEPARTING,f.Mode.LANDING]:
  f.mode=mode;press(JOY_BUTTON_A);check(not home.riding and home._station()=="","Exterior interlock")
 f.reset(0);press(JOY_BUTTON_A);await frames(30);home._load_profile("other");await frames(8)
 check(not home.riding and not home.outside and not w.stationary and absf(w.position.y)<0.15,"Profile switch interrupts ride and restores cabin")
 print("SHIP BOARDING: ","PASSED" if errors.is_empty() else errors);quit(0 if errors.is_empty() else 1)
