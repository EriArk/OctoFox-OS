# SPDX-License-Identifier: GPL-3.0-or-later
extends "expedition.gd"

func run() -> void:
 out=OS.get_environment("SHIP_REGION_SHOTS")
 if not out.is_empty():
  root.unfocusable=true
  for frame in 35:await process_frame
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.unavailable.disconnect(home._identity_lost);home.avatar_client.disconnect_host()
 home.store.directory="user://regional-route-"+str(Time.get_ticks_usec());home._load_profile("scout");home._pause(false)
 var f=home.flight
 physics_frame.connect(watch_doors)
 var ports:=[0,0,0]
 for site in f.BERTHS.size():
  var contact:int=f.Regions.BERTH_CONTACT[site]
  var item:Dictionary=f.Regions.CONTACTS[contact]
  check(item.site==site and item.name==f.NAMES[site],"Berth matches chart")
  check(home.store.BERTH_KEYS.count(home.store.BERTH_KEYS[site])==1,"Unique saved berth")
  if item.kind=="station":ports[item.sector]+=1
 check(ports==[2,2,2] and f.island_ids.size()==10,"Six ports and ten real islands")
 for pair in [[1,3],[10,15],[5,11]]:
  var cruise_seconds:float=f.BERTHS[pair[0]].distance_to(f.BERTHS[pair[1]])/f.Regions.CRUISE_SPEED
  check(cruise_seconds>=120 and cruise_seconds<=240,"Travel between island groups takes two to four minutes")
 for port_id in [7,8]:
  home._load_profile("scout");f.reset(port_id);home._pause(false)
  await exit_lifts()
  var room=f.station_rooms[port_id]
  await walk_to(room.to_global(Vector3(0,0,23.65)))
  check(home._station()=="route_desk","Reach route console from boarding lift")
  var contact:int=room.ROUTES[port_id]
  press(JOY_BUTTON_A)
  check(f.avionics.target==contact and f.destination==f.Regions.CONTACTS[contact].site,"Console programs helm")
  home.message_time=0;home.status.hide()
  await room_shot("chart-loft" if port_id==7 else "assay-room",room,Vector3(-2.4,1.85,21.30),Vector3(0.1,1.35,24.9))
  await room_shot("wayfinders-hall" if port_id==7 else "freight-receiving",room,Vector3(-1.06,1.88,13.34),Vector3(1.08,1.32,17.70))
  await board()
  check(f.avionics.target==contact,"Boarding preserves plotted destination")
  var harbour:int=f.Regions.CONTACTS[contact].site
  var seconds:float=f.BERTHS[port_id].distance_to(f.BERTHS[harbour])/f.Regions.CRUISE_SPEED
  check(seconds>=30 and seconds<=60,"Nearby working island within a minute of cruise")
  fly(harbour)
  if not issues.is_empty():finish();return
  await exit_lifts()
  var activity=home.garden if port_id==7 else home.mine
  await walk_to(Vector3(home.studio.EXIT_CENTER.x,f.GROUND_Y,8.5))
  await walk_to(activity.global_position+Vector3.FORWARD*1.23)
  check(home._station()==("garden" if port_id==7 else "mine"),"Reach local plant or ore")
  press(JOY_BUTTON_A);check(activity.active,"Open field activity");press(JOY_BUTTON_B)
  await walk_to(Vector3(home.studio.EXIT_CENTER.x,f.GROUND_Y,8.5))
  await board()
  fly(port_id)
  if not issues.is_empty():finish();return
  for door in 2:check(witnessed.has(str(port_id)+"/"+str(door)),"Cycle both doors")
 for site in [9,10,11,12,13,14,15]:
  home._load_profile("scout");f.reset(site);home._pause(false)
  f.avionics.navigate_to(f.Regions.BERTH_CONTACT[site])
  f.mode=f.Mode.FLYING;f.location=f.BERTHS[site]+Vector3.UP*6
  check(f.clearance()=="","Charted pad accepts landing approach")
  f.interact()
  for frame in 17:f.tick(0.1,Vector2.ZERO,0,0,Vector2.ZERO,false)
  await exit_lifts()
  await walk_to(Vector3(home.studio.EXIT_CENTER.x,f.GROUND_Y,8.5))
  await walk_to(Vector3(0,f.GROUND_Y,11))
  if site in [9,10,11]:
   var origin:Vector3=f.BERTHS[site]+Vector3(30,f.GROUND_Y,-48)
   await room_shot(["reedwater-delta","meridian-rift","kiln-caldera"][site-9],f,origin+Vector3(95,206,155),origin+Vector3(0,3,-12))
  home.store.berth=site;check(home.store.save(home.rows),"Save new berth")
  home._load_profile("scout");check(f.berth==site,"Restore berth "+f.NAMES[site])
 check(not overlapping_doors,"Pressure doors stay interlocked")
 finish()

func finish() -> void:
 print("REGIONAL GEOGRAPHY: ","PASSED" if issues.is_empty() else issues);quit(0 if issues.is_empty() else 1)
