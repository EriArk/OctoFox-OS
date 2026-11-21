# SPDX-License-Identifier: GPL-3.0-or-later
extends ColorRect
signal dismissed
const Garment = preload("res://scripts/fitting_garment.gd")
const Mine=preload("res://scripts/ore_outcrop.gd")
const Garden=preload("res://scripts/botanical_garden.gd")
const Plate = preload("res://scripts/fabricator_plate.gd")
const MATERIALS = ["Cotton","Plastic","Aluminium","Steel"]
const PARTS = ["Top","Bottom","Footwear","Headwear"]
# Preview quantities in cartridge units. Never used to authorize a print or grant an item.
const REQUIREMENTS = {
 "traveller":[{"Cotton":6,"Aluminium":1},{"Cotton":4},{"Plastic":3,"Steel":1},{"Cotton":2,"Aluminium":1}],
 "mage":[{"Cotton":7,"Aluminium":2},{"Cotton":4},{"Plastic":3,"Aluminium":1},{"Cotton":3,"Plastic":1}],
 "merchant":[{"Cotton":5,"Steel":1},{"Cotton":4},{"Plastic":3,"Steel":1},{"Cotton":2}]
}
const CANVAS = Vector2(1280,720)
const BG = Color("#10282d")
const SURFACE = Color("#1d373b")
const SELECTED = Color("#334946")
const LINE = Color("#395451")
const IVORY = Color("#f4eddc")
const MUTED = Color("#b3c3bb")
const GOLD = Color("#e6c684")
var workshop
var ship:Node
var processor:=false
var station_title:Label
var ore_index:=0
var pigment_index:=0
var store_sample_button:Button
var next_tick:=0
var last_ready:Dictionary={}
var has_materials:=false
var sheet:=Control.new()
var page:=0
var blueprint:=0
var part:=0
var material_index:=0
var on_parts:=false
var stick:=Vector2i.ZERO
var tabs:Array[Button]=[]
var list:Array[Button]=[]
var thumbs:Array[Control]=[]
var names:Array[Label]=[]
var subtitles:Array[Label]=[]
var parts:Array[Button]=[]
var rows:Array[Label]=[]
var amounts:Array[Label]=[]
var ingredients:Array[Control]=[]
var art=Plate.new()
var group_label:Label
var part_label:Label
var heading:Label
var section:Label
var columns:Label
var quantity_heading:Label
var caption:Label
var note:Label
var print_button:Button
var bold_font:=FontVariation.new()

func block(rect:Rect2, tone:Color) -> void:
 var panel:=ColorRect.new();panel.color=tone
 place(sheet,panel,rect);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE

func place(parent:Control,node:Control,rect:Rect2) -> void:
 parent.add_child(node);node.position=rect.position;node.size=rect.size
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE

func label(parent:Control, value:String, rect:Rect2, points:int, tone:=IVORY, bold:=false) -> Label:
 var node:=Label.new()
 node.text=value;node.add_theme_font_size_override("font_size",points)
 node.add_theme_color_override("font_color",tone)
 if bold:node.add_theme_font_override("font",bold_font)
 node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 place(parent,node,rect);return node

func style(fill:Color, edge:Color) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=fill;box.set_border_width_all(1)
 box.border_color=edge;box.set_corner_radius_all(5)
 return box

func button(value:String, rect:Rect2, action:Callable) -> Button:
 var node:=Button.new();node.text=value
 place(sheet,node,rect);node.mouse_filter=Control.MOUSE_FILTER_STOP
 node.focus_mode=Control.FOCUS_NONE
 if action.is_valid():node.pressed.connect(action)
 node.add_theme_font_size_override("font_size",22)
 node.add_theme_color_override("font_color",IVORY)
 node.add_theme_stylebox_override("hover",style(Color("#365451"),GOLD))
 node.add_theme_stylebox_override("pressed",style(SELECTED,GOLD))
 node.add_theme_stylebox_override("normal",style(SURFACE,LINE))
 return node

