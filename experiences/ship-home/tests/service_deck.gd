# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:Array[String]=[]
var home
var out:=OS.get_environment("SHIP_DECK_SHOTS")
func check(value:bool,why:String) -> void:
 if not value:failures.append(why);push_error(why)
func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)
func tick() -> void:
 # physics_frame fires before the ship applies that frame's inputs.
 await physics_frame;await physics_frame
func shot(name_value:String,interior:bool,eye:Vector3,focus:Vector3) -> void:
 if out.is_empty():return
 var camera:=Camera3D.new();home.add_child(camera);home.Exterior.configure_camera(camera,interior)
 camera.position=eye;camera.fov=56;camera.look_at(focus);camera.make_current()
 home.walker.hide()
 for layer in home.find_children("*","CanvasLayer",true,false):layer.hide()
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+name_value+".png")==OK,"Capture "+name_value)
 camera.free();home.walker.show();home.walker.camera.make_current()
 for layer in home.find_children("*","CanvasLayer",true,false):layer.show()

func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.unavailable.disconnect(home._identity_lost);home.avatar_client.disconnect_host()
 home.store.directory="user://service-deck-"+str(Time.get_ticks_usec());home._load_profile("captain");home._pause(false)
 var deck=home.studio.service;var w=home.walker;var logbook=home.store;var f=home.flight;var a=f.avionics
 for mesh in deck.payloads.values():check(not mesh.visible,"Fresh hold and empty sockets")
 for station in ["cargo","capacitor","economiser"]:
  var rack:Node3D=deck.cargo if station=="cargo" else deck.sockets
  var near:Vector3=deck.targets[station]+rack.basis.z*0.54
  w.position=Vector3(near.x,home.Art.LOWER_Y+0.07,near.z)
  check(home._station()==station,"Reach "+station)
  press(JOY_BUTTON_B)
  check(home.computer.visible and home.computer.page==(1 if station=="cargo" else 2),"Open "+station)
  if station!="cargo":check(home.computer.items[home.computer.index].id==station,"Correct socket selected")
  press(JOY_BUTTON_A)
 for sku in deck.SAMPLES:
  if sku!="livewell":logbook.record_harvest(home.rows,sku,100)
 var fish=home.Catch.specimen(1,0.5);fish.place="bag";logbook.fish=[fish];logbook.save(home.rows)
 for sku in deck.SAMPLES:check(deck.payloads[sku].visible,sku+" loaded")
 var rack:Node3D=deck.cargo
 await shot("cargo-rack",true,rack.to_global(Vector3(0.28,1.44,2.72)),rack.to_global(Vector3(0,1.00,0.19)))
 logbook.confirm_sample_transfer(home.rows,"bauxite",100);fish.place="tank";logbook.save(home.rows)
 check(not deck.payloads.bauxite.visible and not deck.payloads.livewell.visible,"Unloaded cargo and aquarium fish leave shelves")
 home.avatar_client.profile_id="captain";home.avatar_client.inventory={"installed":["economiser"]};home.avatar_client.workshop_changed.emit()
 check(deck.payloads.economiser.visible and not deck.payloads.capacitor.visible,"Only confirmed fitted module visible")
 rack=deck.sockets
 await shot("drive-bays",true,rack.to_global(Vector3(-0.86,1.40,2.55)),rack.to_global(Vector3(0,1.03,0.25)))
 home._load_profile("second");check(not deck.payloads.economiser.visible and not deck.payloads.sunbell.visible,"Profile switch clears hold and bays")
 home._load_profile("captain");check(deck.payloads.economiser.visible and deck.payloads.sunbell.visible,"Persistent hold and bay")
 var jets=home.exterior.exhaust
 check(not jets.visible,"Engines cold at berth")
 w.sit();f.interact()
 for i in 96:await physics_frame
 f.location+=Vector3.UP*100;f.throttle=1.0;await tick()
 check(jets.visible and is_equal_approx(jets.power,0.60),"Twin plumes in powered flight")
 a.cruise=true;await tick();check(is_equal_approx(jets.power,0.88),"Cruise plume")
 a.cruise=false;a.boost=1.4;await tick();check(jets.power==1.0,"Boost plume")
 await shot("under-thrust",false,Vector3(10,4.9,16),Vector3(0,0.8,3.65))
 a.enabled[0]=false;await tick();check(not jets.visible,"Disabled engines cut plume")
 a.enabled[0]=true;f.throttle=-0.2;await tick();check(not jets.visible,"Reverse has no aft thrust")
 check(a.traffic_plumes[3].is_visible_in_tree(),"Courier has running engines")
 a.sector=1;a.disabled_time=10;a.update_traffic(0);check(not a.traffic_plumes[a.WARDEN].visible,"Disabled contact stops firing engines")
 print("SERVICE DECK: ","PASSED" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
