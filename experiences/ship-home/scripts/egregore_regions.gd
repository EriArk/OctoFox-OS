# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Atlas units measure distance along the field. Each cluster has its own flight space in metres.
const NAMES:=["Lantern Reach","Prism Shoal","Cinder Drift"]
const CENTRES:=[Vector3(-30,1,12),Vector3(0,4,33),Vector3(31,-1,11)]
const TINTS:=[Color("65e0cf"),Color("ae9dfd"),Color("ffb578")]
const JUMP_RANGE:=42.0
const ORIGINS:=[Vector3.ZERO,Vector3(64000,800,-68000),Vector3(127000,1800,9000)]
const GATE_CONTACT:=[0,2,11]
const BERTH_CONTACT:=[0,1,2,8,11,12,15,16,17,18,19,20,9,10,13,14]
const FLIGHT_RADIUS:=39000.0
const CRUISE_SPEED:=155.0
const CONTACTS:=[
 {"name":"Lantern Station","kind":"station","site":0,"sector":0,"p":Vector3.ZERO},
 {"name":"Echo Orchard","kind":"island","site":1,"sector":0,"p":Vector3(0,0,-600)},
 {"name":"Prism Anchorage","kind":"station","site":2,"sector":1,"p":Vector3.ZERO},
 {"name":"Amber Courier","role":"Courier","kind":"ship","sector":0,"p":Vector3(0,25,-130),"orbit":Vector2(76,40)},
 {"name":"Veil signal","kind":"signal","sector":0,"p":Vector3(-120,48,-380)},
 {"name":"Prism Warden","role":"Patrol","kind":"hostile","sector":1,"p":Vector3(78,22,300),"orbit":Vector2(55,45)},
 {"name":"Ring surveyor","role":"Surveyor","kind":"ship","sector":1,"p":Vector3(-30,28,150),"orbit":Vector2(90,55)},
 {"name":"Prism relay","kind":"signal","sector":1,"p":Vector3(-87,26,490)},
 {"name":"Table Isle","kind":"island","site":3,"sector":0,"p":Vector3(-24000,68,-13000)},
 {"name":"Crown Isle","kind":"island","site":12,"sector":0,"p":Vector3(11000,90,-23000)},
 {"name":"Twin Spurs","kind":"island","site":13,"sector":0,"p":Vector3(23000,122,13000)},
 {"name":"Cinder Anchorage","kind":"station","site":4,"sector":2,"p":Vector3.ZERO},
 {"name":"Cinder Garden","kind":"island","site":5,"sector":2,"p":Vector3(0,0,-1600)},
 {"name":"Ember Isle","kind":"island","site":14,"sector":2,"p":Vector3(-22000,180,12000)},
 {"name":"Glass Atoll","kind":"island","site":15,"sector":1,"p":Vector3(23000,120,-11500)},
 {"name":"Lantern Biostation","kind":"station","site":6,"sector":0,"p":Vector3(0,0,6200)},
 {"name":"Wayfarer House","kind":"station","site":7,"sector":1,"p":Vector3(23000,120,-4900)},
 {"name":"Cinder Exchange","kind":"station","site":8,"sector":2,"p":Vector3(-19000,110,-8500)},
 {"name":"Reedwater Delta","kind":"island","site":9,"sector":0,"p":Vector3(-1400,35,22100)},
 {"name":"Meridian Rift","kind":"island","site":10,"sector":1,"p":Vector3(0,0,-6700)},
 {"name":"Kiln Caldera","kind":"island","site":11,"sector":2,"p":Vector3(-19000,110,-15000)},
 {"name":"Marigold Hauler","role":"Freighter","kind":"ship","sector":2,"lane":Vector2i(17,20),"period":154.0},
 {"name":"Threadrunner","role":"Pathfinder","kind":"ship","sector":1,"lane":Vector2i(16,14),"period":122.0},
 {"name":"Vesper Envoy","role":"Envoy","kind":"ship","sector":0,"lane":Vector2i(0,15),"period":164.0},
 {"name":"Ash Jackal","role":"Pirate","kind":"hostile","sector":2,"p":Vector3(-18780,195,-10100),"orbit":Vector2(152,91)},
 {"name":"Veil ray","role":"Field fauna","kind":"fauna","sector":1,"p":Vector3(135,73,-210),"orbit":Vector2(125,64),"period":132.0},
 {"name":"Lantern calf","role":"Field fauna","kind":"fauna","sector":0,"p":Vector3(86,71,6000),"orbit":Vector2(82,43),"period":95.0,"size":0.63}]
const HAULER:=21
const PATHFINDER:=22
const ENVOY:=23
const JACKAL:=24
const VEIL_RAY:=25

static func moving(entry:Dictionary) -> bool:
 return entry.has("orbit") or entry.has("lane")

static func period(entry:Dictionary) -> float:
 return entry.get("period",TAU/0.072)

static func lane_destination(entry:Dictionary,clock:float) -> int:
 return entry.lane.y if fposmod(clock,period(entry))<period(entry)*0.5 else entry.lane.x

static func contact_position(id:int,clock:float) -> Vector3:
 var entry:Dictionary=CONTACTS[id]
 var origin:Vector3=ORIGINS[entry.sector]
 if entry.has("lane"):
  var start:Vector3=CONTACTS[entry.lane.x].p
  var end:Vector3=CONTACTS[entry.lane.y].p
  var side:Vector3=start.direction_to(end).cross(Vector3.UP).normalized()
  var angle:=TAU*clock/period(entry)
  # Parallel outbound and return legs pass above the port, with a wide turn at either end.
  return origin+start.lerp(end,(1-cos(angle))*0.5)+side*(115+92*sin(angle))+Vector3.UP*(97+8*cos(2*angle))
 var pos:Vector3=origin+entry.p
 if entry.has("orbit"):
  var angle:=clock*TAU/period(entry)+id
  pos+=Vector3(cos(angle)*entry.orbit.x,5*sin(2*angle),sin(angle)*entry.orbit.y)
 return pos

# Shore orientation belongs to the place. Adding berths must not rotate an existing coast.
const ISLANDS={
 1:[94.0,0.0,"ridge"], 8:[94.0,1.7,"mesa"], 12:[94.0,3.4,"summit"],
 9:[106.0,5.1,"spurs"], 10:[86.0,6.8,"spurs"], 13:[92.0,8.5,"spurs"], 14:[132.0,10.2,"spurs"],
 18:[136.0,11.9,"delta"], 19:[148.0,13.6,"rift"], 20:[143.0,15.3,"caldera"]
}

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
