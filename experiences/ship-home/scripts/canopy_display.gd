# SPDX-License-Identifier: GPL-3.0-or-later
extends MeshInstance3D
## Transparent flight symbology, projected onto a fixed patch of the bow glazing.
const PIXELS:=Vector2i(900,390)
const GLASS:=Vector2(2.24,0.97067)
const INK:=Color("a5ffe1")
const TARGET:=Color("ffcf7a")
const SHADOW:=Color("112e34cd")
const FIELD:=Rect2(50,94,800,216)
var screen:=SubViewport.new()
var drawing:=Control.new()
var flight
var pilot
var island_pad:=-1
var approach:=false
var age:=0.0

func configure(simulation,walker) -> void:
 flight=simulation
 pilot=walker
 var plane:=QuadMesh.new()
 plane.size=GLASS
 mesh=plane
 position=Vector3(0,1.23,-1.26)
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 screen.size=PIXELS
 screen.disable_3d=true
 screen.transparent_bg=true
 screen.render_target_update_mode=SubViewport.UPDATE_DISABLED
 screen.gui_disable_input=true
 add_child(screen)
 drawing.size=Vector2(PIXELS)
 screen.add_child(drawing)
 drawing.draw.connect(paint)
 var coating:=StandardMaterial3D.new()
 coating.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 coating.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 coating.albedo_texture=screen.get_texture()
 material_override=coating
 hide()

func update_projection(dt:float,active:bool) -> void:
 var just_enabled:=active and not visible
 visible=active
 if not active:
  screen.render_target_update_mode=SubViewport.UPDATE_DISABLED
  approach=false
  return
 var systems=flight.avionics
 island_pad=flight.nearby_island() if systems.charge==0 and systems.transit==0 else -1
 approach=island_pad>=0 or (systems.route<0 and systems.target==systems.Regions.BERTH_CONTACT[flight.destination] and systems.range_to(systems.target)<70)
 age+=dt
 if just_enabled or age>=1.0/20.0:
  age=0
  drawing.queue_redraw()
  screen.render_target_update_mode=SubViewport.UPDATE_ONCE

# Perspective intersection starts at the seated eye and ends on the ship's glass.
func glass_point(eye:Vector3,local_ray:Vector3) -> Vector2:
 var at:=Vector2(eye.x,eye.y)+Vector2(local_ray.x,local_ray.y)*eye.z/maxf(0.001,-local_ray.z)
 return Vector2(PIXELS)*0.5+Vector2(at.x,-at.y)*Vector2(PIXELS)/GLASS

func stroke(points:PackedVector2Array,color:Color,width:=2.4) -> void:
 drawing.draw_polyline(points,SHADOW,width+2.8,true)
 drawing.draw_polyline(points,color,width,true)