func highlight(node:Button,selected:bool,focus:bool) -> void:
 node.add_theme_stylebox_override("normal",style(SELECTED if selected else SURFACE,GOLD if focus else LINE))
 node.add_theme_color_override("font_color",GOLD if selected else IVORY)

func _ready() -> void:
 color=BG;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 bold_font.base_font=ThemeDB.fallback_font;bold_font.variation_embolden=0.5
 add_child(sheet);sheet.size=CANVAS;sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(fit_screen);fit_screen()
 station_title=label(sheet,"Fabricator",Rect2(45,21,354,66),46,IVORY,true)
 for i in 2:
  tabs.append(button(["Blueprints","Cartridges"][i],Rect2(647+i*174,33,164,45),select_page.bind(i)))
 button("Close",Rect2(1117,33,119,45),close)
 block(Rect2(44,98,1192,1),LINE)
 group_label=label(sheet,"",Rect2(44,115,330,41),26,IVORY,true)
 for i in 4:
  var card:=button("",Rect2(44,169+i*105,342,93),select_entry.bind(i))
  list.append(card)
  var thumb:=Plate.new();place(card,thumb,Rect2(7,5,83,82));thumbs.append(thumb)
  names.append(label(card,"",Rect2(105,9,213,46),27,IVORY,true))
  subtitles.append(label(card,"",Rect2(105,50,215,32),20,MUTED))
 block(Rect2(410,121,1,490),LINE)
 caption=label(sheet,"",Rect2(437,119,732,33),20,GOLD)
 heading=label(sheet,"",Rect2(435,154,750,65),44,IVORY,true)
 art.gridded=true;place(sheet,art,Rect2(437,235,401,265))
 section=label(sheet,"",Rect2(868,231,364,39),25,IVORY,true)
 columns=label(sheet,"",Rect2(868,273,175,31),18,MUTED)
 quantity_heading=label(sheet,"",Rect2(1052,273,169,31),18,MUTED)
 quantity_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 for i in 4:
  var icon:=Plate.new();place(sheet,icon,Rect2(866,314+i*48,50,36));ingredients.append(icon)
  rows.append(label(sheet,"",Rect2(928,313+i*48,177,40),22))
  var amount:=label(sheet,"",Rect2(1106,313+i*48,115,40),22,GOLD,true)
  amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amounts.append(amount)
 part_label=label(sheet,"Choose a part",Rect2(436,511,790,38),22,IVORY,true)
 for i in 4:
  parts.append(button(PARTS[i],Rect2(437+i*201,560,190,48),select_part.bind(i)))
 note=label(sheet,"",Rect2(44,616,900,44),20,MUTED)
 print_button=button("Print part",Rect2(1022,617,211,42),print_selected)
 store_sample_button=button("Store sample",Rect2(803,617,200,42),store_selected_sample);store_sample_button.hide()
 print_button.disabled=true
 print_button.add_theme_stylebox_override("disabled",style(Color("#223739"),LINE))
 print_button.add_theme_color_override("font_disabled_color",Color("#a1aaa1"))
 block(Rect2(44,671,1192,1),LINE)
 hide()

func fit_screen() -> void:
 var factor:=minf(size.x/CANVAS.x,size.y/CANVAS.y)
 sheet.scale=Vector2.ONE*factor;sheet.position=(size-CANVAS*factor)/2

func open(use_processor:=false) -> void:
 processor=use_processor
 station_title.text="Refinery" if processor else "Fabricator"
 tabs[0].text="Ore" if processor else "Blueprints"
 tabs[1].text="Plants" if processor else "Cartridges"
 ore_index=0;page=0;blueprint=0;part=0;material_index=0;pigment_index=0;on_parts=false;stick=Vector2i.ZERO
 if is_instance_valid(workshop):workshop.notice=""
 last_ready.clear();show();refresh()
 if is_instance_valid(workshop):workshop.refresh_workshop()

