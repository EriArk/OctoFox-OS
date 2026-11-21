# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Mine=preload("res://scripts/ore_outcrop.gd")
var failures:Array[String]=[]
var out:=OS.get_environment("SHIP_MINING_SHOTS")
var home
var mine

func check(ok:bool,why:String) -> void:
 if not ok:failures.append(why);push_error(why)

func frames(n:int) -> void:
 for i in n:await physics_frame

func press(button:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=button;e.pressed=down;root.push_input(e,true)

func shot(label:String) -> void:
 if out=="":return
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+label+".png")==OK,"Capture "+label)

func hit() -> void:
 for step in 650:
  if mine.cursor.position.distance_to(mine.target.position)<0.085:
   press(JOY_BUTTON_B);return
  await physics_frame
 check(false,"Cutter reaches fracture "+str(mine.cut))

func _initialize() -> void:run.call_deferred()

func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home);mine=home.mine
 var client=home.avatar_client
 client.unavailable.disconnect(home._identity_lost);client.disconnect_host()
 home.store.directory="user://mining-test-"+str(Time.get_ticks_usec());home._load_profile("miner")
 home._pause(false)
 var w=home.walker
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if descriptor!="":w.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor)))
 if out!="":await frames(50)
 for site in [3,5]:
  var index:int=Mine.SITES[site]
  home.flight.reset(site);home._outside(true)
  var dest:Vector3=mine.global_position
  var route:=Vector3(dest.x,0,dest.z).normalized()
  w.yaw=atan2(-route.x,-route.z);w.position=Vector3.UP*(home.flight.GROUND_Y+0.04)+route*8.1
  Input.action_press("walk_forward")
  for step in 230:
   if w.position.distance_to(dest)<1.55:break
   await physics_frame
  Input.action_release("walk_forward");await frames(10)
  check(home._station()=="mine" and w.is_on_floor(),"Reach outcrop on foot: "+Mine.SHORES[index])
  if home._station()!="mine":break
  press(JOY_BUTTON_B);press(JOY_BUTTON_B)
  check(mine.active and mine.cut==0 and mine.help.text.contains("Missed"),"Miss leaves ore intact")
  await hit();press(JOY_BUTTON_A)
  check(not mine.active and w.camera.current and home.store.ore.is_empty()==(index==0),"Leaving a fracture restores exploration")
  press(JOY_BUTTON_B)
  await shot("seam" if index==0 else "magnetite")
  for i in 3:await hit()
  check(not mine.active and home.store.ore.has(Mine.ORES[index]),"Three pulses yield "+Mine.ORES[index])
  press(JOY_BUTTON_B);check(not mine.active,"Vein cannot pay twice")
 home._load_profile("other");check(home.store.ore.is_empty(),"Profile isolation")
 home._load_profile("miner");check(home.store.ore.size()==2,"Both ores survive reload")
 w.position=home.studio.REFINERY_POS+Vector3(0.30,0.1,0.89);press(JOY_BUTTON_B)
 var fab=home.fabricator
 check(fab.refining() and fab.note.text.contains("Ship 1") and fab.print_button.disabled,"Offline cargo in Cartridges")
 if home.store.ore.size()==2:
  var player:="d69c6f99-d23a-4f1f-a357-74169d4d043a"
  var job:="45a683ff-2bd0-4b36-b02e-7a9f63c26162"
  var data={"revision":"0","player_id":player,"refining_hours":2,"prints":{},"colors":{},"stock":[]}
  var receive=func(result):client._packet({"id":str(client.serial),"result":result})
  client.supported=true;client.inventory=data;fab.refresh()
  press(JOY_BUTTON_B);check(client.last_action=="store_sample","Deposit ore")
  receive.call({});check(not home.store.ore.bauxite.days.is_empty(),"Keep ore until confirmed")
  press(JOY_BUTTON_B);receive.call({"player_id":player,"item_id":job})
  data.stock=[{"kind":"ore","sku":"bauxite","units":1}]
  receive.call(data);receive.call({"items":[],"next":null})
  check(home.store.ore.bauxite.days.is_empty() and fab.print_button.text=="Start refining","Confirmed movement to inventory")
  press(JOY_BUTTON_B);check(client.last_action=="refine","Start refining")
  receive.call({"job_id":job});data.stock=[]
  data.prints={"material.Aluminium":{"id":job,"remaining_seconds":7200,"quantity":1}}
  receive.call(data);receive.call({"items":[],"next":null})
  check(fab.part_label.text.contains("02:00:00"),"Two-hour job")
  await shot("refinery")
  client.stock["ore/bauxite"]=1;fab.refresh()
  check(fab.print_button.disabled,"Parallel refining needs an empty cartridge")
  client.stock["material/Empty"]=1;fab.refresh()
  check(not fab.print_button.disabled and fab.print_button.text=="Start extra batch","Additional batch offers shell recipe")
  data.prints["material.Aluminium"].remaining_seconds=0;fab.refresh()
  press(JOY_BUTTON_B);check(client.last_action=="collect_material","Collect cartridge")
 print("SHIP MINING: ","PASSED" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
