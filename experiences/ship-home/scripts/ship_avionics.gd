# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Navigation, sensors and cockpit panels all read the same sector catalogue.
const SECTORS = ["Lantern Reach","Prism Shoal"]
const ORIGINS = [Vector3.ZERO,Vector3(42000,800,-36000)]
const JUMP_COST := 22.0
const TANK := 100.0
const MODULES = ["Thrusters","Shields","Sensors","Comms","Shift drive","Emitter bank"]
const BUSES = ["SYS","ENG","WEP"]
const CATALOG = [
 {"name":"Lantern Station","kind":"station","site":0,"sector":0,"p":Vector3.ZERO},
 {"name":"Echo Orchard","kind":"island","site":1,"sector":0,"p":Vector3(0,0,-600)},
 {"name":"Prism Anchorage","kind":"station","site":2,"sector":1,"p":Vector3.ZERO},
 {"name":"Amber Courier","kind":"ship","sector":0,"p":Vector3(0,25,-130),"orbit":Vector2(76,40)},
 {"name":"Veil signal","kind":"signal","sector":0,"p":Vector3(-120,48,-380)},
 {"name":"Prism Warden","kind":"hostile","sector":1,"p":Vector3(78,22,300),"orbit":Vector2(55,45)},
 {"name":"Ring surveyor","kind":"ship","sector":1,"p":Vector3(-30,28,150),"orbit":Vector2(90,55)},
 {"name":"Prism relay","kind":"signal","sector":1,"p":Vector3(-87,26,490)},
 {"name":"Table Isle","kind":"island","sector":0,"p":Vector3(-485,68,-988)},
 {"name":"Crown Isle","kind":"island","sector":0,"p":Vector3(548,90,-887)},
 {"name":"Twin Spurs","kind":"island","sector":0,"p":Vector3(115,122,-1277)}]
var f
var sector:=0
var target:=1
var route:=-1
var permit:=-1
var lock_id:=-1
var deployed:=false
var cruise:=false
var boost:=0.0
var charge:=0.0
var transit:=0.0
var fuel:=TANK
var pips: Array[int]=[2,2,2]
var enabled: Array[bool]=[true,true,true,true,true,true]
var shield:=100.0
var hull:=100.0
var engine:=100.0
var weapon:=100.0
var npc_shield:=100.0
var disabled_time:=0.0
var pulse_time:=0.0
var orbit_time:=0.0
var reply:=""
var reply_time:=0.0
var bodies: Dictionary={}
var path_line:=MeshInstance3D.new()
var line_target:=-2

func configure(flight) -> void:
 f=flight
 for i in range(3,CATALOG.size()):
  var item:Dictionary=CATALOG[i]
  if item.kind=="island":continue
  var node:=Node3D.new();node.name=item.name.replace(" ","");f.add_child(node);bodies[i]=node
  if item.kind in ["ship","hostile"]:
   var hull_scene:=preload("res://assets/ship/saucer.glb").instantiate() as Node3D
   node.add_child(hull_scene)
   if item.kind=="hostile":
    for side in [-1,1]:f.art.box(node,Vector3(side*3,0.45,-4.3),Vector3(0.48,0.48,3.0),Color("cf715b"),false,true)
  else:
   f.art.cylinder(node,Vector3.ZERO,1.7,5.5,Color("586677"),0.4)
   f.art.cylinder(node,Vector3.UP*2.7,0.65,0.4,Color("74e2d2"),0.4)
 f.add_child(path_line)
 var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color("78b6b3")
 path_line.material_override=ink
 update_traffic(0)

func fresh(saved:Dictionary) -> void:
 fuel=clampf(float(saved.get("fuel",TANK)),0,TANK)
 pips.assign(saved.get("pips",[2,2,2]));enabled.assign(saved.get("modules",[true,true,true,true,true,true]))
 shield=100;hull=100;engine=100;weapon=100;npc_shield=100;disabled_time=0;orbit_time=0
 reply="";reply_time=0

func snapshot() -> Dictionary:
 return {"fuel":fuel,"pips":pips.duplicate(),"modules":enabled.duplicate()}

func docked(site:int) -> void:
 sector=1 if site==2 else 0
 target=1-site if site<2 else 7
 permit=-1;route=-1;lock_id=-1;deployed=false;cruise=false;boost=0;charge=0;transit=0
 update_traffic(0)

