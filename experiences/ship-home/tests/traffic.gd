# SPDX-License-Identifier: GPL-3.0-or-later
extends "expedition.gd"

func comms(id:int) -> void:
 var a=home.flight.avionics
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=JOY_BUTTON_Y;e.pressed=down;root.push_input(e,true)
  if down:press(JOY_BUTTON_DPAD_LEFT)
 for i in a.contacts().find(id):press(JOY_BUTTON_DPAD_DOWN)
 press(JOY_BUTTON_A)
 check(home.instruments.page=="Contact" and a.target==id,"Select "+a.CATALOG[id].name+" on contact drawer")

func tap_drawer(px:Vector2) -> void:
 var panel=home.instruments
 var local:Vector2=px/Vector2(panel.PIXELS)-Vector2.ONE*0.5
 var world:Vector3=panel.surfaces[0].to_global(Vector3(local.x*panel.PANEL_SIZE.x,-local.y*panel.PANEL_SIZE.y,0))
 var event:=InputEventScreenTouch.new();event.position=home.walker.pilot_camera.unproject_position(world)
 event.pressed=true;root.push_input(event,true);event.pressed=false;root.push_input(event,true)

func flyby_shot(label:String,body:Node3D,eye:Vector3,aim:Vector3) -> void:
 if out.is_empty():return
 var camera:=Camera3D.new();body.add_child(camera)
 home.Exterior.configure_camera(camera,false)
 camera.position=eye;camera.look_at(body.to_global(aim));camera.fov=56;camera.make_current()
 await shot(label)
 camera.free();home.walker.pilot_camera.make_current()

func encounter(site:int,id:int,offset:Vector3) -> void:
 var f=home.flight;var a=f.avionics
 home._load_profile("observer");f.reset(site);home._pause(false)
 home.walker.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_A);press(JOY_BUTTON_A);await frames(110)
 check(home.walker.seated and f.mode==f.Mode.FLYING,"Launch from "+f.NAMES[site])
 f.location=a.position_of(id)+offset;f.attitude=Basis.looking_at(-offset.normalized());f.sync_view()
 await frames(2)