func refining() -> bool:
 return processor and page==0

func sample_sku() -> String:
 if refining():return Mine.ORES[ore_index]
 return Garden.PLANTS[pigment_index]

func job_key() -> String:
 if refining():return "material."+Mine.METALS[ore_index]
 return "pigment."+Garden.COLORS[pigment_index]

func case_recipe() -> bool:
 return not processor and page==0 and blueprint==Garment.STYLES.size()

func print_selected() -> void:
 if case_recipe():
  if print_button.disabled:return
  var job:Dictionary=workshop.inventory.get("prints",{}).get("material.Empty",{})
  if not job.is_empty() and seconds_left(job)==0:workshop.commit("collect",{"job":job.id},"collect_material")
  else:workshop.commit("print",{"casing":"empty","hours":1},"print_case")
  return
 if processor:
  if print_button.disabled:return
  var sku:=sample_sku()
  var job:Dictionary=workshop.inventory.get("prints",{}).get(job_key(),{})
  if not job.is_empty() and seconds_left(job)==0:
   workshop.commit("collect",{"job":job.id},"collect_material" if refining() else "collect_pigment")
  elif workshop.units("ore" if refining() else "botanical",sku)>0:
   var args:Dictionary={}
   if refining():args={"ore":sku,"hours":int(workshop.inventory.refining_hours)}
   else:args={"plant":sku,"hours":int(workshop.inventory.extraction_hours)}
   if not job.is_empty():args.extra_case=true
   workshop.commit("print",args,"refine" if refining() else "extract")
  else:store_selected_sample()
  return
 if page==0 and not print_button.disabled and is_instance_valid(workshop):
  var style_id:String=Garment.STYLES[blueprint]
  var slot:String=Garment.SLOTS[part].to_lower()
  var job:Dictionary=workshop.inventory.get("prints",{}).get(style_id+"."+slot,{})
  if not job.is_empty() and seconds_left(job)==0:
   workshop.commit("collect",{"job":job.id})
  else:
   workshop.commit("print",{"style":style_id,"part":slot,"hours":int(workshop.inventory.print_hours[style_id][slot])})

func store_selected_sample() -> void:
 var plant:=sample_sku()
 var days:Array=ship.store.field_cargo(plant).get(plant,{}).get("days",[])
 for i in range(days.size()-1,-1,-1):
  if int(days[i])<=Garden.today():
   workshop.store_sample(plant,int(days[i]),ship.profile);return

func seconds_left(job:Dictionary) -> int:
 var elapsed:=int((Time.get_ticks_msec()-int(workshop.stock_received_ms))/1000.0)
 return maxi(0,int(job.remaining_seconds)-elapsed)

func time_text(seconds:int) -> String:
 return "%02d:%02d:%02d"%[int(seconds/3600.0),int(seconds/60.0)%60,seconds%60]

func update_print_status() -> void:
 if not is_instance_valid(workshop) or not workshop.timed_prints or not workshop.inventory.has("print_hours"):
  for i in parts.size():parts[i].text=PARTS[i]
  part_label.text="Choose a part";print_button.text="Print part";print_button.disabled=true
  return
 var style_id:String=Garment.STYLES[blueprint]
 var jobs:Dictionary=workshop.inventory.get("prints",{})
 var slot:String=Garment.SLOTS[part].to_lower()
 var hours:int=int(workshop.inventory.print_hours[style_id][slot])
 var job:Dictionary=jobs.get(style_id+"."+slot,{})
 var ready:=not job.is_empty() and seconds_left(job)==0
 for i in parts.size():
  var other:Dictionary=jobs.get(style_id+"."+Garment.SLOTS[i].to_lower(),{})
  parts[i].text=PARTS[i] if other.is_empty() else PARTS[i]+(" · Ready" if seconds_left(other)==0 else " · Printing")
 part_label.text="Print time · %d h"%hours
 if not job.is_empty():
  part_label.text+=("     Ready to collect" if ready else "     Remaining · "+time_text(seconds_left(job)))
  if int(job.quantity)>1:part_label.text+="     ×%d"%int(job.quantity)
 print_button.text="Collect part" if ready else ("Print another" if not job.is_empty() else "Print part")
 print_button.disabled=workshop.busy or (not ready and not has_materials)

