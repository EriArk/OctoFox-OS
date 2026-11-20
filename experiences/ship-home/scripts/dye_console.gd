# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
const Garment=preload("res://scripts/fitting_garment.gd")
var workshop
var fitting
var garment_index:=0
var channel_index:=0
var color_index:=0
var cursor:=0
var chosen_id:=""
var choice_key:=""
var channel_names:Array=[]
var colors:Array=[]
var buttons:Array[Button]=[]
var note:=Label.new()
const COLUMNS=4
var grid:=GridContainer.new()
var color_title:=Label.new()
var swatches:Array[Button]=[]
var scope:=""
var entry_index:=0
var entry_id:=""
var open_next_page:=false
var restore_item:=""

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
 offset_left=-393;offset_right=-24;offset_top=-244;offset_bottom=244
 var style:=StyleBoxFlat.new();style.bg_color=Color("#172f35");style.set_corner_radius_all(12)
 style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=14;style.content_margin_bottom=14
 add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",7);add_child(column)
 var heading:=Label.new();heading.text="Colour studio";heading.add_theme_font_size_override("font_size",29);column.add_child(heading)
 for i in 5:
  if i==2:
   buttons.append(null)
   column.add_child(color_title);grid.columns=COLUMNS;column.add_child(grid)
  else:
   var button:=Button.new();button.custom_minimum_size.y=42;button.focus_mode=Control.FOCUS_NONE;buttons.append(button)
   column.add_child(button);button.pressed.connect(choose.bind(i))
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(note)
 var hints:=Label.new();hints.text="D-pad   Select     A   Confirm     B   Back";column.add_child(hints)
 hide()

func open() -> void:
 entry_index=fitting.requested
 entry_id=fitting.selected_id;open_next_page=false;restore_item=""
 scope=Garment.STYLES[entry_index-1] if entry_index>0 and entry_index<=Garment.STYLES.size() else ""
 garment_index=0;channel_index=0;color_index=0;cursor=0;chosen_id="";choice_key=""
 show();refresh();workshop.refresh_workshop()

func close() -> void:
 hide()
 fitting.restore_colors()
 if not entry_id.is_empty():
  entry_index=0
  var saved:Array=fitting.saved_rows()
  for i in saved.size():
   if saved[i].id==entry_id:entry_index=fitting.LOOKS.size()+i;break
 fitting.select(entry_index)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func pieces() -> Array:
 if scope.is_empty() and not workshop.garments.is_empty():return workshop.garments
 var style:String="traveller" if scope.is_empty() else scope
 var rows:Array=[]
 for slot in Garment.SLOTS:
  var sku:String=style+"."+slot.to_lower()
  var owned:Array=workshop.garments.filter(func(piece):return piece.sku==sku)
  if owned.is_empty():rows.append({"id":"","sku":sku,"colors":{}})
  else:rows.append_array(owned)
 return rows

func garment() -> Dictionary:
 var rows:=pieces()
 return rows[clampi(garment_index,0,rows.size()-1)]

func pick_swatch(index:int) -> void:
 color_index=index;cursor=2;workshop.notice="";refresh()

func show_swatches(palette:Dictionary) -> void:
 while swatches.size()>colors.size():
  var old:Button=swatches.pop_back();grid.remove_child(old);old.queue_free()
 while swatches.size()<colors.size():
  var index:=swatches.size()
  var b:=Button.new();b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size=Vector2(72,45)
  b.pressed.connect(pick_swatch.bind(index));grid.add_child(b);swatches.append(b)
 for i in colors.size():
  var key:String=colors[i]
  var b:=swatches[i]
  var spec:Dictionary=palette.get(key,{})
  var skin:=StyleBoxFlat.new();skin.bg_color=Color.from_string(spec.get("hex","#526967"),Color.GRAY)
  skin.set_corner_radius_all(5)
  skin.set_border_width_all(4 if i==color_index else 1)
  skin.border_color=Color("#ffe39d") if i==color_index and cursor==2 else (Color.WHITE if i==color_index else Color("#77918c"))
  for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,skin)
  b.tooltip_text=spec.get("name","Original finish")
  b.text="↺" if i==0 else ("✓" if key in workshop.inventory.get("palette",[]) else "")
  b.add_theme_color_override("font_color",Color("#183537") if skin.bg_color.get_luminance()>0.36 else Color.WHITE)

func paint_preview() -> void:
 if not visible or not is_instance_valid(fitting.garment) or colors.is_empty() or channel_names.is_empty():return
 var item:=garment()
 if item.is_empty():return
 var sku:=str(item.sku).split(".")
 if fitting.current!=Garment.STYLES.find(sku[0])+1:return
 var selected:Dictionary=item.colors.duplicate()
 selected[channel_names[channel_index]]=colors[color_index]
 fitting.garment.tint(sku[1].capitalize(),selected,workshop.inventory.get("colors",{}))

