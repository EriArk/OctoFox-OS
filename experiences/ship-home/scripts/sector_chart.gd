# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## A dedicated helm camera renders the atlas. All marks are projected from its 3D space.
const R:=preload("res://scripts/egregore_regions.gd")
const Field:=preload("res://scripts/atlas_field.gd")
const BASE:=Vector2(1152,648)
const MAP_SCALE:=0.00012
const INK:=Color("edece2")
const GOLD:=Color("ffc778")
const SEA:=Color("7ce3d0")
const DIM:=Color("acbfc9")
const PANEL:=Color("0b1927f4")
const BORDER:=Color("38505e")
const PREV:=Rect2(870,199,110,43)
const NEXT:=Rect2(991,199,115,43)
const PLUS:=Rect2(39,520,49,42)
const MINUS:=Rect2(94,520,49,42)
var region:=0
var focus:=0
var pins:Dictionary[int,Vector2]={}
var region_pins:Dictionary[int,Vector2]={}
var helm
var scene:=Field.new()
var camera:=Camera3D.new()
var yaw:=0.04
var elevation:=0.43
var distance:=117.0
var goal:=117.0
var pivot:=Vector3.ZERO
var down:Dictionary[int,Vector2]={}
var dragged:=false
var islands:Dictionary[int,MeshInstance3D]={}

func setup(owner_helm) -> void:
 helm=owner_helm
 set_anchors_and_offsets_preset(PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE;hide()
 add_child(scene);scene.hide()
 add_child(camera);camera.cull_mask=Field.LAYER;camera.near=.0003;camera.far=320
 camera.fov=48
 var env:=Environment.new();env.background_mode=Environment.BG_SKY;env.sky=Sky.new()
 var sky_ink:=ShaderMaterial.new();sky_ink.shader=preload("res://shaders/atlas_sky.gdshader")
 env.sky.sky_material=sky_ink;camera.environment=env

func is_detail() -> bool:return helm.page=="Local"

func show_page(fresh:bool) -> void:
 if scene.get_child_count()==0:
  scene.ready_field()
  # Share the authored terrain meshes, including the shoreline and relief of each island.
  for id:int in helm.f.chart_islands:
   var model:=MeshInstance3D.new()
   model.mesh=helm.f.chart_islands[id][0];model.layers=Field.LAYER
   model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   scene.add_child(model);islands[id]=model
   for surface in helm.f.chart_islands[id].slice(1):
    scene.instance(model,surface,null,Vector3.ZERO)
 scene.show();show();camera.make_current()
 if is_detail() and not fresh:browse(helm.a,region)
 if fresh:
  browse(helm.a,helm.a.sector)
  yaw=.04;elevation=.43;distance=117;pivot=Vector3.ZERO
 goal=sector_distance() if is_detail() else 117.0
 update_view(0.0);queue_redraw()

func stow() -> void:
 if visible and camera.current and is_instance_valid(helm.pilot) and helm.pilot.seated:helm.pilot.pilot_camera.make_current()
 scene.hide();hide();down.clear();dragged=false;pins.clear();region_pins.clear()

func browse(a,sector:int) -> void:
 region=posmod(sector,R.NAMES.size())
 var ids:Array[int]=a.chart_contacts(region)
 var current:int=a.target if region==a.sector else a.arrival_target
 focus=current if current in ids else ids[0]
 if is_detail():goal=sector_distance()
 pins.clear();queue_redraw()

func step(a,by:int) -> void:
 var ids:Array[int]=a.chart_contacts(region)
 focus=ids[posmod(ids.find(focus)+by,ids.size())];queue_redraw()

func point(world:Vector3) -> Vector3:
 return R.CENTRES[region]+(world-R.ORIGINS[region])*MAP_SCALE

func marker(id:int) -> Vector3:return point(helm.a.position_of(id))

func reference() -> Vector3:
 return helm.f.location if region==helm.a.sector else R.ORIGINS[region]+helm.a.ENTRY_OFFSET

func sector_bounds() -> AABB:
 var bounds:=AABB(point(reference()),Vector3.ZERO)
 for id in helm.a.chart_contacts(region):bounds=bounds.expand(marker(id))
 return bounds

func sector_distance() -> float:return maxf(.32,sector_bounds().size.length()*1.48)

func zoom(change:float) -> void:
 var minimum:=.016
 if is_detail() and islands.has(focus):minimum=islands[focus].mesh.get_aabb().size.length()*MAP_SCALE*1.16
 goal=clampf(goal*exp(change),minimum,185)
 if not is_detail() and goal<22:
  helm.open("Local")
 elif is_detail() and goal>24:
  helm.open("Chart")

func rotate_by(delta:Vector2) -> void:
 yaw=wrapf(yaw+delta.x,-PI,PI)
 elevation=clampf(elevation+delta.y,-1.43,1.43)

func update_view(dt:float) -> void:
 var a=helm.a
 if not focus in a.chart_contacts(region):browse(a,region)
 var stick:=Input.get_vector("look_left","look_right","look_up","look_down",.18)
 var keys:=Input.get_vector("walk_left","walk_right","walk_forward","walk_back",.18)
 rotate_by((stick+keys).limit_length()*dt*1.8)
 var triggers:=Input.get_axis("fly_right","fly_left")
 if absf(triggers)>.05:zoom(triggers*dt*1.75)
 var blend:=1-exp(-dt*9)
 distance=exp(lerpf(log(distance),log(goal),blend))
 var dest:Vector3=R.CENTRES[region]* (1.0-smoothstep(22,90,goal))
 if is_detail():
  var extent:=sector_bounds()
  var near_focus:=1.0-smoothstep(.23,.88,goal/sector_distance())
  dest=extent.get_center().lerp(marker(focus),near_focus)
 pivot=pivot.lerp(dest,blend)
 var normal:=Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))
 var right:=Vector3(cos(yaw),0,-sin(yaw))
 var look:=pivot+right*distance*.19
 camera.position=look+normal*distance;camera.look_at(look,Vector3.UP)
 camera.rotate_object_local(Vector3.BACK,.095)
 camera.near=clampf(distance*.0006,.00015,.09)
 scene.field.visible=not is_detail() or distance>21
 for id in islands:
  var model:=islands[id]
  model.visible=is_detail() and R.CONTACTS[id].sector==region and id in a.chart_contacts(region)
  if model.visible:
   model.position=marker(id)
   if R.CONTACTS[id].has("site"):model.position+=Vector3(30,-5.35,-48)*MAP_SCALE
   var extent_m:=model.mesh.get_aabb().size.x
   model.scale=Vector3.ONE*maxf(MAP_SCALE,minf(distance,.9)*.042/extent_m)
 queue_redraw()

