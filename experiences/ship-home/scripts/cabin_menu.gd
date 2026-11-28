# SPDX-License-Identifier: GPL-3.0-or-later
extends CenterContainer
signal chosen(id:String)
signal dismissed
const PromptStyle=preload("res://scripts/ship_prompts.gd")
const SYMBOLS=preload("res://assets/cabin/station-symbols.svg")
const DESTINATIONS=[
 ["pilot","Cockpit"],["wardrobe","Wardrobe"],["computer","Ship computer"],
 ["workbench","Fabricator"],["refinery","Refinery"],["tank","Aquarium"],
 ["cargo","Cargo"],["trophies","Trophies"],["decorate","Decorate"]]
var tiles:Array[Button]=[]

func _ready() -> void:
 hide()
 set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 var card:=PanelContainer.new()
 card.add_theme_stylebox_override("panel",PromptStyle.skin(Color("#162e33f8"),12,16,12))
 add_child(card)
 var column:=VBoxContainer.new();card.add_child(column)
 var header:=HBoxContainer.new();column.add_child(header)
 var title:=Label.new();title.text="Ship stations";title.add_theme_font_size_override("font_size",24);title.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(title)
 var close:=Button.new();close.text="×";close.tooltip_text="Close";close.focus_mode=FOCUS_NONE
 close.pressed.connect(func():dismissed.emit());header.add_child(close)
 var grid:=GridContainer.new();grid.columns=3;column.add_child(grid)
 for entry in DESTINATIONS:
  var tile:=Button.new()
  tile.add_theme_stylebox_override("normal",PromptStyle.skin(Color("#264449"),7,8,5))
  var focus:StyleBoxFlat=PromptStyle.skin(Color("#385757"),7,8,5)
  focus.set_border_width_all(2);focus.border_color=Color("#edc682")
  for state in ["hover","pressed"]:tile.add_theme_stylebox_override(state,focus)
  var symbol:=AtlasTexture.new();symbol.atlas=SYMBOLS
  symbol.region=Rect2(tiles.size()*32,0,32,32)
  tile.icon=symbol;tile.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
  tile.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;tile.text=entry[1]
  tile.add_theme_font_size_override("font_size",21);tile.custom_minimum_size=Vector2(180,84)
  tile.pressed.connect(func():chosen.emit(entry[0]));grid.add_child(tile);tiles.append(tile)

func open(decorate:bool) -> void:
 tiles.back().disabled=not decorate
 show();tiles.front().grab_focus()
