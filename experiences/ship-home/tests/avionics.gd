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
 key(JOY_BUTTON_X,true);press(dir);key(JOY_BUTTON_X,false)
func choose(n:int) -> void:
 for i in n:press(JOY_BUTTON_DPAD_DOWN)
 press(JOY_BUTTON_B)
func frames(n:int) -> void:
 for i in n:await physics_frame
func shot(label:String) -> void:
 if out.is_empty():return
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+label+".png")
 await physics_frame
func touch(world_point:Vector3) -> void:
 var tap:=InputEventScreenTouch.new()
 tap.position=home.walker.pilot_camera.unproject_position(world_point)
 tap.pressed=true;root.push_input(tap,true)
 tap.pressed=false;root.push_input(tap,true)

func chart_tap(px:Vector2) -> void:
 var chart=home.instruments.chart
 var tap:=InputEventScreenTouch.new();tap.position=chart.ui_offset()+px*chart.ui_scale()
 tap.pressed=true;root.push_input(tap,true);tap.pressed=false;root.push_input(tap,true)

func chart_finger(index:int,point:Vector2,pressed:bool) -> void:
 var chart=home.instruments.chart
 var tap:=InputEventScreenTouch.new();tap.index=index;tap.position=chart.ui_offset()+point*chart.ui_scale()
 tap.pressed=pressed;root.push_input(tap,true)

func chart_drag(index:int,point:Vector2) -> void:
 var chart=home.instruments.chart
 var drag:=InputEventScreenDrag.new();drag.index=index;drag.position=chart.ui_offset()+point*chart.ui_scale()
 root.push_input(drag,true)

