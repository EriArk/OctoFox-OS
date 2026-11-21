# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## One set of selectable panel rows serves touch, keyboard and the pilot's pad.
const AMBER=Color("ffce78")
const MINT=Color("94e5d5")
const RED=Color("ff927a")
const WHITE=Color("f2f0df")
const MUTED=Color("afc4c4")
const GLASS=Color("10252df2")
const PAGES=["Contacts","Ship","Chart","Power"]
var f
var a
var pilot
var page:=""
var cursor:=0
var y_down:=false
var chord:=false
var buttons:Array[Rect2]=[]
var first_button:=0
const PANEL_SIZE:=Vector2(0.60,0.36)
const PIXELS:=Vector2i(600,360)
var surfaces:Array[MeshInstance3D]=[]
var viewports:Array[SubViewport]=[]
var canvases:Array[Control]=[]
var saved_look:=Vector2.ZERO
var repeater:=Label3D.new()
var gauges:Array[Label3D]=[]
var reticle:=MeshInstance3D.new()
var radar_mesh:=ImmediateMesh.new()
var transit_line:=MeshInstance3D.new()
var scanner:=MeshInstance3D.new()
var sweep:=0.0


func bind(flight,walker) -> void:
 f=flight;a=f.avionics;pilot=walker
 mouse_filter=MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.vertex_color_use_as_albedo=true;ink.cull_mode=BaseMaterial3D.CULL_DISABLED;ink.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 scanner.material_override=ink;f.art.radar.add_child(scanner)
 scanner.mesh=radar_mesh
 var dial_glass:=MeshInstance3D.new();var lens:=QuadMesh.new();lens.size=Vector2.ONE*0.51;dial_glass.mesh=lens
 var phosphor:=ShaderMaterial.new();phosphor.shader=preload("res://shaders/scope_phosphor.gdshader");dial_glass.material_override=phosphor
 f.art.radar.add_child(dial_glass);dial_glass.rotation.x=-PI/2;dial_glass.position.y=0.046
 dial_glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for side in [-1,1]:
  var mount:=Node3D.new();f.art.helm_root.add_child(mount)
  mount.position=Vector3(side*1.08,0.785,-0.42)
  mount.rotation=Vector3(-1.14,side*-0.94,0)
  # The glass sits flush in a radiused wood cabinet with a woven speaker below.
  f.art.veneer_case(mount,Vector3(0,-0.021,-0.003),Vector2(0.666,0.463),0.068,0.041)
  f.art.bezel(mount,Vector3(0,0,-0.001),Vector2(0.621,0.382),0.023,0.006,f.art.BRASS)
  f.art.faceplate(mount,Vector3(0,-0.218,-0.001),Vector2(0.551,0.039),0.017,f.art.WEAVE)
  f.art.bezel(mount,Vector3(0,-0.218,0),Vector2(0.558,0.045),0.019,0.003,f.art.BRASS)
  f.art.box(mount,Vector3(0,-0.29,-0.079),Vector3(0.15,0.25,0.08),Color("34434a"))
  var screen:=SubViewport.new();screen.size=PIXELS;screen.disable_3d=true
  screen.render_target_update_mode=SubViewport.UPDATE_ONCE;screen.handle_input_locally=false;add_child(screen)
  var canvas:=Control.new();canvas.size=PIXELS;screen.add_child(canvas)
  var index:=surfaces.size();canvas.draw.connect(paint.bind(canvas,index))
  var glass:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=PANEL_SIZE;glass.mesh=quad
  var face:=ShaderMaterial.new();face.shader=preload("res://shaders/instrument_glass.gdshader")
  face.set_shader_parameter("display",screen.get_texture())
  glass.material_override=face;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mount.add_child(glass)
  var rim:=MeshInstance3D.new();var lens_rim:=QuadMesh.new();lens_rim.size=Vector2(0.694,0.454);rim.mesh=lens_rim
  var light:=ShaderMaterial.new();light.shader=preload("res://shaders/instrument_rim.gdshader")
  light.set_shader_parameter("tint",AMBER if side<0 else MINT);rim.material_override=light
  rim.position.z=0.001;rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mount.add_child(rim)
  surfaces.append(glass);viewports.append(screen);canvases.append(canvas)
  var gauge:=Label3D.new();f.art.helm_root.add_child(gauge)
  gauge.position=Vector3(side*0.50,0.944,-0.57);gauge.rotation=Vector3(-0.36,-side*0.28,0)
  gauge.font_size=30;gauge.pixel_size=0.00115;gauge.outline_size=5;gauge.outline_modulate=Color("245d55");gauge.modulate=MINT;gauges.append(gauge)
 f.art.helm_root.add_child(repeater);repeater.position=Vector3(0,0.995,-0.68)
 repeater.pixel_size=0.00105;repeater.font_size=38;repeater.outline_size=5;repeater.outline_modulate=Color("654322");repeater.modulate=AMBER
 var mark:=ImmediateMesh.new();mark.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
 for point in [Vector2(0,1),Vector2(1,0),Vector2(0,-1),Vector2(-1,0),Vector2(0,1)]:
  mark.surface_add_vertex(Vector3(point.x,point.y,0)*0.025)
 mark.surface_end();reticle.mesh=mark;var dye:=StandardMaterial3D.new();dye.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dye.albedo_color=MINT
 reticle.material_override=dye;f.art.helm_root.add_child(reticle);reticle.hide()
 f.art.helm_root.add_child(transit_line);transit_line.material_override=dye
 hide()