func ui_scale() -> float:return minf(size.x/BASE.x,size.y/BASE.y)
func ui_offset() -> Vector2:return (size-BASE*ui_scale())*.5
func to_ui(p:Vector2) -> Vector2:return (p-ui_offset())/ui_scale()
func project(p:Vector3) -> Vector2:return to_ui(camera.unproject_position(p))

func label(at:Vector2,value:String,color:Color,px:int) -> void:
 draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func button(rect:Rect2,what:String,active:bool=false) -> void:
 draw_rect(rect,Color("263c47") if active else PANEL)
 draw_rect(rect,GOLD if active else BORDER,false,1.4)
 label(rect.position+Vector2(12,rect.size.y*.5+7),what,INK,20)

func line3(path:PackedVector3Array,ink:Color,width:float=1.3) -> void:
 var pts:=PackedVector2Array()
 for p in path:
  if camera.is_position_behind(p):
   if pts.size()>1:draw_polyline(pts,ink,width,true)
   pts.clear()
  else:pts.append(project(p))
 if pts.size()>1:draw_polyline(pts,ink,width,true)

func orbit_plot() -> void:
 var a=helm.a
 var bounds:=sector_bounds()
 var pivot_xz:=bounds.get_center()
 var radius:=maxf(.04,bounds.size.length()*.55)
 # Distance circles and vertical stems make the out-of-plane component visible at any bearing.
 for j in range(1,4):
  var circle:=PackedVector3Array()
  for k in 65:
   var angle:=TAU*k/64
   circle.append(Vector3(pivot_xz.x,R.CENTRES[region].y,pivot_xz.z)+Vector3(cos(angle),0,sin(angle))*radius*j/3.0)
  line3(circle,Color("344457"))
 pins.clear()
 for id in a.chart_contacts(region):
  var item:Dictionary=a.CATALOG[id]
  var pos:=marker(id)
  if R.moving(item):
   var orbit:=PackedVector3Array()
   for k in 49:orbit.append(point(a.position_of(id,k*R.period(item)/48)))
   line3(orbit,Color("637b8c"))
  if camera.is_position_behind(pos):continue
  var p:=project(pos)
  if not Rect2(0,72,850,512).has_point(p):continue
  pins[id]=p
  line3([pos,Vector3(pos.x,R.CENTRES[region].y,pos.z)],DIM)
  var color:=GOLD if id==focus else R.TINTS[region] as Color
  match item.kind:
   "island","hostile":draw_polyline(PackedVector2Array([p+Vector2(0,-6),p+Vector2(7,5),p+Vector2(-7,5),p+Vector2(0,-6)]),color,2,true)
   "station":draw_polyline(PackedVector2Array([p+Vector2.UP*7,p+Vector2.RIGHT*7,p+Vector2.DOWN*7,p+Vector2.LEFT*7,p+Vector2.UP*7]),color,2,true)
   "fauna":draw_arc(p,6,0,TAU,16,Color("bca2eb"),2,true)
   "ship":draw_rect(Rect2(p-Vector2(6,4),Vector2(12,8)),color,false,2)
   _:draw_circle(p,4,color)
 var ship:=point(reference())
 if not camera.is_position_behind(ship):
  var p:=project(ship)
  draw_arc(p,7,0,TAU,20,SEA,2,true)
  if region==a.sector:
   var tip:=project(ship-helm.f.attitude.z*MAP_SCALE)
   draw_line(p,p+p.direction_to(tip)*13,SEA,2,true)
  if pins.has(focus):draw_dashed_line(p,pins[focus],Color("c89f6f"),1.5,6,true)
 if pins.has(focus):
  var p:Vector2=pins[focus]
  draw_arc(p,13,0,TAU,30,GOLD,2,true)
  label(p+Vector2(17,-12),a.CATALOG[focus].name,INK,18)

