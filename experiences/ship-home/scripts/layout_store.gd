# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipLayoutStore
extends RefCounted
signal saved
const BERTH_KEYS:=["station","orchard","prism","table","cinder-port","cinder-garden","lantern-biolab","wayfarer-house","cinder-exchange","reedwater-delta","meridian-rift","kiln-caldera","crown-isle","twin-spurs","ember-isle","glass-atoll"]
const MAX_ITEMS=48
# Different deck coordinates: preserve all earlier preview layouts in homes/.
var directory="user://homes/studio-v1"
var owner="guest"
var error=""
var writable=true
var berth:=0
var systems:Dictionary={}
var survey_started:=false
var observations:Dictionary={}
var fish:Array=[]
var botany:Dictionary={}
var ore:Dictionary={}
var shelf_id:=""
var trophy_key:=""

func path() -> String: return directory+"/"+owner.sha256_text()+".json"

static func valid(rows: Variant) -> bool:
 if not rows is Array or rows.size()>MAX_ITEMS:return false
 for r in rows:
  if not r is Dictionary or not r.get("item","") in ShipInterior.ITEMS:return false
  if not r.get("x") is float and not r.get("x") is int:return false
  if not r.get("z") is float and not r.get("z") is int:return false
  if not r.get("angle") is float and not r.get("angle") is int:return false
  if not is_finite(r.x) or not is_finite(r.z) or not is_finite(r.angle):return false
  if abs(r.x)>9 or r.z< -10 or r.z>14 or abs(r.angle)>TAU*2:return false
 return true

func load_home(profile: String) -> Array:
 shelf_id="";trophy_key=""
 owner=profile if not profile.is_empty() else "guest";error="";writable=true;berth=0;survey_started=false;observations={};systems={};fish=[];botany={};ore={}
 if not FileAccess.file_exists(path()):return defaults()
 var f=FileAccess.open(path(),FileAccess.READ)
 if f==null or f.get_length()>65536:
  error="Could not read this home's layout. Your saved file has been kept.";writable=false;return []
 var parser=JSON.new()
 var parsed=parser.parse(f.get_as_text())
 var value=parser.data if parsed==OK else null
 if not value is Dictionary or value.get("schema")!=1 or value.get("owner")!=owner or not valid(value.get("items")):
  error="This layout could not be loaded. Your saved file has been kept.";writable=false;return []
 var survey:Variant=value.get("observations",{})
 if not survey is Dictionary or not value.get("survey_started",false) is bool:
  error="Could not read the field atlas.";writable=false;return value.items
 for species in survey:
  var specimen:Variant=survey[species]
  if not preload("res://scripts/shore_catch.gd").valid_stock([specimen]) or specimen.species!=species or specimen.site!=1:
   error="Could not read the field atlas.";writable=false;return value.items
 observations=survey;survey_started=value.get("survey_started",false)
 var saved_fish:Variant=value.get("fish",[])
 if not preload("res://scripts/shore_catch.gd").valid_stock(saved_fish):
  error="Could not read the livewell. Your save has been kept.";writable=false;return value.items
 var saved_botany:Variant=value.get("botany",{})
 if not preload("res://scripts/botanical_garden.gd").valid_samples(saved_botany):
  error="Could not read the botanical samples. Your save has been kept.";writable=false;return value.items
 var saved_ore:Variant=value.get("ore",{})
 if not preload("res://scripts/botanical_garden.gd").valid_samples(saved_ore,preload("res://scripts/ore_outcrop.gd").ORES):
  error="Could not read the ore cargo. Your save has been kept.";writable=false;return value.items
 ore=saved_ore
 botany=saved_botany
 var selected:Variant=value.get("shelf","")
 if selected is String and owns_sample(selected):shelf_id=selected
 var pinned:Variant=value.get("trophy","")
 if pinned is String and pinned.length()<=129:trophy_key=pinned
 fish=saved_fish
 berth=maxi(0,BERTH_KEYS.find(value.get("berth","station")))
 var state:Variant=value.get("flight",{})
 if state is Dictionary and not state.is_empty():
  var buses:Variant=state.get("pips");var modules:Variant=state.get("modules")
  if buses is Array and buses.size()==3 and buses.all(func(v):return (v is float or v is int) and float(v)==int(v) and v>=0 and v<=4) and buses[0]+buses[1]+buses[2]==6 and modules is Array and modules.size()==6 and modules.all(func(v):return v is bool) and (state.get("fuel") is float or state.get("fuel") is int):
   systems=state
 # Homes are saved on exit even if the owner never moved a thing.
 if not value.has("layoutRevision") and _original_furnishings(value.items):return defaults()
 return value.items

func save(rows: Array) -> bool:
 if not writable:return false
 if not valid(rows):error="Could not save this furniture arrangement.";return false
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="Could not create the home save folder.";return false
 var content:=JSON.stringify({"schema":1,"layoutRevision":2,"owner":owner,"items":rows,"berth":BERTH_KEYS[berth],"flight":systems,"survey_started":survey_started,"observations":observations,"fish":fish,"botany":botany,"ore":ore,"shelf":shelf_id,"trophy":trophy_key},"\t")
 if content.to_utf8_buffer().size()>65536:error="Home storage is full.";return false
 var temp=path()+".tmp";var f=FileAccess.open(temp,FileAccess.WRITE)
 if f==null:error="Could not write your home. Your previous layout is safe.";return false
 f.store_string(content);f.flush()
 var result=f.get_error();f.close()
 if result!=OK:error="Saving failed. Your previous layout is safe.";return false
 if DirAccess.rename_absolute(temp,path())!=OK:error="Could not finish saving your home.";return false
 error="";saved.emit();return true

