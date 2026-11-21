# SPDX-License-Identifier: GPL-3.0-or-later
extends ColorRect
signal dismissed
const Garment = preload("res://scripts/fitting_garment.gd")
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
 label(sheet,"Fabricator",Rect2(45,21,354,66),46,IVORY,true)
 for i in 3:
  tabs.append(button(["Blueprints","Cartridges","Pigments"][i],Rect2(481+i*174,33,164,45),select_page.bind(i)))
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

func open() -> void:
 page=0;blueprint=0;part=0;material_index=0;pigment_index=0;on_parts=false;stick=Vector2i.ZERO
 if is_instance_valid(workshop):workshop.notice=""
 last_ready.clear();show();refresh()
 if is_instance_valid(workshop):workshop.refresh_workshop()

func print_selected() -> void:
 if page==2:
  if print_button.disabled:return
  var sku:String=Garden.COLORS[pigment_index]
  var plant:String=Garden.PLANTS[pigment_index]
  var job:Dictionary=workshop.inventory.get("prints",{}).get("pigment."+sku,{})
  if not job.is_empty() and seconds_left(job)==0:
   workshop.commit("collect",{"job":job.id},"collect_pigment")
  else:
   if workshop.units("botanical",plant)>0:
    workshop.commit("print",{"plant":plant,"hours":int(workshop.inventory.extraction_hours)},"extract")
   else:store_selected_sample()
  return
 if not print_button.disabled and is_instance_valid(workshop):
  var style_id:String=Garment.STYLES[blueprint]
  var slot:String=Garment.SLOTS[part].to_lower()
  var job:Dictionary=workshop.inventory.get("prints",{}).get(style_id+"."+slot,{})
  if not job.is_empty() and seconds_left(job)==0:
   workshop.commit("collect",{"job":job.id})
  else:
   workshop.commit("print",{"style":style_id,"part":slot,"hours":int(workshop.inventory.print_hours[style_id][slot])})

func store_selected_sample() -> void:
 var plant:String=Garden.PLANTS[pigment_index]
 var days:Array=ship.store.botany.get(plant,{}).get("days",[])
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
 if visible and page==2 and Time.get_ticks_msec()>=next_tick:
  next_tick=Time.get_ticks_msec()+1000
  if is_instance_valid(workshop):
   var key:String="pigment."+Garden.COLORS[pigment_index]
   var job:Dictionary=workshop.inventory.get("prints",{}).get(key,{})
   if not job.is_empty():
    var seconds:=seconds_left(job)
    if seconds>0:part_label.text="Extracting   "+time_text(seconds)
    elif print_button.text!="Collect cartridge":refresh_pigment()
 elif visible and page==0 and Time.get_ticks_msec()>=next_tick:
  next_tick=Time.get_ticks_msec()+1000
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
 if page==0:
  if blueprint!=index:part=0
  blueprint=index
 elif page==1:material_index=index
 else:pigment_index=index
 refresh()

func select_part(index:int) -> void:
 on_parts=true;part=index;refresh()

func refresh() -> void:
 if not is_node_ready():return
 for i in tabs.size():highlight(tabs[i],i==page,false)
 store_sample_button.hide();note.size.x=900
 if page==2:
  refresh_pigment();return
 var connected:bool=is_instance_valid(workshop) and not workshop.inventory.is_empty()
 var browsing_sets:=page==0
 var index:int=blueprint if browsing_sets else material_index
 var style_id:String=Garment.STYLES[blueprint]
 group_label.text="Set blueprints" if browsing_sets else "Cartridge types"
 for i in list.size():
  list[i].visible=not browsing_sets or i<Garment.STYLES.size()
  if not list[i].visible:continue
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
 if browsing_sets:
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

