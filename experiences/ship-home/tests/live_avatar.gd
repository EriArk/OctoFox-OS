extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var home=load("res://main.tscn").instantiate();root.add_child(home)
 var deadline=Time.get_ticks_msec()+20000
 while home.profile.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 if home.profile!="ship-check" or not home.walker.visual.has_method("play_action"):
  printerr("Live host avatar was not loaded");quit(1);return
 var presenter=home.walker.visual
 if presenter.find_children("*","MeshInstance3D",true,false).size()<3:
  printerr("Shared avatar meshes missing");quit(1);return
 if home.walker.skeleton==null or home.walker.joints.size()<8:
  printerr("Shared locomotion rig is incomplete");quit(1);return
 home.walker.velocity=Vector3(0,0,-2.7);home.walker._locomotion(0.1)
 var thigh=home.walker.joints["thigh.L"]
 if home.walker.skeleton.get_bone_pose_rotation(thigh[0]).is_equal_approx(thigh[1]):
  printerr("Walking did not pose the shared rig");quit(1);return
 var layout=home.rows.duplicate(true)
 # Same-owner appearance notifications may not reset furniture/undo state.
 home.has_undo=true
 home.avatar_client._request("avatar.subscribe")
 for i in 20:await process_frame
 if home.rows!=layout or not home.has_undo:
  printerr("Appearance refresh reset the home");quit(1);return
 home.avatar_client._fail("Test host disconnected")
 if not home.profile.is_empty() or not home.paused:
  printerr("Disconnected identity remained active");quit(1);return
 print("LIVE SHIP AVATAR PASSED");quit(0)
