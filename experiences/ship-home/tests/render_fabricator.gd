# SPDX-License-Identifier: GPL-3.0-or-later
## Regenerate the static catalogue plate from the four authored meshes in each set.
extends SceneTree
const Garment = preload("res://scripts/fitting_garment.gd")
const CELL := 320

func _initialize() -> void:
 render.call_deferred()

func render() -> void:
 var view:=SubViewport.new()
 view.size=Vector2i(CELL,CELL);view.world_3d=World3D.new()
 view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_4X
 root.add_child(view)
 var env:=Environment.new()
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color.WHITE;env.ambient_light_energy=0.86
 view.world_3d.environment=env
 var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-30,28,0)
 key.light_energy=1.05;view.add_child(key)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;view.add_child(camera)
 var atlas:=Image.create(CELL*5,CELL*3,false,Image.FORMAT_RGBA8)
 for row in Garment.STYLES.size():
  var model:Node3D=Garment.MODELS[Garment.STYLES[row]].instantiate();view.add_child(model)
  for col in 5:
   var bounds:=AABB()
   var first:=true
   for node:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
    node.visible=col==0 or node.name==Garment.SLOTS[col-1]
    if node.visible:
     var box:=node.global_transform*node.get_aabb()
     bounds=box if first else bounds.merge(box);first=false
   var center:=bounds.get_center()
   camera.position=center+Vector3(0.88,0.55,2.6);camera.look_at(center)
   var inv:=camera.global_transform.affine_inverse()
   var rect:=Rect2()
   for i in 8:
    var pos:=inv*bounds.get_endpoint(i)
    var xy:=Vector2(pos.x,pos.y)
    rect=Rect2(xy,Vector2.ZERO) if i==0 else rect.expand(xy)
   camera.size=maxf(rect.size.x,rect.size.y)*1.10
   view.render_target_update_mode=SubViewport.UPDATE_ONCE
   await process_frame;await RenderingServer.frame_post_draw
   var plate:=view.get_texture().get_image()
   plate.convert(Image.FORMAT_RGBA8);plate.fix_alpha_edges()
   atlas.blit_rect(plate,Rect2i(0,0,CELL,CELL),Vector2i(col,row)*CELL)
  model.free()
 var result:=atlas.save_png("res://assets/fabricator/garments.png")
 quit(0 if result==OK else 1)
