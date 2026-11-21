# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var home
var errors:Array[String]=[]
var out:=OS.get_environment("HELM_SHOTS")
func check(ok:bool,why:String) -> void:
 if not ok:errors.append(why);push_error(why)
func key(code:int,down:bool) -> void:
 var e:=InputEventJoypadButton.new();e.button_index=code;e.pressed=down;root.push_input(e,true)
func press(code:int) -> void:key(code,true);key(code,false)
func panel(dir:int) -> void:
 key(JOY_BUTTON_Y,true);press(dir);key(JOY_BUTTON_Y,false)
func choose(n:int) -> void:
 for i in n:press(JOY_BUTTON_DPAD_DOWN)
 press(JOY_BUTTON_A)
func frames(n:int) -> void:
 for i in n:await physics_frame
func shot(label:String) -> void:
 if out.is_empty():return
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+label+".png")
 await physics_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.appearance_changed.disconnect(home._appearance);home.avatar_client.unavailable.disconnect(home._identity_lost)
 home.avatar_client.disconnect_host();home.store.directory="user://helm-"+str(Time.get_ticks_usec());home._load_profile("pilot")
 home.message_time=0
 var f=home.flight;var a=f.avionics;var hud=home.instruments
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():home.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor)))
 home._pause(false);home.walker.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_A);await frames(4)
 panel(JOY_BUTTON_DPAD_DOWN);check(hud.page=="Power","Y + down opens distributor")
 choose(1);check(a.pips==[2,3,1],"Conserve six pips while diverting to engines")
 await shot("power")
 panel(JOY_BUTTON_DPAD_LEFT);choose(2);choose(0)
 check(a.target==3 and a.reply.contains("Passing"),"Track and hail an orbiting courier")
 await shot("contacts")
 press(JOY_BUTTON_RIGHT_STICK);await frames(20);check(hud.page=="Scope","Lean to the physical scanner")
 await shot("scope");press(JOY_BUTTON_B)
 panel(JOY_BUTTON_DPAD_UP);choose(0);check(a.route==1,"Chart plots next sector")
 await shot("chart")
 choose(2);check(hud.page=="Local","Local chart shows contact orbits")
 await shot("local")
 press(JOY_BUTTON_B)
 press(JOY_BUTTON_B);press(JOY_BUTTON_A);await frames(100)
 check(f.mode==f.Mode.FLYING,"Launch from station")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(1);check(a.deployed,"Extend hull emitters")
 await frames(54)
 check(home.exterior.hardpoint_travel>0.98 and home.exterior.emitters.visible,"Twin pods extend on the actual hull")
 if not out.is_empty():
  var camera:=Camera3D.new();home.add_child(camera);home.Exterior.configure_camera(camera,false)
  camera.position=Vector3(10,3,-13);camera.look_at(Vector3(0,-0.2,-0.5));camera.fov=53;camera.current=true
  await shot("hull");home.walker.pilot_camera.current=true;camera.queue_free()
 panel(JOY_BUTTON_DPAD_RIGHT);choose(2);check(not a.cruise,"Cruise rejects extended pods")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(1);panel(JOY_BUTTON_DPAD_RIGHT);choose(2)
 check(a.cruise,"Engage cruise after stowing")
 press(JOY_BUTTON_B)
 Input.action_press("next_item");await frames(90);Input.action_release("next_item")
 await frames(34);check(f.velocity.length()>65 and a.fuel<100,"Cruise gains speed and burns fuel")
 panel(JOY_BUTTON_DPAD_UP);choose(1);check(a.charge>0,"Charge outside mass shadow")
 await shot("charge")
 var before:float=a.fuel
 press(JOY_BUTTON_B);await frames(220);check(a.transit>0,"Enter shift corridor")
 await shot("jump")
 await frames(102)
 check(a.sector==1 and a.route==-1 and absf(before-a.fuel-22)<0.001,"Arrive in Prism; exact single jump debit")
 await shot("arrival")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(1)
 panel(JOY_BUTTON_DPAD_LEFT);choose(1);choose(0)
 check(a.target==5 and a.lock_id==5,"Independent hostile lock")
 choose(1);check(a.npc_shield==75 and a.weapon<82,"Locked pulse drains capacitor and patrol shield")
 await shot("lock")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(1)
 panel(JOY_BUTTON_DPAD_LEFT);choose(0);choose(0)
 check(a.permit==2 and a.target==2,"Prism control assigns pad 01")
 await shot("clearance");press(JOY_BUTTON_B);press(JOY_BUTTON_B)
 Input.action_press("next_item");await frames(84);Input.action_release("next_item")
 for i in 2100:
  if a.range_to(2)<18:break
  await physics_frame
 Input.action_press("decorate");await frames(110);Input.action_release("decorate")
 check(f.clearance()=="","Reach assigned pad, level and slow")
 press(JOY_BUTTON_A);await frames(110)
 check(f.berth==2 and f.mode==f.Mode.BERTH,"Land at Prism")
 home._load_profile("pilot");check(f.berth==2 and a.sector==1 and a.pips==[2,3,1] and a.fuel<79,"Reload dock, systems and fuel")
 home.walker.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_A)
 panel(JOY_BUTTON_DPAD_RIGHT);choose(4);check(a.fuel==100,"Station refuels")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(0);choose(2);check(not a.enabled[2] and a.contacts()==[2],"Sensor power changes contact list")
 await shot("modules")
 if not out.is_empty():
  await frames(24)
  var glass:MeshInstance3D=hud.surfaces[1]
  var pixel:Vector2=hud.buttons[2].get_center()/Vector2(hud.PIXELS)
  var point:=glass.to_global(Vector3((pixel.x-0.5)*hud.PANEL_SIZE.x,(0.5-pixel.y)*hud.PANEL_SIZE.y,0))
  var tap:=InputEventScreenTouch.new();tap.position=home.walker.pilot_camera.unproject_position(point);tap.pressed=true
  root.push_input(tap,true);tap.pressed=false;root.push_input(tap,true)
  check(a.enabled[2],"Touch the actual glass to restore sensors")
 press(JOY_BUTTON_B);press(JOY_BUTTON_B);press(JOY_BUTTON_A);await frames(100)
 Input.action_press("next_item");await frames(310);Input.action_release("next_item")
 Input.action_press("decorate");await frames(110);Input.action_release("decorate")
 panel(JOY_BUTTON_DPAD_UP);choose(0);choose(1)
 check(a.charge==0 and a.reply.contains("Align"),"Return vector must be lined up")
 press(JOY_BUTTON_B)
 Input.action_press("rotate_right");await frames(221);Input.action_release("rotate_right");await frames(24)
 panel(JOY_BUTTON_DPAD_UP);choose(1)
 check(a.charge>0,"Align for return under yaw control")
 press(JOY_BUTTON_B);await frames(316)
 check(a.sector==0 and absf(a.fuel-78)<0.01 and a.permit==-1,"Return jump consumes fuel and clears clearance")
 home._load_profile("other");check(f.berth==0 and a.fuel==100 and a.enabled[2] and a.pips==[2,2,2],"Profile isolation")
 print("AVIONICS CIRCUIT: ","PASSED" if errors.is_empty() else errors);quit(0 if errors.is_empty() else 1)