func text_at(at:Vector2,value:String,color:Color,size:int) -> void:
 var font:=ThemeDB.fallback_font
 drawing.draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,SHADOW)
 drawing.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func paint() -> void:
 if not visible:return
 var systems=flight.avionics
 var eye:=to_local(pilot.pilot_camera.global_position)
 var local_basis:Basis=flight.attitude.transposed()
 var nose:=glass_point(eye,Vector3.FORWARD)
 var forward:Vector3=-flight.attitude.z
 var heading:=fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)
 var top:=46.0
 text_at(Vector2(412,top-9),"%03d°"%posmod(roundi(heading),360),INK,28)
 stroke([Vector2(445,top),Vector2(450,top+6),Vector2(455,top)],INK)
 for step in range(-3,4):
  var mark:=floori(heading/5)*5+step*5
  var x:float=450+(mark-heading)*6
  stroke([Vector2(x,top+12),Vector2(x,top+(24 if posmod(mark,10)==0 else 18))],INK,2)
  if posmod(mark,10)==0 and absf(mark-heading)>=7.5:
   text_at(Vector2(x-16,top+45),"%02d"%floori(posmod(mark,360)/10.0),INK,18)
 var up:=local_basis*Vector3.UP
 var pitch:=rad_to_deg(asin(clampf(-up.z,-1,1)))
 var bank:=atan2(up.x,up.y)
 var horizon:=Vector2.RIGHT.rotated(bank)
 var down:=Vector2(-horizon.y,horizon.x)
 for step in range(-1,2):
  var rung:=roundi(pitch/10.0)*10+step*10
  if absi(rung)>80:continue
  var center:=nose+down*(eye.z*PIXELS.y/GLASS.y*tan(deg_to_rad(pitch-rung)))
  var span:=80.0 if rung==0 else 52.0
  for side in [-1,1]:
   var inside:Vector2=center+horizon*side*25.0
   var outside:Vector2=center+horizon*side*span
   if FIELD.has_point(inside) and FIELD.has_point(outside):
    stroke([inside,outside,outside+down*(5.0 if rung>=0 else -5.0)],INK,2)
  var label_pos:=center+horizon*(span+10)
  if FIELD.grow(-16).has_point(label_pos):text_at(label_pos+Vector2(0,6),"%+d"%rung,INK,17)
 if not systems.deployed:stroke([nose+Vector2(-13,0),nose+Vector2(-5,0),nose+Vector2(0,5),nose+Vector2(5,0),nose+Vector2(13,0)],INK,2)
 var velocity:Vector3=local_basis*flight.velocity
 if velocity.length()>1.0 and velocity.z<0:
  var path:=glass_point(eye,velocity)
  if FIELD.grow(-18).has_point(path):
   drawing.draw_arc(path,9,0,TAU,24,SHADOW,5,true)
   drawing.draw_arc(path,9,0,TAU,24,INK,2.4,true)
   for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
    stroke([path+direction*9,path+direction*18],INK,2)
 if systems.deployed and island_pad<0:
  fire_sight(systems,eye,local_basis)
 else:
  navigation(systems,eye,local_basis)
 if systems.reply_time>0:text_at(Vector2(104,306),systems.reply,INK,19)
 if systems.incoming>0 or systems.flare_time>0:
  var warning:String="INBOUND  %.1f s"%systems.incoming if systems.incoming>0 else "INTERCEPTED"
  text_at(Vector2(565,350),warning,Color("ff997e"),24)
 if approach and (not systems.deployed or island_pad>=0):
  var height:float=flight.location.y-flight.BERTHS[island_pad if island_pad>=0 else flight.destination].y
  var instruction:String=flight.clearance()
  text_at(Vector2(105,354),"PAD ΔH  %+.1f m"%height,INK,24)
  text_at(Vector2(595,354),"V/S  %+.1f m/s"%flight.velocity.y,INK,24)
  if instruction=="":text_at(Vector2(403,354),"LAND",TARGET,26)

func navigation(systems,eye:Vector3,local_basis:Basis) -> void:
 var ray:Vector3=local_basis*(systems.jump_axis() if systems.route>=0 else systems.position_of(systems.target)-flight.location)
 if island_pad>=0:ray=local_basis*(flight.BERTHS[island_pad]-flight.location)
 var aim:=glass_point(eye,ray)
 var target_on_glass:bool=ray.z<0 and FIELD.grow(-15).has_point(aim)
 if target_on_glass:
  stroke([aim+Vector2.UP*15,aim+Vector2.RIGHT*15,aim+Vector2.DOWN*15,aim+Vector2.LEFT*15,aim+Vector2.UP*15],TARGET,3)
 else:
  var direction:=Vector2(ray.x,-ray.y).normalized()
  if direction.length_squared()<0.001:direction=Vector2.RIGHT
  var half:=FIELD.size*0.5-Vector2.ONE*14
  var target_point:=FIELD.get_center()+direction/maxf(absf(direction.x)/half.x,absf(direction.y)/half.y)
  var wing:=direction.orthogonal()*8
  stroke([target_point-direction*14+wing,target_point,target_point-direction*14-wing],TARGET,3)
  if ray.z>=0:text_at(target_point+Vector2(-20,26),"AFT",TARGET,19)

