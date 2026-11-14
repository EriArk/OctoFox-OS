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
  "bridge":[Vector3(3.8,1.95,-0.65),Vector3(-0.6,1.75,-7.8)],
  "cockpit":[Vector3(1.8,1.85,-5.3),Vector3(0,1.7,-9.6)],
  "spine":[Vector3(0,1.85,-1.0),Vector3(0,1.9,12.0)],
  "cabin":[Vector3(-2.85,2.15,8.7),Vector3(-6.2,1.75,12.0)],
  "workshop":[Vector3(-2.9,2.0,5.7),Vector3(-5.6,1.8,1.0)],
  "gallery":[Vector3(2.9,2.0,5.7),Vector3(5.6,1.8,1.0)],
  "wardrobe":[Vector3(3.3,2.0,8.7),Vector3(5.9,1.8,13.0)]}
 for name in points:
  camera.position=points[name][0];camera.look_at(points[name][1])
  await create_timer(0.6).timeout;await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK)
 print("SHIP DESIGN TOUR PASSED");quit()
