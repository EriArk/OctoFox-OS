# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipLayoutStore
extends RefCounted
const MAX_ITEMS=48
# Different deck coordinates: preserve all earlier preview layouts in homes/.
var directory="user://homes/studio-v1"
var owner="guest"
var error=""
var writable=true
var berth:=0

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
 owner=profile if not profile.is_empty() else "guest";error="";writable=true;berth=0
 if not FileAccess.file_exists(path()):return defaults()
 var f=FileAccess.open(path(),FileAccess.READ)
 if f==null or f.get_length()>65536:
  error="Could not read this home's layout. Your saved file has been kept.";writable=false;return []
 var parser=JSON.new()
 var parsed=parser.parse(f.get_as_text())
 var value=parser.data if parsed==OK else null
 if not value is Dictionary or value.get("schema")!=1 or value.get("owner")!=owner or not valid(value.get("items")):
  error="This layout could not be loaded. Your saved file has been kept.";writable=false;return []
 if value.get("berth","")=="orchard":berth=1
 # Homes are saved on exit even if the owner never moved a thing.
 if not value.has("layoutRevision") and _original_furnishings(value.items):return defaults()
 return value.items

func save(rows: Array) -> bool:
 if not writable:return false
 if not valid(rows):error="Could not save this furniture arrangement.";return false
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="Could not create the home save folder.";return false
 var temp=path()+".tmp";var f=FileAccess.open(temp,FileAccess.WRITE)
 if f==null:error="Could not write your home. Your previous layout is safe.";return false
 f.store_string(JSON.stringify({"schema":1,"layoutRevision":2,"owner":owner,"items":rows,"berth":"orchard" if berth==1 else "station"},"\t"));f.flush()
 var result=f.get_error();f.close()
 if result!=OK:error="Saving failed. Your previous layout is safe.";return false
 if DirAccess.rename_absolute(temp,path())!=OK:error="Could not finish saving your home.";return false
 error="";return true

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