# A field sample already has an identity: one SKU and harvest day per profile.
# One choice per species keeps the physical shelf usable with years of harvests.
func shelf_samples(activity:String) -> Array:
 var choices:Array=[]
 var cargo:Dictionary=botany if activity=="botany" else ore
 var catalogue:Array=preload("res://scripts/botanical_garden.gd").PLANTS if activity=="botany" else preload("res://scripts/ore_outcrop.gd").ORES
 for sku in catalogue:
  var days:Array=cargo.get(sku,{}).get("days",[])
  if days.is_empty():continue
  var day:=int(days[0])
  if shelf_id.begins_with(str(sku)+"/") and owns_sample(shelf_id):day=int(shelf_id.get_slice("/",1))
  choices.append({"id":"%s/%d"%[sku,day],"sku":sku,"day":day})
 return choices

func owns_sample(id:String) -> bool:
 var parts:=id.split("/")
 if parts.size()!=2 or not parts[1].is_valid_int():return false
 var day:=int(parts[1])
 if str(day)!=parts[1]:return false
 var days:Array=field_cargo(parts[0]).get(parts[0],{}).get("days",[])
 return days.any(func(value):return int(value)==day)

func select_specimen(rows:Array,id:String) -> bool:
 if id!="" and not owns_sample(id):error="This sample is no longer aboard.";return false
 var old:=shelf_id
 shelf_id=id
 if save(rows):return true
 shelf_id=old;return false

func field_cargo(sku:String) -> Dictionary:
 return ore if sku in preload("res://scripts/ore_outcrop.gd").ORES else botany

func record_harvest(rows:Array,sku:String,day:int) -> String:
 var cargo:=field_cargo(sku)
 var entry:Dictionary=cargo.get(sku,{"last":-1,"days":[]}).duplicate(true)
 if entry.last==day or entry.days.any(func(sample):return int(sample)==day):return "Already gathered today"
 entry.last=day;entry.days.append(day);entry.days.sort()
 return save_samples(rows,cargo,sku,entry)

func confirm_sample_transfer(rows:Array,sku:String,day:int) -> String:
 var cargo:=field_cargo(sku)
 if not cargo.has(sku):return ""
 var entry:Dictionary=cargo[sku].duplicate(true)
 entry.days=entry.days.filter(func(sample):return int(sample)!=day)
 return save_samples(rows,cargo,sku,entry)

func save_samples(rows:Array,cargo:Dictionary,sku:String,entry:Dictionary) -> String:
 var previous:Variant=cargo.get(sku)
 var old_display:=shelf_id
 cargo[sku]=entry
 if shelf_id!="" and not owns_sample(shelf_id):shelf_id=""
 if save(rows):return ""
 shelf_id=old_display
 if previous==null:cargo.erase(sku)
 else:cargo[sku]=previous
 return error if error!="" else "Could not save samples"

const ORIGINAL_FURNISHINGS = [
  {"item":"armchair","x":-1.95,"z":-0.90,"angle":PI},
  {"item":"low-table","x":-1.9,"z":0.30,"angle":0.0},
  {"item":"plant","x":-4.35,"z":0.35,"angle":0.0},
  {"item":"plant","x":2.05,"z":0.98,"angle":0.0},
  {"item":"lamp","x":-3.7,"z":0.60,"angle":0.0},
  {"item":"rug","x":-2.2,"z":-0.65,"angle":0.0},
  {"item":"stool","x":-3.60,"z":2.65,"angle":0.0}]

static func _original_furnishings(rows:Array) -> bool:
 if rows.size()!=ORIGINAL_FURNISHINGS.size():return false
 for i in rows.size():
  var r=rows[i];var old=ORIGINAL_FURNISHINGS[i]
  if r.item!=old.item or not is_equal_approx(float(r.x),float(old.x)) or not is_equal_approx(float(r.z),float(old.z)) or not is_equal_approx(float(r.angle),float(old.angle)):return false
 return true

static func defaults() -> Array:
 # One conversation group beside the aquarium. The chair faces the built-in
 # bench across the table. The galley stool tucks under its breakfast ledge.
 return [
  {"item":"armchair","x":1.61,"z":0.81,"angle":-1.26},
  {"item":"low-table","x":3.03,"z":0.26,"angle":-0.50},
  {"item":"plant","x":-4.02,"z":2.65,"angle":0.0},
  {"item":"plant","x":-2.20,"z":-1.35,"angle":0.0},
  {"item":"lamp","x":2.86,"z":1.70,"angle":0.0},
  {"item":"rug","x":2.40,"z":0.69,"angle":0.0},
  {"item":"stool","x":-3.02,"z":-0.03,"angle":0.45}]