func side_of(section:String) -> int:
 return 1 if section in ["Ship","Power","Modules"] else 0

func refresh() -> void:
 for i in canvases.size():
  canvases[i].queue_redraw();viewports[i].render_target_update_mode=SubViewport.UPDATE_ONCE

func open(section:String) -> void:
 if page=="" and section!="":saved_look=Vector2(pilot.yaw,pilot.pitch)
 if page!="" and section=="":
  pilot.yaw=saved_look.x;pilot.pitch=saved_look.y
  pilot.pilot_camera.fov=78
 page=section;cursor=0;buttons.clear()
 if pilot.seated:
  pilot.walking=page==""
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if page!="" else Input.MOUSE_MODE_CAPTURED
 refresh()

func clear() -> void:
 open("");y_down=false;chord=false;hide();scanner.hide()

func line3(mesh:ImmediateMesh,one:Vector3,two:Vector3,ink:Color) -> void:
 var width:=(two-one).cross(Vector3(0,0.55,1)).normalized()*0.0016
 for dir in [-1,1]:
  var edge:Vector3=width*dir
  var verts:=[one+edge,two+edge,two+edge*4.5,one+edge,two+edge*4.5,one+edge*4.5]
  for i in 6:
   mesh.surface_set_color(Color(ink,0.0 if i in [2,4,5] else 0.34))
   mesh.surface_add_vertex(verts[i])
 for point in [one-width,two-width,two+width,one-width,two+width,one+width]:
  mesh.surface_set_color(ink);mesh.surface_add_vertex(point)

func glyph(mesh:ImmediateMesh,point:Vector3,shape:Array,color:Color) -> void:
 for i in shape.size():
  var start:Vector2=shape[i];var end:Vector2=shape[(i+1)%shape.size()]
  line3(mesh,point+Vector3(start.x,0,start.y)*0.014,point+Vector3(end.x,0,end.y)*0.014,color)

func scan() -> void:
 var mesh:=radar_mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 line3(mesh,Vector3(-0.007,0.062,0),Vector3(0.007,0.062,0),MINT)
 for id in a.contacts():
  var ray:Vector3=f.attitude.inverse()*(a.position_of(id)-f.location)
  var distance:=ray.length()
  if distance<1 or distance>1600:continue
  var planar:=Vector2(ray.x,ray.z).normalized()*clampf(log(1.0+distance/30.0)/4.0,0.08,1.0)*0.205
  var base:=Vector3(planar.x,0.056,planar.y)
  var top:=base+Vector3.UP*clampf(ray.y/maxf(12,distance)*0.12,-0.046,0.084)
  var kind:String=a.CATALOG[id].kind
  var ink:=RED if kind=="hostile" else (AMBER if id==a.target else MINT)
  line3(mesh,base,top,ink)
  match kind:
   "ship":glyph(mesh,top,[Vector2(-1,-0.55),Vector2(1,-0.55),Vector2(1,0.55),Vector2(-1,0.55)],ink)
   "hostile":glyph(mesh,top,[Vector2(0,-1),Vector2(1,0.7),Vector2(-1,0.7)],ink)
   "station":glyph(mesh,top,[Vector2(-1,0),Vector2(0,-1),Vector2(1,0),Vector2(0,1)],ink)
   "island":glyph(mesh,top,[Vector2(-1,0.6),Vector2(-0.4,-0.7),Vector2(0.4,-0.3),Vector2(1,0.6)],ink)
   _:glyph(mesh,top,[Vector2(-0.32,0),Vector2(0,-0.32),Vector2(0.32,0),Vector2(0,0.32)],ink)
  if a.CATALOG[id].has("orbit"):
   var heading:Vector3=f.attitude.inverse()*(a.position_of(id,a.orbit_time+1)-a.position_of(id)).normalized()
   line3(mesh,top,top+heading*0.037,ink)
  if id==a.target:
   glyph(mesh,top,[Vector2(-1.6,-1.6),Vector2(1.6,-1.6),Vector2(1.6,1.6),Vector2(-1.6,1.6)],WHITE)
 mesh.surface_end()

