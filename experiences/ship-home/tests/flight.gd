# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:Array[String]=[]
var home
func check(ok:bool,reason:String) -> void:
 if not ok:failures.append(reason);push_error(reason)

func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)

func frames(n:int) -> void:
 for i in n:await physics_frame

func _initialize() -> void:run.call_deferred()

func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.disconnect_host();home.store.directory="user://flight-"+str(Time.get_ticks_usec());home._load_profile("test")
 var w=home.walker;var f=home.flight
 var desc:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not desc.is_empty():check(w.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(desc))),"Bind SDK pilot")
 home._pause(false);w.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_A)
 check(w.seated and f.mode==f.Mode.BERTH,"Board at station")
 if is_instance_valid(w.skeleton):
  var rig:Skeleton3D=w.skeleton
  for axes in [Vector2.ZERO,Vector2(1,-1),Vector2(-1,1)]:
   for power in [-0.32,1.0]:
    w.steer(axes,power)
    for side in ["L","R"]:
     var wrist:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand."+side)).origin)
     var knuckle:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("middle.01."+side)).origin)
     var grip:Vector3=home.art.left_grip.global_position if side=="L" else home.art.right_grip.global_position
     check(wrist.lerp(knuckle,0.76).distance_to(grip)<0.016,"Palm contact throughout stick travel: "+side)
    var hip:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin)
    check(hip.distance_to(home.art.helm_root.to_global(Vector3(0,0.615,0.38)))<0.001,"Hips stay on the seat")
 for leg in 2:
  press(JOY_BUTTON_A);await frames(100)
  check(f.mode==f.Mode.FLYING and not home._leave_pilot(),"Clear the berth with seated pilot")
  check(home.exterior.hover_amount==0,"Hover field shortens after departure")
  press(JOY_BUTTON_START);var stopped:Vector3=f.location;var field_phase:float=home.exterior.cycle
  Input.action_press("next_item");await frames(12);Input.action_release("next_item")
  check(f.location==stopped and f.throttle==0,"Pause freezes throttle and travel")
  check(home.exterior.cycle==field_phase,"Suspended ring animation while paused")
  press(JOY_BUTTON_B)
  # Fly toward the other berth using exactly the normal throttle and brake actions.
  Input.action_press("next_item");await frames(85);Input.action_release("next_item")
  check(home.exterior.drive_power>0.9,"Aft exhaust responds to forward throttle")
  for i in 360:
   if f.location.distance_to(f.BERTHS[f.destination])<18:break
   await physics_frame
  check(not f.clearance().is_empty(),"A fast approach cannot start docking")
  press(JOY_BUTTON_A);check(f.mode==f.Mode.FLYING,"Reject fast docking")
  Input.action_press("decorate");await frames(100);Input.action_release("decorate")
  check(f.clearance().is_empty(),"Stopped level over destination: "+str(f.location))
  press(JOY_BUTTON_A);await frames(100)
  check(f.mode==f.Mode.BERTH and f.berth==(1-leg),"Arrive and settle at destination")
  check(home.exterior.hover_amount==1 and home.exterior.drive_power==0,"Landing restores full hover and idle exhaust")
  var store:=ShipLayoutStore.new();store.directory=home.store.directory;store.load_home("test")
  check(store.berth==f.berth,"Restore most recently landed berth")
 press(JOY_BUTTON_B);check(not w.seated and w.camera.current,"Leave chair after arrival")
 f.interact();f.tick(2,Vector2.ZERO,0,0,Vector2.ZERO,false)
 for i in 20:f.tick(1.0/60,Vector2(0.7,0.4),0.6,0,Vector2(1,0.8),false)
 check(not f.attitude.is_equal_approx(Basis.IDENTITY) and f.velocity.length()>0.5,"Attitude and translations respond")
 f.reset(0);f.interact();f.tick(2,Vector2.ZERO,0,0,Vector2.ZERO,false)
 for i in 200:f.tick(1.0/60,Vector2.ZERO,0,0,Vector2.DOWN,false)
 check(f.location.y>=f.GROUND_Y+2.7-0.001,"Hull cannot pass through landing platform")
 print("SHIP FLIGHT: ","PASSED" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