func _process(_delta:float) -> void:
 if visible and processor and Time.get_ticks_msec()>=next_tick:
  next_tick=Time.get_ticks_msec()+1000
  if is_instance_valid(workshop):
   var key:=job_key()
   var job:Dictionary=workshop.inventory.get("prints",{}).get(key,{})
   if not job.is_empty():
    var seconds:=seconds_left(job)
    if seconds>0:part_label.text=("Refining   " if refining() else "Extracting   ")+time_text(seconds)
    elif print_button.text!="Collect cartridge":refresh()
 elif visible and not processor and page==0 and Time.get_ticks_msec()>=next_tick:
  next_tick=Time.get_ticks_msec()+1000
  if case_recipe():refresh();return
  var ready:Dictionary={}
  if is_instance_valid(workshop):
   var jobs:Dictionary=workshop.inventory.get("prints",{})
   for sku in jobs:
    if seconds_left(jobs[sku])==0:ready[sku]=true
  if ready!=last_ready:
   last_ready=ready;refresh()
  else:update_print_status()

func close() -> void:
 if visible:hide();dismissed.emit()

func select_page(index:int) -> void:
 page=index;on_parts=false;refresh()

func select_entry(index:int) -> void:
 on_parts=false
 if processor:
  if refining():ore_index=index
  else:pigment_index=index
 elif page==0:
  if blueprint!=index:part=0
  blueprint=index
 else:material_index=index
 refresh()

func select_part(index:int) -> void:
 on_parts=true;part=index;refresh()

