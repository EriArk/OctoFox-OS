# SPDX-License-Identifier: GPL-3.0-or-later
extends ColorRect
signal dismissed
const TABS=["Ship","Cargo","Upgrades","Store"]
const OFFERS=["case-plan","traveller-plan","merchant-plan","case","trousers","cap","cruise-kit","boost-kit"]
const TITLES=["Empty cartridge blueprint","Traveller set blueprint","Merchant set blueprint","Empty cartridge","Trail trousers","Market beret","Cruise economiser","Boost capacitor"]
const KITS=["economiser","capacitor"]
const EFFECTS=["Cruise uses 20% less fuel.","Boost draws 27 energy instead of 36."]
const INK=Color("#12282b")
const PANEL=Color("#233d40")
const LINE=Color("#395351")
const GOLD=Color("#edcb8b")
const TEXT=Color("#f0eadb")
const MINT=Color("#a8d9cc")
var ship:Node
var workshop
var page:=0
var index:=0
var confirmation:Dictionary={}
var stick:=0
var sheet:=Control.new()
var tabs:Array[Button]=[]
var scroll:=ScrollContainer.new()
var entries:=VBoxContainer.new()
var detail:=VBoxContainer.new()
var account:=Label.new()
var title:=Label.new()
var description:=Label.new()
var figures:=Label.new()
var notice:=Label.new()
var action:Button
var items:Array[Dictionary]=[]

func style(fill:Color,border:Color) -> StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(6)
 s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=6;s.content_margin_bottom=6
 return s

func place(node:Control,at:Rect2) -> void:
 sheet.add_child(node);node.position=at.position;node.size=at.size

func typeface(node:Label,points:int,color_value:Color) -> void:
 node.add_theme_font_size_override("font_size",points);node.add_theme_color_override("font_color",color_value)

func button(text_value:String,callback:Callable) -> Button:
 var b:=Button.new();b.text=text_value;b.focus_mode=Control.FOCUS_NONE;b.add_theme_font_size_override("font_size",22)
 b.add_theme_stylebox_override("normal",style(PANEL,LINE));b.pressed.connect(callback);return b

func _ready() -> void:
 color=INK;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(sheet);sheet.size=Vector2(1280,720);sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var nameplate:=Label.new();nameplate.text="Ship computer";typeface(nameplate,42,TEXT);place(nameplate,Rect2(42,18,420,60))
 typeface(account,22,GOLD);account.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;place(account,Rect2(710,26,370,42))
 place(button("Close",close),Rect2(1112,23,125,46))
 for i in TABS.size():
  var tab:=button(TABS[i],select_page.bind(i));tabs.append(tab);place(tab,Rect2(43+i*298,96,284,50))
 place(scroll,Rect2(42,173,483,438));scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.add_child(entries);entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries.add_theme_constant_override("separation",6)
 var panel:=Panel.new();panel.add_theme_stylebox_override("panel",style(PANEL,LINE));place(panel,Rect2(550,173,686,438))
 place(detail,Rect2(580,203,625,365));detail.add_theme_constant_override("separation",19)
 for label in [title,figures,description]:
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_child(label)
 typeface(title,37,TEXT);typeface(figures,24,GOLD);typeface(description,24,MINT)
 typeface(notice,20,MINT);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;place(notice,Rect2(44,615,800,61))
 action=button("",activate);place(action,Rect2(879,625,357,51))
 resized.connect(fit);fit();hide()

func fit() -> void:
 var scale_factor:=minf(size.x/1280,size.y/720)
 sheet.scale=Vector2.ONE*scale_factor;sheet.position=(size-sheet.size*scale_factor)/2

func open() -> void:
 page=0;index=0;stick=0;confirmation.clear()
 workshop.notice="";show();refresh();workshop.refresh_workshop()

func close() -> void:
 if visible:confirmation.clear();hide();dismissed.emit()

