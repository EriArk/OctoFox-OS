# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:Array[String]=[]
var home
var out:=OS.get_environment("SHIP_COMPUTER_SHOTS")
func check(value:bool,why:String) -> void:
 if not value:failures.append(why);push_error(why)
func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)
func shot(label:String) -> void:
 if out=="":return
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+label+".png")==OK,label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 var client=home.avatar_client
 client.unavailable.disconnect(home._identity_lost);client.disconnect_host()
 home.store.directory="user://computer-test-"+str(Time.get_ticks_usec());home._load_profile("captain");home._pause(false);home.message_time=0
 var w=home.walker;var pc=home.computer;var fab=home.fabricator;var a=home.flight.avionics
 if out!="":
  var camera:=Camera3D.new();home.add_child(camera);home.Exterior.configure_camera(camera,true)
  camera.fov=68;camera.position=Vector3(-1.74,1.63,4.42);camera.look_at(Vector3(-2.88,1.01,1.46));camera.make_current();w.hide()
  for i in 45:await process_frame
  await shot("stations");camera.free();w.show();w.camera.make_current()
 w.position=home.studio.REFINERY_POS+Vector3(0.30,0.10,0.89);press(JOY_BUTTON_B)
 check(fab.processor and fab.tabs[0].text=="Ore" and fab.tabs[1].text=="Plants","Refinery has its own screen")
 await shot("refinery");press(JOY_BUTTON_A)
 w.position=home.studio.COMPUTER_POS+Vector3(0.33,0.10,0.69)
 check(home._station()=="computer","Computer has its own interaction")
 press(JOY_BUTTON_B)
 check(pc.visible and pc.title.text=="Flight status" and pc.description.text.contains("Hull"),"Read flight instruments offline")
 await shot("ship")
 home.store.record_harvest(home.rows,"bauxite",home.garden.today())
 press(JOY_BUTTON_RIGHT_SHOULDER);check(pc.title.text=="Bauxite" and pc.figures.text.contains("1"),"Offline cargo matches local hold")
 await shot("cargo")
 press(JOY_BUTTON_RIGHT_SHOULDER);press(JOY_BUTTON_B)
 check(pc.page==2 and not pc.action.visible,"Missing kit cannot be ordered from upgrades")
 press(JOY_BUTTON_RIGHT_SHOULDER)
 check(pc.page==3 and pc.items.size()==3 and pc.action.disabled,"Offline market only contains blueprints")
 var player:="73987842-2263-4ccc-a980-41f4b6ecfaaa"
 var data={"supplies":{"cruise-kit":{"title":"Cruise economiser","price":250}},"sparks":500,"installed":[],"stock":[],"player_id":player,"revision":"0","prints":{}}
 client.supported=true;client.supplies_supported=true;client.profile_id="captain";client.inventory=data
 for i in pc.OFFERS.size():
  data.supplies[pc.OFFERS[i]]={"title":pc.TITLES[i],"price":[30,100,100,12,45,35,250,300][i]}
 pc.refresh();press(JOY_BUTTON_B)
 check(not pc.confirmation.is_empty() and not client.busy,"Review quote before charging")
 press(JOY_BUTTON_A);check(pc.visible and pc.confirmation.is_empty(),"Cancel quote without leaving PC")
 press(JOY_BUTTON_B);press(JOY_BUTTON_B)
 check(client.last_action=="buy" and client.busy,"Buy selected blueprint")
 var receive=func(value):client._packet({"id":str(client.serial),"result":value})
 receive.call({"item_id":player});data.sparks=470;data.stock=[{"kind":"blueprint","sku":"empty","units":1}]
 receive.call(data);receive.call({"items":[],"next":null})
 check(pc.action.disabled and pc.action.text=="Owned","Owned blueprint cannot be charged again")
 data.stock=[{"kind":"upgrade","sku":"economiser","units":1}]
 client.refresh_workshop();receive.call(data);receive.call({"items":[],"next":null})
 await shot("store")
 press(JOY_BUTTON_LEFT_SHOULDER);check(pc.action.text=="Fit module","Purchased kit can be fitted")
 press(JOY_BUTTON_B);check(client.last_action=="install","Fit calls authenticated workshop")
 receive.call({"item_id":player});data.installed=["economiser"];data.stock=[];receive.call(data);receive.call({"items":[],"next":null})
 check(a.installed==["economiser"] and pc.figures.text=="Installed","Fitted module updates live ship")
 await shot("upgrades")
 press(JOY_BUTTON_A)
 home._load_profile("other");check(a.installed.is_empty(),"Module isolated by profile")
 home._load_profile("captain");check(a.installed==["economiser"],"Fitted module survives restart offline")
 a.fuel=80;a.cruise=true;home.flight.throttle=1;a.advance(1)
 check(absf(a.fuel-(80-0.09*0.8))<0.001,"Economiser affects flight fuel use")
 a.cruise=false;home.flight.mode=home.flight.Mode.FLYING;a.installed=["capacitor"];a.engine=27;a.boost_drive()
 check(a.engine==0 and a.boost>0,"Capacitor drives boost using 27 energy")
 home.flight.reset(0);client.disconnect_host()
 w.position=Vector3(-2.55,0.1,2.45);press(JOY_BUTTON_B)
 check(not fab.processor and fab.station_title.text=="Fabricator","Printer opens independently")
 press(JOY_BUTTON_DPAD_UP)
 check(fab.case_recipe() and fab.heading.text=="Empty cartridge","Utility blueprint in fabricator")
 data={"revision":"4","player_id":player,"case_hours":1,"stock":[],"prints":{}}
 client.supported=true;client.inventory=data
 client.stock={"blueprint/empty":1,"material/Plastic":1}
 fab.refresh();press(JOY_BUTTON_B)
 check(client.last_action=="print_case","Print a shell through its blueprint")
 receive.call({"job_id":player});data.prints={"material.Empty":{"id":player,"quantity":1,"remaining_seconds":0}}
 receive.call(data);receive.call({"items":[],"next":null})
 press(JOY_BUTTON_B);check(client.last_action=="collect_material","Collect a printed shell")
 receive.call({"item_id":player});data.prints={};receive.call(data);receive.call({"items":[],"next":null})
 press(JOY_BUTTON_RIGHT_SHOULDER)
 check(fab.tabs[1].text=="Cartridges" and not fab.print_button.visible,"Cartridge inventory has no processing controls")
 press(JOY_BUTTON_A);check(w.walking and not root.disable_3d,"Return to deck")
 print("SHIP COMPUTER: ","PASSED" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
