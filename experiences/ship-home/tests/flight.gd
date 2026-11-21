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
 home._pause(false);w.position=Vector3(0,0.08,0)
 press(JOY_BUTTON_B);press(JOY_BUTTON_A)
 check(not home.paused and not w.seated,"Face buttons on an empty deck never open Start")
 w.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_B)
 check(w.seated and f.mode==f.Mode.BERTH,"Board at station")
 check(f.air_zones.size()==10 and f.find_children("Waterfalls","MeshInstance3D",true,false).size()==10,"Running water on each open island")
 check(f.find_children("RisingSpray","MultiMeshInstance3D",true,false).size()==10,"Spray at all island rims")
 check(f.local_air==0.0 and home.art.field_stars.visible,"Station opens onto the Egregore")
 check(f.find_children("AtmosphereClouds*","MultiMeshInstance3D",true,false).size()==10,"Each open sea has spatial cloud banks")
 for zone in f.air_zones:
  var center:=Vector3(zone.x,zone.y,zone.z)
  for heading in [Vector3.BACK,Vector3.UP*f.coast.CLOUD_HEIGHT]:
   var ray:Vector3=heading*f.shell_radius(zone.w)
   f.location=center+ray*1.03;f.sync_view()
   check(f.local_air==0 and f.cloud_cover>0,"Outer cloud precedes daylight")
   f.location=center+ray*0.93;f.sync_view()
   check(f.cloud_cover>0.95 and f.local_air>0 and f.local_air<1,"Canopy is obscured during the sky change")
   f.location=center+ray*0.72;f.sync_view()
   check(f.local_air==1.0 and f.cloud_cover==0.0 and not home.art.field_stars.visible,"Clear air inside the bank")
  var water_area:=0.0;var land_area:=0.0
  for j in f.coast.SEGMENTS:
   var a:float=TAU*j/f.coast.SEGMENTS;var seed_angle:float=f.Regions.ISLANDS[f.island_ids[f.air_zones.find(zone)]][1]
   land_area+=pow(f.coast.headland(a,seed_angle),2)
   water_area+=pow(f.coast.rim(a,seed_angle),2)-pow(f.coast.headland(a,seed_angle),2)
  check(water_area>land_area*5.0,"Surrounding water dominates each island footprint")
 f.reset(0)
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
  press(JOY_BUTTON_B);press(JOY_BUTTON_A)
  check(not w.seated and not home.paused,"Stand during powered departure")
  await frames(100)
  check(f.mode==f.Mode.FLYING,"Departure completes with the seat empty")
  press(JOY_BUTTON_B);check(w.seated,"Retake helm in flight")
  check(home.exterior.hover_amount==0,"Hover field shortens after departure")
  press(JOY_BUTTON_START);var stopped:Vector3=f.location;var field_phase:float=home.exterior.cycle
  var water_phase:float=f.coast.clock
  Input.action_press("throttle_up");await frames(12);Input.action_release("throttle_up")
  check(f.location==stopped and f.throttle==0,"Pause freezes throttle and travel")
  check(f.coast.clock==water_phase,"Pause freezes water and rising mist together")
  check(home.exterior.cycle==field_phase,"Suspended ring animation while paused")
  press(JOY_BUTTON_A)
  # Fly toward the other berth using exactly the normal throttle and brake actions.
  Input.action_press("throttle_up");await frames(85);Input.action_release("throttle_up")
  check(home.exterior.drive_power>0.9,"Aft exhaust responds to forward throttle")
  var flight_frames:=ceili(f.BERTHS[0].distance_to(f.BERTHS[1])/22.0*60.0)+180
  for i in flight_frames:
   if f.location.distance_to(f.BERTHS[f.destination])<18:break
   await physics_frame
  if leg==0:
   f.avionics.select(0);f.attitude=f.attitude.rotated(Vector3.FORWARD,0.55)
   check(f.clearance().is_empty(),"Island accepts an off-axis moving ship with another target")
   press(JOY_BUTTON_B);check(f.mode==f.Mode.LANDING and f.destination==1,"East button captures the local island")
   press(JOY_BUTTON_A);check(not w.seated and not home.paused,"Stand while the landing assist flies")
   await frames(620)
   press(JOY_BUTTON_B);check(w.seated,"Retake helm at island")
  else:
   press(JOY_BUTTON_B);check(f.mode==f.Mode.FLYING,"Station keeps docking clearance")
   Input.action_press("decorate");await frames(100);Input.action_release("decorate")
   check(f.clearance()=="Request docking clearance","Station needs local permission")
   f.avionics.hail()
   check(f.clearance().is_empty(),"Stopped level over station: "+str(f.location))
   press(JOY_BUTTON_B);await frames(100)
  check(f.mode==f.Mode.BERTH and f.berth==(1-leg),"Arrive and settle at destination")
  check(is_equal_approx(f.local_air,float(1-leg)),"Settled sky follows the actual berth on both legs")
  check(home.exterior.hover_amount==1 and home.exterior.drive_power==0,"Landing restores full hover and idle exhaust")
  var store:=ShipLayoutStore.new();store.directory=home.store.directory;store.load_home("test")
  check(store.berth==f.berth,"Restore most recently landed berth")
 press(JOY_BUTTON_A);check(not w.seated and w.camera.current,"Leave chair after arrival")
 f.interact();f.tick(2,Vector2.ZERO,0,0,Vector2.ZERO,false)
 for i in 20:f.tick(1.0/60,Vector2(0.7,0.4),0.6,0,Vector2(1,0.8),false)
 check(not f.attitude.is_equal_approx(Basis.IDENTITY) and f.velocity.length()>0.5,"Attitude and translations respond")
 f.reset(0);f.interact();f.tick(2,Vector2.ZERO,0,0,Vector2.ZERO,false)
 for i in 200:f.tick(1.0/60,Vector2.ZERO,0,0,Vector2.DOWN,false)
 check(f.location.y>=f.GROUND_Y+2.7-0.001,"Hull cannot pass through landing platform")
 exercise_island_approaches(f)
 await exercise_triggers()
 exercise_cluster_flight(f)
 print("SHIP FLIGHT: ","PASSED" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)