func tick(dt:float,active:bool) -> void:
 visible=active;scanner.visible=active;repeater.visible=active
 for i in surfaces.size():
  var mount:=surfaces[i].get_parent() as Node3D
  var raised:=active and page!="" and page!="Scope" and side_of(page)==i
  var factor:=1.0-exp(-16.0*dt)
  mount.position.y=lerpf(mount.position.y,1.145 if raised else 0.785,factor)
  mount.rotation.x=lerpf(mount.rotation.x,-0.22 if raised else -1.14,factor)
  gauges[i].visible=active
 reticle.visible=active and page=="" and f.mode==f.Mode.FLYING and a.transit==0
 transit_line.visible=reticle.visible and a.pulse_time>0
 if not active:return
 if page!="":
  var focus:Vector3=f.art.radar.global_position if page=="Scope" else surfaces[side_of(page)].global_position
  var ray:Vector3=(focus-pilot.pilot_pivot.global_position).normalized()
  var blend:=1.0-exp(-15.0*dt)
  pilot.yaw=lerp_angle(pilot.yaw,atan2(-ray.x,-ray.z),blend)
  pilot.pitch=lerpf(pilot.pitch,asin(ray.y),blend)
  pilot.pilot_camera.fov=lerpf(pilot.pilot_camera.fov,23.0,blend)
 var course:bool=a.route>=0
 var ray:Vector3=f.attitude.inverse()*(a.jump_axis() if course else a.position_of(a.target)-f.location)
 var eye:Vector3=f.art.helm_root.to_local(pilot.pilot_pivot.global_position)
 var frac:=1.55/maxf(0.05,-ray.z)
 var offset:=Vector2(ray.x,ray.y)*frac
 var behind:=ray.z>=0
 if behind:offset.x=signf(ray.x+0.001)*0.68
 var edge:=offset.clamp(Vector2(-0.68,-0.22),Vector2(0.68,0.38))
 reticle.position=eye+Vector3(edge.x,edge.y,-1.55)
 if transit_line.visible:
  var trace:=ImmediateMesh.new();trace.surface_begin(Mesh.PRIMITIVE_LINES)
  trace.surface_add_vertex(Vector3(0.55,0.75,-0.56));trace.surface_add_vertex(reticle.position)
  trace.surface_end();transit_line.mesh=trace
 var reading:String="PAD 01   /   MOORED" if f.mode==f.Mode.BERTH else "%03d m/s    %s"%[roundi(f.velocity.length()),"CRUISE" if a.cruise else "LOCAL"]
 if f.mode==f.Mode.FLYING:
  reading+="\n"+("SHIFT VECTOR" if course else "%s   %d m"%[a.CATALOG[a.target].name,roundi(a.range_to(a.target))])
  if behind:reading+="   AFT"
  if a.lock_id>=0:reading+="   LOCK"
  if a.permit==a.target and a.range_to(a.target)<70:
   var approach:String=f.clearance()
   reading+="\nPAD 01   /   "+("LAND" if approach=="" else approach.to_upper())
 if a.charge>0:reading="DRIVE CHARGE   %d%%"%roundi(a.charge/3*100)
 if a.transit>0:reading="TRANSIT   /   "+a.SECTORS[a.route].to_upper()
 repeater.text=reading
 gauges[0].text="THR  %+03d%%"%roundi(f.throttle*100)
 gauges[1].text="SHD %d  /  FUEL %d"%[roundi(a.shield),roundi(a.fuel)]
 sweep+=dt
 if sweep>=0.10:
  sweep=0;scan();refresh()