func run() -> void:
 out=OS.get_environment("SHIP_TRAFFIC_SHOTS")
 if out!="":
  root.unfocusable=true
  for i in 35:await process_frame
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.unavailable.disconnect(home._identity_lost);home.avatar_client.disconnect_host()
 home.store.directory="user://traffic-"+str(Time.get_ticks_usec())
 var f=home.flight;var a=f.avionics;var r=f.Regions
 for site in [0,7,8]:
  home._load_profile("observer");f.reset(site);home._pause(false)
  var room=f.station_rooms[site];var id:int=room.STAFF[site].contact
  await exit_lifts();await walk_to(room.to_global(Vector3(0,0,14.38)))
  await walk_to(room.to_global(Vector3(-1.25,0,14.77)))
  check(home._station()=="port_crew","Reach "+room.STAFF[site].name)
  press(JOY_BUTTON_A);check(a.target==id and home.message.contains("marked"),"Navigator receives local transponder")
  if site==8:
   home.message_time=0;home.status.hide()
   await room_shot("factor-orin",room,Vector3(-0.47,1.65,13.48),room.STAFF_POST+Vector3.UP*0.96)
  await walk_to(room.to_global(Vector3(0,0,14.38)))
  await board();check(not room.resident.visible and a.target==id,"Leave station worker and preserve contact")
  home.walker.position=Vector3(0,0.08,-2.4);press(JOY_BUTTON_A);press(JOY_BUTTON_A);await frames(110)
  check(f.mode==f.Mode.FLYING and home.walker.seated,"Take the report to the helm")
  # Leave the approach vertically before steering after the moving transponder.
  for step in 170:f.tick(0.1,Vector2.ZERO,0,0,Vector2.DOWN,false)
  if a.range_to(id)>650:
   a.toggle_cruise()
   for step in 2400:
    if a.range_to(id)<525:break
    f.attitude=Basis.looking_at(f.location.direction_to(a.position_of(id)))
    f.tick(0.06,Vector2.ZERO,0,1,Vector2.ZERO,false)
  for step in 65:f.tick(0.06,Vector2.ZERO,0,0,Vector2.ZERO,true)
  check(a.range_to(id)<850,"Close to radio range under power")
  comms(id);press(JOY_BUTTON_A)
  var entry:Dictionary=a.CATALOG[id]
  check(a.received_from==id and a.received_waypoint==r.lane_destination(entry,a.orbit_time),"Hail near departure and receive current destination")
  var destination:int=a.received_waypoint
  if site==8:
   await frames(30);await shot("convoy-radio")
   if not out.is_empty():
    press(JOY_BUTTON_B);await frames(14)
    tap_drawer(Vector2(548,67));await frames(14)
    check(home.instruments.first_button>0,"Touch next reveals later traffic")
    tap_drawer(Vector2(455,67));await frames(14)
    check(home.instruments.first_button==0,"Touch previous returns to first contacts")
    for i in posmod(a.contacts().find(id)-home.instruments.cursor,a.contacts().size()):press(JOY_BUTTON_DPAD_DOWN)
    press(JOY_BUTTON_A);press(JOY_BUTTON_A)
  press(JOY_BUTTON_DPAD_DOWN);press(JOY_BUTTON_A)
  check(a.target==destination and f.destination==a.CATALOG[destination].site and home.instruments.page=="","Transfer received waypoint to glass")
  a.orbit_time=r.period(entry)*0.75;a.select(id);f.location=a.position_of(id)+Vector3.RIGHT*1500
  a.hail();check(a.reply.contains("range") and a.received_from==-1,"No radio fix beyond range")
  f.location=a.position_of(id)+Vector3.RIGHT*40;a.hail()
  check(a.received_waypoint==entry.lane.x,"Inbound leg broadcasts the other port")
  var pos:Vector3=a.position_of(id,0)
  check(pos.distance_to(a.position_of(id,r.period(entry)))<0.10 and pos.distance_to(a.position_of(id,r.period(entry)*0.5))>5000,"Route loops between real berths")
  check(id not in a.chart_contacts((a.sector+1)%3),"Live traffic stays local")
  f.sync_view();a.update_traffic(0)
  if site==8:
   await flyby_shot("marigold-hauler",a.bodies[id],Vector3(9.8,5.9,-12.4),Vector3(0,-0.07,-0.3))
  else:
   await flyby_shot("vesper-envoy" if site==0 else "threadrunner",a.bodies[id],Vector3(8.4,4.1,-10.6),Vector3(0,0,-0.28))
 await encounter(2,r.VEIL_RAY,Vector3(11,6,15))
 comms(r.VEIL_RAY);press(JOY_BUTTON_A)
 check(a.reply.contains("harmonic") and a.receiver.stream is AudioStreamWAV and a.receiver.stream.get_length()>1,"Listen to field fauna")
 press(JOY_BUTTON_Y);a.deployed=true;a.acquire();check(a.lock_id==-1,"Fauna cannot be combat-locked")
 a.module_switch(2);check(r.VEIL_RAY not in a.contacts(),"Fauna disappears with sensors off");a.module_switch(2)
 await flyby_shot("veil-ray",a.bodies[r.VEIL_RAY],Vector3(5.6,8.9,-12.6),Vector3(0,0,1.3))
 await encounter(8,r.JACKAL,Vector3(33,8,18))
 check(a.pirate_warning and a.retaliation>0 and a.incoming==0,"Pirate warns before engaging")
 comms(r.JACKAL);a.hardpoints();press(JOY_BUTTON_A)
 check(a.lock_id==r.JACKAL and a.tracking(),"Lock the Cinder pirate")
 press(JOY_BUTTON_Y);a.group=a.Group.LASER;a.fire()
 check(a.npc_shield==66 and a.tracking(),"Laser hits Ash Jackal")
 for i in 130:
  if a.incoming>0:break
  a.advance(0.05)
 check(a.incoming>0,"Pirate attacks after warning");a.intercept();check(a.incoming==0,"Countermeasure clears pirate attack")
 a.pulse_time=0;f.location=a.position_of(r.JACKAL)+Vector3(12,6,16)
 f.attitude=Basis.looking_at(f.location.direction_to(a.position_of(r.JACKAL)));f.sync_view()
 await frames(2);await shot("jackal-on-glass")
 f.reset(2);check(a.npc_shield==100 and a.hostile_id==a.WARDEN,"Independent Prism patrol integrity")
 f.reset(8);check(a.npc_shield==66,"Cinder pirate retains its own damage")
 print("REGIONAL TRAFFIC: ","PASSED" if issues.is_empty() else issues);quit(0 if issues.is_empty() else 1)
