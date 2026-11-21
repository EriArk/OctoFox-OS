# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## One set of selectable panel rows serves touch, keyboard and the pilot's pad.
const AMBER=Color("ffce78")
const MINT=Color("94e5d5")
const RED=Color("ff927a")
const WHITE=Color("f2f0df")
const MUTED=Color("afc4c4")
const KEY_SIZE:=Vector2(0.454,0.166)
const TRAVEL:=0.76
const STOWED_Y:=-0.222
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
var extensions: Array[float]=[0.0,0.0]
var gauges:Array[Label3D]=[]
var canopy:=preload("res://scripts/canopy_display.gd").new()
var radar_mesh:=ImmediateMesh.new()
var ordnance:=preload("res://scripts/ordnance_effects.gd").new()
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
  var track:=Node3D.new();f.art.helm_root.add_child(track)
  track.position=Vector3(side*1.08,0.605,-0.385)
  track.rotation=Vector3(-0.22,side*-0.94,0)
  # The screen slides between two fixed lips; only the active leaf is rendered.
  f.art.box(track,Vector3(0,-0.265,0.050),Vector3(0.701,0.53,0.033),f.art.TRIM)
  f.art.box(track,Vector3(0,-0.265,-0.098),Vector3(0.701,0.53,0.036),f.art.NIGHT)
  for end in [-1,1]:
   f.art.box(track,Vector3(end*0.347,-0.265,-0.024),Vector3(0.018,0.53,0.163),f.art.TRIM)
  f.art.box(track,Vector3(0,-0.011,0.052),Vector3(0.693,0.013,0.035),f.art.BRASS)
  var mount:=Node3D.new();track.add_child(mount)
  mount.position.y=STOWED_Y;mount.hide()
  # The glass sits flush in a radiused wood cabinet with a woven speaker below.
  f.art.veneer_case(mount,Vector3(0,-0.021,-0.003),Vector2(0.666,0.463),0.068,0.041)
  f.art.bezel(mount,Vector3(0,0,-0.001),Vector2(0.621,0.382),0.023,0.006,f.art.BRASS)
  f.art.faceplate(mount,Vector3(0,-0.218,-0.001),Vector2(0.551,0.039),0.017,f.art.WEAVE)
  f.art.bezel(mount,Vector3(0,-0.218,0),Vector2(0.558,0.045),0.019,0.003,f.art.BRASS)
  f.art.box(mount,Vector3(0,-0.411,-0.058),Vector3(0.14,0.47,0.045),Color("34434a"))
  var screen:=SubViewport.new();screen.size=PIXELS;screen.disable_3d=true
  screen.render_target_update_mode=SubViewport.UPDATE_DISABLED;screen.handle_input_locally=false;add_child(screen)
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
  var key:Node3D=f.art.helm_keys[index]
  var title:=key_text(key,Vector3(-0.197,0.051,0.004),21,AMBER if side<0 else MINT)
  title.text="NAV   ▴" if side<0 else "SYS   ▴"
  gauges.append(key_text(key,Vector3(-0.197,-0.019,0.005),30,WHITE))
 f.art.helm_root.add_child(canopy)
 canopy.configure(f,pilot)
 f.add_child(ordnance)
 hide()

func key_text(key:Node3D,at:Vector3,size:int,ink:Color) -> Label3D:
 var line:=Label3D.new()
 line.position=at;line.font_size=size;line.pixel_size=0.0010
 line.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
 line.outline_size=0;line.modulate=ink;line.double_sided=false
 key.add_child(line)
 return line

func side_of(section:String) -> int:
 return 1 if section in ["Ship","Power","Modules","Fire control"] else 0

func refresh() -> void:
 if page=="" or page=="Scope":return
 var i:=side_of(page)
 canvases[i].queue_redraw()
 viewports[i].render_target_update_mode=SubViewport.UPDATE_ONCE

