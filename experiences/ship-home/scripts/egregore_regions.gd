# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Atlas units measure distance along the field. Each cluster has its own flight space in metres.
const NAMES:=["Lantern Reach","Prism Shoal","Cinder Drift"]
const CENTRES:=[Vector3(-30,1,12),Vector3(0,4,33),Vector3(31,-1,11)]
const TINTS:=[Color("65e0cf"),Color("ae9dfd"),Color("ffb578")]
const JUMP_RANGE:=42.0
const ORIGINS:=[Vector3.ZERO,Vector3(64000,800,-68000),Vector3(127000,1800,9000)]
const GATE_CONTACT:=[0,2,11]
const BERTH_CONTACT:=[0,1,2,8,11,12]
const FLIGHT_RADIUS:=39000.0
const CRUISE_SPEED:=155.0
const CONTACTS:=[
 {"name":"Lantern Station","kind":"station","site":0,"sector":0,"p":Vector3.ZERO},
 {"name":"Echo Orchard","kind":"island","site":1,"sector":0,"p":Vector3(0,0,-600)},
 {"name":"Prism Anchorage","kind":"station","site":2,"sector":1,"p":Vector3.ZERO},
 {"name":"Amber Courier","kind":"ship","sector":0,"p":Vector3(0,25,-130),"orbit":Vector2(76,40)},
 {"name":"Veil signal","kind":"signal","sector":0,"p":Vector3(-120,48,-380)},
 {"name":"Prism Warden","kind":"hostile","sector":1,"p":Vector3(78,22,300),"orbit":Vector2(55,45)},
 {"name":"Ring surveyor","kind":"ship","sector":1,"p":Vector3(-30,28,150),"orbit":Vector2(90,55)},
 {"name":"Prism relay","kind":"signal","sector":1,"p":Vector3(-87,26,490)},
 {"name":"Table Isle","kind":"island","site":3,"sector":0,"p":Vector3(-24000,68,-13000)},
 {"name":"Crown Isle","kind":"island","sector":0,"p":Vector3(11000,90,-23000)},
 {"name":"Twin Spurs","kind":"island","sector":0,"p":Vector3(23000,122,13000)},
 {"name":"Cinder Anchorage","kind":"station","site":4,"sector":2,"p":Vector3.ZERO},
 {"name":"Cinder Garden","kind":"island","site":5,"sector":2,"p":Vector3(0,0,-1600)},
 {"name":"Ember Isle","kind":"island","sector":2,"p":Vector3(-22000,180,12000)},
 {"name":"Glass Atoll","kind":"island","sector":1,"p":Vector3(23000,120,-11500)}]

static func linked(from:int,to:int) -> bool:
 return from>=0 and to>=0 and from<CENTRES.size() and to<CENTRES.size() and from!=to and CENTRES[from].distance_to(CENTRES[to])<=JUMP_RANGE

static func passage(from:int,to:int) -> Array[int]:
 var result:Array[int]=[]
 if from==to:return result
 var pending:Array[int]=[from]
 var parent:Dictionary[int,int]={from:-1}
 while not pending.is_empty():
  var here:int=pending.pop_front()
  for next in CENTRES.size():
   if parent.has(next) or not linked(here,next):continue
   parent[next]=here
   if next==to:
    var leg:=next
    while leg!=from:
     result.push_front(leg);leg=parent[leg]
    return result
   pending.append(next)
 return result

static func range_text(metres:float) -> String:
 return "%.1f km"%(metres/1000.0) if metres>=1000 else "%d m"%roundi(metres)

static func cruise_time(metres:float) -> String:
 var seconds:=ceili(metres/CRUISE_SPEED)
 return "%d:%02d"%[floori(seconds/60.0),seconds%60]