func select_page(value:int) -> void:
 page=posmod(value,TABS.size());index=0;confirmation.clear();scroll.scroll_vertical=0;refresh()

func select(index_value:int) -> void:
 index=index_value;confirmation.clear();draw_selection()

func add_entry(name_value:String,measure:String,body:String,identity:="") -> void:
 items.append({"name":name_value,"measure":measure,"body":body,"id":identity})

func online() -> bool:
 return workshop.supplies_supported and not ship.profile.is_empty() and workshop.inventory.has("supplies")

func refresh() -> void:
 if not visible or not is_node_ready():return
 items.clear()
 var a=ship.flight.avionics
 var inventory:Dictionary=workshop.inventory
 account.text=("%s Sparks"%inventory.sparks) if online() else "Local ship"
 match page:
  0:
   add_entry("Flight status",ship.flight.NAMES[ship.flight.berth] if ship.flight.mode==ship.flight.Mode.BERTH else a.SECTORS[a.sector],
    "Hull   %d%%\nShields   %d%%\nFuel   %d / %d"%[roundi(a.hull),roundi(a.shield),floori(a.fuel),int(a.TANK)])
   for i in a.MODULES.size():
    add_entry(a.MODULES[i],"Online" if a.enabled[i] else "Offline","Power distribution\nSYS   %d      ENG   %d      WEP   %d"%[a.pips[0],a.pips[1],a.pips[2]])
  1:
   for group:Dictionary in [ship.store.botany,ship.store.ore]:
    for sku in group:
     var units:int=group[sku].days.size()
     if units>0:add_entry(str(sku).capitalize(),"On ship   × %d"%units,"Unload at the refinery to trade or process this sample.")
   var fish:Dictionary={}
   for catch_data in ship.store.fish:
    if catch_data.place!="tank":
     var species:String=ship.Catch.SPECIES[catch_data.species][0];fish[species]=fish.get(species,0)+1
   for species in fish:add_entry(species,"Livewell   × %d"%fish[species],"Visit the aquarium to display or transfer your catch.")
   for row in inventory.get("stock",[]):
    var sku_name:String=str(row.sku).capitalize()
    if row.kind=="garment":sku_name=garment_name(row.sku)
    add_entry(sku_name,"Profile inventory   × %d"%int(row.units),str(row.kind).capitalize())
   if items.is_empty():add_entry("Cargo hold","Empty","Gather flowers, mine a vein or fish from an island pier.")
  2:
   for i in KITS.size():
    var installed:bool=KITS[i] in a.installed
    var held:int=workshop.units("upgrade",KITS[i])
    add_entry(TITLES[6+i],"Installed" if installed else ("Kit in inventory" if held else "Available to order"),EFFECTS[i],KITS[i])
  3:
   for i in OFFERS.size():
    var offer:Dictionary=inventory.get("supplies",{}).get(OFFERS[i],{})
    var details:String=["Reusable plan. Print empty shells from plastic at the fabricator.","Reusable plan for four Traveller garments.","Reusable plan for four Merchant garments.","Use one shell for an additional refinery batch.","Ready to wear at the fitting station.","Ready to wear at the fitting station.",EFFECTS[0],EFFECTS[1]][i]
    var summary:="%s Sparks"%offer.price if not offer.is_empty() else "Price unavailable"
    add_entry(offer.get("title",TITLES[i]),summary,details,OFFERS[i])
 for child in entries.get_children():entries.remove_child(child);child.queue_free()
 index=clampi(index,0,items.size()-1)
 for i in items.size():
  var b:=button(items[i].name,select.bind(i));b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.custom_minimum_size.y=52;entries.add_child(b)
 draw_selection()

func garment_name(sku:String) -> String:
 var bits:=sku.split(".")
 if bits.size()==2 and bits[0] in ship.fabricator.Garment.STYLES:
  var slot:int=["top","bottom","boots","hat"].find(bits[1])
  if slot>=0:return ship.fabricator.Garment.NAMES[bits[0]][slot]
 return sku.capitalize()