func open(section:String) -> void:
 if page=="" and section!="":saved_look=Vector2(pilot.yaw,pilot.pitch)
 if page!="" and section=="":
  pilot.yaw=saved_look.x;pilot.pitch=saved_look.y
  pilot.pilot_camera.fov=78
 page=section;cursor=0;buttons.clear()
 if section!="":canopy.update_projection(0,false)
 if pilot.seated:
  pilot.walking=page==""
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if page!="" else Input.MOUSE_MODE_CAPTURED
 refresh()

func clear() -> void:
 open("");y_down=false;chord=false;hide();scanner.hide();canopy.update_projection(0,false)

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
 visible=active;scanner.visible=active
 var selected:=-1 if not active or page in ["","Scope"] else side_of(page)
 # Fully lower the previous drawer before exposing its opposite.
 var retract_first:=selected>=0 and extensions[1-selected]>0.0
 for i in surfaces.size():
  var mount:=surfaces[i].get_parent() as Node3D
  var goal:=1.0 if i==selected and not retract_first else 0.0
  extensions[i]=move_toward(extensions[i],goal,dt*5.5) if active else 0.0
  mount.position.y=STOWED_Y+TRAVEL*smoothstep(0.0,1.0,extensions[i])
  mount.visible=extensions[i]>0.0
  gauges[i].visible=active
 var glass_live:bool=active and page=="" and f.mode==f.Mode.FLYING and a.transit==0
 canopy.update_projection(dt,glass_live)
 ordnance.refresh(a)
 if not active:return
 if page!="":
  var focus:Vector3=f.art.radar.global_position
  if selected>=0:
   var track:Node3D=surfaces[selected].get_parent().get_parent()
   # Aim just inboard of the leaf so the canopy stays in peripheral view.
   var inward:=0.105 if selected==0 else -0.105
   focus=track.to_global(Vector3(inward,STOWED_Y+TRAVEL,0))
  var ray:Vector3=(focus-pilot.pilot_pivot.global_position).normalized()
  var blend:=1.0-exp(-15.0*dt)
  pilot.yaw=lerp_angle(pilot.yaw,atan2(-ray.x,-ray.z),blend)
  pilot.pitch=lerpf(pilot.pitch,asin(ray.y),blend)
  pilot.pilot_camera.fov=lerpf(pilot.pilot_camera.fov,23.0 if page=="Scope" else 32.0,blend)
 var course:bool=a.route>=0
 var ray:Vector3=f.attitude.inverse()*(a.jump_axis() if course else a.position_of(a.target)-f.location)
 var behind:=ray.z>=0
 update_keys(behind)
 sweep+=dt
 if sweep>=0.10:
  sweep=0;scan();refresh()

func update_keys(aft:bool) -> void:
 var nav:String=a.CATALOG[a.target].name+"\n%d m%s"%[roundi(a.range_to(a.target)),"  AFT" if aft else ""]
 var mode: String="CRUISE" if a.cruise else "LOCAL"
 var systems:="%d m/s   %s"%[roundi(f.velocity.length()),mode]
 var caution:=""
 if f.mode==f.Mode.BERTH:
  nav=f.NAMES[f.berth];systems="MOORED"
 elif f.mode==f.Mode.LANDING:
  nav=f.NAMES[f.destination];systems="TOUCHDOWN"
 elif f.mode==f.Mode.DEPARTING:
  nav=f.NAMES[f.berth];systems="LIFTING OFF"
 elif a.transit>0:
  nav=a.SECTORS[a.route];systems="IN TRANSIT"
 elif a.charge>0:
  nav=a.SECTORS[a.route];systems="CHARGING %d%%"%roundi(a.charge/3*100)
 elif a.route>=0:
  nav=a.SECTORS[a.route]+"\nSHIFT VECTOR"
 elif a.target==f.destination and a.range_to(a.target)<70:
  var instruction:String=f.clearance()
  nav="PAD 01   %d m"%roundi(a.range_to(a.target)) if a.target!=1 else "ISLAND   %d m"%roundi(a.range_to(a.target))
  nav+="\n"+("LAND" if instruction=="" else landing_order(instruction))
 elif a.lock_id>=0:
  nav+="  LOCK"
 if f.mode==f.Mode.FLYING:
  if a.hull<35:caution="HULL %d%%"%roundi(a.hull)
  elif a.fuel<a.JUMP_COST:caution="LOW FUEL %d"%floori(a.fuel)
  elif a.shield<25:caution="SHIELD %d%%"%roundi(a.shield)
 gauges[0].text=nav
 if caution=="" and f.mode==f.Mode.FLYING and a.transit<=0 and not is_zero_approx(f.throttle):
  systems+="\nTHR %+.0f%%"%(f.throttle*100)
 gauges[1].text=systems+("\n"+caution if caution!="" else "")
 gauges[1].modulate=AMBER if caution!="" else WHITE

