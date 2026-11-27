# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
const FIELDS=["top","bottom","shoes","headwear","socks"]
const LABELS=["Top","Bottom","Shoes","Headwear","Socks"]
var fitting
var client
var look:Dictionary
var field:=0
var item:=0
var options:Array=[]
var ticket:=0
var wanted:=""
var displayed:=""
var title:=Label.new()
var status:=Label.new()
var slot_button:=Button.new()
const ICONS=["ankle-socks", "base-shorts", "canvas-shoes", "crew-socks", "denim-breeches", "denim-breeches-womens", "everyday-tee", "golf-cap", "golf-shoes-classic", "golf-shoes-sport", "golf-shorts", "golf-visor", "mage.boots", "mage.bottom", "mage.hat", "mage.top", "merchant.boots", "merchant.bottom", "merchant.hat", "merchant.top", "pleated-skirt", "polo-short-sleeve", "polo-sleeveless", "racing-boots", "racing-helmet", "racing-suit", "rose-racing-boots", "rose-racing-helmet", "rose-racing-suit", "sandals", "sundress", "tank", "traveller.boots", "traveller.bottom", "traveller.hat", "traveller.top"]
const PIECES=preload("res://assets/wardrobe-pieces.webp")
var tiles:=GridContainer.new()
var tile_buttons:Array[Button]=[]
var apply:=Button.new()
var debounce:=Timer.new()
var cursor:=0
var saving:=false

func _ready() -> void:
 debounce.one_shot=true;debounce.wait_time=0.12;add_child(debounce);debounce.timeout.connect(request_preview)
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
 offset_left=-448;offset_right=-24;offset_top=-243;offset_bottom=243
 var skin:=StyleBoxFlat.new();skin.bg_color=Color("#172f35");skin.set_corner_radius_all(10)
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:skin.set_content_margin(side,18)
 add_theme_stylebox_override("panel",skin)
 var column:=VBoxContainer.new();add_child(column);column.add_theme_constant_override("separation",12)
 title.add_theme_font_size_override("font_size",26);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;column.add_child(title)
 for button in [slot_button,apply]:
  button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size.y=48;column.add_child(button)
 column.add_child(tiles);column.move_child(tiles,2);tiles.columns=3
 for n in 6:
  var button:=Button.new()
  button.focus_mode=Control.FOCUS_NONE;button.expand_icon=true;button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
  button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;button.custom_minimum_size=Vector2(118,77)
  button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.add_theme_font_size_override("font_size",13);button.pressed.connect(choose_tile.bind(n))
  tiles.add_child(button);tile_buttons.append(button)
 slot_button.pressed.connect(step.bind(0,1));apply.pressed.connect(save)
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
 var back:=Button.new();back.text="Back";back.focus_mode=Control.FOCUS_NONE
 back.custom_minimum_size.y=40;back.pressed.connect(close);column.add_child(back)
 hide()

func open(row:Dictionary) -> void:
 if row.is_empty() or fitting.returning:return
 look=row;field=0;cursor=0;saving=false;title.text=row.name;show()
 fitting.editing_parts=true;load_field()

func load_field() -> void:
 options=[];item=0;wanted="";displayed="";ticket+=1;status.text="Loading pieces…"
 client.get_parts(look,FIELDS[field],ticket);refresh()

func receive(id:int,items:Array,error:String) -> void:
 if not visible or ticket!=id:return
 options=items;item=0
 if options.is_empty():
  status.text="No pieces available" if error.is_empty() else error.replace("_"," ").capitalize()
  refresh();return
 for i in options.size():
  if options[i].id==equipped_piece():item=i;break
 preview()

func equipped_piece() -> String:
 var appearance:Dictionary=look.recipe.appearance
 return appearance.get("equipment",{}).get(FIELDS[field],{}).get("id",appearance.get(FIELDS[field],""))

func preview() -> void:
 wanted="part/%d/%d"%[ticket,item];displayed=""
 status.text="Previewing…";refresh();debounce.start()

func request_preview() -> void:
 if visible and debounce.is_stopped() and not wanted.is_empty() and client.resolving_key.is_empty():
  if not client.resolve_recipe(options[item].recipe,wanted):status.text="Preview unavailable";refresh()