func draw_selection() -> void:
 if items.is_empty():return
 for i in tabs.size():tabs[i].add_theme_stylebox_override("normal",style(PANEL,GOLD if i==page else LINE))
 for i in entries.get_child_count():
  var b:Button=entries.get_child(i);b.add_theme_stylebox_override("normal",style(Color("#344b48") if i==index else INK,GOLD if i==index else LINE))
 reveal_selection.call_deferred()
 var row:Dictionary=items[index];title.text=row.name;figures.text=row.measure;description.text=row.body
 action.hide();notice.text=""
 if page>=2 and not online():notice.text="Connect to Ship Supplies to place orders or fit kits."
 if page==1 and workshop.inventory.is_empty():notice.text="Profile inventory is offline."
 if page==2 and row.id not in ship.flight.avionics.installed:
  action.show();var held:int=workshop.units("upgrade",row.id)
  action.text="Fit module" if held else "View in store";action.disabled=workshop.busy or (held>0 and not online())
 if page==3:
  action.show();var offer:Dictionary=workshop.inventory.get("supplies",{}).get(row.id,{})
  action.disabled=not online() or workshop.busy or offer.is_empty() or int(workshop.inventory.get("sparks",0))<int(offer.get("price",0))
  var quote={"offer":row.id,"price":offer.get("price",-1),"player_id":workshop.inventory.get("player_id","")}
  if confirmation!=quote or action.disabled:confirmation.clear()
  action.text=("Confirm · %s Sparks"%offer.price) if not confirmation.is_empty() else "Order"
  if online() and action.disabled and not workshop.busy:notice.text="Insufficient Sparks"
 if not workshop.notice.is_empty():notice.text=workshop.notice
 if workshop.busy:notice.text="Updating inventory…"

func reveal_selection() -> void:
 if visible and index<entries.get_child_count():scroll.ensure_control_visible(entries.get_child(index))

func activate() -> void:
 if not action.visible or action.disabled:return
 var row:Dictionary=items[index]
 if page==2:
  if workshop.units("upgrade",row.id)>0:
   workshop.commit("install",{"module":row.id,"player_id":workshop.inventory.player_id})
  else:
   var item:=OFFERS.find("cruise-kit" if row.id=="economiser" else "boost-kit")
   select_page(3);select(item)
 elif page==3 and online():
  var offer:Dictionary=workshop.inventory.supplies[row.id]
  var quote={"offer":row.id,"price":offer.price,"player_id":workshop.inventory.player_id}
  if confirmation!=quote:confirmation=quote;draw_selection();return
  confirmation={};workshop.commit("buy",quote)

func action_hints() -> Array:
 var hints:Array=[["tab_pair","Pages"],["vertical","Select"]]
 if action.visible and not action.disabled:hints.append(["interact",action.text])
 hints.append(["cancel_ship","Back"]);return hints

func _input(event:InputEvent) -> void:
 if not is_visible_in_tree() or event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or event.is_action_pressed("pause_ship"):return
 if event.is_action_pressed("cancel_ship") or event.is_action_pressed("ui_cancel"):
  if not confirmation.is_empty():confirmation.clear();draw_selection()
  else:close()
 elif event.is_action_pressed("previous_item"):select_page(page-1)
 elif event.is_action_pressed("next_item"):select_page(page+1)
 elif event.is_action_pressed("ui_down",true):select(posmod(index+1,items.size()))
 elif event.is_action_pressed("ui_up",true):select(posmod(index-1,items.size()))
 elif event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_Y:
  var direction:=int(signf(event.axis_value)) if absf(event.axis_value)>0.55 else 0
  if direction!=0 and direction!=stick:select(posmod(index+direction,items.size()))
  stick=direction
 elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):activate()
 get_viewport().set_input_as_handled()
