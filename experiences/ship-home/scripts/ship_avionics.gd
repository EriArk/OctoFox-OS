# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Navigation, sensors and cockpit panels all read the same sector catalogue.
const Regions:=preload("res://scripts/egregore_regions.gd")
const SECTORS:=Regions.NAMES
const ORIGINS:=Regions.ORIGINS
const ENTRY_OFFSET:=Vector3(0,6,700)
const JUMP_COST := 22.0
const TANK := 100.0
const MODULES = ["Thrusters","Shields","Sensors","Comms","Shift drive","Emitter bank"]
const BUSES = ["SYS","ENG","WEP"]
const CATALOG:=Regions.CONTACTS
enum Group { PULSE, LASER, MISSILES }
const GROUP_NAMES:=["Pulse cannon","Beam laser","Seeker rack"]
const WARDEN:=5
const RACK_SIZE:=3
const SEEK_TIME:=1.4
const FLIGHT_TIME:=1.25
const WARNING_TIME:=4.0
var installed:Array=[]
var group:=Group.PULSE
var gimballed:=true
var missiles:=RACK_SIZE
var seeker:=0.0
var missile_time:=0.0
var incoming:=0.0
var retaliation:=0.0
var defence_cooldown:=0.0
var burst_from:=Vector3.ZERO
var burst_to:=Vector3.ZERO
var shot_group:=Group.PULSE
var burst_span:=0.0
var missile_from:=Vector3.ZERO
var incoming_from:=Vector3.ZERO
var flare_time:=0.0
var flare_at:=Vector3.ZERO
var f
var sector:=0
var target:=1
var route:=-1
var arrival_target:=-1
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
 installed=saved.get("installed",[]).duplicate() if saved.get("installed") is Array else []
 fuel=clampf(float(saved.get("fuel",TANK)),0,TANK)
 pips.assign(saved.get("pips",[2,2,2]));enabled.assign(saved.get("modules",[true,true,true,true,true,true]))
 group=clampi(int(saved.get("fireGroup",Group.PULSE)),Group.PULSE,Group.MISSILES)
 gimballed=bool(saved.get("gimballed",true));missiles=clampi(int(saved.get("missiles",RACK_SIZE)),0,RACK_SIZE)
 shield=100;hull=100;engine=100;weapon=100;npc_shield=100;disabled_time=0;orbit_time=0
 reply="";reply_time=0

func snapshot() -> Dictionary:
 return {"installed":installed.duplicate(),"fuel":fuel,"pips":pips.duplicate(),"modules":enabled.duplicate(),"fireGroup":group,"gimballed":gimballed,"missiles":missiles}

func docked(site:int) -> void:
 sector=CATALOG[Regions.BERTH_CONTACT[site]].sector
 target=1-site if site<2 else (7 if site==2 else Regions.GATE_CONTACT[sector])
 permit=-1;route=-1;arrival_target=-1;lock_id=-1;deployed=false;cruise=false;boost=0;charge=0;transit=0
 clear_ordnance()
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

func chart_contacts(region:int) -> Array[int]:
 var result:Array[int]=[]
 for i in CATALOG.size():
  var entry:Dictionary=CATALOG[i]
  if entry.sector!=region or (not enabled[2] and not entry.has("site")):continue
  if region!=sector and entry.has("orbit"):continue
  result.append(i)
 return result

func contacts() -> Array[int]:
 return chart_contacts(sector)

func select(id:int) -> void:
 if not id in contacts():return
 if lock_id!=id:lock_id=-1;seeker=0
 target=id
 if CATALOG[id].has("site") and f.mode!=f.Mode.LANDING:f.destination=CATALOG[id].site

func nose_contact() -> void:
 var score:=-2.0;var best:=-1
 for i in contacts():
  var ray:Vector3=position_of(i)-f.location
  if ray.length()<4:continue
  var bearing:float=(-f.attitude.z).dot(ray.normalized())
  if bearing>score:best=i;score=bearing
 if best>=0:select(best);say(CATALOG[best].name)

func range_to(id:int) -> float:return position_of(id).distance_to(f.location)
func jump_axis() -> Vector3:
 # The established Lantern–Prism corridor leaves through the bow and returns aft.
 if mini(sector,route)==0:return Vector3.FORWARD if sector==0 else Vector3.BACK
 return (Regions.CENTRES[route]-Regions.CENTRES[sector]).normalized() if route>=0 else Vector3.FORWARD

