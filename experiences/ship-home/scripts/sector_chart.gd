# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The left terminal can preview a waypoint without changing the captain's course.
const PLOT:=Rect2(16,100,315,190)
const TAB_Y:=Rect2(14,52,572,42)
const PREV:=Rect2(350,232,108,51)
const NEXT:=Rect2(471,232,108,51)
const ENGAGE:=Rect2(15,299,570,49)
const INK:=Color("f1eedc")
const GOLD:=Color("ffd588")
const SEA:=Color("90e5d6")
const DIM:=Color("a3b9be")
const GRID:=Color("355459")
var region:=0
var focus:=0
var pins:Dictionary[int,Vector2]={}

func browse(a,sector:int) -> void:
 region=sector
 var contacts:Array[int]=a.chart_contacts(region)
 var current:int=a.target if region==a.sector else a.arrival_target
 focus=current if current in contacts else contacts[0]
 pins.clear()

func step(a,by:int) -> void:
 var ids:Array[int]=a.chart_contacts(region)
 focus=ids[posmod(ids.find(focus)+by,ids.size())]

func touch_at(at:Vector2,a) -> bool:
 if TAB_Y.has_point(at):browse(a,0 if at.x<TAB_Y.get_center().x else 1)
 elif PREV.has_point(at):step(a,-1)
 elif NEXT.has_point(at):step(a,1)
 elif ENGAGE.has_point(at):return true
 elif PLOT.has_point(at):
  var best:=19.0
  for id in pins:
   var gap:=at.distance_to(pins[id])
   if gap<best:focus=id;best=gap
 return false

func flat(p:Vector3) -> Vector2:return Vector2(p.x,p.z)

func caption(c:Control,at:Vector2,s:String,ink:Color,size:int) -> void:
 c.draw_string(ThemeDB.fallback_font,at,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,ink)

func render(c:Control,a) -> void:
 var ids:Array[int]=a.chart_contacts(region)
 if focus not in ids:browse(a,region)
 var local:bool=region==a.sector
 for i in a.SECTORS.size():
  var tab:=Rect2(TAB_Y.position+Vector2(286*i,0),Vector2(280,TAB_Y.size.y))
  if i==region:c.draw_rect(tab,Color("263d42"));c.draw_line(tab.end-Vector2(tab.size.x,0),tab.end,GOLD,2)
  caption(c,tab.position+Vector2(10,27),("%s   %s" % ["LB" if i==0 else "RB",a.SECTORS[i]])+("  ·  HERE" if i==a.sector else ""),INK if region==i else DIM,19)
 c.draw_rect(PLOT,Color("112c33"))
 for i in range(1,5):
  var x:=PLOT.position.x+PLOT.size.x*i/5
  c.draw_line(Vector2(x,PLOT.position.y),Vector2(x,PLOT.end.y),GRID)
 for i in range(1,4):
  var y:=PLOT.position.y+PLOT.size.y*i/4
  c.draw_line(Vector2(PLOT.position.x,y),Vector2(PLOT.end.x,y),GRID)
 var reference:Vector3=a.f.location if local else a.ORIGINS[region]+a.ENTRY_OFFSET
 var anchor:=flat(reference-a.ORIGINS[region])
 var bounds:=Rect2(anchor,Vector2.ZERO)
 for id in ids:
  var item:Dictionary=a.CATALOG[id]
  var extent:Vector2=item.get("orbit",Vector2.ZERO)
  bounds=bounds.expand(flat(item.p)-extent).expand(flat(item.p)+extent)
 var extent_scale:=minf((PLOT.size.x-38)/maxf(80,bounds.size.x),(PLOT.size.y-38)/maxf(80,bounds.size.y))
 var origin:=PLOT.get_center()-bounds.get_center()*extent_scale
 var ship:=origin+anchor*extent_scale
 pins.clear()
 for id in ids:
  var item:Dictionary=a.CATALOG[id]
  var pt:=origin+flat(a.position_of(id)-a.ORIGINS[region])*extent_scale
  pins[id]=pt
  if item.has("orbit"):
   var curve:=PackedVector2Array()
   for j in 49:
    var t:=TAU*j/48.0
    curve.append(origin+(flat(item.p)+Vector2(cos(t),sin(t))*Vector2(item.orbit))*extent_scale)
   c.draw_polyline(curve,GRID,1.6,true)
 c.draw_dashed_line(ship,pins[focus],GOLD,1.5,5,true)
 for id in ids:
  var p:Vector2=pins[id]
  var color:=GOLD if id==focus else DIM
  match a.CATALOG[id].kind:
   "station":c.draw_polyline(PackedVector2Array([p+Vector2.UP*5,p+Vector2.RIGHT*5,p+Vector2.DOWN*5,p+Vector2.LEFT*5,p+Vector2.UP*5]),color,2,true)
   "island":c.draw_polyline(PackedVector2Array([p+Vector2(-5,3),p+Vector2(-2,-3),p+Vector2(3,-4),p+Vector2(6,3),p+Vector2(-5,3)]),color,2,true)
   "hostile":c.draw_polyline(PackedVector2Array([p+Vector2(0,-5),p+Vector2(5,4),p+Vector2(-5,4),p+Vector2(0,-5)]),color,2,true)
   "ship":c.draw_rect(Rect2(p-Vector2(5,3),Vector2(10,6)),color,false,2)
   _:c.draw_circle(p,3.1,color)
 var heading:=Vector2.UP
 if local:
  var ahead:Vector2=flat(-a.f.attitude.z)
  if ahead.length_squared()>0.001:heading=ahead.normalized()
  var tail:=ship-heading*4
  c.draw_colored_polygon(PackedVector2Array([ship+heading*8,tail+heading.orthogonal()*4,tail-heading.orthogonal()*4]),SEA)
 else:c.draw_arc(ship,5,0,TAU,16,SEA,2,true)
 c.draw_arc(pins[focus],10,0,TAU,28,GOLD,2,true)
 var item:Dictionary=a.CATALOG[focus]
 var detail:String="OPEN PAD" if item.has("site") else "FLYBY ONLY"
 match item.kind:
  "station":detail="STATION  /  PAD 01"
  "ship","hostile":detail="TRAFFIC"
  "signal":detail="BEACON"
 caption(c,Vector2(350,132),item.name,INK,24)
 caption(c,Vector2(350,161),detail,GOLD,18)
 var distance:=reference.distance_to(a.position_of(focus))
 caption(c,Vector2(350,206),"%d m   %s"%[roundi(distance),"RANGE" if local else "FROM ENTRY"],DIM,17)
 for control in [PREV,NEXT]:
  c.draw_rect(control,GRID,false,1)
 caption(c,PREV.position+Vector2(11,32),"‹  Prev",INK,20)
 caption(c,NEXT.position+Vector2(12,32),"Next  ›",INK,20)
 c.draw_rect(ENGAGE,Color("2a474e"))
 c.draw_rect(Rect2(ENGAGE.position,Vector2(4,ENGAGE.size.y)),GOLD)
 caption(c,ENGAGE.position+Vector2(12,33),"Track contact" if local else "Plot jump",INK,24)
 var hint:String="LOCAL" if local else "%d FUEL"%roundi(a.JUMP_COST)
 if a.charge>0 or a.transit>0:hint="DRIVE ENGAGED"
 caption(c,Vector2(388,332),hint,GOLD,19)