func regional_plot() -> void:
 var a=helm.a
 var end:int=preview_destination()
 var path:=R.passage(a.sector,end)
 for i in R.NAMES.size():
  for j in range(i+1,R.NAMES.size()):
   if R.linked(i,j):line3([R.CENTRES[i],R.CENTRES[j]],Color("526572"),1.3)
 var active:int=a.sector
 for leg in path:
  line3([R.CENTRES[active],R.CENTRES[leg]],GOLD if reviewing_course() else DIM,2.4)
  active=leg

 region_pins.clear()
 for i in R.NAMES.size():
  var pos:Vector3=R.CENTRES[i]
  if camera.is_position_behind(pos):continue
  var p:=project(pos)
  region_pins[i]=p
  draw_circle(p,5,R.TINTS[i])
  draw_arc(p,14 if i==region else 9,0,TAU,32,GOLD if i==region else R.TINTS[i],2,true)
  label(p+Vector2(0,33),R.NAMES[i],INK,19)

func preview_destination() -> int:
 var a=helm.a
 return a.CATALOG[a.arrival_target].sector if region==a.sector and a.route>=0 else region

func reviewing_course() -> bool:
 var a=helm.a
 return a.route>=0 and preview_destination()==a.CATALOG[a.arrival_target].sector

func controls() -> Array[String]:
 if is_detail():return ["Track contact" if region==helm.a.sector else "Plot route"]
 var a=helm.a
 var dest:int=region if region!=a.sector else (1 if region==0 else 0)
 return [ "Clear course" if reviewing_course() else "Plot to "+R.NAMES[dest],"Cancel charge" if a.charge>0 else "Charge drive","Explore cluster"]

func act(index:int) -> void:
 var a=helm.a
 if is_detail():helm.commit_waypoint();return
 match index:
  0:
   if reviewing_course():a.clear_course()
   else:a.plot(R.GATE_CONTACT[region if region!=a.sector else (1 if region==0 else 0)])
  1:a.jump()
  2:helm.open("Local")

func row(i:int) -> Rect2:return Rect2(870,383+i*54,236,45)

