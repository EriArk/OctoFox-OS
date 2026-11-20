# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
const Garment=preload("res://scripts/fitting_garment.gd")
var failures:Array=[]
func check(ok:bool,reason:String) -> void:
 if not ok:failures.append(reason);push_error(reason)
func press(id:int) -> void:
 for down in [true,false]:
  var e:=InputEventJoypadButton.new();e.button_index=id;e.pressed=down;root.push_input(e,true)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var home=load("res://main.tscn").instantiate();root.add_child(home)
 var client=home.avatar_client
 client.disconnect_host()
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():
  check(home.walker.install_avatar(JSON.parse_string(FileAccess.get_file_as_string(descriptor))),"SDK character loads")
 home._pause(false)
 var colors={"sea-glass":{"name":"Sea glass","finish":"satin","hex":"#479b91"},"rose-gold":{"name":"Rose gold","finish":"metallic","hex":"#c78d75"},"aurora":{"name":"Aurora violet","finish":"iridescent","hex":"#7966c2"}}
 client.supported=true;client.timed_prints=true
 var fab=home.fabricator
 var recipes:Dictionary={}
 for style in fab.REQUIREMENTS:
  recipes[style]={}
  for i in 4:recipes[style][Garment.SLOTS[i].to_lower()]=fab.REQUIREMENTS[style][i]
 var data={"revision":"7","colors":colors,"recipes":recipes,"palette":["sea-glass"],"stock":[{"kind":"blueprint","sku":"traveller","units":1},{"kind":"material","sku":"Cotton","units":6},{"kind":"material","sku":"Aluminium","units":1},{"kind":"pigment","sku":"rose-gold","units":1}]}
 var item={"id":"9bdb9bc5-5ad0-435b-97ee-c178f849adfc","sku":"traveller.top","colors":{"trim":"sea-glass"}}
 data["print_hours"]={"traveller":{"top":6,"bottom":2,"boots":4,"hat":2}}
 data["prints"]={}
 var receive=func(payload):
  client._packet({"id":str(client.serial),"result":payload})
 home.walker.position=Vector3(-2.55,0.1,2.45);press(JOY_BUTTON_A)
 receive.call(data);receive.call({"items":[item],"next":null})
 check(fab.amounts[0].text=="6 / 6" and not fab.print_button.disabled,"Actual stock enables print")
 press(JOY_BUTTON_A);press(JOY_BUTTON_A)
 check(client.last_action=="print" and client.busy,"Controller prints once")
 for lot in data.stock:
  if lot.kind=="material":lot.units=0
 data.prints={"traveller.top":{"id":item.id,"remaining_seconds":21600,"quantity":1}}
 receive.call({"job_id":item.id});receive.call(data);receive.call({"items":[],"next":null})
 check(fab.part_label.text.contains("06:00:00"),"Server duration appears for running print")
 var print_capture:=OS.get_environment("SHIP_PRINT_CAPTURE")
 if not print_capture.is_empty() and DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(print_capture)==OK,"Write running print capture")
 press(JOY_BUTTON_B);press(JOY_BUTTON_A)
 data.prints["traveller.top"].remaining_seconds=0
 receive.call(data);receive.call({"items":[],"next":null})
 check(fab.print_button.text=="Collect part","Completed print survives reopening")
 press(JOY_BUTTON_A);press(JOY_BUTTON_A)
 check(client.last_action=="collect","Controller collects the finished part")
 data.prints={}
 receive.call({"item_id":item.id});receive.call(data);receive.call({"items":[item],"next":null})
 press(JOY_BUTTON_B);home.walker.position=ShipInterior.BOOTH+Vector3(-0.65,0.08,-0.65)
 press(JOY_BUTTON_A);press(JOY_BUTTON_Y)
 receive.call(data);receive.call({"items":[item],"next":null})
 check(home.dye.visible,"Y opens the colour studio")
 for i in 65:await physics_frame
 var piece:MeshInstance3D=home.fitting.garment.get_node("Top")
 var owned:Dictionary=item.colors.duplicate()
 press(JOY_BUTTON_DPAD_DOWN);press(JOY_BUTTON_DPAD_DOWN)
 press(JOY_BUTTON_DPAD_RIGHT);press(JOY_BUTTON_DPAD_RIGHT)
 var metal:=false
 for i in piece.mesh.get_surface_count():
  var m=piece.get_surface_override_material(i)
  if m is StandardMaterial3D and m.metallic>0.8:metal=true
 check(metal and item.colors==owned,"Metallic preview uses independent surfaces")
 press(JOY_BUTTON_DPAD_DOWN);press(JOY_BUTTON_A)
 check(client.last_action=="activate","Locked colour consumes a cartridge only on confirmation")
 receive.call({});data.palette.append("rose-gold");receive.call(data);receive.call({"items":[item],"next":null})
 press(JOY_BUTTON_A);check(client.last_action=="paint","Unlocked colour applies separately")
 receive.call({});receive.call(data);receive.call({"items":[item],"next":null})
 press(JOY_BUTTON_DPAD_UP);press(JOY_BUTTON_DPAD_RIGHT)
 var pearl:=false
 for i in piece.mesh.get_surface_count():
  if piece.get_surface_override_material(i) is ShaderMaterial:pearl=true
 check(pearl,"Iridescent preview uses angle-dependent shader")
 var capture:=OS.get_environment("SHIP_WORKSHOP_CAPTURE")
 if not capture.is_empty() and DisplayServer.get_name()!="headless":
  await process_frame;await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(capture)==OK,"Write colour studio capture")
 press(JOY_BUTTON_B);check(not home.dye.visible and home.fitting.active,"B returns to fitting booth")
 for style in Garment.STYLES:
  for slot in Garment.SLOTS:
   check(not Garment.channels(style,slot).is_empty(),"Selectable surfaces in "+style+" "+slot)
 print("WORKSHOP ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