func corners(at:Vector2,radius:float,arm:float,ink:Color) -> void:
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
  var tip:Vector2=at+corner*radius
  stroke([tip-Vector2(corner.x*arm,0),tip,tip-Vector2(0,corner.y*arm)],ink,2)

func ring(at:Vector2,radius:float,start:float,end:float,ink:Color) -> void:
 drawing.draw_arc(at,radius,start,end,32,SHADOW,5,true)
 drawing.draw_arc(at,radius,start,end,32,ink,2.3,true)

func fire_sight(a,eye:Vector3,local_basis:Basis) -> void:
 var seeker_rack:bool=a.group==a.Group.MISSILES
 var pulse:bool=a.group==a.Group.PULSE
 var acquired:bool=a.tracking()
 var locked:bool=a.lock_id>=0 and a.lock_id==a.hostile_id
 var present:bool=a.hostile_id>=0 and a.disabled_time<=0 and (locked or a.target==a.hostile_id)
 var center:=glass_point(eye,Vector3.FORWARD)
 var contact:=center
 var on_glass:=false
 if present:
  var ray:Vector3=local_basis*(a.position_of(a.hostile_id)-flight.location)
  contact=glass_point(eye,ray)
  on_glass=ray.z<0 and FIELD.grow(-16).has_point(contact)
  if on_glass:corners(contact,12,6,TARGET)
 var mode:String="GIMBAL" if a.gimballed else "FIXED"
 var status:String=a.GROUP_NAMES[a.group].to_upper()+"   /   "+mode
 if seeker_rack:
  status="SEEKER   /   %d"%a.missiles
  var point:Vector2=contact if acquired and on_glass else center
  var radius:float=lerpf(30,18,a.seeker)
  corners(point,radius,8,INK)
  if a.seeker>0.01:ring(point,radius+5,-PI/2,-PI/2+TAU*a.seeker,INK)
  var hint:="NO LOCK"
  if a.missile_time>0:hint="IN FLIGHT"
  elif a.missiles==0:hint="EMPTY"
  elif a.seeker>=1:hint="LOCK"
  elif a.seeker>0:hint="ACQUIRING  %d%%"%floori(a.seeker*100)
  text_at(Vector2(200,350),hint,TARGET,22)
 else:
  var depth:=500.0
  if acquired:
   depth=a.muzzle().distance_to(a.pulse_mark() if pulse else a.position_of(a.hostile_id))
  var bore:Vector3=local_basis*(a.muzzle()-flight.location+a.gun_ray()*depth)
  var point:=glass_point(eye,bore)
  if bore.z<0 and FIELD.grow(-18).has_point(point):
   if pulse:
    for side in [0.0,PI]:ring(point,10,side-0.76,side+0.76,INK)
   else:
    for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
     stroke([point+direction*5,point+direction*14],INK)
   if a.gimballed and acquired:drawing.draw_circle(point,2.2,INK,true,-1,true)
  if pulse and acquired and on_glass:
   var predicted:Vector3=local_basis*(a.pulse_mark()-flight.location)
   var lead:=glass_point(eye,predicted)
   if predicted.z<0 and FIELD.grow(-12).has_point(lead):
    ring(lead,4,0,TAU,INK)
    if lead.distance_to(contact)>18:stroke([contact.direction_to(lead)*14+contact,lead+lead.direction_to(contact)*6],INK,1.5)
    var offset:=Vector2(24,-27) if lead.x<740 else Vector2(-76,-27)
    if lead.y<130:offset.y=34
    stroke([lead+lead.direction_to(lead+offset)*7,lead+offset*0.75],INK,1.6)
    text_at(lead+offset+Vector2(0,5),"LEAD",INK,18)
  if present and not on_glass:text_at(Vector2(350,350),"OFF GLASS",TARGET,19)
 text_at(Vector2(60,381),status,INK,23)