func refresh_pigment() -> void:
 if not is_instance_valid(ship):return
 var connected:bool=is_instance_valid(workshop) and ship.profile!="" and workshop.inventory.has("extraction_hours")
 group_label.text="Field samples"
 for i in list.size():
  list[i].visible=i<Garden.PLANTS.size()
  if not list[i].visible:continue
  var count:int=ship.store.botany.get(Garden.PLANTS[i],{}).get("days",[]).size()
  names[i].text=Garden.NAMES[i]
  subtitles[i].text="Ship %d   ·   Inventory %d"%[count,workshop.units("botanical",Garden.PLANTS[i])] if connected else "On ship   %d"%count
  thumbs[i].pigment(Garden.SWATCHES[i]);list[i].tooltip_text=Garden.SHORES[i]
  highlight(list[i],i==pigment_index,i==pigment_index)
 var key:String=Garden.COLORS[pigment_index]
 var palette:Dictionary=workshop.inventory.get("colors",{}).get(key,{}) if is_instance_valid(workshop) else {}
 var fallback:Array=["Saffron","Sea glass","Aurora violet"]
 var color_name:String=palette.get("name",fallback[pigment_index])
 heading.text=color_name+" cartridge";caption.text=Garden.NAMES[pigment_index]+"   /   "+Garden.SHORES[pigment_index]
 art.pigment(Garden.SWATCHES[pigment_index]);section.text="Pigment extraction"
 columns.text="";quantity_heading.text="";part_label.show()
 for b in parts:b.hide()
 for i in rows.size():
  ingredients[i].hide();rows[i].position.x=868;rows[i].text="";amounts[i].text=""
 rows[0].text="Samples needed";amounts[0].text="1"
 rows[1].text="Extraction time";amounts[1].text="%d h"%int(workshop.inventory.get("extraction_hours",1) if connected else 1)
 rows[2].text="Finish";amounts[2].text=palette.get("finish",["matte","satin","iridescent"][pigment_index]).capitalize()
 var job:Dictionary=workshop.inventory.get("prints",{}).get("pigment."+key,{}) if connected else {}
 var ready:=not job.is_empty() and seconds_left(job)==0
 var samples:Array=ship.store.botany.get(Garden.PLANTS[pigment_index],{}).get("days",[])
 var has_sample:bool=samples.any(func(d):return int(d)<=Garden.today())
 part_label.text="Open colour in the fitting station" if job.is_empty() else ("Ready to collect" if ready else "Extracting   "+time_text(seconds_left(job)))
 var in_inventory:bool=connected and workshop.units("botanical",Garden.PLANTS[pigment_index])>0
 print_button.show()
 print_button.text="Collect cartridge" if ready else ("Store sample" if has_sample and not in_inventory else "Start extraction")
 print_button.disabled=not connected or workshop.busy or not (ready or has_sample or in_inventory)
 store_sample_button.visible=connected and has_sample and (ready or in_inventory)
 store_sample_button.disabled=not connected or workshop.busy
 note.size.x=732 if store_sample_button.visible else 900
 note.text="Pick two open flowers at "+Garden.SHORES[pigment_index]+"." if not has_sample else "Field sample stored on this ship."
 if not samples.is_empty() and not has_sample:note.text="Sample dated in the future. Check the system clock."
 if not connected:note.text="Samples stay on this ship. Connect to a workshop with pigment extraction."
 elif workshop.busy:note.text="Updating inventory…"
 elif workshop.notice!="":note.text=workshop.notice

func action_hints() -> Array:
 var actions:Array=[["vertical",["Blueprint","Cartridge","Plant"][page]],["tab_pair","Tabs"]]
 if page==0:
  actions.append(["horizontal","Part"])
  if not on_parts:actions.append(["interact","Choose part"])
  elif not print_button.disabled:actions.append(["interact",print_button.text])
 if page==2 and not print_button.disabled:actions.append(["interact",print_button.text])
 if page==2 and store_sample_button.visible:actions.append(["pick_item","Store sample"])
 actions.append(["cancel_ship","Close"])
 return actions

func navigate(direction:Vector2i) -> void:
 if direction.y!=0:
  if page==0:select_entry(posmod(blueprint+direction.y,Garment.STYLES.size()))
  elif page==1:select_entry(posmod(material_index+direction.y,MATERIALS.size()))
  else:select_entry(posmod(pigment_index+direction.y,Garden.PLANTS.size()))
 elif page==0 and direction.x!=0:
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
 elif page==2 and event.is_action_pressed("pick_item") and store_sample_button.visible:store_selected_sample()
 elif page==2 and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):print_selected()
 elif page==0 and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
  if on_parts and not print_button.disabled:print_selected()
  else:select_part(part)
 get_viewport().set_input_as_handled()