func refresh() -> void:
 if not is_node_ready() or not visible:return
 for i in tabs.size():highlight(tabs[i],i==page,false)
 store_sample_button.hide();note.size.x=900
 if processor:
  refresh_refinery();return
 var connected:bool=is_instance_valid(workshop) and not workshop.inventory.is_empty()
 var browsing_sets:=page==0
 var index:int=blueprint if browsing_sets else material_index
 var style_id:String=Garment.STYLES[blueprint] if blueprint<Garment.STYLES.size() else ""
 group_label.text="Blueprints" if browsing_sets else "Cartridge types"
 for i in list.size():
  list[i].show()
  if browsing_sets and i==Garment.STYLES.size():
   names[i].text="Empty cartridge";list[i].tooltip_text="Reusable cartridge shell blueprint"
   subtitles[i].text=("Owned" if workshop.units("blueprint","empty")>0 else "Blueprint needed") if connected else "1 recipe"
   thumbs[i].pigment(Color("#b6b9aa"));highlight(list[i],i==index,i==index);continue
  var title:String=Garment.STYLES[i].capitalize() if browsing_sets else MATERIALS[i]
  names[i].text=title
  if browsing_sets:
   subtitles[i].text=("Owned" if workshop.units("blueprint",Garment.STYLES[i])>0 else "Blueprint needed") if connected else "4 parts"
   if connected:
    for slot in Garment.SLOTS:
     var job:Dictionary=workshop.inventory.get("prints",{}).get(Garment.STYLES[i]+"."+slot.to_lower(),{})
     if not job.is_empty():
      subtitles[i].text="Ready to collect" if seconds_left(job)==0 else "Printing"
      if seconds_left(job)==0:break
  else:subtitles[i].text=("Held   %d"%workshop.units("material",MATERIALS[i])) if connected else "Held   —"
  list[i].tooltip_text=title
  thumbs[i].present(i,0,not browsing_sets)
  highlight(list[i],i==index,i==index and not on_parts)
 for i in parts.size():
  parts[i].visible=browsing_sets
  highlight(parts[i],i==part,i==part and on_parts)
 part_label.visible=browsing_sets;print_button.visible=browsing_sets
 for i in rows.size():
  rows[i].text="";amounts[i].text="";ingredients[i].hide()
  rows[i].position.x=928 if browsing_sets else 868
 if case_recipe():
  for b in parts:b.hide()
  caption.text="Reusable utility blueprint";heading.text="Empty cartridge"
  art.pigment(Color("#b6b9aa"));section.text="Required cartridges";columns.text="Material";quantity_heading.text="Held / Needed"
  ingredients[0].present(1,0,true);ingredients[0].show();rows[0].text="Plastic"
  amounts[0].text=("%d / 1"%workshop.units("material","Plastic")) if connected else "— / 1"
  var job:Dictionary=workshop.inventory.get("prints",{}).get("material.Empty",{}) if connected else {}
  var ready:=not job.is_empty() and seconds_left(job)==0
  part_label.text="Print time · 1 h" if job.is_empty() else ("Ready to collect" if ready else "Printing   "+time_text(seconds_left(job)))
  print_button.text="Collect cartridge" if ready else "Print cartridge"
  print_button.disabled=not connected or not workshop.inventory.has("case_hours") or workshop.busy or not (ready or (workshop.units("blueprint","empty")>0 and workshop.units("material","Plastic")>=1))
  note.text="Buy the blueprint at the ship computer." if not connected or workshop.units("blueprint","empty")==0 else "An empty shell for an additional refinery batch."
 elif browsing_sets:
  caption.text=style_id.capitalize()+"   /   Reusable set blueprint"
  heading.text=Garment.NAMES[style_id][part]
  art.present(blueprint,part+1,false)
  section.text="Required cartridges";columns.text="Material";quantity_heading.text="Held / Needed"
  var costs:Dictionary=REQUIREMENTS[style_id][part]
  if connected:costs=workshop.inventory.recipes[style_id][Garment.SLOTS[part].to_lower()]
  var printable:bool=connected and not workshop.busy and workshop.units("blueprint",style_id)>0
  var i:=0
  for material_name in costs:
   ingredients[i].present(MATERIALS.find(material_name),0,true);ingredients[i].show()
   rows[i].text=material_name
   var held:int=workshop.units("material",material_name) if connected else 0
   amounts[i].text=("%d / %d"%[held,costs[material_name]]) if connected else "— / %d"%costs[material_name]
   printable=printable and held>=int(costs[material_name]);i+=1
  has_materials=printable
  update_print_status()
  note.text=""
  if not connected:note.text="Connect to your inventory to print."
  elif not workshop.timed_prints or not workshop.inventory.has("print_hours"):note.text="Update the workshop to start timed prints."
  elif print_button.disabled and not workshop.inventory.prints.has(style_id+"."+Garment.SLOTS[part].to_lower()):note.text="Blueprint or cartridges required"
 else:
  var selected:String=MATERIALS[material_index]
  caption.text="Printer cartridge";heading.text=selected;art.present(material_index,0,true)
  section.text="Used in";columns.text="Set";quantity_heading.text="Parts"
  var i:=0
  for outfit in Garment.STYLES:
   var uses:=0
   for costs in REQUIREMENTS[outfit]:
    if costs.has(selected):uses+=1
   if uses:
    rows[i].text=outfit.capitalize();amounts[i].text=str(uses);i+=1
  note.text=("Held   %d"%workshop.units("material",selected)) if connected else "Cartridge balance unavailable."

 if is_instance_valid(workshop):
  if workshop.busy:note.text="Updating inventory…"
  elif not workshop.notice.is_empty():note.text=workshop.notice

