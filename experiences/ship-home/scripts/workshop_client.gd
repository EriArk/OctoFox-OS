# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://addons/avatar/avatar_client.gd"
signal fish_transferred(owner:String,id:String,problem:String)
signal fish_stock_changed
var fish_ready:=false
var fish_supported:=false
var fish_tank:Array=[]
var fish_bag:Array=[]
var fish_next:=""
var fish_epoch:=0
var fish_error:=""

signal sample_stored(owner:String,plant:String,day:int)
signal workshop_changed
var supported := false
signal looks_changed
signal parts_received(ticket:int,items:Array,error:String)
var looks_supported:=false
var looks_loading:=false
var wearing:=false
var saved_looks:Array=[]
var pending_looks:Array=[]
var look_notice:=""
var timed_prints := false
var stock_received_ms := 0
var busy := false
var stock: Dictionary = {}
var inventory: Dictionary = {}
var garments: Array = []
var next_page := ""
var replace_garments := false
var notice := ""
var last_action := ""
var expired:Dictionary={}

func _request(method: String, params: Dictionary={}) -> void:
 if method=="hello":
  var key:=OS.get_environment("OCTOFOX_SHIP_LAUNCH")
  if not key.is_empty():params["ship_key"]=key
 super._request(method,params)
 if method.begins_with("workshop."):pending[str(serial)].deadline=Time.get_ticks_msec()+25000

func disconnect_host() -> void:
 fish_supported=false;fish_ready=false;fish_tank=[];fish_bag=[];fish_next="";fish_error=""
 fish_stock_changed.emit()
 super.disconnect_host()
 looks_supported=false;looks_loading=false;wearing=false;saved_looks.clear();pending_looks.clear();look_notice=""
 looks_changed.emit()
 expired.clear();supported=false;timed_prints=false;busy=false;inventory.clear();stock.clear();garments.clear();next_page="";notice=""
 workshop_changed.emit()

func send_fish(fish:Dictionary,owner:String) -> void:
 busy=true
 _request("workshop.fish",{"id":fish.id,"species":fish.species,"site":int(fish.site)})
 pending[str(serial)].owner=owner;pending[str(serial)].fish=fish.id

func reset_fish() -> void:
 fish_epoch+=1;fish_ready=false;fish_tank=[];fish_bag=[];fish_next="";fish_error=""

func read_fish(more:=false) -> void:
 if busy or not fish_supported or (more and fish_next==""):return
 busy=true
 _request("workshop.fishstock",{"after":fish_next} if more else {})
 pending[str(serial)].append_page=more;pending[str(serial)].epoch=fish_epoch

func display_fish(id:String,display:bool) -> void:
 if busy or not fish_supported:return
 busy=true;_request("workshop.fishdisplay",{"id":id,"display":display})
 pending[str(serial)].epoch=fish_epoch

func refresh_looks() -> void:
 if not looks_supported or looks_loading or wearing:return
 looks_loading=true;pending_looks=[]
 _request("ship.looks",{"profile":profile_id,"offset":0})

func get_parts(row:Dictionary,field:String,ticket:int) -> void:
 _request("ship.parts",{"profile":profile_id,"recipe":row.recipe,"field":field})
 pending[str(serial)].ticket=ticket

func wear_look(row:Dictionary,field:String="",item:String="") -> void:
 if not looks_supported or wearing or looks_loading or (row.get("worn",false) and field.is_empty()):return
 wearing=true;look_notice="Changing outfit…"
 var args={"profile":profile_id,"id":row.id,"recipe":row.recipe}
 if not field.is_empty():args.merge({"field":field,"item":item})
 _request("ship.wear",args)
 looks_changed.emit()

func store_sample(sku:String,day:int,owner:String) -> void:
 var mineral:=sku in preload("res://scripts/ore_outcrop.gd").ORES
 if busy or owner=="" or not inventory.has("refining_hours" if mineral else "extraction_hours"):return
 busy=true;notice="";last_action="store_sample"
 var batch={"day":day,"player_id":inventory.player_id}
 batch["ore" if mineral else "plant"]=sku
 _request("workshop.collect",batch)
 pending[str(serial)].sample=[owner,sku,day]
 workshop_changed.emit()

func refresh_workshop() -> void:
 if not supported or busy:return
 busy=true;_request("workshop.get")
 workshop_changed.emit()

func more_garments() -> void:
 if not busy and not next_page.is_empty():
  busy=true;_request("workshop.garments",{"after":next_page});workshop_changed.emit()

func units(kind:String,sku:String) -> int:
 return stock.get(kind+"/"+sku,0)

func commit(action:String, args:Dictionary, feedback:String="") -> void:
 if busy or not supported or not inventory.has("revision"):return
 var bytes:=Crypto.new().generate_random_bytes(16)
 bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128
 var hex:=bytes.hex_encode()
 args["operation_id"]="%s-%s-%s-%s-%s"%[hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20)]
 args["revision"]=inventory.revision
 last_action=feedback if feedback!="" else action;busy=true;notice=""
 _request("workshop."+action,args);workshop_changed.emit()