func refresh() -> void:
 if not visible:return
 var rows:=pieces()
 if restore_item!="" and not workshop.busy:
  var index:=rows.find_custom(func(piece):return piece.id==restore_item)
  if index>=0:garment_index=index
  elif not workshop.next_page.is_empty():
   workshop.more_garments();return
  else:garment_index=0
  restore_item=""
 if open_next_page and not workshop.busy:
  open_next_page=false
  if garment_index>=rows.size() and not workshop.next_page.is_empty():
   open_next_page=true;workshop.more_garments();return
  garment_index=posmod(garment_index,rows.size())
 var item:=garment()
 var palette:Dictionary=workshop.inventory.get("colors",{})
 colors=["original"];colors.append_array(palette.keys())
 color_index=clampi(color_index,0,colors.size()-1)
 channel_names=[]
 var title:="No printed parts"
 if not item.is_empty():
  var sku:=str(item.sku).split(".")
  var slot:=sku[1].capitalize()
  title=Garment.NAMES[sku[0]][Garment.SLOTS.find(slot)]
  if str(item.id).is_empty():title+=" · Preview"
  channel_names=Garment.channels(sku[0],slot)
  channel_index=clampi(channel_index,0,channel_names.size()-1)
  chosen_id=item.id
  if not chosen_id.is_empty():fitting.selected_pieces[item.sku]=item.id
  var identity:String=item.sku+"/"+chosen_id+"/"+str(channel_names[channel_index])
  if identity!=choice_key:
   choice_key=identity
   color_index=maxi(0,colors.find(item.colors.get(channel_names[channel_index],"original")))
  fitting.select(Garment.STYLES.find(sku[0])+1)
 var key:String=colors[color_index]
 var spec:Dictionary=palette.get(key,{})
 buttons[0].text="‹  "+title+"  ›"
 buttons[1].text="‹  "+(str(channel_names[channel_index]).capitalize() if not channel_names.is_empty() else "Channel")+"  ›"
 color_title.text=str(spec.get("name","Original finish"))
 show_swatches(palette)
 var unlocked:bool=key=="original" or key in workshop.inventory.get("palette",[])
 var held:int=workshop.units("pigment",key)
 buttons[3].text="Apply finish" if unlocked else "Unlock colour · 1 cartridge"
 buttons[3].disabled=workshop.busy or workshop.inventory.is_empty() or (str(item.id).is_empty() if unlocked else held<1)
 buttons[4].text="Close"
 for i in [0,1,3,4]:buttons[i].modulate=Color("#ffe39d") if i==cursor else Color.WHITE
 note.text=("Original finish" if key=="original" else str(spec.finish).capitalize()+(" · In your palette" if unlocked else " · %d cartridges"%held))
 if workshop.busy:note.text="Updating inventory…"
 elif not workshop.notice.is_empty():note.text+="\n"+workshop.notice
 elif workshop.inventory.is_empty():note.text="Connect your account to use the colour studio."
 paint_preview()

func step(row:int, amount:int) -> void:
 if workshop.busy:return
 workshop.notice=""
 if row==0:
  var rows:=pieces()
  if garment_index+amount>=rows.size() and not workshop.next_page.is_empty():
   open_next_page=true;garment_index=rows.size();workshop.more_garments();return
  # Restore previous part before showing another part of the same set.
  if is_instance_valid(fitting.garment):fitting.restore_colors()
  garment_index=posmod(garment_index+amount,rows.size());channel_index=0
 elif row==1 and not channel_names.is_empty():channel_index=posmod(channel_index+amount,channel_names.size())
 elif row==2 and not colors.is_empty():color_index=clampi(color_index+amount,0,colors.size()-1)
 refresh()

func choose(row:int) -> void:
 cursor=row
 if row<2:step(row,1)
 elif row==2:cursor=3;refresh()
 elif row==4:close()
 elif not buttons[3].disabled:
  restore_item=garment().id
  var key:String=colors[color_index]
  if key!="original" and key not in workshop.inventory.get("palette",[]):
   workshop.commit("activate",{"color":key})
  else:
   workshop.commit("paint",{"item":garment().id,"color":key,"channel":channel_names[channel_index]})

func vertical(amount:int) -> void:
 if cursor==2:
  var adjacent:=color_index+amount*COLUMNS
  if adjacent>=0 and adjacent<colors.size():
   pick_swatch(adjacent);return
  if amount>0 and color_index/COLUMNS<(colors.size()-1)/COLUMNS:
   pick_swatch(colors.size()-1);return
 cursor=posmod(cursor+amount,5);refresh()

func _input(event:InputEvent) -> void:
 if not is_visible_in_tree() or event is InputEventMouse:return
 if event.is_action_pressed("cancel_ship") or event.is_action_pressed("ui_cancel"):close()
 elif event.is_action_pressed("ui_up",true):vertical(-1)
 elif event.is_action_pressed("ui_down",true):vertical(1)
 elif event.is_action_pressed("ui_left",true):step(cursor,-1)
 elif event.is_action_pressed("ui_right",true):step(cursor,1)
 elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):choose(cursor)
 else:return
 get_viewport().set_input_as_handled()
