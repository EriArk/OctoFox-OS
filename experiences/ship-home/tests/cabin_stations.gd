# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var errors:Array[String]=[]

func check(ok:bool,reason:String) -> void:
 if not ok:errors.append(reason);push_error(reason)

func pad(index:int) -> void:
 for down in [true,false]:
  var event:=InputEventJoypadButton.new();event.button_index=index;event.pressed=down
  root.push_input(event,true)

func capture(name:String) -> void:
 var destination:=OS.get_environment("SHIP_CAPTURE_DIR")
 if destination.is_empty():return
 for frame in 12:await physics_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(destination.path_join(name+".png"))==OK,"Capture "+name)

func _initialize() -> void:run.call_deferred()

func run() -> void:
 var ship=load("res://main.tscn").instantiate();root.add_child(ship)
 ship.avatar_client.appearance_changed.disconnect(ship._appearance)
 ship.avatar_client.unavailable.disconnect(ship._identity_lost)
 ship.avatar_client.disconnect_host()
 ship.store.directory="user://cabin-test";ship._load_profile("pilot");ship._pause(false)
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():
  check(ship.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor))),"Install SDK rig")
 for i in 5:await physics_frame
 var ordered=["pilot","wardrobe","computer","workbench","refinery","tank","cargo","trophies","decorate"]
 for id in ordered:
  pad(JOY_BUTTON_BACK)
  check(ship.quick.visible and not ship.walker.walking,"Open chooser for "+id)
  if id=="pilot":await capture("stations")
  var tile:Button=ship.quick.tiles[ordered.find(id)]
  tile.grab_focus();pad(JOY_BUTTON_B)
  check(not ship.quick.visible,"Confirm closes chooser")
  match id:
   "pilot":
    check(ship.walker.seated,"Reach helm");ship._leave_pilot()
   "wardrobe":
    check(ship.fitting.active,"Enter wardrobe");ship.fitting.finish()
   "computer","cargo":
    check(ship.computer.visible and ship._station()==id,"Open "+id);ship.computer.close()
   "workbench","refinery":
    check(ship.fabricator.visible and ship._station()==id,"Open "+id);ship.fabricator.close()
   "tank":
    check(ship.fishing.phase==ship.fishing.Phase.AQUARIUM,"Open aquarium");ship.fishing.close()
   "trophies":check(ship._station()==id,"Reach trophy case")
   "decorate":check(ship.editing,"Enter decoration");ship._edit(false)
  await physics_frame
 for place:Node3D in get_nodes_in_group("ship_rest"):
  ship.walker.position=place.to_global(place.get_meta("approach"))+Vector3.UP*0.08
  check(ship._station()=="rest","Reach "+str(place.get_meta("rest")))
  var approach:Vector3=ship.walker.position
  pad(JOY_BUTTON_B);check(ship.leisure==place and not ship.walker.seated,"Rest on "+str(place.get_meta("rest")))
  pad(JOY_BUTTON_BACK);check(not ship.quick.visible,"No travel from leisure pose")
  pad(JOY_BUTTON_A);check(ship.leisure==null and ship.walker.position==approach,"Stand at original approach")
 var pilot=ship.walker
 pilot.position=Vector3(0,0.08,-2.4);pad(JOY_BUTTON_B)
 var a=ship.flight.avionics
 ship.flight.mode=ship.flight.Mode.FLYING
 ship.flight.location=a.ORIGINS[a.sector]+Vector3(0,300,2500);ship.flight.local_air=0
 a.clear_course();a.reply_time=0
 check(ship.instruments.next_action().ends_with("Engage cruise"),"Glass offers cruise before first press")
 await capture("cruise-ready")
 a.plot();a.reply_time=0
 ship.flight.attitude=Basis(Vector3.UP,PI)
 check(ship.instruments.next_action().contains("Align"),"Glass explains blocked jump")
 await capture("jump-alignment")
 ship.flight.attitude=Basis.IDENTITY
 check(ship.instruments.next_action().contains("Jump"),"Aligned jump has a shortcut")
 await capture("jump-ready")
 a.clear_course()
 a.deployed=true;a.enabled[4]=false;a.fuel=0
 check(a.drive_blockers("cruise").size()==3,"Report simultaneous cruise interlocks")
 a.toggle_cruise();check(not a.cruise and a.reply==a.blocker("cruise"),"Display and execution share interlocks")
 a.jump();check(a.charge==0 and a.reply==a.blocker("jump"),"Unplotted jump rejected")
 ship.queue_free();await process_frame
 print("CABIN STATIONS: ","PASSED" if errors.is_empty() else str(errors));quit(int(not errors.is_empty()))