func rows() -> Array:
 match page:
  "Contacts":
   var entries:Array=[]
   for id in a.contacts():entries.append([a.CATALOG[id].name,"%d m"%roundi(a.range_to(id)),id])
   return entries
  "Contact":
   var id:int=a.target;var kind:String=a.CATALOG[id].kind
   if kind=="hostile":return [["Target lock","TRACKING" if a.lock_id==id else "ACQUIRE","lock"],["Pulse emitter","%d%%"%roundi(a.weapon),"fire"],["Hail ship","COMMS","hail"]]
   return [["Request pad 01" if kind=="station" else "Hail contact","CLEARED" if a.permit==id else "COMMS","hail"]]
  "Ship":return [["Components","6 MODULES","modules"],["Hardpoints","DEPLOYED" if a.deployed else "STOWED","arms"],["Cruise drive","ENGAGED" if a.cruise else "STANDBY","cruise"],["Engine boost","%d%%"%roundi(a.engine),"boost"],["Station service","FUEL / REPAIR","service"]]
  "Modules":
   var list:Array=[]
   for i in a.MODULES.size():list.append([a.MODULES[i],"ONLINE" if a.enabled[i] else "OFFLINE",i])
   return list
  "Power":
   var list:Array=[]
   for i in 3:list.append([["Systems & shields","Engines & boost","Weapons"][i],str(a.pips[i])+" / 4",i])
   return list
  "Local":return [["Track on scope",a.CATALOG[a.target].name,"track"]]
  "Chart":return [[a.SECTORS[1-a.sector],"PLOTTED" if a.route>=0 else "PLOT COURSE","plot"],["Shift drive","CANCEL" if a.charge>0 else "CHARGE","jump"],["Sector ephemeris","LOCAL","local"]]
 return []

func activate() -> void:
 var entries:=rows()
 if cursor>=entries.size() or entries.is_empty() or a.transit>0:return
 var action:Variant=entries[cursor][2]
 match page:
  "Contacts":a.select(action);open("Contact")
  "Power":a.distribute(action)
  "Modules":a.module_switch(action)
  _:
   match action:
    "local":open("Local")
    "track":open("Contacts")
    "modules":open("Modules")
    "arms":a.hardpoints()
    "cruise":a.toggle_cruise()
    "boost":a.boost_drive()
    "service":a.service()
    "plot":a.plot()
    "jump":a.jump()
    "hail":a.hail()
    "lock":a.acquire()
    "fire":a.fire()
 refresh()

func event(e:InputEvent) -> bool:
 if (e is InputEventJoypadButton and e.button_index==JOY_BUTTON_RIGHT_STICK and e.pressed) or (e is InputEventKey and e.physical_keycode==KEY_V and e.pressed and not e.echo):
  open("" if page=="Scope" else "Scope");return true
 if e.is_action_pressed("pick_item"):
  y_down=true;chord=false;return true
 if e.is_action_released("pick_item"):
  if y_down and not chord and page=="":a.nose_contact()
  y_down=false;chord=false;return true
 var dir:=""
 for pair in [["rotate_left","ui_left","Contacts"],["rotate_right","ui_right","Ship"],["fly_up","ui_up","Chart"],["fly_down","ui_down","Power"]]:
  if e.is_action_pressed(pair[0]) or e.is_action_pressed(pair[1]):dir=pair[2]
 if y_down and dir!="":
  chord=true;open(dir);return true
 if page=="":return false
 if e.is_action_pressed("cancel_ship"):
  open("Contacts" if page=="Contact" else ("Ship" if page=="Modules" else ("Chart" if page=="Local" else "")));return true
 if e.is_action_pressed("interact") or e.is_action_pressed("ui_accept"):
  activate();return true
 if page=="Scope":return not e.is_action_pressed("pause_ship")
 if dir in ["Chart","Power"]:cursor=posmod(cursor+(-1 if dir=="Chart" else 1),maxi(1,rows().size()))
 return not e.is_action_pressed("pause_ship")