func _process(delta:float) -> void:
 for id in pending.keys():
  var entry:Dictionary=pending[id]
  if str(entry.method).begins_with("workshop.") and Time.get_ticks_msec()>int(entry.deadline):
   if entry.method=="workshop.fish":
    fish_transferred.emit(entry.owner,entry.fish,"Transfer not confirmed · select Retry transfer")
   if entry.method in ["workshop.fishstock","workshop.fishdisplay"]:
    fish_ready=false;fish_tank=[];fish_bag=[];fish_next="";fish_error="Inventory connection timed out";fish_stock_changed.emit()
   pending.erase(id);expired[id]=true;busy=false;inventory.clear();stock.clear();garments.clear();next_page=""
   if expired.size()>32:expired.erase(expired.keys()[0])
   notice="Connection timed out. Reopen the station to check your inventory."
   workshop_changed.emit()
 super._process(delta)

func _packet(packet:Dictionary) -> void:
 if expired.erase(str(packet.get("id",""))):return
 var method:String=pending.get(str(packet.get("id","")),{}).get("method","")
 if method in ["workshop.fishstock","workshop.fishdisplay"]:
  var entry:Dictionary=pending[str(packet.id)]
  pending.erase(str(packet.id));busy=false
  if entry.epoch!=fish_epoch:
   read_fish();return
  fish_error=str(packet.get("error",{}).get("code","")).replace("_"," ").capitalize()
  if fish_error!="":
   fish_ready=false;fish_tank=[];fish_bag=[];fish_next=""
  elif method=="workshop.fishdisplay":
   read_fish();return
  else:
   var stock:Dictionary=packet.result
   fish_ready=true;fish_tank=stock.tank
   for item in fish_tank:item.merge({"place":"tank","account":true})
   if not entry.append_page:fish_bag=[]
   for item in stock.items:
    item.merge({"place":"inventory","account":true});fish_bag.append(item)
   fish_next=str(stock.next) if stock.next else ""
  fish_stock_changed.emit();return
 if method=="workshop.fish":
  var entry:Dictionary=pending[str(packet.id)]
  pending.erase(str(packet.id));busy=false
  var issue:String=str(packet.get("error",{}).get("code","")).replace("_"," ").capitalize()
  if issue=="" and str(packet.get("result",{}).get("item_id",""))!=entry.fish:issue="Transfer not confirmed"
  fish_transferred.emit(entry.owner,entry.fish,issue)
  return
 if method=="hello":
  fish_supported=packet.get("result",{}).get("capabilities",{}).get("ship.fishing")==1
  looks_supported=packet.get("result",{}).get("capabilities",{}).get("ship.looks")==1
  timed_prints=packet.get("result",{}).get("capabilities",{}).get("ship.timed_prints")==1
  supported=packet.get("result",{}).get("capabilities",{}).get("ship.workshop")==1
 if method=="ship.parts":
  var ticket:int=pending[str(packet.id)].ticket
  pending.erase(str(packet.id))
  parts_received.emit(ticket,packet.get("result",{}).get("items",[]),packet.get("error",{}).get("code",""))
  return
 if method in ["ship.wear","ship.looks"]:
  pending.erase(str(packet.id))
  if packet.has("error"):
   look_notice=str(packet.error.get("code","Wardrobe unavailable")).replace("_"," ").capitalize()
   wearing=false;looks_loading=false;pending_looks.clear()
   if method=="ship.looks":saved_looks.clear()
   else:refresh_looks()
  elif method=="ship.wear":
   wearing=false;look_notice="Outfit equipped";refresh_looks()
  else:
   var page:Dictionary=packet.result
   pending_looks.append_array(page.items)
   if int(page.next)>0:
    _request("ship.looks",{"profile":profile_id,"offset":page.next});return
   saved_looks=pending_looks;pending_looks=[];looks_loading=false
  looks_changed.emit();return
 if not method.begins_with("workshop."):
  super._packet(packet)
  return
 var sample:Array=pending[str(packet.id)].get("sample",[])
 pending.erase(str(packet.id))
 var data:Dictionary=packet.get("result",{})
 if packet.has("error"):
  notice=str(packet.error.get("code","Service unavailable")).replace("_"," ").capitalize()
  busy=false
  if method not in ["workshop.get","workshop.garments"]:refresh_workshop()
  elif method=="workshop.get":
   inventory.clear();stock.clear();garments.clear();next_page=""
  workshop_changed.emit()
  return
 if method=="workshop.get":
  stock_received_ms=Time.get_ticks_msec();inventory=data;stock.clear()
  for entry in data.get("stock",[]):stock[entry.kind+"/"+entry.sku]=int(entry.units)
  replace_garments=true
  _request("workshop.garments")
 elif method=="workshop.garments":
  if replace_garments:garments.clear();replace_garments=false
  garments.append_array(data.get("items",[]))
  next_page=str(data.next) if data.get("next") else ""
  busy=false
 else:
  if not sample.is_empty():
   if str(data.get("item_id","")).length()!=36:
    busy=false;notice="Could not confirm transfer. Your sample has been kept.";workshop_changed.emit();return
   sample_stored.emit(sample[0],sample[1],sample[2])
  notice={"refine":"Ore refining started","collect_material":"Material cartridge added to inventory","store_sample":"Field sample added to inventory","extract":"Pigment extraction started","collect_pigment":"Cartridge added to inventory","print":"Print started","collect":"Part added to inventory","paint":"Finish saved","activate":"Colour added to your palette"}.get(last_action,"Saved")
  _request("workshop.get")
 workshop_changed.emit()