func landing_order(instruction:String) -> String:
 match instruction:
  "Request docking clearance":return "CALL CONTROL"
  "Select the landing site":return "SELECT SITE"
  "Approach the pad":return "ON APPROACH"
  "Level the ship":return "LEVEL %d°"%roundi(rad_to_deg(f.attitude.y.angle_to(Vector3.UP)))
  "Slow below 2.5 m/s":return "SLOW < 2.5 m/s"
  _:return instruction.to_upper()

func rows() -> Array:
 match page:
  "Contacts":
   var entries:Array=[]
   for id in a.contacts():entries.append([a.CATALOG[id].name,"%d m"%roundi(a.range_to(id)),id])
   return entries
  "Contact":
   var id:int=a.target;var kind:String=a.CATALOG[id].kind
   if kind=="hostile":return [["Target lock","TRACKING" if a.lock_id==id else "ACQUIRE","lock"],[a.GROUP_NAMES[a.group],"%d LEFT"%a.missiles if a.group==a.Group.MISSILES else "%d%%"%roundi(a.weapon),"fire"],["Hail ship","COMMS","hail"]]
   return [["Request pad 01" if kind=="station" else "Hail contact","CLEARED" if a.permit==id else "COMMS","hail"]]
  "Ship":return [["Components","6 MODULES","modules"],["Hardpoints","DEPLOYED" if a.deployed else "STOWED","arms"],["Cruise drive","ENGAGED" if a.cruise else "STANDBY","cruise"],["Engine boost","%d%%"%roundi(a.engine),"boost"],["Station service","FUEL / REPAIR","service"],["Fire control",a.GROUP_NAMES[a.group].to_upper(),"fire_control"]]
  "Fire control":
   var controls:Array=[["Fire group",a.GROUP_NAMES[a.group],"cycle"]]
   if a.group!=a.Group.MISSILES:controls.append(["Mount","GIMBAL" if a.gimballed else "FIXED","mount"])
   controls.append(["Point defence","INTERCEPT" if a.incoming>0 else ("RECHARGE" if a.defence_cooldown>0 else "READY"),"defend"])
   return controls
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

func activate(power_delta:int=1) -> void:
 var entries:=rows()
 if cursor>=entries.size() or entries.is_empty() or a.transit>0:return
 var action:Variant=entries[cursor][2]
 match page:
  "Contacts":a.select(action);open("Contact")
  "Power":a.distribute(action,power_delta)
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
    "fire_control":open("Fire control")
    "cycle":a.cycle_group();cursor=0
    "mount":a.cycle_mount()
    "defend":a.intercept()
    "lock":a.acquire()
    "fire":a.fire()
 refresh()

