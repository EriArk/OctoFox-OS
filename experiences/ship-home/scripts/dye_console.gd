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
var swatch:=ColorRect.new()

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
 offset_left=-385;offset_right=-24;offset_top=-207;offset_bottom=207
 var style:=StyleBoxFlat.new();style.bg_color=Color("#172f35");style.set_corner_radius_all(12)
 style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=14;style.content_margin_bottom=14
 add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",7);add_child(column)
 var heading:=Label.new();heading.text="Colour studio";heading.add_theme_font_size_override("font_size",29);column.add_child(heading)
 for i in 5:
  var b:=Button.new();b.custom_minimum_size.y=38;b.focus_mode=Control.FOCUS_NONE
  column.add_child(b);buttons.append(b);b.pressed.connect(choose.bind(i))
 swatch.custom_minimum_size.y=8;column.add_child(swatch)
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(note)
 var hints:=Label.new();hints.text="↑ ↓ Select   ← → Change   B Close";column.add_child(hints)
 hide()

func open() -> void:
 garment_index=0;channel_index=0;color_index=0;cursor=0;chosen_id="";choice_key=""
 show();refresh();workshop.refresh_workshop()

func close() -> void:
 hide()
 if is_instance_valid(fitting.garment) and fitting.current!=0:fitting.change()
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func garment() -> Dictionary:
 if workshop.garments.is_empty():
  var style:String=Garment.STYLES[maxi(0,fitting.requested-1)]
  return {"id":"","sku":style+".top","colors":{}}
 return workshop.garments[clampi(garment_index,0,workshop.garments.size()-1)]

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
  fitting.requested=Garment.STYLES.find(sku[0])+1
 var key:String=colors[color_index]
 var spec:Dictionary=palette.get(key,{})
 buttons[0].text="‹  "+title+"  ›"
 buttons[1].text="‹  "+(str(channel_names[channel_index]).capitalize() if not channel_names.is_empty() else "Channel")+"  ›"
 buttons[2].text="‹  "+str(spec.get("name","Original finish"))+"  ›"
 var unlocked:bool=key=="original" or key in workshop.inventory.get("palette",[])
 var held:int=workshop.units("pigment",key)
 buttons[3].text="Apply finish" if unlocked else "Unlock colour · 1 cartridge"
 buttons[3].disabled=workshop.busy or workshop.inventory.is_empty() or (str(item.id).is_empty() if unlocked else held<1)
 buttons[4].text="Close"
 for i in buttons.size():buttons[i].modulate=Color("#ffe39d") if i==cursor else Color.WHITE
 swatch.color=Color.from_string(spec.get("hex","#a5ada9"),Color.WHITE)
 note.text=("Original finish" if key=="original" else str(spec.finish).capitalize()+(" · In your palette" if unlocked else " · %d cartridges"%held))
 if workshop.busy:note.text="Updating inventory…"
 elif not workshop.notice.is_empty():note.text+="\n"+workshop.notice
 elif workshop.inventory.is_empty():note.text="Connect your account to use the colour studio."
 paint_preview()

func step(row:int, amount:int) -> void:
 if workshop.busy:return
 workshop.notice=""
 if row==0 and not workshop.garments.is_empty():
  if garment_index+amount>=workshop.garments.size() and not workshop.next_page.is_empty():
   garment_index=workshop.garments.size();workshop.more_garments();return
  # Restore previous part before showing another part of the same set.
  if is_instance_valid(fitting.garment):fitting.restore_colors()
  garment_index=posmod(garment_index+amount,workshop.garments.size());channel_index=0
 elif row==1 and not channel_names.is_empty():channel_index=posmod(channel_index+amount,channel_names.size())
 elif row==2 and not colors.is_empty():color_index=posmod(color_index+amount,colors.size())
 refresh()

func choose(row:int) -> void:
 cursor=row
 if row<3:step(row,1)
 elif row==4:close()
 elif not buttons[3].disabled:
  var key:String=colors[color_index]
  if key!="original" and key not in workshop.inventory.get("palette",[]):
   workshop.commit("activate",{"color":key})
  else:
   workshop.commit("paint",{"item":garment().id,"color":key,"channel":channel_names[channel_index]})

func _input(event:InputEvent) -> void:
 if not is_visible_in_tree() or event is InputEventMouse:return
 if event.is_action_pressed("cancel_ship") or event.is_action_pressed("ui_cancel"):close()
 elif event.is_action_pressed("ui_up",true):cursor=posmod(cursor-1,5);refresh()
 elif event.is_action_pressed("ui_down",true):cursor=posmod(cursor+1,5);refresh()
 elif event.is_action_pressed("ui_left",true):step(cursor,-1)
 elif event.is_action_pressed("ui_right",true):step(cursor,1)
 elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):choose(cursor)
 else:return
 get_viewport().set_input_as_handled()