func exercise_cluster_flight(f) -> void:
 var a=f.avionics
 f.reset(1);f.interact();f.tick(1.6,Vector2.ZERO,0,0,Vector2.ZERO,false)
 a.navigate_to(8)
 for i in 600:f.tick(1.0/30,Vector2.ZERO,0,0,Vector2.DOWN,false)
 var overhead:Vector3=f.BERTHS[3]+Vector3.UP*130
 f.attitude=Basis.looking_at(overhead-f.location)
 a.toggle_cruise()
 var elapsed:=0.0
 while f.location.distance_to(overhead)>190 and elapsed<300:
  f.tick(1.0/30,Vector2.ZERO,0,1,Vector2.ZERO,false)
  elapsed+=1.0/30
 check(elapsed>165 and elapsed<185 and f.location.distance_to(overhead)<190,"Cruise covers Echo Orchard to Table Isle in about three minutes")
 check(f.destination==3 and a.target==8 and a.fuel>65,"Cruise route keeps the destination and uses affordable fuel")
 print("Echo Orchard to Table Isle · cruise seconds ",snappedf(elapsed,.1))
 f.reset(0);f.interact();f.tick(1.6,Vector2.ZERO,0,0,Vector2.ZERO,false)
 # Start the drive beyond the station mass shadow, with full fuel.
 f.location=Vector3(0,10,165);f.sync_view();a.fuel=100
 check(a.Regions.passage(0,2)==[1,2] and a.Regions.passage(2,0)==[1,0],"Opposite clusters require a stop in Prism in both directions")
 a.route=2;a.jump()
 check(a.charge==0,"Drive rejects an out-of-range leg even if selected directly")
 a.plot(12)
 for leg in [1,2]:
  check(a.route==leg and a.arrival_target==12,"Plotted route exposes only the next reachable cluster")
  if leg==2:
   a.fuel=21;a.jump();check(a.charge==0 and a.route==2,"Insufficient fuel cannot skip the second crossing")
   a.fuel=78
  f.attitude=Basis.looking_at(a.jump_axis())
  a.jump()
  for i in 165:f.tick(1.0/30,Vector2.ZERO,0,0,Vector2.ZERO,false)
  check(a.sector==leg and absf(a.fuel-(100-22*leg))<.01,"One crossing consumes exactly one leg of fuel")
 check(a.route==-1 and a.target==12 and f.destination==5,"Second crossing selects the garden landing pad")
 f.reset(5)
 check(a.sector==2 and f.local_air>.99,"Reloading Cinder Garden restores its cluster and atmosphere")