func event(e:InputEvent) -> bool:
 if y_down and e.is_action_pressed("interact"):
  chord=true;a.intercept();return true
 if page=="" and ((e is InputEventJoypadButton and e.button_index==JOY_BUTTON_LEFT_STICK and e.pressed) or (e is InputEventKey and e.physical_keycode==KEY_G and e.pressed and not e.echo)):
  if y_down:chord=true;a.cycle_mount()
  else:a.cycle_group()
  return true
 if (e is InputEventJoypadButton and e.button_index==JOY_BUTTON_RIGHT_STICK and e.pressed) or (e is InputEventKey and e.physical_keycode==KEY_V and e.pressed and not e.echo):
  open("" if page=="Scope" else "Scope");return true
 if e.is_action_pressed("pick_item"):
  y_down=true;chord=false;return true
 if e.is_action_released("pick_item"):
  if y_down and not chord:
   if page=="":a.nose_contact()
   else:open("")
  y_down=false;chord=false;return true
 var dir:=""
 for pair in [["rotate_left","ui_left","Contacts"],["rotate_right","ui_right","Ship"],["fly_up","ui_up","Chart"],["fly_down","ui_down","Power"]]:
  if e.is_action_pressed(pair[0]) or e.is_action_pressed(pair[1]):dir=pair[2]
 if y_down and dir!="":
  chord=true;open(dir);return true
 if page=="":return false
 if e.is_action_pressed("cancel_ship"):
  open("Contacts" if page=="Contact" else ("Ship" if page in ["Modules","Fire control"] else ("Chart" if page=="Local" else "")));return true
 if e.is_action_pressed("interact") or e.is_action_pressed("ui_accept"):
  activate();return true
 if page=="Power" and dir in ["Contacts","Ship"]:
  activate(-1 if dir=="Contacts" else 1);return true
 if page=="Scope":return not e.is_action_pressed("pause_ship")
 if dir in ["Chart","Power"]:cursor=posmod(cursor+(-1 if dir=="Chart" else 1),maxi(1,rows().size()))
 return not e.is_action_pressed("pause_ship")

func _input(e:InputEvent) -> void:
 if not visible:return
 if e is InputEventJoypadButton or e is InputEventKey:
  if not e.is_action_pressed("pause_ship") and event(e):get_viewport().set_input_as_handled()
  return
 if e.device==InputEvent.DEVICE_ID_EMULATION:return
 var pos:Vector2
 if e is InputEventScreenTouch and e.pressed:pos=e.position
 elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:pos=e.position
 else:return
 var camera:Camera3D=pilot.pilot_camera
 if page=="":
  for i in 2:
   var uv:=face_hit(camera,pos,f.art.helm_keys[i],KEY_SIZE)
   if uv.x>=0:
    open("Contacts" if i==0 else "Power");get_viewport().set_input_as_handled();return
 for side in 2:
  if page in ["","Scope"] or side_of(page)!=side or extensions[side]<0.98:continue
  var uv:=face_hit(camera,pos,surfaces[side],PANEL_SIZE)
  if uv.x<0:continue
  var px:=uv*Vector2(PIXELS)
  if px.y<48:
   if px.x>507:open("")
   elif side==0:open("Contacts" if px.x<260 else "Chart")
   else:open("Ship" if px.x<260 else "Power")
  else:
   for i in buttons.size():
    if buttons[i].has_point(px):
     cursor=i+first_button
     activate(-1 if page=="Power" and px.x>=321 and px.x<384 else 1)
     break
  get_viewport().set_input_as_handled();return

 if page in ["","Scope"] and not camera.is_position_behind(f.art.radar.global_position):
  var dial:Vector2=camera.unproject_position(f.art.radar.global_position)
  var rim:Vector2=camera.unproject_position(f.art.radar.to_global(Vector3(0.235,0.045,0)))
  if pos.distance_to(dial)<dial.distance_to(rim):
   open("" if page=="Scope" else "Scope");get_viewport().set_input_as_handled()

func face_hit(camera:Camera3D,pos:Vector2,face:Node3D,size:Vector2) -> Vector2:
 var normal:=face.global_basis.z.normalized()
 var ray:=camera.project_ray_normal(pos)
 if ray.dot(normal)>=0:return Vector2(-1,-1)
 var hit:Variant=Plane(normal,face.global_position).intersects_ray(camera.project_ray_origin(pos),ray)
 if hit!=null:
  var local:=face.to_local(hit)
  var uv:=Vector2(local.x,-local.y)/size+Vector2.ONE*0.5
  if Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv):return uv
 return Vector2(-1,-1)

