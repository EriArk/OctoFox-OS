# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
var home
var errors:Array[String]=[]

func check(value:bool,reason:String) -> void:
 if not value:errors.append(reason);push_error(reason)

func pad(button:int) -> void:
 for down in [true,false]:
  var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=down
  root.push_input(event,true)

func key(code:Key) -> void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
  root.push_input(event,true)

func capture(name:String) -> void:
 var out:=OS.get_environment("SHIP_CAPTURE_DIR")
 if out.is_empty():return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"Save screenshot")

func settle() -> void:
 for i in 5:await physics_frame
 for i in 2:await process_frame

func _initialize() -> void:run.call_deferred()

func run() -> void:
 home=load("res://main.tscn").instantiate();root.add_child(home)
 home.avatar_client.disconnect_host()
 var descriptor:=OS.get_environment("SHIP_TEST_DESCRIPTOR")
 if not descriptor.is_empty():
  home.fitting.live_descriptor=JSON.parse_string(FileAccess.get_file_as_string(descriptor))
  check(home.walker.install_avatar(home.fitting.live_descriptor),"Show SDK character")
 home._pause(false);home.message_time=0
 var hud=home.prompts
 home.walker.position=Vector3(0,0.08,0);await settle()
 check(not hud.bubble.visible and not hud.strip.visible and not home.dot.visible and not home.status.visible,"Quiet exploration")
 key(KEY_F);await settle()
 check(home.message_time==0,"No tutorial on an empty interaction")
 home.walker.position=Vector3(-2.55,0.08,2.45);home.walker.yaw=0.44;await settle()
 check(hud.station=="workbench" and hud.bubble.visible and hud.mark.text=="F","Nearby keyboard action")
 pad(JOY_BUTTON_LEFT_SHOULDER);await settle()
 check(hud.mark.text=="A" and hud.bubble.text=="Use fabricator","Controller badge follows live input")
 await capture("interaction")
 pad(JOY_BUTTON_B);await settle()
 check(home.fabricator.visible and not hud.bubble.visible and hud.strip.visible,"Replace bubble with station actions")
 check(["interact","Choose part"] in hud.last_actions,"Blueprint selection action")
 pad(JOY_BUTTON_B);await settle()
 check(not ["interact","Print part"] in hud.last_actions,"Missing materials cannot advertise Print")
 key(KEY_BRACKETRIGHT);await settle()
 check(not hud.gamepad and ["vertical","Cartridge"] in hud.last_actions and hud.glyph("cancel_ship")=="Esc","Tab and input family change while the panel consumes input")
 pad(JOY_BUTTON_LEFT_SHOULDER);await settle();await capture("fabricator-actions")
 pad(JOY_BUTTON_A);await settle()
 check(not hud.strip.visible and hud.station=="workbench","Restore world prompt after closing station")
 home._pause(true);await settle()
 check(not hud.bubble.visible and not hud.strip.visible,"Pause hides prompts")
 home._pause(false);home.walker.position=Vector3(0,0.08,-2.35);home.walker.yaw=0;await settle()
 check(hud.station=="pilot","Seat prompt")
 pad(JOY_BUTTON_B);await settle()
 check(home.walker.seated and not hud.bubble.visible and ["cancel_ship","Hold to stand"] in hud.last_actions and ["interact","Launch"] in hud.last_actions,"Docked pilot can launch or stand")
 key(KEY_ESCAPE);await settle()
 home.walker.position=ShipInterior.BOOTH+Vector3(-0.65,0.08,-0.65);await settle()
 check(hud.station=="wardrobe","Wardrobe prompt from any camera heading")
 pad(JOY_BUTTON_B);await settle()
 check(home.cards.visible and not hud.bubble.visible and ["cancel_ship","Leave"] in hud.last_actions,"Wardrobe actions")
 home.avatar_client.garments=[{"id":"test-cloak","sku":"traveller.top","colors":{}}]
 pad(JOY_BUTTON_X);await settle()
 check(home.dye.visible and ["cancel_ship","Back"] in hud.last_actions and not ["cancel_ship","Leave"] in hud.last_actions,"Colour studio owns its footer")
 pad(JOY_BUTTON_A);await settle();pad(JOY_BUTTON_A)
 for i in 100:await physics_frame
 home.walker.position=Vector3(-1.42,0.08,4.58);await settle()
 check(hud.station=="cabin","Display shelf prompt")
 home.walker.position=Vector3(ShipInterior.LIFT.x,0.08,ShipInterior.LIFT.y);await settle()
 check(hud.station=="lift" and hud.bubble.text=="Go below","Lift direction on main deck")
 pad(JOY_BUTTON_B);await settle()
 check(home.riding and not hud.bubble.visible and not hud.strip.visible,"Lift transit")
 for i in 120:await physics_frame
 check(hud.station=="lift" and hud.bubble.text=="Go upstairs","Lift direction on lower deck")
 print("SHIP PROMPTS: ","PASSED" if errors.is_empty() else errors)
 quit(0 if errors.is_empty() else 1)
