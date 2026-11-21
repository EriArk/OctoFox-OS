# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Catch=preload("res://scripts/shore_catch.gd")
var home
var errors:Array[String]=[]
var out:=OS.get_environment("SHIP_FISH_SHOTS")

func check(ok:bool,why:String) -> void:
 if not ok:errors.append(why);push_error(why)
func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)
func trigger(axis:int,value:float) -> void:
 var e:=InputEventJoypadMotion.new();e.axis=axis;e.axis_value=value;root.push_input(e,true)
func frames(n:int) -> void:
 for i in n:await physics_frame
func shot(label:String) -> void:
 if out.is_empty():return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+label+".png")==OK,"capture "+label)
func _initialize() -> void:run.call_deferred()

func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.unavailable.disconnect(home._identity_lost);home.avatar_client.disconnect_host()
 home.store.directory="user://fish-test-"+str(Time.get_ticks_usec())
 home._load_profile("angler");var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if descriptor!="":home.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor)))
 if out!="":await frames(52)
 home._pause(false)
 var f=home.flight;var w=home.walker;var game=home.fishing
 check(home.studio.fish.is_empty(),"Empty aquarium before first catch")
 for site in [1,3]:
  f.reset(site);home._outside(true);w.yaw=0
  var pier:Vector3=f.to_global(f.fishing_spots[site])
  w.position=Vector3(0,f.GROUND_Y+0.05,8*(1 if pier.z>0 else -1))
  var move:="walk_back" if pier.z>0 else "walk_forward"
  Input.action_press(move);Input.action_press("walk_run")
  for i in 2200:
   if absf(w.position.z-pier.z)<0.65:break
   await physics_frame
  Input.action_release(move);Input.action_release("walk_run");await frames(16)
  check(home._station()=="fish" and w.is_on_floor(),"Walk from landing pad to "+str(site)+" pier. At "+str(w.position)+" target "+str(pier))
  if home._station()!="fish":break
  press(JOY_BUTTON_B);check(game.phase==game.Phase.READY and game.equipment.definition==game.Rod,"Equip the SDK rod")
  trigger(JOY_AXIS_TRIGGER_RIGHT,1);game.tick(0.72 if site==3 else 0.14);trigger(JOY_AXIS_TRIGGER_RIGHT,0)
  check(game.phase==game.Phase.CAST,"Release trigger to cast")
  for i in 350:
   if game.phase==game.Phase.BITE:break
   game.tick(1.0/60)
  check(game.phase==game.Phase.BITE,"Float dips for a bite")
  trigger(JOY_AXIS_TRIGGER_LEFT,1);trigger(JOY_AXIS_TRIGGER_LEFT,0)
  check(game.phase==game.Phase.FIGHT,"LT hooks the fish")
  if site==1:await shot("pier")
  for i in 4500:
   if game.phase!=game.Phase.FIGHT:break
   # Point the rod against the pull and let drag run during a strong surge.
   var left:bool=game.fight.direction>0
   Input.action_press("look_left" if left else "look_right")
   Input.action_release("look_right" if left else "look_left")
   Input.action_press("fish_reel",0.0 if game.fight.tension>0.75 else 0.86)
   game.tick(1.0/60)
  Input.action_release("fish_reel");Input.action_release("look_left");Input.action_release("look_right")
  check(game.phase==game.Phase.LANDED,"Land a catch with analog drag: "+str(site)+" "+game.outcome)
  if game.phase!=game.Phase.LANDED:break
  check(game.specimen.species==("ribbon" if site==3 else "glassfin"),"Species varies by water and cast")
  if site==3:await shot("catch")
  press(JOY_BUTTON_B);check(home.store.fish.size()==(2 if site==3 else 1),"Keep once")
  press(JOY_BUTTON_A)
  check(not w.stationary and not game.pole.visible,"Stow rod and restore walking")
 home._load_profile("angler")
 check(home.store.fish.size()==2,"Reload livewell")
 if home.store.fish.size()==2:
  w.position=home.studio.aquarium.to_global(Vector3(0,0.04,1.20))
  var toward:Vector3=home.studio.aquarium.global_position-w.position
  w.yaw=atan2(-toward.x,-toward.z);w.pitch=-0.08
  await frames(4);check(home._station()=="tank","Aquarium station reaches front glass")
  press(JOY_BUTTON_B)
  var first:String=home.store.fish[0].id
  press(JOY_BUTTON_B);press(JOY_BUTTON_RIGHT_SHOULDER);press(JOY_BUTTON_B)
  check(home.studio.fish.size()==2 and home.store.fish[0].id==first,"Same two specimens swim in the aquarium")
  await frames(12);await shot("aquarium");press(JOY_BUTTON_A)
  home._load_profile("other");check(home.studio.fish.is_empty(),"Other profile has its own tank")
  home._load_profile("angler")
  check(home.studio.fish.size()==2 and home.store.fish[0].id==first,"Tank persists across profile change")
  check(home.move_fish(first,"bag")=="" and home.studio.fish.size()==1,"Remove one aquarium specimen")
  var client=home.avatar_client
  client.fish_supported=true
  check(not home.can_export(),"Older service cannot lock a local catch")
  client.read_fish()
  client._packet({"id":str(client.serial),"result":{"tank":[],"items":[],"next":null}})
  home.export_fish(home.store.fish[0])
  check(home.store.fish[0].place=="sending" and home.move_fish(first,"tank")!="","Pending handoff locks local specimen")
  var request:int=client.serial
  client._packet({"id":str(request),"error":{"code":"backend_unavailable"}})
  home.export_fish(home.store.fish[0])
  check(client.pending[str(client.serial)].fish==first,"Retry same stable ID")
  client._packet({"id":str(client.serial),"result":{"item_id":first}})
  check(home.store.fish.size()==1,"Only confirmed handoff removes local specimen")
  var imported={"id":first,"species":"glassfin","site":1}
  client._packet({"id":str(client.serial),"result":{"items":[imported.duplicate()],"tank":[],"next":null}})
  check(home.fish_stock().size()==2 and home.fish_stock()[1].place=="inventory","Inventory fish available to display")
  client.display_fish(first,true)
  client._packet({"id":str(client.serial),"result":{}})
  client._packet({"id":str(client.serial),"result":{"items":[],"tank":[imported.duplicate()],"next":null}})
  check(home.studio.fish.size()==2,"Local and account fish share the tank")
  client.read_fish()
  client._packet({"id":str(client.serial),"result":{"items":[],"tank":[],"next":null}})
  check(home.studio.fish.size()==1,"Listed fish leaves tank on inventory refresh")
  var local:Dictionary=home.store.fish[0]
  check(home.move_fish(local.id,"bag")=="","Local fish remains mobile")
  first=local.id
  home.store.writable=false
  check(home.move_fish(first,"tank")!="" and home.store.fish[0].place=="bag","Failed save rolls back")
  home.store.writable=true
  game.open_tank()
  press(JOY_BUTTON_Y);press(JOY_BUTTON_A)
  check(home.store.fish.size()==1 and game.phase==game.Phase.AQUARIUM,"Cancel a release")
  press(JOY_BUTTON_Y);press(JOY_BUTTON_B)
  check(home.store.fish.is_empty(),"Confirmed release removes just the selected specimen")
  press(JOY_BUTTON_A)
 var model=Catch.new();model.rng.seed=14
 var fish=Catch.specimen(1,15)
 check(fish.species=="loach","Bottom fish on longer orchard cast")
 model.start(Catch.specimen(1,4),4)
 var result:=""
 for i in 1600:
  result=model.advance(1.0/60,0,0)
  if result!="":break
 check(result=="Fish slipped away","Slack loses small fish")
 var ray={"id":"ffff0000-0000-4000-8000-000000000000","species":"ribbon","site":3,"place":"bag"}
 model.rng.seed=4;model.start(ray,17);result=""
 for i in 1800:
  result=model.advance(1.0/60,1,0)
  if result!="":break
 check(result=="Line snapped","A strong fresh ray can break a continuously loaded line")
 print("SHIP FISHING: ","PASSED" if errors.is_empty() else errors);quit(0 if errors.is_empty() else 1)