func _draw() -> void:
 if not visible or helm==null:return
 draw_set_transform(ui_offset(),0,Vector2.ONE*ui_scale())
 if is_detail():orbit_plot()
 else:regional_plot()
 draw_rect(Rect2(0,0,BASE.x,69),PANEL)
 label(Vector2(32,46),"Egregore atlas",INK,34)
 label(Vector2(290,44),R.NAMES[region] if is_detail() else "Regional field",SEA,20)
 button(Rect2(1004,14,114,41),"‹  Back")
 draw_rect(Rect2(846,91,283,469),PANEL)
 draw_rect(Rect2(846,91,283,3),R.TINTS[region])
 label(Vector2(870,131),R.NAMES[region],INK,28)
 label(Vector2(870,164),"CURRENT CLUSTER" if region==helm.a.sector else "ENERGY CLUSTER",R.TINTS[region],16)
 button(PREV,"‹  Prev");button(NEXT,"Next  ›")
 var a=helm.a
 if is_detail():
  var item:Dictionary=a.CATALOG[focus]
  label(Vector2(870,280),item.name,INK,23)
  var kind:String=str(item.get("role",item.kind)).to_upper()
  if item.kind=="island":kind="ISLAND  /  "+("OPEN PAD" if item.has("site") else "FLYBY")
  label(Vector2(870,305),kind,SEA,16)
  var m:=reference().distance_to(a.position_of(focus))
  label(Vector2(870,337),R.range_text(m)+"   ·   "+R.cruise_time(m)+" cruise",INK,19)
  if region!=a.sector:label(Vector2(870,362),"From jump entry",DIM,16)
 else:
  var dest:=preview_destination()
  var path:=R.passage(a.sector,dest)
  var summary:="Tank  %d / 100"%floori(a.fuel)
  if not path.is_empty():
   summary="%d jumps  ·  %d fuel"%[path.size(),path.size()*int(a.JUMP_COST)]
   if path.size()==1:summary="1 jump  ·  %d fuel"%int(a.JUMP_COST)
  label(Vector2(870,282),summary,INK,22)
  if path.size()>0:
   label(Vector2(870,315),"Next   "+R.NAMES[path[0]],GOLD,17)
   label(Vector2(870,342),"Next leg  %d   /   tank  %d"%[int(a.JUMP_COST),floori(a.fuel)],DIM,17)
  else:label(Vector2(870,315),"Select a cluster to plot",DIM,17)
 var actions:=controls()
 for i in actions.size():button(row(i),actions[i],helm.cursor==i)
 button(PLUS,"+");button(MINUS,"−")
 draw_rect(Rect2(0,589,1152,59),PANEL)
 label(Vector2(32,626),"RS   Orbit       LT / RT   Zoom       LB / RB   Cluster       D-pad   Select       A   Confirm",DIM,19)
 if a.reply_time>0 and a.reply!="":label(Vector2(162,547),a.reply,GOLD,17)

func tap(p:Vector2) -> void:
 if Rect2(1004,14,114,41).has_point(p):helm.open("Chart" if is_detail() else "");return
 if PLUS.has_point(p):zoom(-.48);return
 if MINUS.has_point(p):zoom(.48);return
 if PREV.has_point(p) or NEXT.has_point(p):
  var direction:=-1 if PREV.has_point(p) else 1
  if is_detail():step(helm.a,direction)
  else:browse(helm.a,region+direction)
  return
 for i in controls().size():
  if row(i).has_point(p):helm.cursor=i;act(i);return
 if p.x>844 or p.y<71 or p.y>584:return
 var marks:=pins if is_detail() else region_pins
 var closest:=-1;var best:=24.0
 for i in marks:
  var gap:=p.distance_to(marks[i])
  if gap<best:best=gap;closest=i
 if closest>=0:
  if is_detail():focus=closest
  else:browse(helm.a,closest);helm.open("Local")

func pointer(e:InputEvent) -> bool:
 if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  zoom(-.19 if e.button_index==MOUSE_BUTTON_WHEEL_UP else .19);return true
 var index:=-1
 if e is InputEventScreenTouch or e is InputEventScreenDrag:index=e.index
 if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT):
  var p:=to_ui(e.position)
  if e.pressed:
   if down.is_empty():dragged=false
   else:dragged=true
   down[index]=p
  elif down.has(index):
   down.erase(index)
   if not dragged:tap(p)
  return true
 if (e is InputEventScreenDrag or e is InputEventMouseMotion) and down.has(index):
  var p:=to_ui(e.position);var prior:Vector2=down[index]
  if down.size()>=2:
   for other in down:
    if other!=index:
     var old:=prior.distance_to(down[other]);var span:=p.distance_to(down[other])
     if minf(old,span)>3:zoom(log(old/span))
     break
  elif dragged or p.distance_to(prior)>3:rotate_by((p-prior)*.007)
  else:return true
  dragged=true;down[index]=p;return true
 return false