func axis_event(axis:int,value:float) -> void:
 var event:=InputEventJoypadMotion.new()
 event.device=1;event.axis=axis;event.axis_value=value
 Input.parse_input_event(event);Input.flush_buffered_events()

func exercise_triggers() -> void:
 var f=home.flight
 f.reset(0);home.walker.position=Vector3(0,0.08,-2.4);home.walker.sit()
 f.interact();await frames(100)
 f.location+=Vector3.UP*100
 axis_event(JOY_AXIS_TRIGGER_RIGHT,0.82);await frames(80)
 check(f.velocity.length()>8 and f.throttle>0.5,"RT gives forward thrust on a reconnected controller")
 axis_event(JOY_AXIS_TRIGGER_RIGHT,0);axis_event(JOY_AXIS_TRIGGER_LEFT,1);await frames(100)
 check(f.velocity.is_zero_approx() and is_zero_approx(f.throttle),"LT brakes and holding it keeps the ship still")
 axis_event(JOY_AXIS_TRIGGER_LEFT,0);await frames(2)
 axis_event(JOY_AXIS_TRIGGER_LEFT,1);await frames(30)
 check(f.throttle<0,"Pull LT again from rest to reverse")
 axis_event(JOY_AXIS_TRIGGER_LEFT,0);press(JOY_BUTTON_A)
 check(not home.walker.seated and not home.paused,"Bottom face button leaves an airborne helm")
 var orientation:Basis=f.attitude
 axis_event(JOY_AXIS_LEFT_X,1);axis_event(JOY_AXIS_TRIGGER_RIGHT,1);await frames(80)
 check(f.velocity.is_zero_approx() and orientation.is_equal_approx(f.attitude),"Cabin movement cannot steer or accelerate an empty helm")
 axis_event(JOY_AXIS_LEFT_X,0);axis_event(JOY_AXIS_TRIGGER_RIGHT,0)

func exercise_island_approaches(f) -> void:
 var sites_checked:=0
 for site in f.BERTHS.size():
  var id:int=f.Regions.BERTH_CONTACT[site]
  if f.Regions.CONTACTS[id].kind!="island":continue
  var approaches:=0
  for heading in 8:
   f.reset(site);f.mode=f.Mode.FLYING
   var angle:=TAU*heading/8.0
   f.location=f.BERTHS[site]+Vector3(cos(angle)*65,15,sin(angle)*65)
   if f.hits_island(f.location) or f.hits_structure(f.location,f.location):continue
   f.attitude=Basis(Vector3.FORWARD,0.5);f.velocity=Vector3(6,-2,-19)
   f.interact()
   check(f.mode==f.Mode.LANDING,"Acquire "+f.NAMES[site])
   var clear_path:=true
   for frame in 360:
    if f.mode!=f.Mode.LANDING:break
    var previous:Vector3=f.location
    f.tick(1.0/30,Vector2.ZERO,0,0,Vector2.ZERO,false)
    if f.hits_island(f.location) or f.hits_structure(previous,f.location):clear_path=false
   check(clear_path and f.mode==f.Mode.BERTH and f.berth==site,"Clear approach: "+f.NAMES[site]+" / "+str(heading))
   approaches+=1
  check(approaches>0,"Reachable pad: "+f.NAMES[site]);sites_checked+=1
 check(sites_checked==10,"Every open island accepts assisted landings")