func label(c:Control,x:float,y:float,value:String,col:Color,px:int=23) -> void:
 c.draw_string(ThemeDB.fallback_font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,col)

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
 if a==null or page in ["","Scope"] or side_of(page)!=side:return
 c.draw_rect(Rect2(Vector2.ZERO,Vector2(PIXELS)),Color("0d2028"))
 var accent:=AMBER if side==0 else MINT
 var primary:=page in ["Contacts","Contact","Ship","Modules","Fire control"]
 label(c,20,32,"CONTACTS" if side==0 else "SYSTEMS",accent if primary else MUTED,22)
 label(c,274,32,"CHART" if side==0 else "POWER",MUTED if primary else accent,22)
 label(c,519,32,"STOW",WHITE,19)
 c.draw_line(Vector2(15,47),Vector2(584,47),Color("345159"),1)
 var tab_x:=20 if primary else 274
 c.draw_line(Vector2(tab_x,46),Vector2(tab_x+91,46),accent,3)
 buttons.clear()
 var top:=74;var height:=38
 if page in ["Chart","Local"]:
  map_view(c,page=="Local");top=210
  if page=="Chart":
   var reserve:float=a.fuel-2*a.JUMP_COST
   var balance:="RESERVE %d"%floori(reserve) if reserve>=0 else "REFUEL TO RETURN"
   label(c,18,194,"TANK %d   /   LEG 22   /   %s"%[floori(a.fuel),balance],MINT if reserve>=0 else AMBER,19)
 elif page=="Contacts":
  var up:Vector3=f.attitude.transposed()*Vector3.UP
  label(c,23,77,"PITCH  %+.0f°     BANK  %+.0f°"%[rad_to_deg(asin(clampf(-up.z,-1.0,1.0))),rad_to_deg(atan2(up.x,up.y))],MUTED,19)
  top=88
 elif page=="Ship":
  label(c,23,79,"HULL  %d%%     SHIELD  %d%%     FUEL  %d"%[roundi(a.hull),roundi(a.shield),floori(a.fuel)],MINT,20)
  top=88
 elif page=="Modules":
  var loads:=[4,3,1,1,3,2];var draw:=0
  for i in loads.size():
   if a.enabled[i]:draw+=loads[i]
  label(c,18,75,"REACTOR   %d / 16 MW"%draw,AMBER,20);top=84
 elif page=="Contact":
  label(c,18,94,a.CATALOG[a.target].name,AMBER,32);top=121
 elif page=="Power":
  label(c,25,85,"BUS",MUTED,19);label(c,244,85,"CHARGE",MUTED,19)
  label(c,375,85,"6 POWER UNITS",MINT,19);top=101;height=69
 var entries:=rows()
 first_button=maxi(0,cursor-5)
 for i in range(first_button,mini(first_button+6,entries.size())):
  var r:=Rect2(14,top+(i-first_button)*height,571,height-2);buttons.append(r)
  if i==cursor:c.draw_rect(r,Color("2a474e"));c.draw_rect(Rect2(r.position,Vector2(4,r.size.y)),AMBER)
  label(c,25,r.position.y+(36 if page=="Power" else 27),str(entries[i][0]),WHITE,23)
  if page=="Power":
   label(c,245,r.position.y+36,"%d%%"%roundi([a.shield,a.engine,a.weapon][i]),MINT,21)
   label(c,342,r.position.y+38,"−",WHITE if a.pips[i]>0 else MUTED,30)
   for j in 4:c.draw_rect(Rect2(389+31*j,r.position.y+19,23,17),AMBER if j<a.pips[i] else Color("36494e"))
   label(c,536,r.position.y+38,"+",WHITE if a.pips[i]<4 else MUTED,30)
  else:label(c,362,r.position.y+26,str(entries[i][1]),MINT,20)
 if a.incoming>0 or a.reply_time>0:
  c.draw_rect(Rect2(0,320,600,40),Color("243b40"))
  label(c,13,347,"MISSILE INBOUND  ·  %d s"%ceili(a.incoming) if a.incoming>0 else a.reply,RED if a.incoming>0 else AMBER,19)
