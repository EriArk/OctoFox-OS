# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Garden=preload("res://scripts/botanical_garden.gd")
var failures:Array[String]=[]
var out:=OS.get_environment("SHIP_BOTANY_SHOTS")
var home
var garden
func check(ok:bool,why:String) -> void:
 if not ok:failures.append(why);push_error(why)
func frames(n:int) -> void:
 for i in n:await physics_frame
func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)
func select_flower(index:int) -> void:
 for i in Garden.BLOOMS:
  if garden.selected==index:break
  press(JOY_BUTTON_DPAD_RIGHT)
func shot(label:String) -> void:
 if out=="":return
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+label+".png")==OK,"capture "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home);garden=home.garden
 var client=home.avatar_client
 client.unavailable.disconnect(home._identity_lost);client.disconnect_host()
 home.store.directory="user://botany-test-"+str(Time.get_ticks_usec());home._load_profile("gardener")
 if out!="":await frames(52)
 home._pause(false)
 var w=home.walker
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if descriptor!="":w.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor)))
 for site in Garden.SITES:
  var i:int=Garden.SITES.find(site)
  home.flight.reset(site);home._outside(true)
  var dest:Vector3=garden.global_position
  var route:Vector3=Vector3(dest.x,0,dest.z).normalized()
  w.yaw=atan2(-route.x,-route.z);w.position=Vector3.UP*(home.flight.GROUND_Y+0.04)+route*8.1
  Input.action_press("walk_forward")
  for step in 230:
   if w.position.distance_to(dest)<1.48:break
   await physics_frame
  Input.action_release("walk_forward");await frames(10)
  check(home._station()=="garden" and w.is_on_floor(),"Walk from pad to "+Garden.SHORES[i]+" patch at "+str(dest))
  if home._station()!="garden":break
  press(JOY_BUTTON_A)
  check(garden.active and garden.view.current,"Inspect the real flower heads")
  var closed:=0
  while closed in garden.ripe:closed+=1
  select_flower(closed);press(JOY_BUTTON_A)
  check(garden.picked.is_empty(),"Leave closed buds alone")
  select_flower(garden.ripe[0]);press(JOY_BUTTON_A);press(JOY_BUTTON_B)
  check(not garden.active and not home.store.botany.has(Garden.PLANTS[i]),"Leaving a partial harvest does not spend the bloom")
  press(JOY_BUTTON_A);select_flower(garden.ripe[0])
  if i==0:await shot("flowers")
  press(JOY_BUTTON_A);press(JOY_BUTTON_A)
  check(garden.picked.size()==1,"One head cannot fill both slots")
  select_flower(garden.ripe[1]);press(JOY_BUTTON_A)
  check(not garden.active and w.visible and home.store.botany[Garden.PLANTS[i]].days.size()==1,"Save completed sample and restore camera")
  press(JOY_BUTTON_A);check(not garden.active,"Cleared bed cannot be harvested twice")
 home._load_profile("other");check(home.store.botany.is_empty(),"Profile separation")
 home._load_profile("gardener");check(home.store.botany.size()==3,"All samples survive reload")
 w.position=home.studio.REFINERY_POS+Vector3(0.30,0.1,0.89);press(JOY_BUTTON_A)
 var fab=home.fabricator
 press(JOY_BUTTON_LEFT_SHOULDER)
 check(fab.processor and fab.page==1 and fab.print_button.disabled,"Offline fabricator displays samples and keeps them")
 if home.store.botany.size()==3:
  var today:=Garden.today()
  var player:="9bdb9bc5-5ad0-435b-97ee-c178f849adfc"
  var job:="872b73c6-5a2e-4fc1-8c67-fdee9b48c159"
  var data={"revision":"0","player_id":player,"extraction_hours":1,"prints":{},"colors":{},"stock":[]}
  var receive=func(result):client._packet({"id":str(client.serial),"result":result})
  client.supported=true;client.inventory=data;fab.refresh()
  press(JOY_BUTTON_A)
  check(client.pending[str(client.serial)].sample==["gardener","sunbell",today],"Submit original harvest identity")
  var request:int=client.serial
  client._packet({"id":str(request),"error":{"code":"backend_unavailable"}})
  receive.call(data);receive.call({"items":[],"next":null})
  check(home.store.botany.sunbell.days.size()==1,"Retain sample on error")
  press(JOY_BUTTON_A);receive.call({"player_id":player,"item_id":job})
  data.stock=[{"kind":"botanical","sku":"sunbell","units":1}]
  receive.call(data);receive.call({"items":[],"next":null})
  check(home.store.botany.sunbell.days.is_empty() and fab.print_button.text=="Start extraction","Sample moved to inventory")
  press(JOY_BUTTON_A);check(client.last_action=="extract","Owned sample enables extraction")
  receive.call({"player_id":player,"job_id":job});data.stock=[]
  data.prints={"pigment.saffron":{"id":job,"quantity":1,"remaining_seconds":3600}}
  receive.call(data);receive.call({"items":[],"next":null})
  check(home.store.botany.sunbell.days.is_empty() and fab.part_label.text.contains("01:00:00"),"Confirmed timed extraction")
  await shot("fabricator")
  client.inventory.prints["pigment.saffron"].remaining_seconds=0;fab.refresh()
  check(fab.print_button.text=="Collect cartridge" and not fab.print_button.disabled,"Collect when ready")
  press(JOY_BUTTON_A);check(client.last_action=="collect_pigment","Use the existing inventory collection command")
  press(JOY_BUTTON_B)
 print("SHIP BOTANY: ","PASSED" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
