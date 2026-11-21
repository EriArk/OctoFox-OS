# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Fight adapted from Tidewater's CatchMinigame.js (MIT, see licenses/Tidewater.txt).
## Each entry contains length range, pull, stamina, and two natural colour morphs.
const SPECIES = {
 "glassfin": ["Glassfin", 9, 19, 0.32, 9.0, "9adcca", "83badb"],
 "loach": ["Copper loach", 18, 34, 0.72, 14.0, "c99366", "d5b57b"],
 "ribbon": ["Ribbon ray", 32, 56, 1.35, 19.0, "a293d9", "e39dad"],
}
const WATERS = {1:"Echo Orchard", 3:"Table Isle"}
const TANK_LIMIT = 8
const BAG_LIMIT = 24

static func specimen(site:int, reach:float) -> Dictionary:
 var bytes:=Crypto.new().generate_random_bytes(16)
 bytes[6]=(bytes[6]&15)|64
 bytes[8]=(bytes[8]&63)|128
 var hex:=bytes.hex_encode()
 var id:="%s-%s-%s-%s-%s"%[hex.left(8),hex.substr(8,4),hex.substr(12,4),hex.substr(16,4),hex.substr(20)]
 var species:="glassfin" if reach<9.5 else ("ribbon" if site==3 else "loach")
 return {"id":id,"species":species,"site":site,"place":"bag"}

static func length_cm(fish:Dictionary) -> int:
 var row:Array=SPECIES[fish.species]
 return int(row[1])+fish.id.left(4).hex_to_int()%(int(row[2])-int(row[1])+1)

static func tint(fish:Dictionary) -> Color:
 return Color(SPECIES[fish.species][5+fish.id.substr(4,2).hex_to_int()%2])

static func title(fish:Dictionary) -> String:
 return "%s · %d cm"%[SPECIES[fish.species][0],length_cm(fish)]

static func valid_stock(value:Variant) -> bool:
 if not value is Array or value.size()>BAG_LIMIT+TANK_LIMIT:return false
 var seen:Dictionary={}
 var tank:=0
 for item in value:
  if not item is Dictionary or not SPECIES.has(item.get("species")):return false
  if not (item.get("site") is float or item.get("site") is int) or (item.site!=1 and item.site!=3):return false
  if (item.site==1 and item.species=="ribbon") or (item.site==3 and item.species=="loach"):return false
  var id:String=str(item.get("id",""))
  if id.length()!=36 or id[8]!="-" or id[13]!="-" or id[18]!="-" or id[23]!="-" or id[14]!="4" or not id[19] in ["8","9","a","b"] or not id.replace("-","").is_valid_hex_number() or seen.has(id):return false
  if item.get("place") not in ["bag","tank","sending"]:return false
  if item.place=="tank":tank+=1
  seen[id]=true
 return tank<=TANK_LIMIT and value.size()-tank<=BAG_LIMIT

var rng:=RandomNumberGenerator.new()
var distance:=0.0
var stamina:=1.0
var tension:=0.3
var surge:=0.0
var direction:=1.0
var power:=0.0
var endurance:=0.0
var next_surge:=0.0
var surge_left:=0.0
var overload:=0.0
var slack:=0.0

func start(fish:Dictionary, reach:float) -> void:
 var row:Array=SPECIES[fish.species]
 power=float(row[3])*pow(float(length_cm(fish))/float(row[2]),0.55)
 endurance=float(row[4])
 distance=reach;stamina=1;tension=0.3;surge=0;overload=0;slack=0
 surge_left=0;next_surge=rng.randf_range(1.2,3.2)
 direction=1 if rng.randf()>0.5 else -1

func advance(dt:float,reel:float,rod:float) -> String:
 next_surge-=dt
 if next_surge<=0 and surge_left<=0:
  surge_left=rng.randf_range(0.8,2.0)*(0.4+0.6*stamina)
  next_surge=rng.randf_range(2,5)*(2-stamina)
  direction=-direction
 surge_left-=dt
 surge=lerpf(surge,1 if surge_left>0 else 0,1-exp(-dt*6))
 var counter:=maxf(0,-rod*direction)
 var pull:=power*(0.35+0.65*surge)*(0.35+0.65*stamina)*(1-0.20*counter)
 var target:=lerpf(pull*0.72,0.5+pull*0.95,reel)
 tension=lerpf(tension,target,1-exp(-dt*lerpf(3,2.2,reel)))
 distance=maxf(0,distance+dt*lerpf(pull*1.4,-1.35*(1.15-0.6*surge*stamina),reel))
 stamina=maxf(0,stamina-dt/endurance*(1.0 if tension>=0.30 and tension<=0.85 else 0.3))
 overload=maxf(0,overload+(dt if tension>1 else -2*dt))
 slack=maxf(0,slack+(dt if tension<0.12 else -2*dt))
 if overload>0.45:return "Line snapped"
 if slack>4 or distance>60:return "Fish slipped away"
 return "caught" if distance<1.2 else ""