func say(text:String) -> void:
 reply=text;reply_time=5

func position_of(id:int,at:float=-1) -> Vector3:
 var item:Dictionary=CATALOG[id]
 var pos:Vector3=ORIGINS[item.sector]+item.p
 if item.has("orbit"):
  var t:float=(orbit_time if at<0 else at)*0.072+id
  var radii:Vector2=item.orbit
  pos+=Vector3(cos(t)*radii.x,5*sin(2*t),sin(t)*radii.y)
 return pos

func contacts() -> Array[int]:
 var result:Array[int]=[]
 for i in CATALOG.size():
  if CATALOG[i].sector==sector and (enabled[2] or CATALOG[i].has("site")):result.append(i)
 return result

func select(id:int) -> void:
 if not id in contacts():return
 if lock_id!=id:lock_id=-1
 target=id
 if CATALOG[id].has("site"):f.destination=id

func nose_contact() -> void:
 var score:=-2.0;var best:=-1
 for i in contacts():
  var ray:Vector3=position_of(i)-f.location
  if ray.length()<4:continue
  var bearing:float=(-f.attitude.z).dot(ray.normalized())
  if bearing>score:best=i;score=bearing
 if best>=0:select(best);say(CATALOG[best].name)

func range_to(id:int) -> float:return position_of(id).distance_to(f.location)
func jump_axis() -> Vector3:return Vector3.FORWARD if sector==0 else Vector3.BACK

func distribute(bus:int) -> void:
 if pips[bus]>=4:say("Maximum allocation");return
 var donor:=(bus+1)%3;var other:=(bus+2)%3
 if pips[other]>pips[donor]:donor=other
 pips[donor]-=1;pips[bus]+=1

func module_switch(index:int) -> void:
 enabled[index]=not enabled[index]
 if not enabled[index]:
  match index:
   0:cruise=false;boost=0
   1:shield=0
   2:lock_id=-1;select(f.destination)
   4:charge=0;cruise=false
   5:deployed=false;lock_id=-1

func hail() -> void:
 if not enabled[3]:say("Comms offline");return
 if range_to(target)>850:say("Outside communications range");return
 match CATALOG[target].kind:
  "station":
   if f.mode!=f.Mode.FLYING:say("Already alongside");return
   if deployed:say("Control · Stow hardpoints first");return
   permit=target;f.destination=target;say(CATALOG[target].name+" · Cleared for pad 01")
  "ship":say(CATALOG[target].name+" · Passing on your scope. Safe flight.")
  "hostile":say("Warden · Restricted patrol. Keep your distance.")
  "island":say("Open landing site · Approach at your discretion" if CATALOG[target].has("site") else "Survey contact · No landing pad")
  _:say("Beacon · Sector coordinates confirmed")

func hardpoints() -> void:
 if not enabled[5]:say("Emitter bank offline");return
 if f.mode!=f.Mode.FLYING or cruise or charge>0:say("Normal flight required");return
 deployed=not deployed
 if deployed:permit=-1
 else:lock_id=-1
 say("Hardpoints deployed" if deployed else "Hardpoints stowed")

func acquire() -> void:
 if lock_id==target:lock_id=-1;return
 if not deployed or not enabled[2]:say("Deploy hardpoints and power sensors");return
 if CATALOG[target].kind!="hostile" or disabled_time>0:say("No hostile signature");return
 if range_to(target)>650:say("Outside tracking range");return
 lock_id=target;say("Target locked · "+CATALOG[target].name)

func fire() -> void:
 if lock_id!=target or not deployed or disabled_time>0:say("Acquire a hostile contact");return
 if weapon<20 or pulse_time>0:say("Emitter recharging");return
 var ray:Vector3=position_of(target)-f.location
 if ray.length()>500 or (-f.attitude.z).dot(ray.normalized())<0.82:say("Bring the target into the forward arc");return
 weapon-=20;pulse_time=0.45;npc_shield=maxf(0,npc_shield-25)
 if npc_shield<=0:disabled_time=30;lock_id=-1;say("Warden disabled")
 else:say("Pulse contact · Warden shield %d%%"%int(npc_shield))

func toggle_cruise() -> void:
 if cruise:cruise=false;say("Normal flight");return
 if f.mode!=f.Mode.FLYING or not enabled[0] or not enabled[4] or deployed or charge>0 or fuel<1:
  say("Cruise requires fuel, drives and stowed hardpoints");return
 cruise=true;boost=0;say("Cruise engaged")