func distribute(bus:int,delta:int=1) -> void:
 if bus<0 or bus>=pips.size() or absi(delta)!=1:return
 if delta>0 and pips[bus]>=4:say("Maximum allocation");return
 if delta<0 and pips[bus]==0:say("Minimum allocation");return
 var partner:=(bus+1)%3
 var other:=(bus+2)%3
 if (pips[other]-pips[partner])*delta>0:partner=other
 pips[bus]+=delta
 pips[partner]-=delta
 var source:int=partner if delta>0 else bus
 var recipient:int=bus if delta>0 else partner
 say("%s  →  %s    ·    1 unit"%[BUSES[source],BUSES[recipient]])

func module_switch(index:int) -> void:
 enabled[index]=not enabled[index]
 if not enabled[index]:
  match index:
   0:cruise=false;boost=0
   1:shield=0
   2:lock_id=-1;select(Regions.BERTH_CONTACT[f.destination])
   4:charge=0;cruise=false
   5:deployed=false;lock_id=-1

func hail() -> void:
 if not enabled[3]:say("Comms offline");return
 if range_to(target)>850:say("Outside communications range");return
 match CATALOG[target].kind:
  "station":
   if f.mode!=f.Mode.FLYING:say("Already alongside");return
   if deployed:say("Control · Stow hardpoints first");return
   permit=target;f.destination=CATALOG[target].site;say(CATALOG[target].name+" · Cleared for pad 01")
  "ship":say(CATALOG[target].name+" · Passing on your scope. Safe flight.")
  "hostile":say("Warden · Restricted patrol. Keep your distance.")
  "island":say("Open landing site · Approach at your discretion" if CATALOG[target].has("site") else "Survey contact · No landing pad")
  _:say("Beacon · Sector coordinates confirmed")

func hardpoints() -> void:
 if not enabled[5]:say("Emitter bank offline");return
 if f.mode!=f.Mode.FLYING or cruise or charge>0:say("Normal flight required");return
 deployed=not deployed
 if deployed:permit=-1
 else:lock_id=-1;seeker=0
 say("Hardpoints deployed" if deployed else "Hardpoints stowed")

func acquire() -> void:
 if lock_id==target:lock_id=-1;seeker=0;return
 if not deployed or not enabled[2]:say("Deploy hardpoints and power sensors");return
 if CATALOG[target].kind!="hostile" or disabled_time>0:say("No hostile signature");return
 if range_to(target)>650:say("Outside tracking range");return
 lock_id=target;say("Target locked · "+CATALOG[target].name)

func cycle_group() -> void:
 group=(group+1)%GROUP_NAMES.size()
 seeker=0

func cycle_mount() -> void:
 if group==Group.MISSILES:return
 gimballed=not gimballed

func tracking() -> bool:
 if sector!=1 or lock_id!=WARDEN or not deployed or disabled_time>0:return false
 var ray:Vector3=position_of(WARDEN)-f.location
 return ray.length()<=500 and (-f.attitude.z).dot(ray.normalized())>0.82

func muzzle() -> Vector3:
 return f.location+f.attitude*Vector3(1.7,0.85,-5.5)

func pulse_span() -> float:
 var distance:=minf(500,muzzle().distance_to(position_of(WARDEN))) if sector==1 else 500.0
 return lerpf(0.30,2.1,distance/500.0)

func pulse_mark() -> Vector3:
 # The Warden follows an authored orbit; sample its animation at the bolt's arrival beat.
 return position_of(WARDEN,orbit_time+pulse_span())

func gun_ray() -> Vector3:
 if gimballed and tracking():
  var point:=pulse_mark() if group==Group.PULSE else position_of(WARDEN)
  return (point-muzzle()).normalized()
 return -f.attitude.z

func hit_warden(amount:float) -> void:
 npc_shield=maxf(0,npc_shield-amount)
 if npc_shield<=0:
  disabled_time=30;lock_id=-1;seeker=0;retaliation=0;say("Warden disabled")
 else:
  if retaliation<=0:retaliation=0.8
  say("Warden shield  %d%%"%roundi(npc_shield))

