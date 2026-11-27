# SPDX-License-Identifier: GPL-3.0-or-later
extends PanelContainer
const Plate=preload("res://scripts/fabricator_plate.gd")
var fitting
var column:=VBoxContainer.new()
var scroll:=ScrollContainer.new()
var cards:=VBoxContainer.new()
var action:=Button.new()
var parts:=Button.new()
signal pieces_requested(row:Dictionary)
var note:=Label.new()
var entries:Array=[]
signal appearance_requested

func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
 offset_left=25;offset_right=342;offset_top=-254;offset_bottom=254
 var panel:=StyleBoxFlat.new();panel.bg_color=Color("#152f34f5");panel.set_corner_radius_all(10)
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:panel.set_content_margin(side,16)
 add_theme_stylebox_override("panel",panel);add_child(column)
 column.add_theme_constant_override("separation",10)
 var heading:=Label.new();heading.text="Wardrobe";heading.add_theme_font_size_override("font_size",26);column.add_child(heading)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
 cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(cards)
 column.add_child(note);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 action.custom_minimum_size.y=46;action.focus_mode=Control.FOCUS_NONE
 action.pressed.connect(activate);column.add_child(action)
 parts.text="Change a piece";parts.custom_minimum_size.y=42;parts.focus_mode=Control.FOCUS_NONE
 parts.pressed.connect(open_parts);column.add_child(parts);hide()

func refresh() -> void:
 if not is_instance_valid(fitting):return
 if not fitting.active:hide();return
 var rows:Array=[["Profile outfit","Equipped",0]]
 if is_instance_valid(fitting.workshop):
  for row in fitting.workshop.saved_looks:
   if row.worn:rows[0]=[row.name,"Equipped",0];break
 var saved:Array=fitting.saved_rows()
 for i in saved.size():rows.append([saved[i].name,"Saved outfit",fitting.LOOKS.size()+i])
 for i in range(1,fitting.LOOKS.size()):
  var count:int=fitting.owned_slots(i).size()
  if count:rows.append([fitting.LOOKS[i],"%d / 4 pieces owned"%count,i])
 if entries!=rows:
  entries=rows
  for b in cards.get_children():cards.remove_child(b);b.queue_free()
  for i in entries.size():
   var b:=Button.new();b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size.y=49
   b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
   b.text="    "+str(entries[i][0])
   var key:int=entries[i][2]
   if key>0 and key<fitting.LOOKS.size():
    b.text="          "+str(entries[i][0])
    var icon:=Plate.new();icon.position=Vector2(6,2);icon.size=Vector2(44,44)
    icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(icon);icon.present(key-1,0,false)
   b.pressed.connect(fitting.select.bind(key));cards.add_child(b)
 var index:=selected_card()
 for i in entries.size():
  var b:Button=cards.get_child(i)
  var skin:=StyleBoxFlat.new()
  skin.bg_color=Color("#36534f") if i==index else Color("#213e42")
  if i==index:skin.set_border_width(SIDE_LEFT,4);skin.border_color=Color("#efd08f")
  skin.set_corner_radius_all(4);b.add_theme_stylebox_override("normal",skin)
 scroll.ensure_control_visible(cards.get_child(index))
 var selected:Dictionary=fitting.selected_look(fitting.requested)
 note.text=str(entries[index][1])
 if is_instance_valid(fitting.workshop) and not fitting.workshop.look_notice.is_empty():note.text=fitting.workshop.look_notice
 if not fitting.preview_error.is_empty():note.text=fitting.preview_error
 var can_edit:=not editable().is_empty()
 parts.visible=can_edit and not selected.is_empty()
 parts.disabled=not parts.visible or not is_instance_valid(fitting.workshop) or fitting.workshop.wearing or fitting.current!=fitting.requested or (not selected.is_empty() and fitting.resolved_key!=selected.id)
 action.text="Wear outfit" if not selected.is_empty() else ("Change a piece" if can_edit else "Garment colours")
 action.disabled=(not can_edit and (fitting.requested==0 or fitting.owned_slots(fitting.requested).is_empty())) or can_edit and (fitting.current!=fitting.requested or fitting.workshop.wearing or fitting.workshop.looks_loading or (not selected.is_empty() and fitting.resolved_key!=selected.id))

func selected_card() -> int:
 for i in entries.size():
  if entries[i][2]==fitting.requested:return i
 return 0

func move(direction:int) -> void:
 if not entries.is_empty():
  fitting.select(entries[posmod(selected_card()+direction,entries.size())][2])

func editable() -> Dictionary:
 if fitting.requested!=0:return fitting.selected_look(fitting.requested)
 if is_instance_valid(fitting.workshop):
  for row in fitting.workshop.saved_looks:
   if row.worn:return row
 return {}

func open_parts() -> void:
 if parts.visible and not parts.disabled:pieces_requested.emit(editable())

func activate() -> void:
 if fitting.returning or action.disabled:return
 var row:Dictionary=fitting.selected_look(fitting.requested)
 if row.is_empty() and not editable().is_empty():pieces_requested.emit(editable())
 elif row.is_empty():appearance_requested.emit()
 else:fitting.workshop.wear_look(row)