func boost_drive() -> void:
 if f.mode!=f.Mode.FLYING or cruise or not enabled[0] or engine<36 or charge>0:say("Boost unavailable");return
 engine-=36;boost=1.8;say("Boost")

func plot() -> void:
 route=1-sector;say("Course plotted · "+SECTORS[route])

func jump() -> void:
 if charge>0:charge=0;say("Charge cancelled");return
 if route<0:say("Plot a route first");return
 if f.mode!=f.Mode.FLYING or deployed or not enabled[4] or fuel<JUMP_COST:say("Jump requires flight, fuel and a clear drive");return
 if f.local_air>0.01 or range_to(0 if sector==0 else 2)<75:say("Clear the local mass shadow");return
 if (-f.attitude.z).dot(jump_axis())<0.95:say("Align with the course diamond");return
 cruise=false;boost=0;f.velocity=Vector3.ZERO;f.throttle=0;charge=0.001;say("Shift drive charging")

func service() -> void:
 if f.mode!=f.Mode.BERTH or f.berth==1:say("Station service requires a berth");return
 fuel=TANK;hull=100;shield=100 if enabled[1] else 0;say("Service complete · tank full")

func impact(speed:float) -> void:
 if speed<5:return
 var hit:=clampf(speed*0.32,2,38)/lerpf(0.74,1.26,pips[0]/4.0);var absorbed:=minf(shield,hit)
 shield-=absorbed;hull=maxf(0,hull-hit+absorbed);say("Hull contact")

func advance(dt:float) -> void:
 update_traffic(dt)
 reply_time=maxf(reply_time-dt,0)
 pulse_time=maxf(pulse_time-dt,0);boost=maxf(boost-dt,0)
 engine=minf(100,engine+dt*pips[1]*2.8);weapon=minf(100,weapon+dt*pips[2]*3.0)
 if enabled[1]:shield=minf(100,shield+dt*pips[0]*0.9)
 if disabled_time>0:
  disabled_time=maxf(0,disabled_time-dt)
  if disabled_time==0:npc_shield=100
 if lock_id>=0 and range_to(lock_id)>650:lock_id=-1
 if sector==1 and disabled_time<=0 and f.mode==f.Mode.FLYING and range_to(5)<90:
  var hit:=dt*5.0/lerpf(0.74,1.26,pips[0]/4.0);var absorbed:=minf(hit,shield);shield-=absorbed;hull=maxf(0,hull-hit+absorbed)
 if hull<=0:
  f.reset(f.berth);service();hull=100;say("Recovery tow · last berth");return
 if cruise:
  fuel=maxf(0,fuel-dt*(0.12+0.22*absf(f.throttle)))
  if fuel<1:cruise=false;say("Cruise reserve reached")
 if transit>0:
  transit=maxf(0,transit-dt)
  if transit==0:
   sector=route;route=-1;permit=-1;lock_id=-1
   f.destination=2 if sector==1 else 0;target=f.destination
   f.location=ORIGINS[sector]+Vector3(0,6,700);f.attitude=Basis.IDENTITY
   f.velocity=Vector3.ZERO;f.throttle=0;f.turn_rate=Vector3.ZERO;update_traffic(0);say("Arrived · "+SECTORS[sector])
 elif charge>0:
  if (-f.attitude.z).dot(jump_axis())<0.95:charge=0;say("Alignment lost");return
  charge+=dt
  if charge>=3:
   charge=0;transit=2;fuel-=JUMP_COST

func update_traffic(dt:float) -> void:
 orbit_time+=dt
 for id:int in bodies:
  var node:Node3D=bodies[id];node.visible=CATALOG[id].sector==sector
  if not node.visible:continue
  node.position=position_of(id)
  if CATALOG[id].has("orbit"):
   node.rotation.y=atan2(node.position.x-position_of(id,orbit_time+0.1).x,node.position.z-position_of(id,orbit_time+0.1).z)
 if target!=line_target:
  line_target=target;path_line.mesh=null
  if CATALOG[target].has("orbit"):
   var line:=ImmediateMesh.new();line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
   for i in 73:line.surface_add_vertex(position_of(target,i*TAU/(72*0.072)))
   line.surface_end();path_line.mesh=line