func fire() -> void:
 if not deployed or not enabled[5] or f.mode!=f.Mode.FLYING:return
 if group==Group.MISSILES:
  if not tracking() or seeker<1:say("Seeker has no lock");return
  if missiles==0:say("Rack empty");return
  if missile_time>0:return
  missiles-=1;seeker=0;missile_time=FLIGHT_TIME
  missile_from=f.location+f.attitude*Vector3(1.7,0.8,-5.5)
  say("Seeker away");return
 var cost:=20 if group==Group.PULSE else 28
 if weapon<cost or pulse_time>0:say("Emitter recharging");return
 var ray:=gun_ray()
 shot_group=group;weapon-=cost
 burst_from=muzzle()
 if group==Group.PULSE:
  burst_span=pulse_span();pulse_time=burst_span
  var reach:=minf(500,burst_from.distance_to(pulse_mark())) if sector==1 else 500.0
  burst_to=burst_from+ray*reach
  return
 burst_span=0.48;pulse_time=burst_span
 burst_to=burst_from+ray*500
 if sector==1 and disabled_time<=0:
  var target_ray:Vector3=position_of(WARDEN)-burst_from
  if target_ray.length()<=500 and ray.dot(target_ray.normalized())>=0.9998:
   burst_to=position_of(WARDEN)
   hit_warden(34)

func incoming_point() -> Vector3:
 return incoming_from.lerp(f.location,1.0-incoming/WARNING_TIME)

func intercept() -> void:
 if incoming<=0:say("No inbound signature");return
 if not enabled[5] or defence_cooldown>0:say("Defence unavailable");return
 flare_at=incoming_point();flare_time=0.65;incoming=0;defence_cooldown=6
 say("Inbound neutralised")

func clear_ordnance() -> void:
 incoming=0;missile_time=0;retaliation=0;seeker=0;flare_time=0;pulse_time=0;defence_cooldown=0

func advance_ordnance(dt:float) -> void:
 if group==Group.MISSILES and tracking():
  seeker=minf(1,seeker+dt/SEEK_TIME)
 else:seeker=0
 defence_cooldown=maxf(0,defence_cooldown-dt)
 flare_time=maxf(0,flare_time-dt)
 if missile_time>0:
  missile_time=maxf(0,missile_time-dt)
  if missile_time==0 and disabled_time<=0:hit_warden(48)
 if incoming>0:
  incoming=maxf(0,incoming-dt)
  if incoming==0:
   var absorbed:=minf(shield,20)
   shield-=absorbed;hull=maxf(0,hull-(20-absorbed));say("Missile impact")
 if retaliation>0:
  retaliation=maxf(0,retaliation-dt)
  if retaliation==0 and disabled_time<=0 and sector==1 and f.mode==f.Mode.FLYING and range_to(WARDEN)<500 and not cruise and charge==0:
   incoming=WARNING_TIME;incoming_from=position_of(WARDEN);retaliation=12

func toggle_cruise() -> void:
 if cruise:cruise=false;say("Normal flight");return
 if f.mode!=f.Mode.FLYING or not enabled[0] or not enabled[4] or deployed or charge>0 or fuel<1:
  say("Cruise requires fuel, drives and stowed hardpoints");return
 cruise=true;boost=0;say("Cruise engaged")

func boost_cost() -> float:return 27.0 if "capacitor" in installed else 36.0

func boost_drive() -> void:
 if f.mode!=f.Mode.FLYING or cruise or not enabled[0] or engine<boost_cost() or charge>0:say("Boost unavailable");return
 engine-=boost_cost();boost=1.8;say("Boost")

func plot(waypoint:int=-1) -> void:
 if transit>0 or charge>0:
  say("Shift drive engaged");return
 if waypoint<0:waypoint=Regions.GATE_CONTACT[1 if sector==0 else 0]
 var region:int=CATALOG[waypoint].sector
 if waypoint not in chart_contacts(region):return
 var legs:=Regions.passage(sector,region)
 if legs.is_empty():say("No shift corridor");return
 route=legs[0];arrival_target=waypoint
 say("Course plotted · "+CATALOG[waypoint].name)

func clear_course() -> void:
 if charge>0 or transit>0:say("Shift drive engaged");return
 route=-1;arrival_target=-1
 say("Course cleared")

