# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://addons/avatar/avatar_client.gd"
signal workshop_changed
var supported := false
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
 super.disconnect_host()
 expired.clear();supported=false;busy=false;inventory.clear();stock.clear();garments.clear();next_page="";notice=""
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

func commit(action:String, args:Dictionary) -> void:
 if busy or not supported or not inventory.has("revision"):return
 var bytes:=Crypto.new().generate_random_bytes(16)
 bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128
 var hex:=bytes.hex_encode()
 args["operation_id"]="%s-%s-%s-%s-%s"%[hex.substr(0,8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20)]
 args["revision"]=inventory.revision
 last_action=action;busy=true;notice=""
 _request("workshop."+action,args);workshop_changed.emit()

func _process(delta:float) -> void:
 for id in pending.keys():
  var entry:Dictionary=pending[id]
  if str(entry.method).begins_with("workshop.") and Time.get_ticks_msec()>int(entry.deadline):
   pending.erase(id);expired[id]=true;busy=false;inventory.clear();stock.clear();garments.clear();next_page=""
   if expired.size()>32:expired.erase(expired.keys()[0])
   notice="Connection timed out. Reopen the station to check your inventory."
   workshop_changed.emit()
 super._process(delta)

func _packet(packet:Dictionary) -> void:
 if expired.erase(str(packet.get("id",""))):return
 var method:String=pending.get(str(packet.get("id","")),{}).get("method","")
 if method=="hello":
  supported=packet.get("result",{}).get("capabilities",{}).get("ship.workshop")==1
 if not method.begins_with("workshop."):
  super._packet(packet)
  return
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
  inventory=data;stock.clear()
  for entry in data.get("stock",[]):stock[entry.kind+"/"+entry.sku]=int(entry.units)
  replace_garments=true
  _request("workshop.garments")
 elif method=="workshop.garments":
  if replace_garments:garments.clear();replace_garments=false
  garments.append_array(data.get("items",[]))
  next_page=str(data.next) if data.get("next") else ""
  busy=false
 else:
  notice={"print":"Part added to inventory","paint":"Finish saved","activate":"Colour added to your palette"}.get(last_action,"Saved")
  _request("workshop.get")
 workshop_changed.emit()
