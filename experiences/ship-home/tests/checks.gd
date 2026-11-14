extends SceneTree
var failures:Array[String]=[]
func check(ok:bool,message:String) -> void:
 if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func triangles(node:Node3D) -> int:
 var count=0
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var arrays=mesh.mesh.surface_get_arrays(0)
  var indices=arrays[Mesh.ARRAY_INDEX]
  count+=(indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 return count
func run() -> void:
 var geometry=Node3D.new();root.add_child(geometry)
 var art=ShipInterior.new()
 art.box(geometry,Vector3.ZERO,Vector3.ONE,ShipInterior.PAPER,true)
 art.cylinder(geometry,Vector3(2,0,0),0.5,1.0,ShipInterior.PAPER)
 var before=triangles(geometry);art.batch_static(geometry)
 check(before>0 and triangles(geometry)==before,"Batching retains both indexed and unindexed geometry")
 geometry.queue_free()
 var store=ShipLayoutStore.new();store.directory="user://checks-"+str(Time.get_ticks_usec())
 var original=store.load_home("alpha");check(store.save(original),"Initial save")
 var moved=original.duplicate(true);moved[0].x=-3.0
 check(store.save(moved),"Atomic replacement")
 check(store.load_home("alpha")[0].x==-3.0,"Saved arrangement survives reload")
 check(store.load_home("beta")[0].x==-1.95,"Profiles have independent layouts")
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
 for i in home.rows.size():
  var r=home.rows[i]
  check(home.can_place(r.item,Vector3(r.x,0,r.z),r.angle,i),"Starter furnishing fits: "+r.item+" "+str(i))
 check(home.can_place("plant",Vector3(3.4,0,2.8),0),"Open floor accepts furniture")
 check(not home.can_place("armchair",Vector3(0.85,0,2.3),0),"Door remains clear")
 check(not home.can_place("plant",Vector3(0,0,5),0),"Passage remains clear")
 check(not home.can_place("plant",Vector3(0,0,-12),0),"Outside hull rejected")
 check(not home.can_place("armchair",Vector3(-2.85,0,1.48),0),"Workbench overlap rejected")
 check(not home.can_place("plant",Vector3(0,0,-4.6),0),"Cockpit console overlap rejected")
 home._edit(true);home.item_index=2;home.placement=Vector3(3.4,0,2.8);home.placement_valid=true
 home._place();check(home.rows.size()==8,"Place furniture through game operation")
 check(home.store.load_home("test-walker").size()==8,"Placement saved")
 home._undo();check(home.rows.size()==7,"Undo restores arrangement")
 home._edit(false)
 check(not home.can_place("plant",Vector3(4.8,0,3),0),"Curved hull clips rectangular room bounds")
 check(not home.can_place("rug",Vector3(4.4,0,3),0),"All rug corners must fit inside hull")
 # Walk through each actual compact hatch in both directions of the spine.
 for door in ShipInterior.DOORS:
  home.walker.position=Vector3(0,0.1,door.y);home.walker.velocity=Vector3.ZERO
  home.walker.yaw=PI/2 if door.x<0 else -PI/2
  Input.action_press("walk_forward")
  for i in 42:await physics_frame
  Input.action_release("walk_forward")
  check(abs(home.walker.position.x)>1.6 and abs(home.walker.position.z-door.y)<0.15,"Traversable hatch "+str(door))
 home.walker.position=Vector3(-4.3,0.1,2.6);home.walker.velocity=Vector3.ZERO;home.walker.yaw=PI/2
 Input.action_press("walk_forward")
 for i in 90:await physics_frame
 Input.action_release("walk_forward")
 check(home.walker.position.x> -4.9 and home.walker.position.x< -4.4,"Sloping curved hull stops walking")
 home.walker.yaw=-PI/2
 for i in 15:await physics_frame
 check(home.walker.arm.get_hit_length()<1.0,"Camera retracts at curved hull")
 await process_frame
 if home.walker.arm.get_hit_length()<0.85:
  check(not home.walker.visual.visible,"Close wall camera does not render inside the avatar")
 home.walker.position=Vector3(0,0.1,-2.2);home.walker.velocity=Vector3.ZERO;home.walker.yaw=0
 Input.action_press("walk_forward")
 for i in 60:await physics_frame
 Input.action_release("walk_forward")
 check(home.walker.position.z> -3.1 and home.walker.position.z< -2.55,"Pilot seat blocks walking through cockpit")
 home._identity_lost("test revoke")
 check(home.profile.is_empty() and home.paused,"Profile revoke clears private layout and pauses")
 home.queue_free();await process_frame
 print("SHIP CHECKS: ","PASSED" if failures.is_empty() else str(failures));quit(0 if failures.is_empty() else 1)