func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.appearance_changed.disconnect(home._appearance);home.avatar_client.unavailable.disconnect(home._identity_lost)
 home.avatar_client.disconnect_host();home.store.directory="user://helm-"+str(Time.get_ticks_usec());home._load_profile("pilot")
 home.message_time=0
 var f=home.flight;var a=f.avionics;var hud=home.instruments
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():home.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor)))
 # Let the window manager finish its startup focus transition before driving the bridge.
 if not out.is_empty():await frames(52)
 home._pause(false);home.walker.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_B);await frames(4)
 check(hud.extensions==[0.0,0.0] and not hud.surfaces[0].is_visible_in_tree() and not hud.surfaces[1].is_visible_in_tree(),"Both drawers are housed when seated")
 check(not hud.canopy.visible,"Parked ship keeps the canopy clear")
 await shot("moored")
 if not out.is_empty():
  for side in 2:
   var key_at:Vector3=home.art.helm_keys[side].global_position
   check(root.get_visible_rect().has_point(home.walker.pilot_camera.unproject_position(key_at)),"Stowed-panel key reachable in forward view")
   touch(key_at)
   check(hud.page==("Contacts" if side==0 else "Power"),"Touch the navigation and system release keys")
   await frames(32)
   if side==1:
    var row_y:float=hud.buttons[1].get_center().y
    for x in [545,345]:
     var point:=Vector2(x,row_y)/Vector2(hud.PIXELS)-Vector2.ONE*0.5
     touch(hud.surfaces[1].to_global(Vector3(point.x*hud.PANEL_SIZE.x,-point.y*hud.PANEL_SIZE.y,0)))
     check(a.pips==([2,3,1] if x==545 else [2,2,2]),"One unit per tap on a power control")
   touch(hud.surfaces[side].to_global(Vector3(0.25,0.158,0)))
   check(hud.page=="","Stow key returns to flight")
   await frames(32)
 panel(JOY_BUTTON_DPAD_RIGHT);choose(0);press(JOY_BUTTON_X)
 check(hud.page=="","One Y tap stows a nested instrument page")
 panel(JOY_BUTTON_DPAD_DOWN);check(hud.page=="Power","Y + down opens distributor")
 press(JOY_BUTTON_DPAD_DOWN)
 for i in 3:press(JOY_BUTTON_DPAD_LEFT)
 check(a.pips==[3,0,3],"An empty bus cannot release another unit")
 for i in 2:press(JOY_BUTTON_DPAD_RIGHT)
 check(a.pips==[2,2,2],"Adding units takes them from the most supplied bus")
 for i in 3:press(JOY_BUTTON_DPAD_RIGHT)
 check(a.pips[1]==4 and a.pips[0]+a.pips[1]+a.pips[2]==6,"Cannot exceed four units on a bus")
 press(JOY_BUTTON_DPAD_LEFT);check(a.pips==[1,3,2] or a.pips==[2,3,1],"Left releases a unit to another bus")
 press(JOY_BUTTON_DPAD_LEFT);check(a.pips==[2,2,2],"Released units return to the least supplied bus")
 press(JOY_BUTTON_B);check(a.pips==[2,3,1],"Conserve six pips while diverting to engines")
 await frames(27)
 check(hud.extensions==[0.0,1.0],"Only the selected drawer is raised")
 await shot("power")
 panel(JOY_BUTTON_DPAD_LEFT);choose(2);choose(0)
 check(a.target==3 and a.reply.contains("Passing"),"Track and hail an orbiting courier")
 await frames(33)
 check(hud.extensions==[1.0,0.0],"Changing sides stows the previous drawer")
 await shot("contacts")
 press(JOY_BUTTON_RIGHT_STICK);await frames(20);check(hud.page=="Scope","Lean to the physical scanner")
 await shot("scope");press(JOY_BUTTON_A)
 panel(JOY_BUTTON_DPAD_UP);choose(0);check(a.route==1,"Chart plots next sector")
 check(hud.chart.camera.current and hud.chart.size==root.get_visible_rect().size,"Atlas takes over the full viewport")
 await shot("chart")
 var initial:Transform3D=hud.chart.camera.transform
 Input.action_press("look_right");Input.action_press("fly_thrust");await frames(25)
 Input.action_release("look_right");Input.action_release("fly_thrust")
 check(not initial.basis.is_equal_approx(hud.chart.camera.basis) and hud.chart.distance<110,"Orbit and zoom move the atlas camera")
 await shot("rotated")
 if not out.is_empty():
  var previous_yaw:float=hud.chart.yaw
  var previous_zoom:float=hud.chart.goal
  chart_finger(0,Vector2(330,280),true);chart_drag(0,Vector2(355,300))
  chart_finger(1,Vector2(430,300),true);chart_drag(1,Vector2(465,300))
  chart_finger(1,Vector2(465,300),false);chart_finger(0,Vector2(355,300),false)
  check(hud.chart.yaw!=previous_yaw and hud.chart.goal<previous_zoom and hud.page=="Chart","Drag and pinch orbit and zoom without selecting a marker")
 press(JOY_BUTTON_LEFT_SHOULDER)
 check(hud.chart.region==2,"Cycle to Cinder Drift")
 choose(2);press(JOY_BUTTON_DPAD_RIGHT);press(JOY_BUTTON_B)
 check(a.route==1 and a.arrival_target==12,"Full-screen atlas plots both legs to Cinder Garden")
 await frames(36);await shot("clusters")
 choose(0);press(JOY_BUTTON_RIGHT_SHOULDER);choose(0)
 check(a.route==1,"Restore the single-hop course for the flight circuit")
 choose(2);check(hud.page=="Local","Local chart shows contact orbits")
 press(JOY_BUTTON_DPAD_RIGHT);press(JOY_BUTTON_DPAD_RIGHT)
 check(hud.chart.focus==8 and a.target==3 and a.route==1,"Previewing a survey island preserves the active course")
 await frames(33);await shot("local")
 if not out.is_empty():
  chart_tap(hud.chart.pins[9])
  check(hud.chart.focus==9 and a.target==3,"Touch an individual island on the projected chart")
  chart_tap(hud.chart.PREV.get_center())
  check(hud.chart.focus==8,"Touch cycles nearby or overlapping marks")
 if not out.is_empty():
  var old_distance:float=hud.chart.distance
  for i in 10:chart_tap(hud.chart.PLUS.get_center())
  await frames(65)
  check(hud.chart.distance<old_distance*.2,"Touch zoom resolves the selected island")
  await shot("island-detail")
 press(JOY_BUTTON_B)
 check(a.target==8 and a.route==-1 and hud.page=="","Tracking a local island replaces the jump vector and stows the drawer")
 panel(JOY_BUTTON_DPAD_UP);choose(2)
 press(JOY_BUTTON_RIGHT_SHOULDER);press(JOY_BUTTON_DPAD_RIGHT)
 check(hud.chart.focus==7 and a.chart_contacts(1)==[2,7,14,16,19] and a.target==8,"Remote chart lists charted sites without exposing live traffic")
 await frames(33);await shot("arrival-chart")
 if not out.is_empty():
  press(JOY_BUTTON_LEFT_SHOULDER);check(hud.chart.region==0,"Browse back to home cluster")
  press(JOY_BUTTON_RIGHT_SHOULDER);await frames(80)
  chart_tap(hud.chart.NEXT.get_center());chart_tap(hud.chart.row(0).get_center())
 else:press(JOY_BUTTON_B)
 check(hud.page=="Chart" and a.route==1 and a.arrival_target==7 and a.target==8,"Commit an arrival beacon without changing local sensors")
 choose(0)
 check(a.route==-1 and a.arrival_target==-1,"Clear a plotted leg before charging the drive")
 choose(2);press(JOY_BUTTON_DPAD_RIGHT);press(JOY_BUTTON_B)
 await shot("plotted")
 press(JOY_BUTTON_A);press(JOY_BUTTON_B);await frames(100)
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
 press(JOY_BUTTON_A)
 Input.action_press("throttle_up");await frames(90);Input.action_release("throttle_up")
 await frames(34);check(f.velocity.length()>65 and a.fuel<100,"Cruise gains speed and burns fuel")
 check(hud.canopy.visible,"Airborne canopy shows guidance in the forward view")
 await shot("cruise")
 panel(JOY_BUTTON_DPAD_UP);choose(1);check(a.charge>0,"Charge outside mass shadow")
 await frames(2)
 check(not hud.canopy.visible,"Reading the chart clears the glass")
 await shot("charge")
 var before:float=a.fuel
 press(JOY_BUTTON_A);await frames(220);check(a.transit>0,"Enter shift corridor")
 await shot("jump")
 await frames(102)
 check(a.sector==1 and a.route==-1 and absf(before-a.fuel-22)<0.001,"Arrive in Prism; exact single jump debit")
 check(a.target==7 and hud.gauges[0].text.contains("Prism relay"),"Jump hands guidance to the chosen beacon")
 await shot("arrival")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(1)
 panel(JOY_BUTTON_DPAD_LEFT);choose(1);choose(0)
 check(a.target==5 and a.lock_id==5,"Independent hostile lock")
 choose(1)
 check(a.npc_shield==100 and a.weapon<82 and a.pulse_time>0,"The pulse leaves the muzzle before it reaches the Warden")
 check(a.burst_to.distance_to(a.position_of(a.WARDEN,a.orbit_time+a.burst_span))<0.1,"Gimbal places the bolt at the marked future orbit position")
 await frames(ceili(a.burst_span*60)+2)
 check(a.npc_shield==75,"The moving Warden takes damage only when the bolt arrives")
 await shot("lock")
 press(JOY_BUTTON_X);await frames(35)
 await shot("pulse-gimbal")
 panel(JOY_BUTTON_LEFT_STICK);check(not a.gimballed and hud.page=="","Mount chord leaves the helm facing forwards")
 await shot("pulse-fixed")
 # Arrange a broadside pass to distinguish aiming at the hull from aiming ahead of it.
 var course:Basis=f.attitude
 a.orbit_time=(2.5*PI-a.WARDEN)/0.072
 f.attitude=Basis.looking_at(a.position_of(a.WARDEN)-a.muzzle(),Vector3.UP)
 await shot("crossing")
 f.attitude=Basis.looking_at(a.position_of(a.WARDEN)-a.muzzle(),Vector3.UP)
 press(JOY_BUTTON_B)
 var hull_at_firing:Vector3=a.position_of(a.WARDEN)-a.muzzle()
 check(a.pulse_time>0 and hull_at_firing.cross(a.gun_ray()).length()<0.2 and a.burst_to.distance_to(a.pulse_mark())>4,"Fixed pulse aimed at the current hull falls behind the lead cue")
 await frames(ceili(a.burst_span*60)+2)
 check(a.npc_shield==75,"Unaligned fixed pulse misses the patrol")
 check(a.incoming>0,"Patrol response reaches the pilot warning display")
 await shot("inbound")
 var intact:float=a.shield
 panel(JOY_BUTTON_B)
 check(a.incoming==0 and a.flare_time>0 and a.shield==intact and not hud.y_down,"Point defence intercepts without firing the selected group")
 f.attitude=Basis.looking_at(a.pulse_mark()-a.muzzle(),Vector3.UP)
 press(JOY_BUTTON_B)
 await frames(ceili(a.burst_span*60)+2)
 check(a.npc_shield==50,"A fixed cannon aligned with the lead cue hits the moving patrol")
 f.attitude=course
 press(JOY_BUTTON_LEFT_STICK);panel(JOY_BUTTON_LEFT_STICK)
 check(a.group==a.Group.LASER and a.gimballed,"Pilot changes from fixed cannon to gimballed beam")
 press(JOY_BUTTON_B)
 check(a.npc_shield==16 and a.burst_to.distance_to(a.position_of(a.WARDEN))<0.1,"Beam strikes current position immediately")
 await shot("beam")
 press(JOY_BUTTON_LEFT_STICK);press(JOY_BUTTON_B)
 check(a.missiles==3 and a.missile_time==0,"Seeker refuses a launch before its own lock")
 await frames(42);await shot("seeker")
 await frames(50);press(JOY_BUTTON_B)
 check(a.missiles==2 and a.missile_time>0 and a.npc_shield==16,"Launch spends one round and sends a visible missile")
 await frames(80)
 check(a.disabled_time>0 and a.lock_id==-1,"Seeker arrival disables patrol and clears its lock")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(1)
 panel(JOY_BUTTON_DPAD_LEFT);choose(0);choose(0)
 check(a.permit==2 and a.target==2,"Prism control assigns pad 01")
 await shot("clearance");press(JOY_BUTTON_A);press(JOY_BUTTON_A)
 Input.action_press("throttle_up");await frames(84);Input.action_release("throttle_up")
 for i in 2100:
  if a.range_to(2)<18:break
  await physics_frame
 Input.action_press("decorate");await frames(110);Input.action_release("decorate")
 check(f.clearance()=="","Reach assigned pad, level and slow")
 check(hud.gauges[0].text.contains("LAND") and hud.extensions==[0.0,0.0],"Landing guidance remains on the dash with drawers retracted")
 check(hud.canopy.visible and hud.canopy.approach,"Pad-relative indications appear on final approach")
 await shot("approach")
 press(JOY_BUTTON_B);await frames(110)
 check(f.berth==2 and f.mode==f.Mode.BERTH,"Land at Prism")
 home._load_profile("pilot");check(f.berth==2 and a.sector==1 and a.pips==[2,3,1] and a.fuel<79,"Reload dock, systems and fuel")
 check(a.group==a.Group.MISSILES and a.missiles==2,"Weapon group and rack count survive docking and reloading")
 home.walker.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_B)
 panel(JOY_BUTTON_DPAD_RIGHT);choose(4);check(a.fuel==100 and a.missiles==3,"Station refuels and replenishes the rack")
 panel(JOY_BUTTON_DPAD_RIGHT);choose(0);choose(2);check(not a.enabled[2] and a.contacts()==[2,14,16,19],"Sensor power changes contact list")
 await shot("modules")
 if not out.is_empty():
  await frames(24)
  var glass:MeshInstance3D=hud.surfaces[1]
  var pixel:Vector2=hud.buttons[2].get_center()/Vector2(hud.PIXELS)
  var point:=glass.to_global(Vector3((pixel.x-0.5)*hud.PANEL_SIZE.x,(0.5-pixel.y)*hud.PANEL_SIZE.y,0))
  touch(point)
  check(a.enabled[2],"Touch the actual glass to restore sensors")
 press(JOY_BUTTON_A);press(JOY_BUTTON_A);press(JOY_BUTTON_B);await frames(100)
 Input.action_press("throttle_up");await frames(310);Input.action_release("throttle_up")
 Input.action_press("decorate");await frames(110);Input.action_release("decorate")
 panel(JOY_BUTTON_DPAD_UP);choose(2);press(JOY_BUTTON_LEFT_SHOULDER);press(JOY_BUTTON_DPAD_RIGHT);press(JOY_BUTTON_B)
 check(a.arrival_target==1,"Plot directly to a remote open landing pad")
 choose(1)
 check(a.charge==0 and a.reply.contains("Align"),"Return vector must be lined up")
 press(JOY_BUTTON_A)
 Input.action_press("walk_right");await frames(221);Input.action_release("walk_right");await frames(24)
 panel(JOY_BUTTON_DPAD_UP);choose(1)
 check(a.charge>0,"Align for return under yaw control")
 press(JOY_BUTTON_A);await frames(316)
 check(a.sector==0 and absf(a.fuel-78)<0.01 and a.permit==-1,"Return jump consumes fuel and clears clearance")
 check(a.target==1 and f.destination==1,"The remote island becomes both the selected contact and the landing destination")
 Input.action_press("walk_forward");Input.action_press("roll_right");await frames(21)
 Input.action_release("walk_forward");Input.action_release("roll_right")
 check(absf(f.attitude.y.x)>0.05,"Bank the ship for the attitude ladder")
 await shot("bank")
 home._load_profile("other");check(f.berth==0 and a.fuel==100 and a.enabled[2] and a.pips==[2,2,2],"Profile isolation")
 print("AVIONICS CIRCUIT: ","PASSED" if errors.is_empty() else errors);quit(0 if errors.is_empty() else 1)
