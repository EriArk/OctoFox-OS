extends SceneTree
var home
func _initialize() -> void:call_deferred("run")
func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 var descriptor=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():
  var look=JSON.parse_string(FileAccess.get_file_as_string(descriptor))
  look["profile"]="ship-capture"
  home._appearance(look);home.message_time=0
 await create_timer(2).timeout
 home._pause(false);home.walker.walking=false
 var out=OS.get_environment("SHIP_CAPTURE_DIR")
 if out.is_empty():out="/tmp/ship-tour"
 DirAccess.make_dir_recursive_absolute(out)
 var points={"lounge":[Vector3(0,0.1,-1.4),0.0,-0.08],"panorama":[Vector3(2.0,0.1,-7),0.0,0.08],"workshop":[Vector3(-4.5,0.1,4.5),0.0,-0.18],"gallery":[Vector3(4.5,0.1,4.5),0.0,-0.12],"cabin":[Vector3(-4.7,0.1,9),PI,-0.20],"wardrobe":[Vector3(5.5,0.1,9.4),PI,-0.10]}
 var selected=OS.get_environment("SHIP_CAPTURE_ROOMS").split(",",false)
 for name in points:
  if not selected.is_empty() and not name in selected:continue
  var p=points[name];home.walker.position=p[0];home.walker.yaw=p[1];home.walker.pitch=p[2]
  await create_timer(0.6).timeout
  await RenderingServer.frame_post_draw
  var result=root.get_texture().get_image().save_png(out+"/"+name+".png")
  assert(result==OK)
 home.walker.position=Vector3(0,0.1,-2);home.walker.yaw=0;home.walker.pitch=-0.35;home._edit(true)
 await create_timer(0.5).timeout;await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(out+"/decorating.png")==OK)
 print("SHIP TOUR PASSED; objects=",Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"; draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"; static_bytes=",Performance.get_monitor(Performance.MEMORY_STATIC))
 quit()
