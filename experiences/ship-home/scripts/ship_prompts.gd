# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## The station name passed to the bubble also guards a tap released after moving away.
signal used(station:String)
const INK:=Color("#173136")
const PAPER:=Color("#f4efdd")
const GOLD:=Color("#edd099")
var gamepad:=false
var bubble:=Button.new()
var tail:=Polygon2D.new()
var strip:=PanelContainer.new()
var commands:=HBoxContainer.new()
var mark:Label
var station:=""
var pressed_station:=""
var last_actions:Array=[]
var strip_pad:=false

func skin(color:Color,radius:int,horizontal:int,vertical:int) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=color;style.set_corner_radius_all(radius)
 style.content_margin_left=horizontal;style.content_margin_right=horizontal
 style.content_margin_top=vertical;style.content_margin_bottom=vertical
 return style

func _ready() -> void:
 set_anchors_and_offsets_preset(PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE
 gamepad=not Input.get_connected_joypads().is_empty()
 tail.polygon=PackedVector2Array([Vector2(-7,-1),Vector2(7,-1),Vector2(0,7)])
 tail.color=INK;tail.hide();add_child(tail)
 bubble.focus_mode=FOCUS_NONE;bubble.mouse_default_cursor_shape=CURSOR_POINTING_HAND
 var base:=skin(INK,9,14,8);base.content_margin_left=47
 base.shadow_color=Color(0,0,0,0.25);base.shadow_size=2
 for state in ["normal","hover","pressed"]:bubble.add_theme_stylebox_override(state,base)
 bubble.add_theme_font_size_override("font_size",19)
 bubble.add_theme_color_override("font_color",PAPER)
 bubble.custom_minimum_size.y=42;bubble.hide();add_child(bubble)
 mark=Label.new();mark.mouse_filter=MOUSE_FILTER_IGNORE;mark.position=Vector2(9,8);bubble.add_child(mark)
 bubble.button_down.connect(func():pressed_station=station)
 bubble.pressed.connect(func():if station!="" and pressed_station==station:used.emit(station))
 strip.mouse_filter=MOUSE_FILTER_IGNORE;strip.add_theme_stylebox_override("panel",skin(Color("#14292eec"),5,12,6))
 add_child(strip);strip.hide()
 commands.mouse_filter=MOUSE_FILTER_IGNORE;commands.add_theme_constant_override("separation",18);strip.add_child(commands)

func _input(event:InputEvent) -> void:
 if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>0.35):
  gamepad=true
 elif event is InputEventKey or (event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION):
  gamepad=false
 elif event is InputEventMouseMotion and event.device!=InputEvent.DEVICE_ID_EMULATION and event.relative.length_squared()>4:
  gamepad=false

func glyph(action:String) -> String:
 match action:
  "vertical":return "↕"
  "horizontal":return "↔"
  "turn":return "RS"
  "throttle":return "RT LT" if gamepad else "[ ]"
  "tab_pair":return "LB RB" if gamepad else "[ ]"
  "rotation":return "← →" if gamepad else "Q E"
 for event in InputMap.action_get_events(action):
  if gamepad and event is InputEventJoypadButton:
   return str({JOY_BUTTON_A:"B",JOY_BUTTON_B:"A",JOY_BUTTON_X:"Y",JOY_BUTTON_Y:"X"}.get(event.button_index,""))
  if not gamepad and event is InputEventKey:
   return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode).replace("Escape","Esc")
 return ""

func badge(label:Label,action:String) -> void:
 var symbol:=glyph(action)
 label.text=symbol;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.custom_minimum_size=Vector2(26,26)
 label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",INK)
 var round_button:=gamepad and symbol in ["A","B","X","Y"]
 label.add_theme_stylebox_override("normal",skin(GOLD,14 if round_button else 4,4,1))
 label.reset_size()

func clear_world() -> void:
 station="";pressed_station="";bubble.hide();tail.hide()

func show_world(id:String,caption:String,camera:Camera3D,at:Vector3,character:Vector3) -> void:
 if id!=station or caption!=bubble.text:
  pressed_station=""
  bubble.text=caption;bubble.reset_size()
 station=id
 if mark.text!=glyph("interact"):badge(mark,"interact")
 var safe:=Rect2(Vector2.ZERO,size).grow(-9)
 var tip:Vector2
 for point in [at,character]:
  if camera.is_position_behind(point):continue
  tip=camera.unproject_position(point)
  if not safe.has_point(tip):continue
  var top:=tip.y-bubble.size.y-8
  if top<safe.position.y:continue
  bubble.position=Vector2(clampf(tip.x-bubble.size.x/2,safe.position.x,safe.end.x-bubble.size.x),top).round()
  tail.position=Vector2(clampf(tip.x,bubble.position.x+9,bubble.position.x+bubble.size.x-9),bubble.position.y+bubble.size.y)
  bubble.show();tail.show();return
 clear_world()

func actions(rows:Array) -> void:
 strip.visible=not rows.is_empty()
 if rows.is_empty():return
 if rows!=last_actions or strip_pad!=gamepad:
  last_actions=rows.duplicate();strip_pad=gamepad
  for node in commands.get_children():commands.remove_child(node);node.queue_free()
  for row in rows:
   var pair:=HBoxContainer.new();pair.mouse_filter=MOUSE_FILTER_IGNORE;pair.add_theme_constant_override("separation",6)
   var key:=Label.new();badge(key,row[0]);pair.add_child(key)
   var caption:=Label.new();caption.text=row[1];caption.add_theme_font_size_override("font_size",17);caption.add_theme_color_override("font_color",PAPER);pair.add_child(caption)
   commands.add_child(pair)
  strip.reset_size()
 var factor:=minf(1.0,maxf(1.0,size.x-24)/strip.size.x)
 strip.scale=Vector2.ONE*factor
 strip.position=(size-strip.size*factor-Vector2(18,12)).round()
