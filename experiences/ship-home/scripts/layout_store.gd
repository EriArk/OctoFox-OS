# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipLayoutStore
extends RefCounted
const MAX_ITEMS=48
# Different deck coordinates: preserve all earlier preview layouts in homes/.
var directory="user://homes/saucer-v2"
var owner="guest"
var error=""
var writable=true

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
 owner=profile if not profile.is_empty() else "guest";error="";writable=true
 if not FileAccess.file_exists(path()):return defaults()
 var f=FileAccess.open(path(),FileAccess.READ)
 if f==null or f.get_length()>65536:
  error="Could not read this home's layout. Your saved file has been kept.";writable=false;return []
 var parser=JSON.new()
 var parsed=parser.parse(f.get_as_text())
 var value=parser.data if parsed==OK else null
 if not value is Dictionary or value.get("schema")!=1 or value.get("owner")!=owner or not valid(value.get("items")):
  error="This layout could not be loaded. Your saved file has been kept.";writable=false;return []
 return value.items

func save(rows: Array) -> bool:
 if not writable:return false
 if not valid(rows):error="Could not save this furniture arrangement.";return false
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="Could not create the home save folder.";return false
 var temp=path()+".tmp";var f=FileAccess.open(temp,FileAccess.WRITE)
 if f==null:error="Could not write your home. Your previous layout is safe.";return false
 f.store_string(JSON.stringify({"schema":1,"owner":owner,"items":rows},"\t"));f.flush()
 var result=f.get_error();f.close()
 if result!=OK:error="Saving failed. Your previous layout is safe.";return false
 if DirAccess.rename_absolute(temp,path())!=OK:error="Could not finish saving your home.";return false
 error="";return true

static func defaults() -> Array:
 return [
  {"item":"armchair","x":-1.95,"z":-0.90,"angle":PI},
  {"item":"low-table","x":-1.9,"z":0.30,"angle":0.0},
  {"item":"plant","x":-4.35,"z":0.35,"angle":0.0},
  {"item":"plant","x":4.3,"z":0.50,"angle":0.0},
  {"item":"lamp","x":-3.7,"z":0.60,"angle":0.0},
  {"item":"rug","x":-2.2,"z":-0.65,"angle":0.0},
  {"item":"stool","x":-2.8,"z":2.65,"angle":0.0}]