func navigate_to(id:int) -> bool:
 if f.mode==f.Mode.LANDING:
  say("Docking in progress");return false
 if transit>0 or charge>0:
  say("Shift drive engaged");return false
 var region:int=CATALOG[id].sector
 if id not in chart_contacts(region):return false
 if region!=sector:plot(id)
 else:
  route=-1;arrival_target=-1;select(id)
  say("Tracking · "+CATALOG[id].name)
 return true

func jump() -> void:
 if charge>0:charge=0;say("Charge cancelled");return
 if route<0:say("Plot a route first");return
 if not Regions.linked(sector,route):say("Destination outside drive range");return
 if f.mode!=f.Mode.FLYING or deployed or not enabled[4] or fuel<JUMP_COST:say("Jump requires flight, fuel and a clear drive");return
 if f.local_air>0.01 or range_to(Regions.GATE_CONTACT[sector])<75:say("Clear the local mass shadow");return
 if (-f.attitude.z).dot(jump_axis())<0.95:say("Align with the course diamond");return
 cruise=false;boost=0;f.velocity=Vector3.ZERO;f.throttle=0;charge=0.001;say("Shift drive charging")

func service() -> void:
 if f.mode!=f.Mode.BERTH or CATALOG[Regions.BERTH_CONTACT[f.berth]].kind!="station":say("Station service requires a berth");return
 fuel=TANK;missiles=RACK_SIZE;hull=100;shield=100 if enabled[1] else 0;say("Service complete · tank full")

func impact(speed:float) -> void:
 if speed<5:return
 var hit:=clampf(speed*0.32,2,38)/lerpf(0.74,1.26,pips[0]/4.0);var absorbed:=minf(shield,hit)
 shield-=absorbed;hull=maxf(0,hull-hit+absorbed);say("Hull contact")

func advance(dt:float) -> void:
 update_traffic(dt)
 reply_time=maxf(reply_time-dt,0)
 if pulse_time>0:
  pulse_time=maxf(0,pulse_time-dt)
  if pulse_time==0 and shot_group==Group.PULSE and sector==1 and disabled_time<=0 and burst_to.distance_to(position_of(WARDEN))<4:
   hit_warden(25)
 boost=maxf(boost-dt,0)
 engine=minf(100,engine+dt*pips[1]*2.8);weapon=minf(100,weapon+dt*pips[2]*3.0)
 if enabled[1]:shield=minf(100,shield+dt*pips[0]*0.9)
 if disabled_time>0:
  disabled_time=maxf(0,disabled_time-dt)
  if disabled_time==0:npc_shield=100
 if lock_id>=0 and range_to(lock_id)>650:lock_id=-1
 if sector==1 and disabled_time<=0 and f.mode==f.Mode.FLYING and range_to(5)<90:
  var hit:=dt*5.0/lerpf(0.74,1.26,pips[0]/4.0);var absorbed:=minf(hit,shield);shield-=absorbed;hull=maxf(0,hull-hit+absorbed)
 advance_ordnance(dt)
 if hull<=0:
  f.reset(f.berth);service();hull=100;say("Recovery tow · last berth");return
 if cruise:
  fuel=maxf(0,fuel-dt*(0.025+0.065*absf(f.throttle))*(0.8 if "economiser" in installed else 1.0))
  if fuel<1:cruise=false;say("Cruise reserve reached")
 if transit>0:
  transit=maxf(0,transit-dt)
  if transit==0:
   sector=route;route=-1;permit=-1;lock_id=-1
   var gate:int=Regions.GATE_CONTACT[sector]
   select(gate)
   if arrival_target>=0 and CATALOG[arrival_target].sector!=sector:
    plot(arrival_target)
   else:
    if arrival_target in contacts():select(arrival_target)
    arrival_target=-1
   f.location=ORIGINS[sector]+ENTRY_OFFSET;f.attitude=Basis.IDENTITY
   f.velocity=Vector3.ZERO;f.throttle=0;f.turn_rate=Vector3.ZERO;update_traffic(0);say("Arrived · "+SECTORS[sector])
 elif charge>0:
  if (-f.attitude.z).dot(jump_axis())<0.95:charge=0;say("Alignment lost");return
  charge+=dt
  if charge>=3:
   charge=0;transit=2;fuel-=JUMP_COST;clear_ordnance()

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