func resolved(key:String,descriptor:Dictionary) -> void:
 if not visible:return
 if key!=wanted:request_preview();return
 var selected:=func():return visible and fitting.active and not fitting.returning and key==wanted
 var ok:bool=await fitting.install_preview(descriptor,selected)
 if not selected.call():return
 if ok:
  fitting.preview_installed=true;displayed=key;status.text=""
 else:status.text="Preview unavailable"
 refresh()

func failed(key:String,error:String) -> void:
 if not visible:return
 if key!=wanted:request_preview();return
 status.text=error.replace("_"," ").capitalize();refresh()

func step(row:int,direction:int) -> void:
 if saving:return
 cursor=row
 if row==0:field=posmod(field+direction,FIELDS.size());load_field()
 elif row==1 and not options.is_empty():item=posmod(item+direction,options.size());preview()
 else:refresh()

func refresh() -> void:
 slot_button.text="‹   "+LABELS[field]+"   ›"
 for n in tile_buttons.size():
  var button:=tile_buttons[n]
  var index:=item-item%6+n
  button.visible=index<options.size()
  if not button.visible:continue
  var option:Dictionary=options[index]
  var sku:String=option.recipe.get("appearance",{}).get(FIELDS[field],option.id)
  var icon_index:=ICONS.find(sku)
  if button.get_meta("sku","")!=sku:
   button.set_meta("sku",sku);button.icon=null
   if icon_index>=0:
    var region:=AtlasTexture.new();region.atlas=PIECES
    region.region=Rect2((icon_index%6)*96,floori(icon_index/6.0)*96,96,96);button.icon=region
  button.text=str(option.name);button.tooltip_text=button.text
  button.modulate=Color("#ffe39d") if index==item and cursor==1 else Color.WHITE

 apply.text="Save and wear"
 apply.disabled=saving or client.wearing or client.looks_loading or wanted=="" or displayed!=wanted or options.is_empty() or options[item].id==equipped_piece()
 slot_button.modulate=Color("#ffe39d") if cursor==0 else Color.WHITE
 apply.modulate=Color("#ffe39d") if cursor==2 else Color.WHITE

func choose_tile(n:int) -> void:
 if saving:return
 cursor=1;item=item-item%6+n;preview()

func vertical(direction:int) -> void:
 if cursor==1 and item+direction*3>=0 and item+direction*3<options.size():
  item+=direction*3;preview()
 else:
  cursor=posmod(cursor+direction,3);refresh()

func action_hints() -> Array:
 var actions:Array=[["vertical","Navigate"]]
 if cursor==0 and not saving:actions.append(["horizontal","Slot"])
 elif cursor==1 and not saving and options.size()>1:actions.append(["horizontal","Piece"])
 elif cursor==2 and not apply.disabled:actions.append(["interact",apply.text])
 actions.append(["cancel_ship","Back"])
 return actions

func save() -> void:
 if apply.disabled:return
 saving=true;status.text="Saving outfit…"
 client.wear_look(look,FIELDS[field],options[item].id);refresh()

func sync() -> void:
 if not visible or not saving or client.wearing:return
 if client.look_notice=="Outfit equipped":close()
 else:saving=false;status.text=client.look_notice;refresh()

func close() -> void:
 if not visible:return
 hide();ticket+=1;wanted="";fitting.editing_parts=false
 fitting.restore_avatar();fitting.current=-1
 fitting.selection_changed.emit()

func _input(event:InputEvent) -> void:
 if not is_visible_in_tree() or event is InputEventMouse:return
 if event.is_action_pressed("cancel_ship") or event.is_action_pressed("ui_cancel"):close()
 elif event.is_action_pressed("ui_up",true):vertical(-1)
 elif event.is_action_pressed("ui_down",true):vertical(1)
 elif event.is_action_pressed("ui_right",true):step(cursor,1)
 elif event.is_action_pressed("ui_left",true):step(cursor,-1)
 elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
  if cursor==2:save()
  else:step(cursor,1)
 else:return
 get_viewport().set_input_as_handled()
