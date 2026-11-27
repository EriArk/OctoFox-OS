# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var failures:Array[String]=[]
var home

func check(value:bool,reason:String) -> void:
 if not value:failures.append(reason);push_error(reason)

func use_shelf() -> void:
 var walker=home.walker
 walker.position=home.studio.SHELF_POS+Vector3(0,-1.03,-0.84)
 check(home._station()=="cabin","Reach the specimen shelf")
 var event:=InputEventJoypadButton.new()
 event.button_index=JOY_BUTTON_B;event.pressed=true;root.push_input(event,true)
 event.pressed=false;root.push_input(event,true)

func _initialize() -> void:run.call_deferred()

func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.unavailable.disconnect(home._identity_lost);home.avatar_client.disconnect_host()
 var store=home.store
 store.directory="user://facility-test-"+str(Time.get_ticks_usec())
 home._load_profile("collector");home._pause(false)
 use_shelf()
 check(home.shelf_choices.is_empty() and home.studio.display_model==null,"Empty shelf grants no samples")
 for row in [["sunbell",20],["sunbell",21],["magnetite",22]]:
  check(store.record_harvest(home.rows,row[0],row[1])=="","Existing harvest saved")
 check(home.shelf_choices.size()==2 and home.shelf_choices[0].result_type=="plant" and home.shelf_choices[1].activity=="geology","Typed local cargo, one choice per SKU")
 use_shelf()
 var model=home.studio.display_model
 check(store.shelf_id=="sunbell/20" and is_instance_valid(model),"Display the harvested plant")
 check(store.save(home.rows) and model==home.studio.display_model,"Unchanged refresh reuses shelf geometry")
 home._load_profile("visitor")
 check(home.studio.display_model==null and not store.owns_sample("sunbell/20"),"Profile switch removes exhibit")
 home._load_profile("collector")
 check(store.shelf_id=="sunbell/20" and home.studio.display_sku=="sunbell","Restore same specimen after disk reload")
 use_shelf()
 check(store.shelf_id=="magnetite/22" and home.studio.display_sku=="magnetite","Controller selects mineral")
 use_shelf()
 check(store.shelf_id=="" and store.ore.magnetite.days.size()==1 and store.botany.sunbell.days.size()==2 and store.owns_sample("sunbell/20") and store.owns_sample("sunbell/21") and store.owns_sample("magnetite/22"),"Clearing the shelf preserves all cargo")
 use_shelf()
 store.writable=false
 check(store.confirm_sample_transfer(home.rows,"sunbell",20)!="" and store.shelf_id=="sunbell/20" and store.owns_sample("sunbell/20"),"Failed persistence preserves display and ownership")
 store.writable=true
 check(store.confirm_sample_transfer(home.rows,"sunbell",20)=="" and store.shelf_id=="" and home.studio.display_model==null,"Confirmed transfer clears exact display")
 check(not store.select_specimen(home.rows,"sunbell/20") and store.owns_sample("sunbell/21"),"Cannot display a spent sample")
 home._load_profile("collector")
 check(store.shelf_id=="" and store.botany.sunbell.days.size()==1 and store.owns_sample("sunbell/21"),"Removal persists without substituting another harvest")
 home.facilities.register("fixture","prize","fixture-case",func():return [{"id":"fixture-owned"}])
 check(home.facilities.results("fixture-case")[0].result_type=="prize" and home.facilities.results("missing").is_empty(),"Additional result provider requires no core changes")
 print("FACILITIES ", "PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