func refresh_refinery() -> void:
 if not is_instance_valid(ship):return
 var metal:=refining()
 var capability:="refining_hours" if metal else "extraction_hours"
 var connected:bool=is_instance_valid(workshop) and ship.profile!="" and workshop.inventory.has(capability)
 var catalogue:Array=Mine.ORES if metal else Garden.PLANTS
 var selected:=ore_index if metal else pigment_index
 var shores:Array=Mine.SHORES if metal else Garden.SHORES
 group_label.text="Ore samples" if metal else "Field samples"
 for i in list.size():
  list[i].visible=i<catalogue.size()
  if not list[i].visible:continue
  var sku:String=catalogue[i]
  var count:int=ship.store.field_cargo(sku).get(sku,{}).get("days",[]).size()
  names[i].text=sku.capitalize()
  subtitles[i].text="Ship %d   ·   Inventory %d"%[count,workshop.units("ore" if metal else "botanical",sku)] if connected else "On ship   %d"%count
  if metal:thumbs[i].present(MATERIALS.find(Mine.METALS[i]),0,true)
  else:thumbs[i].pigment(Garden.SWATCHES[i])
  list[i].tooltip_text=shores[i]
  highlight(list[i],i==selected,i==selected)
 caption.text=catalogue[selected].capitalize()+"   /   "+shores[selected]
 if metal:
  heading.text=Mine.METALS[selected]+" cartridge"
  art.present(MATERIALS.find(Mine.METALS[selected]),0,true)
 else:
  var color_name:String=["Saffron","Sea glass","Aurora violet"][selected]
  heading.text=color_name+" cartridge"
  art.pigment(Garden.SWATCHES[selected])
 section.text="Metal refining" if metal else "Pigment extraction"
 columns.text="";quantity_heading.text="";part_label.show()
 for b in parts:b.hide()
 for i in rows.size():
  ingredients[i].hide();rows[i].position.x=868;rows[i].text="";amounts[i].text=""
 rows[0].text="Samples needed";amounts[0].text="1"
 rows[1].text="Processing time";amounts[1].text="%d h"%int(workshop.inventory[capability] if connected else (2 if metal else 1))
 rows[2].text="Yield" if metal else "Finish"
 amounts[2].text="1 unit" if metal else ["Matte","Satin","Iridescent"][selected]
 if not metal and connected:
  var palette:Dictionary=workshop.inventory.get("colors",{}).get(Garden.COLORS[selected],{})
  heading.text=palette.get("name",heading.text.trim_suffix(" cartridge"))+" cartridge"
  amounts[2].text=palette.get("finish",amounts[2].text).capitalize()
 refresh_processing(connected,"Use in fabricator blueprints" if metal else "Open colour in the fitting station")

func refresh_processing(connected:bool, purpose:String) -> void:
 var sku:=sample_sku()
 var job:Dictionary=workshop.inventory.get("prints",{}).get(job_key(),{}) if connected else {}
 var ready:=not job.is_empty() and seconds_left(job)==0
 var samples:Array=ship.store.field_cargo(sku).get(sku,{}).get("days",[])
 var available:bool=samples.any(func(d):return int(d)<=Garden.today())
 var held:int=workshop.units("ore" if refining() else "botanical",sku) if connected else 0
 var progress:="Refining   " if refining() else "Extracting   "
 part_label.text=purpose if job.is_empty() else ("Ready to collect" if ready else progress+time_text(seconds_left(job)))
 var deposit:="Store ore" if refining() else "Store sample"
 print_button.show();print_button.text="Start refining" if refining() else "Start extraction"
 if ready:print_button.text="Collect cartridge"
 elif available and held==0:print_button.text=deposit
 print_button.disabled=not connected or workshop.busy or not (ready or available or held>0)
 store_sample_button.text=deposit;store_sample_button.visible=connected and available and (ready or held>0)
 store_sample_button.disabled=not connected or workshop.busy
 note.size.x=732 if store_sample_button.visible else 900
 if refining():
  note.text="%s ore   ·   Ship %d"%[sku.capitalize(),samples.size()]
  note.text+=("   ·   Inventory %d"%held) if connected else "   ·   Connect to a workshop with ore refining."
 else:
  note.text="Field sample stored on this ship." if available else "Pick two open flowers at "+Garden.SHORES[pigment_index]+"."
  if not connected:note.text="Samples stay on this ship. Connect to a workshop with pigment extraction."
 if not job.is_empty() and not ready:
  var shells:int=workshop.units("material","Empty")
  rows[3].text="Extra batch shell";amounts[3].text="%d / 1"%shells
  note.text="Additional batch needs 1 empty cartridge   ·   Held %d"%shells
  if held>0:
   print_button.text="Start extra batch";print_button.disabled=workshop.busy or shells==0
 if not samples.is_empty() and not available:note.text="Sample dated in the future. Check the system clock."
 if connected:
  if workshop.busy:note.text="Updating inventory…"
  elif workshop.notice!="":note.text=workshop.notice

