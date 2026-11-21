# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var home
var issues:Array[String]=[]
var overlapping_doors:=false
var witnessed:Dictionary={}
var out:=OS.get_environment("SHIP_LAB_SHOTS")
func check(ok:bool,why:String) -> void:
 if not ok:issues.append(why);push_error(why)
func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)
func trigger(axis:int,strength:float) -> void:
 var e:=InputEventJoypadMotion.new();e.axis=axis;e.axis_value=strength;root.push_input(e,true)
func frames(n:int) -> void:
 for i in n:await physics_frame
func shot(label:String) -> void:
 if out=="":return
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+label+".png")==OK,"Capture "+label)
func fly(site:int) -> void:
 var f=home.flight;var a=f.avionics
 check(a.navigate_to(f.Regions.BERTH_CONTACT[site]),"Select landable contact")
 f.interact()
 for i in 17:f.tick(0.1,Vector2.ZERO,0,0,Vector2.ZERO,false)
 var direction:float=signf(f.BERTHS[site].z-f.location.z)
 # Align the pilot for a straight flight; move with normal thrust and braking.
 f.attitude=Basis(Vector3.UP,PI if direction>0 else 0.0)
 a.toggle_cruise()
 check(a.cruise,"Engage cruise")
 for i in 2500:
  var remaining:float=(f.BERTHS[site].z-f.location.z)*direction
  if remaining<118:break
  f.tick(0.04,Vector2.ZERO,0,1,Vector2.ZERO,false)
 for i in 100:f.tick(0.04,Vector2.ZERO,0,0,Vector2.ZERO,true)
 if f.Regions.CONTACTS[a.target].kind=="station":
  check(f.clearance()=="Request docking clearance","Station requires clearance");a.hail()
 for i in 1500:
  var delta:float=(f.BERTHS[site].z-f.location.z)*direction
  if absf(delta)<2 and f.velocity.length()<1:break
  var target_throttle:=clampf(delta*0.012,-0.22,0.70)
  f.tick(0.05,Vector2.ZERO,0,clampf((target_throttle-f.throttle)*4,-1,1),Vector2.ZERO,false)
 check(f.clearance().is_empty(),"Arrival clearance at "+f.NAMES[site]+" "+f.clearance()+" "+str(f.location))
 f.interact()
 for i in 17:f.tick(0.1,Vector2.ZERO,0,0,Vector2.ZERO,false)
 check(f.mode==f.Mode.BERTH and f.berth==site,"Dock "+f.NAMES[site])

func walk_to(point:Vector3) -> void:
 var w=home.walker;w.yaw=0
 var keys:=["walk_left","walk_right","walk_forward","walk_back"]
 for i in 2100:
  var gap:=Vector2(point.x-w.position.x,point.z-w.position.z)
  if gap.length()<0.2:break
  var step:=gap.normalized()
  for k in 4:
   var force:float=[-step.x,step.x,-step.y,step.y][k]
   if force>0:Input.action_press(keys[k],force)
   else:Input.action_release(keys[k])
  Input.action_press("walk_run");await physics_frame
 for key in keys:Input.action_release(key)
 Input.action_release("walk_run");await frames(8)
 check(Vector2(point.x-w.position.x,point.z-w.position.z).length()<0.6 and w.is_on_floor(),"Reach "+str(point)+" at "+str(w.position)+" in "+home.flight.NAMES[home.flight.berth])

func exit_lifts() -> void:
 var w=home.walker
 w.position=Vector3(home.Art.LIFT.x,0.09,home.Art.LIFT.y);await frames(4)
 press(JOY_BUTTON_A);await frames(120)
 await walk_to(home.studio.exit_lift.position);press(JOY_BUTTON_A);await frames(120)
 check(home.outside,"Leave through boarding hatch")
func board() -> void:
 await walk_to(home.studio.exit_lift.position);press(JOY_BUTTON_A);await frames(120)
 await walk_to(home.studio.lift.position);press(JOY_BUTTON_A);await frames(120)
 check(not home.outside and absf(home.walker.position.y)<0.12,"Board and return upstairs")

func watch_doors() -> void:
 var f=home.flight
 if home.outside and f.station_rooms.has(f.berth):
  var lock=f.station_rooms[f.berth]
  if lock.openings[0]>0.01 and lock.openings[1]>0.01:overlapping_doors=true
  for i in 2:
   if lock.openings[i]>0.95:witnessed[str(f.berth)+"/"+str(i)]=true

