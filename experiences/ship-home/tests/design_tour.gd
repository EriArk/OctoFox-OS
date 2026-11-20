# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var home=load("res://main.tscn").instantiate();root.add_child(home)
 home._pause(false);home.walker.walking=false;home.walker.hide()
 for child in home.get_children():
  if child is CanvasLayer:
   for control in child.get_children():
    if control is Control:control.hide()
 var camera=Camera3D.new();camera.fov=72;camera.near=0.06;camera.far=600;home.add_child(camera);camera.current=true
 var out=OS.get_environment("SHIP_CAPTURE_DIR")
 if out.is_empty():out="/tmp/ship-design"
 DirAccess.make_dir_recursive_absolute(out)
 var points={
  "bridge":[Vector3(1.15,1.70,-0.7),Vector3(0,1.25,-4.4)],
  "cockpit":[Vector3(0.45,1.52,-2.4),Vector3(0,1.2,-4.8)],
  "lounge":[Vector3(-0.3,1.65,-2.05),Vector3(3.2,1.1,-0.25)],
  "galley":[Vector3(-0.9,1.65,-0.2),Vector3(-3.65,1.25,-0.85)],
  "living":[Vector3(1.0,1.55,-2.65),Vector3(-1.3,1.5,0.55)],
  "lights":[Vector3(0.8,1.45,-0.5),Vector3(0,2.5,1.3)],
  "studio":[Vector3(-1.75,1.56,-1.25),Vector3(0.62,1.14,4.92)],
  "berth":[Vector3(-0.42,1.52,3.11),Vector3(0.06,1.11,5.78)],
  "fabricator":[Vector3(-1.37,1.48,3.12),Vector3(-2.85,1.14,1.48)],
  "aquarium":[Vector3(2.10,1.28,1.07),Vector3(4.15,1.20,1.82)],
  "fitting":[Vector3(0.90,1.55,2.10),Vector3(2.45,1.14,3.95)],
  "service":[Vector3(-1.64,-1.35,3.86),Vector3(0.52,-1.59,1.15)]}
 var selected=OS.get_environment("SHIP_VIEWS").split(",",false)
 for name in points:
  if not selected.is_empty() and name not in selected:continue
  camera.position=points[name][0];camera.look_at(points[name][1])
  await create_timer(0.6).timeout;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
 # Inspection-only roof cutaway documents the real footprint, not another scene.
 home.get_node("HullRoof").hide()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15.5
 camera.position=Vector3(0,18,0.6);camera.look_at(Vector3(0,0,0.6),Vector3.FORWARD)
 await create_timer(0.6).timeout;await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(out+"/deck-plan.png")==OK)
 var fixture=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not fixture.is_empty():
  home.get_node("HullRoof").show()
  var descriptor=JSON.parse_string(FileAccess.get_file_as_string(fixture))
  assert(home.walker.install_avatar(descriptor))
  home.walker.show();home._pause(false)
  home.walker.position=ShipInterior.BOOTH+Vector3(-0.65,0.08,-0.65)
  home._interact();home.cards.move(1)
  for stage in ["closed","traveller"]:
   for i in 240:
    await process_frame
    if (stage=="closed" and home.fitting.closure>=0.999) or (stage=="traveller" and home.fitting.current==1 and home.fitting.closure==0):break
   assert(home.fitting.closure>=0.999 if stage=="closed" else (home.fitting.current==1 and home.fitting.closure==0))
   await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png(out+"/fitting-"+stage+".png")==OK)
 print("SHIP DESIGN TOUR PASSED");quit()
