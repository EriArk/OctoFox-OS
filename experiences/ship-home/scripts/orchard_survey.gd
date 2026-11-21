# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
const Catch=preload("res://scripts/shore_catch.gd")
const NOTES={"glassfin":"A short cast reaches the glassfin shoal in the reed shallows.","loach":"Copper loaches take the bait beyond the reed shelf. Cast farther from the pier."}
var home
var camera:=Camera3D.new()
var heading:=Label.new()
var body:=Label.new()
var primary:=Button.new()
var done:=false
var slide:=-1
var lens:=ColorRect.new()

func configure(ship,layer:CanvasLayer) -> void:
 home=ship;layer.add_child(self)
 layer.add_child(lens);lens.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 lens.offset_left=-130;lens.offset_right=130;lens.offset_top=30;lens.offset_bottom=290;lens.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var optic:=ShaderMaterial.new();optic.shader=preload("res://shaders/reference_slide.gdshader");lens.material=optic;lens.hide()
 home.add_child(camera);home.Exterior.configure_camera(camera,false);camera.fov=49
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 offset_left=-350;offset_right=350;offset_top=-236;offset_bottom=-28
 add_theme_stylebox_override("panel",home.computer.style(Color("182e32"),Color("84b8a9")))
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);add_child(box)
 heading.text="Dr. Neri   ·   Field biology";home.computer.typeface(heading,27,home.computer.GOLD);box.add_child(heading)
 body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;home.computer.typeface(body,22,home.computer.TEXT)
 body.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(body)
 var actions:=HBoxContainer.new();box.add_child(actions)
 for button:Button in [primary,home.computer.button("Back",close)]:
  actions.add_child(button);button.custom_minimum_size=Vector2(130,44);button.focus_mode=Control.FOCUS_NONE
 primary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;primary.add_theme_font_size_override("font_size",21);primary.pressed.connect(activate)
 hide()

func candidate() -> Dictionary:
 for fish in home.store.fish:
  if fish.site==1 and fish.place in ["bag","tank"] and not home.store.observations.has(fish.species):return fish
 return {}

func next_site() -> int:
 return 1 if home.store.survey_started and candidate().is_empty() and home.store.observations.size()<NOTES.size() else home.flight.lab.SITE

func brief() -> String:
 if not home.store.survey_started:return "Meet Dr. Neri by the aquarium on Lantern Biostation."
 if home.store.observations.size()==NOTES.size():return "Echo Orchard survey complete. Both aquarium plates are aboard."
 if not candidate().is_empty():return "Bring your ship to Dr. Neri. A specimen aboard is ready to document."
 return "Fish from the pier on Echo Orchard. Keep the catch and return to Dr. Neri."

func open() -> void:
 heading.text="Dr. Neri   ·   Field biology"
 done=false;home.walker.walking=false;home.walker.velocity=Vector3.ZERO
 var speaker:Vector3=home.flight.lab.keeper.global_position
 camera.global_position=speaker+Vector3(-1.48,1.52,-1.75)
 camera.look_at(speaker+Vector3(0,0.92,0));camera.make_current()
 home.walker.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;show()
 var fish:=candidate()
 if not home.store.survey_started:
  body.text="Will you survey Echo Orchard for me? Keep a fish from the reed pier and bring it back. I’ll record its markings and engrave a species plate for your aquarium."
  primary.text="Accept survey"
 elif not fish.is_empty():
  body.text="A %s from Echo Orchard! May I record this specimen? It stays aboard your ship."%Catch.title(fish)
  primary.text="Record observation"
 else:
  body.text=brief()
  primary.text="Mark Echo Orchard" if next_site()==1 else "Finish conversation"

func inspect() -> void:
 var scope:Vector3=home.flight.lab.to_global(home.flight.lab.SCOPE)
 home.walker.walking=false;home.walker.velocity=Vector3.ZERO
 camera.global_position=scope+Vector3(-0.73,0.94,-1.10);camera.look_at(scope+Vector3(0,0.36,0));camera.make_current()
 home.walker.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;show();lens.show();show_slide(0)

func show_slide(index:int) -> void:
 slide=index;lens.material.set_shader_parameter("loach",slide==1)
 heading.text="Reference collection   ·   40×"
 if slide==0:body.text="Glassfin   /   Scale impression\nWide, translucent scales. Growth rings are visible in transmitted light."
 else:body.text="Copper loach   /   Scale impression\nSmall scales sit close together. Compare the spacing of the growth rings."
 primary.text="Next slide"

func activate() -> void:
 if slide>=0:show_slide(1-slide);return
 if done:close();return
 var store:ShipLayoutStore=home.store
 if not store.survey_started:
  store.survey_started=true
  if not store.save(home.rows):
   store.survey_started=false;body.text=store.error if store.error!="" else "Field atlas is read-only.";return
  home.flight.avionics.navigate_to(1)
  body.text="I’ve marked Echo Orchard. Try a short cast by the reeds, then a longer one past the shelf."
 else:
  var fish:=candidate()
  if fish.is_empty():
   if next_site()==1:home.flight.avionics.navigate_to(1)
   close();return
  store.observations[fish.species]=fish.duplicate(true)
  if not store.save(home.rows):
   store.observations.erase(fish.species);body.text=store.error if store.error!="" else "Field atlas is read-only.";return
  body.text="%s entered in your field atlas. Your aquarium now carries its species plate.\n%s"%[Catch.SPECIES[fish.species][0],NOTES[fish.species]]
 done=true;primary.text="Finish conversation"

func close() -> void:
 if not visible:return
 slide=-1;lens.hide();hide();home.walker.show();home.walker.camera.make_current();home.walker.walking=not home.paused
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _input(event:InputEvent) -> void:
 if not is_visible_in_tree() or event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or event.is_action_pressed("pause_ship"):return
 if event.is_action_pressed("cancel_ship"):close()
 elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):activate()
 get_viewport().set_input_as_handled()