func room_shot(id:String,room:Node3D,eye:Vector3,focus:Vector3) -> void:
 if out.is_empty():return
 var cam:=Camera3D.new();home.add_child(cam);home.Exterior.configure_camera(cam,false)
 cam.global_position=room.to_global(eye);cam.look_at(room.to_global(focus));cam.fov=64;cam.make_current()
 home.walker.hide();home.prompts.hide();await shot(id)
 cam.free();home.walker.show();home.prompts.show();home.walker.camera.make_current()

func _initialize() -> void:run.call_deferred()
func run() -> void:
 if out!="":
  # The capture window is offscreen. Let X11 settle focus before starting
  # the route so the normal background-pause handler stays out of the way.
  root.unfocusable=true
  for frame in 35:await process_frame
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.unavailable.disconnect(home._identity_lost);home.avatar_client.disconnect_host()
 home.store.directory="user://expedition-"+str(Time.get_ticks_usec());home._load_profile("angler");home._pause(false)
 var f=home.flight;var w=home.walker;var s=home.survey;var stock=home.store
 physics_frame.connect(watch_doors)
 fly(f.lab.SITE)
 if not issues.is_empty():finish();return
 await exit_lifts()
 if out!="":
  await walk_to(f.lab.to_global(Vector3(0,0,11.18)));await frames(28)
  await room_shot("airlock",f.lab,Vector3(-0.66,1.67,10.05),Vector3(0.12,1.41,12.94))
 var meet:Vector3=f.lab.keeper.global_position+Vector3.FORWARD*1.55
 await walk_to(meet)
 check(home._station()=="biologist","Reach NPC from pad")
 w.yaw=PI;w.pitch=-0.12;await frames(12)
 if out!="":
  var cam:=Camera3D.new();home.add_child(cam);home.Exterior.configure_camera(cam,false)
  cam.position=Vector3(-16.0,4.6,3.7);cam.look_at(Vector3(0,-3.8,16.6));cam.fov=55;cam.make_current()
  home.prompts.hide()
  await shot("biostation");home.prompts.show();cam.free();w.camera.make_current()
 press(JOY_BUTTON_A);check(s.visible and not w.walking,"Read biologist's invitation")
 await shot("biologist")
 press(JOY_BUTTON_A);press(JOY_BUTTON_B);check(stock.survey_started and f.avionics.target==1,"Accept and plot orchard")
 var rooms:Node3D=f.station_rooms[f.lab.SITE]
 await walk_to(rooms.to_global(Vector3(-2.45,0,15.35)))
 await walk_to(rooms.to_global(Vector3(-2.45,0,18.85)))
 await walk_to(rooms.to_global(Vector3(0,0,20.70)))
 await walk_to(rooms.to_global(Vector3(-1.44,0,23.15)))
 check(home._station()=="microscope","Reach sample lab through interior partition")
 await room_shot("sample-lab",rooms,Vector3(2.70,1.76,21.41),Vector3(-0.53,1.55,24.96))
 await room_shot("research-hall",rooms,Vector3(-2.12,2.08,13.34),Vector3(1.24,1.41,17.3))
 press(JOY_BUTTON_A);check(s.visible and s.slide==0 and s.lens.visible,"Read glassfin reference slide")
 press(JOY_BUTTON_A);check(s.slide==1 and s.body.text.contains("Copper loach"),"Change microscope slide")
 await shot("microscopy");press(JOY_BUTTON_B)
 check(not s.lens.visible and w.walking and stock.observations.is_empty(),"Studying a reference preserves survey progress")
 await walk_to(rooms.to_global(Vector3(0,0,20.76)))
 await walk_to(rooms.to_global(Vector3(-2.45,0,18.80)))
 await walk_to(rooms.to_global(Vector3(-2.45,0,15.0)))
 await walk_to(rooms.to_global(Vector3(0,0,14.03)))
 await board();fly(1)
 if not issues.is_empty():finish();return
 await exit_lifts()
 await walk_to(f.to_global(f.fishing_spots[1]))
 var game=home.fishing
 press(JOY_BUTTON_A);trigger(JOY_AXIS_TRIGGER_RIGHT,1);game.tick(0.14);trigger(JOY_AXIS_TRIGGER_RIGHT,0)
 for i in 400:
  if game.phase==game.Phase.BITE:break
  game.tick(1.0/60)
 trigger(JOY_AXIS_TRIGGER_LEFT,1);trigger(JOY_AXIS_TRIGGER_LEFT,0)
 for i in 4500:
  if game.phase!=game.Phase.FIGHT:break
  Input.action_press("fish_reel",0.20 if game.fight.tension>0.82 else 0.86);game.tick(1.0/60)
 Input.action_release("fish_reel");check(game.phase==game.Phase.LANDED,"Land orchard fish")
 if not issues.is_empty():finish();return
 press(JOY_BUTTON_A);press(JOY_BUTTON_B)
 var fish_id:String=stock.fish[0].id
 await board();fly(f.lab.SITE);await exit_lifts();await walk_to(meet)
 press(JOY_BUTTON_A);stock.writable=false;press(JOY_BUTTON_A)
 check(stock.observations.is_empty() and not home.studio.species_plates.glassfin.visible,"Failed save rolls back reward")
 stock.writable=true;press(JOY_BUTTON_A);press(JOY_BUTTON_B)
 check(stock.observations.glassfin.id==fish_id and stock.fish[0].id==fish_id and home.studio.species_plates.glassfin.visible,"Record and plate without consuming specimen")
 check(s.candidate().is_empty(),"Duplicate species earns no second reward")
 await board();w.position=home.studio.aquarium.to_global(Vector3(0,0.04,1.2));press(JOY_BUTTON_A);press(JOY_BUTTON_A);press(JOY_BUTTON_B)
 check(stock.fish[0].place=="tank","Display actual expedition catch")
 if out!="":
  var tank:Node3D=home.studio.aquarium;var camera:=Camera3D.new();home.add_child(camera)
  home.Exterior.configure_camera(camera,true);camera.fov=55
  camera.position=tank.to_global(Vector3(-0.22,1.04,2.45));camera.look_at(tank.to_global(Vector3(0,0.98,0.0)))
  camera.make_current();w.hide();home.prompts.hide();await shot("species-plate")
  home.prompts.show();w.show();camera.free();w.camera.make_current()
 w.position=home.studio.COMPUTER_POS+Vector3(0.33,0.10,0.69);press(JOY_BUTTON_A);press(JOY_BUTTON_DPAD_DOWN);press(JOY_BUTTON_DPAD_DOWN)
 check(home.computer.title.text=="Glassfin","Field atlas on ship PC")
 await shot("field-atlas");press(JOY_BUTTON_B)
 home._load_profile("other");check(stock.observations.is_empty() and not stock.survey_started and not home.studio.species_plates.glassfin.visible,"Separate profiles")
 home._load_profile("angler");check(stock.observations.glassfin.id==fish_id and stock.fish[0].place=="tank" and home.studio.species_plates.glassfin.visible,"Offline journal, fish and award persist")
 # Returning with another species from the same pier earns its own unique plate.
 var loach:Dictionary=home.Catch.specimen(1,16)
 check(home.keep_fish(loach)=="" and s.candidate().id==loach.id,"Second species is eligible")
 check(home.move_fish(loach.id,"tank")=="" and s.candidate().id==loach.id,"Aquarium specimen can be documented")
 fly(f.lab.SITE);await exit_lifts();await walk_to(meet)
 press(JOY_BUTTON_A);press(JOY_BUTTON_A);press(JOY_BUTTON_B)
 check(stock.observations.size()==2 and home.studio.species_plates.loach.visible and s.brief().contains("complete"),"Complete two-species survey")
 # The other ports use the same collar and have reachable, enclosed aft rooms.
 for site in [0,2,4]:
  home._load_profile("room-check");f.reset(site);home._pause(false);await exit_lifts()
  var port:Node3D=f.station_rooms[site]
  await walk_to(port.to_global(Vector3(0,0,22.7)))
  await room_shot(["dispatch","chart-room","service-shop"][int(site/2)],port,Vector3(-2.10,1.80,20.99),Vector3(0.38,1.41,24.9))
  var origins:Vector3=port.to_global(Vector3(0,1.2,22.7))
  for offset in [Vector3.UP*4,Vector3.LEFT*5,Vector3.RIGHT*5,Vector3.BACK*5]:
   var ray:=PhysicsRayQueryParameters3D.create(origins,origins+offset,f.WALK_LAYER)
   check(not port.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Sealed workroom "+f.NAMES[site])
  await board()
 for site in [0,2,4,6]:
  for i in 2:check(witnessed.has(str(site)+"/"+str(i)),"Cycled door "+str(i)+" at "+f.NAMES[site])
 check(not overlapping_doors,"Inner and outer hatches interlock throughout the route")
 finish()
func finish() -> void:
 print("LANTERN SURVEY: ","PASSED" if issues.is_empty() else issues);quit(0 if issues.is_empty() else 1)
