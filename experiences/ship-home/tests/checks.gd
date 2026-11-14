extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var store=ShipLayoutStore.new();store.directory="user://checks-"+str(Time.get_ticks_usec())
 var original=store.load_home("alpha");check(store.save(original),"Initial save")
 var moved=original.duplicate(true);moved[0].x=-3.0
 check(store.save(moved),"Atomic replacement")
 check(store.load_home("alpha")[0].x==-3.0,"Saved arrangement survives reload")
 check(store.load_home("beta")[0].x==-2.2,"Profiles have independent layouts")
 var bad=original.duplicate(true);bad[0].x=NAN;check(not ShipLayoutStore.valid(bad),"Reject non-finite positions")
 bad=original.duplicate(true);bad[0].item="../../foreign";check(not store.save(bad),"Reject unknown items")
 store.load_home("alpha");var file=FileAccess.open(store.path(),FileAccess.WRITE);file.store_string("broken");file.close()
 check(store.load_home("alpha").is_empty() and not store.writable,"Corrupt layout is preserved read-only")
 check(not store.save(original),"Do not overwrite corrupt save")
 check(FileAccess.get_file_as_string(store.path())=="broken","Corrupt original untouched")
 var home=load("res://main.tscn").instantiate();root.add_child(home)
 await process_frame
 home.store.directory=store.directory+"/scene";home._load_profile("test-walker")
 home._pause(false)
 for i in 10:await physics_frame
 check(home.can_place("plant",Vector3(4,0,-7),0),"Open floor accepts furniture")
 check(not home.can_place("armchair",Vector3(2,0,3.5),0),"Door remains clear")
 check(not home.can_place("plant",Vector3(0,0,5),0),"Passage remains clear")
 check(not home.can_place("plant",Vector3(0,0,-12),0),"Outside hull rejected")
 check(not home.can_place("armchair",Vector3(-5.5,0,1),0),"Workbench overlap rejected")
 home._edit(true);home.item_index=2;home.placement=Vector3(4,0,-7);home.placement_valid=true
 home._place();check(home.rows.size()==8,"Place furniture through game operation")
 check(home.store.load_home("test-walker").size()==8,"Placement saved")
 home._undo();check(home.rows.size()==7,"Undo restores arrangement")
 home._edit(false);home.walker.position=Vector3(0,0.1,-7.5);home.walker.yaw=0
 Input.action_press("walk_forward")
 for i in 150:await physics_frame
 Input.action_release("walk_forward")
 check(home.walker.position.z> -9.8 and home.walker.position.z< -9.3,"Walk reaches window and collides with glass")
 home.walker.yaw=PI
 for i in 15:await physics_frame
 check(home.walker.arm.get_hit_length()<1.0,"Camera retracts at window")
 home._identity_lost("test revoke")
 check(home.profile.is_empty() and home.paused,"Profile revoke clears private layout and pauses")
 home.queue_free();await process_frame
 print("SHIP CHECKS: ","PASSED" if failures.is_empty() else str(failures));quit(0 if failures.is_empty() else 1)
