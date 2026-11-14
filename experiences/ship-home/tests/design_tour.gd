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
  "spine":[Vector3(0,1.6,0.4),Vector3(0,1.45,6.0)],
  "cabin":[Vector3(-1.15,1.65,5.5),Vector3(-2.7,1.1,4.5)],
  "workshop":[Vector3(-1.3,1.65,3.0),Vector3(-3.05,1.4,1.5)],
  "gallery":[Vector3(1.3,1.65,3.0),Vector3(3.05,1.4,1.5)],
  "wardrobe":[Vector3(1.25,1.65,4.0),Vector3(3.05,1.2,4.9)]}
 for name in points:
  camera.position=points[name][0];camera.look_at(points[name][1])
  await create_timer(0.6).timeout;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
 # Inspection-only roof cutaway documents the real footprint, not another scene.
 home.get_node("HullRoof").hide()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=15.5
 camera.position=Vector3(0,18,0.6);camera.look_at(Vector3(0,0,0.6),Vector3.FORWARD)
 await create_timer(0.6).timeout;await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(out+"/deck-plan.png")==OK)
 print("SHIP DESIGN TOUR PASSED");quit()