func _input(e:InputEvent) -> void:
 if not visible:return
 if e is InputEventJoypadButton or e is InputEventKey:
  if not e.is_action_pressed("pause_ship") and event(e):get_viewport().set_input_as_handled()
  return
 var pos:Vector2
 if e is InputEventScreenTouch and e.pressed:pos=e.position
 elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:pos=e.position
 else:return
 var camera:Camera3D=pilot.pilot_camera
 for side in 2:
  var panel:=surfaces[side];var basis:=panel.global_transform.basis
  var plane:=Plane(basis.z.normalized(),panel.global_position)
  var hit:Variant=plane.intersects_ray(camera.project_ray_origin(pos),camera.project_ray_normal(pos))
  if hit==null:continue
  var local:=panel.to_local(hit)
  var uv:=Vector2(local.x,-local.y)/PANEL_SIZE+Vector2.ONE*0.5
  if not Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv):continue
  var px:=uv*Vector2(PIXELS)
  if page=="" or side!=side_of(page):open("Contacts" if side==0 else "Ship")
  elif px.y<48:
   if px.x>507:open("")
   elif side==0:open("Contacts" if px.x<260 else "Chart")
   else:open("Ship" if px.x<260 else "Power")
  else:
   for i in buttons.size():
    if buttons[i].has_point(px):cursor=i+first_button;activate();break
  get_viewport().set_input_as_handled();return

 if not camera.is_position_behind(f.art.radar.global_position):
  var dial:Vector2=camera.unproject_position(f.art.radar.global_position)
  var rim:Vector2=camera.unproject_position(f.art.radar.to_global(Vector3(0.235,0.045,0)))
  if pos.distance_to(dial)<dial.distance_to(rim):
   open("" if page=="Scope" else "Scope");get_viewport().set_input_as_handled()

func label(c:Control,x:float,y:float,value:String,col:Color,px:int=23) -> void:
 c.draw_string(ThemeDB.fallback_font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,col)

func meter(c:Control,x:float,y:float,w:float,value:float,ink:Color) -> void:
 c.draw_rect(Rect2(x,y,w,7),Color("294044"));c.draw_rect(Rect2(x,y,w*clampf(value/100,0,1),7),ink)

func map_view(c:Control,local:bool) -> void:
 var center:=Vector2(302,122)
 if local:
  c.draw_arc(center,68,0,TAU,64,Color("37595d"),1.5,true)
  var contacts:Array[int]=a.contacts()
  var bounds:=Rect2(Vector2.ZERO,Vector2.ONE)
  for id in contacts:
   var delta:Vector3=a.position_of(id)-a.ORIGINS[a.sector]
   bounds=bounds.expand(Vector2(delta.x,delta.z))
  var scale_m:=minf(1.0, minf(445.0/maxf(bounds.size.x,1),112.0/maxf(bounds.size.y,1)))
  var origin:=center-bounds.get_center()*scale_m
  for id in contacts:
   var delta:Vector3=a.position_of(id)-a.ORIGINS[a.sector]
   var p:=origin+Vector2(delta.x,delta.z)*scale_m
   if a.CATALOG[id].has("orbit"):
    var curve:=PackedVector2Array()
    for j in 49:
     var coord:Vector3=a.position_of(id,j*TAU/(48*0.072))-a.ORIGINS[a.sector]
     curve.append(origin+Vector2(coord.x,coord.z)*scale_m)
    c.draw_polyline(curve,MUTED,1.5,true)
   c.draw_circle(p,4,AMBER if id==a.target else MINT)
   if id==a.target:
    label(c,p.x+12,p.y,a.CATALOG[id].name,WHITE,17)
    if a.CATALOG[id].has("orbit"):
     var lead:Vector3=a.position_of(id,a.orbit_time+8)-a.ORIGINS[a.sector]
     c.draw_arc(origin+Vector2(lead.x,lead.z)*scale_m,6,0,TAU,5,AMBER,2,true)
 else:
  for k in 3:
   var points:=PackedVector2Array()
   for j in 73:
    var t:=j*TAU/72;points.append(center+Vector2(cos(t)*(126+k*26),sin(t)*(35+k*6)).rotated(-0.16))
   c.draw_polyline(points,Color("537478"),2,true)
  c.draw_circle(center,6,AMBER)
  var pts:=[center+Vector2(-118,35),center+Vector2(114,-36)]
  c.draw_dashed_line(pts[0],pts[1],AMBER if a.route>=0 else MUTED,2,8)
  for i in 2:
   c.draw_circle(pts[i],7 if i==a.sector else 5,MINT if i==a.sector else AMBER)
   label(c,pts[i].x-48,pts[i].y+(22 if i==1 else -10),a.SECTORS[i],WHITE,17)