func action_hints() -> Array:
 var labels:Array=["Ore","Plant"] if processor else ["Blueprint","Cartridge"]
 var actions:Array=[["vertical",labels[page]],["tab_pair","Tabs"]]
 if case_recipe():
  if not print_button.disabled:actions.append(["interact",print_button.text])
 elif not processor and page==0:
  actions.append(["horizontal","Part"])
  if not on_parts:actions.append(["interact","Choose part"])
  elif not print_button.disabled:actions.append(["interact",print_button.text])
 if processor and not print_button.disabled:actions.append(["interact",print_button.text])
 if store_sample_button.visible:actions.append(["pick_item",store_sample_button.text])
 actions.append(["cancel_ship","Close"])
 return actions

func navigate(direction:Vector2i) -> void:
 if direction.y!=0:
  if processor:
   if refining():select_entry(posmod(ore_index+direction.y,Mine.ORES.size()))
   else:select_entry(posmod(pigment_index+direction.y,Garden.PLANTS.size()))
  elif page==0:select_entry(posmod(blueprint+direction.y,Garment.STYLES.size()+1))
  else:select_entry(posmod(material_index+direction.y,MATERIALS.size()))
 elif not processor and not case_recipe() and page==0 and direction.x!=0:
  select_part(posmod(part+direction.x,parts.size()))

func _input(event:InputEvent) -> void:
 if not is_visible_in_tree():return
 if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:return
 if event.is_action_pressed("pause_ship"):return
 if event.is_action_pressed("cancel_ship") or event.is_action_pressed("ui_cancel"):close()
 elif event.is_action_pressed("previous_item"):select_page(posmod(page-1,tabs.size()))
 elif event.is_action_pressed("next_item"):select_page((page+1)%tabs.size())
 elif event is InputEventJoypadMotion:
  var axis:int=event.axis
  if axis==JOY_AXIS_LEFT_X or axis==JOY_AXIS_LEFT_Y:
   var delta:=int(signf(event.axis_value)) if absf(event.axis_value)>0.55 else 0
   var slot:=0 if axis==JOY_AXIS_LEFT_X else 1
   if delta!=0 and delta!=stick[slot]:navigate(Vector2i(delta,0) if slot==0 else Vector2i(0,delta))
   stick[slot]=delta
 elif event.is_action_pressed("ui_up",true):navigate(Vector2i.UP)
 elif event.is_action_pressed("ui_down",true):navigate(Vector2i.DOWN)
 elif event.is_action_pressed("ui_left",true):navigate(Vector2i.LEFT)
 elif event.is_action_pressed("ui_right",true):navigate(Vector2i.RIGHT)
 elif event.is_action_pressed("pick_item") and store_sample_button.visible:store_selected_sample()
 elif (processor or case_recipe()) and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):print_selected()
 elif page==0 and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
  if on_parts and not print_button.disabled:print_selected()
  else:select_part(part)
 get_viewport().set_input_as_handled()