func paint(c:Control,side:int) -> void:
 if a==null:return
 c.draw_rect(Rect2(Vector2.ZERO,Vector2(PIXELS)),Color("0d2028"))
 var focused:=page!="" and page!="Scope" and side_of(page)==side
 var name1:="CONTACTS" if side==0 else "SHIP SYSTEMS"
 var name2:="CHART" if side==0 else "DISTRIBUTOR"
 label(c,18,32,name1,MINT,23);label(c,270,32,name2,MINT,23)
 if focused:label(c,519,32,"EXIT",AMBER,21)
 c.draw_line(Vector2(15,47),Vector2(584,47),Color("41616a"),2)
 if not focused:
  if side==0:
   label(c,18,94,a.SECTORS[a.sector].to_upper(),AMBER,30)
   label(c,18,137,a.CATALOG[a.target].name,WHITE,29)
   label(c,18,178,"%d m    /    %d m/s"%[roundi(a.range_to(a.target)),roundi(f.velocity.length())],MINT,32)
   label(c,18,226,"PAD 01   CLEARED" if a.permit>=0 else ("SHIFT  /  "+a.SECTORS[a.route] if a.route>=0 else "LOCAL NAVIGATION"),AMBER,23)
   label(c,18,268,"THRUST   %d%%"%roundi(f.throttle*100),WHITE)
   meter(c,18,283,360,absf(f.throttle)*100,AMBER)
  else:
   for i in 3:
    var value:float=[a.shield,a.hull,a.fuel][i]
    var x:=20+i*193
    label(c,x,100,["SHIELD","HULL","FUEL"][i],MUTED)
    label(c,x,150,"%d"%roundi(value),WHITE,40);meter(c,x,169,159,value,MINT)
    label(c,x,238,a.BUSES[i],AMBER,24)
    for j in 4:c.draw_rect(Rect2(x+j*33,255,25,11),AMBER if j<a.pips[i] else Color("30424a"))
   label(c,20,308,"HARDPOINTS   "+("EXTENDED" if a.deployed else "STOWED"),WHITE,21)
 else:
  buttons.clear()
  var top:=74;var height:=38
  if page in ["Chart","Local"]:
   map_view(c,page=="Local");top=210
   if page=="Chart":
    var reserve:float=a.fuel-2*a.JUMP_COST
    var balance:="RESERVE %d"%floori(reserve) if reserve>=0 else "REFUEL TO RETURN"
    label(c,18,194,"TANK %d   /   LEG 22   /   %s"%[floori(a.fuel),balance],MINT if reserve>=0 else AMBER,19)
  elif page=="Modules":
   var loads:=[4,3,1,1,3,2];var draw:=0
   for i in loads.size():
    if a.enabled[i]:draw+=loads[i]
   label(c,18,75,"REACTOR   %d / 16 MW"%draw,AMBER,20);top=84
  elif page=="Contact":
   label(c,18,94,a.CATALOG[a.target].name,AMBER,32);top=121
  elif page=="Power":
   label(c,18,90,"CAPACITOR DISTRIBUTION",AMBER,24);top=112;height=53
  var entries:=rows()
  first_button=maxi(0,cursor-5)
  for i in range(first_button,mini(first_button+6,entries.size())):
   var r:=Rect2(14,top+(i-first_button)*height,571,height-2);buttons.append(r)
   if i==cursor:c.draw_rect(r,Color("2a474e"));c.draw_rect(Rect2(r.position,Vector2(4,r.size.y)),AMBER)
   label(c,25,r.position.y+27,str(entries[i][0]),WHITE,23)
   if page=="Power":
    for j in 4:c.draw_rect(Rect2(363+35*j,r.position.y+12,27,12),AMBER if j<a.pips[i] else Color("36494e"))
   else:label(c,362,r.position.y+26,str(entries[i][1]),MINT,20)
 if a.reply_time>0 and (side==0 or focused):
  c.draw_rect(Rect2(0,320,600,40),Color("243b40"))
  label(c,13,347,a.reply,AMBER,19)
