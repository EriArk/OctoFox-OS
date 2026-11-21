# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Navigation is in sector metres. Keep the furnished, walkable cabin in its local physics frame.
enum Mode { BERTH, DEPARTING, FLYING, LANDING }
const GROUND_Y:=-5.35
const WALK_LAYER:=8
const BERTHS=[Vector3.ZERO,Vector3(0,0,-600),Vector3(42000,800,-36000)]
const NAMES=["Lantern Station","Echo Orchard","Prism Anchorage"]
var mode:=Mode.BERTH
var berth:=0
var destination:=1
var location:=Vector3.ZERO
var attitude:=Basis.IDENTITY
var velocity:=Vector3.ZERO
var throttle:=0.0
var stick:=Vector2.ZERO
var turn_rate:=Vector3.ZERO
var transition:=0.0
var from:=Transform3D.IDENTITY
var obstacles:Array[AABB]=[]
var coast := preload("res://scripts/island_coast.gd").new()
var air_zones: Array[Vector4] = []
var cloud_materials: Array[ShaderMaterial] = []
var cloud_densities: Array[float] = []
var island_depths: Array[float] = []
var cloud_cover := -1.0
var local_air := -1.0
var sky_sector:=-1
var sky_jump:=-1.0
var avionics:=preload("res://scripts/ship_avionics.gd").new()
var art:ShipInterior

func build(interior:ShipInterior) -> void:
 art=interior
 for i in BERTHS.size():
  var site:=Node3D.new();add_child(site);site.position=BERTHS[i]+Vector3.UP*(GROUND_Y+3.9)
  var surface:=Vector3.DOWN*4.1
  var deck=art.cylinder(site,surface,9.0,0.4,Color("535e68"))
  walk_surface(deck)
  for j in 20:
   var a:=TAU*j/20.0;var b:=TAU*(j+0.72)/20.0
   art.beam(site,surface+Vector3(cos(a)*7.7,0.23,sin(a)*7.7),surface+Vector3(cos(b)*7.7,0.23,sin(b)*7.7),0.085,Color("ffca71"),true)
  solid(site.position+Vector3(0,-6.3,0),Vector3(17,4,17))
  if i!=1:
   var pad_number:=Label3D.new();pad_number.text="01";pad_number.font_size=72;pad_number.pixel_size=0.016
   pad_number.modulate=Color("f1d49d");pad_number.outline_size=0;pad_number.rotation.x=-PI/2
   pad_number.position=surface+Vector3(0,0.22,-6.3);site.add_child(pad_number)
   if i==2:
    # An inclined navigation hoop marks the inner-ring anchorage from cruise range.
    var hoop:=Node3D.new();site.add_child(hoop);hoop.position=Vector3(0,3,-22);hoop.rotation.x=1.28
    art.scope_arc(hoop,Vector3.ZERO,16,0,TAU,Color("ab9cfc"),0.30)
    for segment in 24:
     var angle:=TAU*segment/24
     var center:=site.position+hoop.transform*Vector3(sin(angle)*16,0,cos(angle)*16)
     solid(center,Vector3(3.0,3.0,1.0))
   for side in [-1,1]:
    var p:=Vector3(side*14,-6,2)
    var tower=art.cylinder(site,p,3.4,13,Color("45596a"),2.8)
    walk_surface(tower)
    var bridge=art.box(site,Vector3(side*10.0,-4.05,2),Vector3(7.0,0.30,2.3),Color("637580"))
    walk_surface(bridge)
    for edge in [-1,1]:
     var rail=art.box(site,Vector3(side*10.6,-3.5,2+edge*1.08),Vector3(6.3,0.8,0.09),Color("a87953"))
     walk_surface(rail)
    art.cylinder(site,p+Vector3.UP*5.6,4.1,2.5,Color("a87953"))
    art.cylinder(site,p+Vector3.UP*7.0,3.7,0.5,Color("90dcca"))
    art.beam(site,p+Vector3.DOWN*3,surface,0.85,Color("56536b"))
    solid(site.position+p,Vector3(8,16,8))
  else:
   island(site,Vector3(30,-3.902,-48),94.0,64.0,true)
 # Each sea has space for its own basin and atmosphere.
 island(self,Vector3(-485,68,-988),48.0,52.0)
 island(self,Vector3(548,90,-887),57.0,62.0)
 island(self,Vector3(115,122,-1277),65.0,74.0)
 art.batch_static(self)
 avionics.configure(self)
 reset(0)

func solid(center:Vector3,size_m:Vector3) -> void:
 # Conservative hull clearance, including the service deck beneath the ship.
 obstacles.append(AABB(center-size_m*0.5,size_m).grow(3.1))

func walk_surface(mesh:MeshInstance3D) -> void:
 mesh.create_trimesh_collision()
 var body:=mesh.get_child(mesh.get_child_count()-1) as StaticBody3D
 body.collision_layer=WALK_LAYER;body.collision_mask=0

func island(parent:Node3D,center:Vector3,radius:float,depth:float,walkable:=false) -> void:
 var sector_center := center if parent==self else parent.position+center
 var seed_angle := float(air_zones.size())*1.7
 var crown := coast.build(parent,center,radius,depth,seed_angle)
 coast.plant_shore(crown,radius,seed_angle)
 plant_groves(parent,center,radius,seed_angle,walkable)
 air_zones.append(Vector4(sector_center.x,sector_center.y,sector_center.z,radius))
 island_depths.append(depth)
 cloud_densities.append(-1.0)
 cloud_materials.append(coast.cloud_boundary(parent,center,shell_radius(radius),seed_angle))
 if walkable:walk_surface(crown)

func plant_groves(parent:Node3D,center:Vector3,radius:float,seed_angle:float,walkable:bool) -> void:
 var trees: Array[Transform3D] = []
 var rng:=RandomNumberGenerator.new();rng.seed=3412+roundi(seed_angle*100)
 for i in (96 if walkable else 44):
  var a:=float(i%10)*TAU/10+seed_angle+rng.randf_range(-0.23,0.23)
  var fraction:=rng.randf_range(0.37,0.80)
  var flat:=coast.polar(a,radius*coast.headland(a,seed_angle)*fraction)
  if walkable and absf(flat.x-coast.PAD_FROM_CENTER.x)<13 and flat.y>coast.PAD_FROM_CENTER.y-14:continue
  var ground:=coast.relief(flat,radius,seed_angle,fraction)
  if ground<0.10 or ground>radius*0.22:continue
  var p:=center+Vector3(flat.x,ground-0.10,flat.y)
  var height:=rng.randf_range(3.1,6.8)
  trees.append(Transform3D(Basis(Vector3.UP,a).scaled(Vector3.ONE*height),p))
  var sector_p:=p if parent==self else p+parent.position
  solid(sector_p+Vector3.UP*height*0.65,Vector3(height*0.64,height*1.3,height*0.64))
  if walkable:
   var trunk:=StaticBody3D.new()
   trunk.position=p+Vector3.UP*height*0.28
   trunk.collision_layer=WALK_LAYER;trunk.collision_mask=0
   var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new()
   cylinder.radius=height*0.047;cylinder.height=height*0.56
   shape.shape=cylinder;trunk.add_child(shape);parent.add_child(trunk)
 coast.plant_batch(parent,"tree_detailed",trees)

func shell_radius(radius:float) -> float:
 return radius*coast.SEA_RADIUS*1.31

func update_air() -> void:
 var nearest := INF
 for i in air_zones.size():
  var zone:=air_zones[i]
  var offset := location-Vector3(zone.x,zone.y,zone.z)
  offset.y/=coast.CLOUD_HEIGHT
  var distance:=offset.length()/shell_radius(zone.w)
  nearest=minf(nearest,distance)
  var visible_density:=smoothstep(0.74,0.93,distance)*lerpf(1.0,0.23,smoothstep(1.04,1.40,distance))
  if not is_equal_approx(cloud_densities[i],visible_density):
   cloud_densities[i]=visible_density
   cloud_materials[i].set_shader_parameter("presence",visible_density)
 # From either side: cross the physical banks, change sky in the thickest part,
 # then clear the mist with daylight already established over the ocean.
 var air := 1.0-smoothstep(0.89,0.966,nearest)
 var cover := smoothstep(0.76,0.925,nearest)*(1.0-smoothstep(0.967,1.075,nearest))
 if is_equal_approx(air,local_air) and is_equal_approx(cover,cloud_cover):return
 local_air=air;cloud_cover=cover
 var env:=art.sky_environment
 var sky_material := env.sky.sky_material as ShaderMaterial
 sky_material.set_shader_parameter("local_air",air)
 var stars := art.field_stars.multimesh.mesh.material as StandardMaterial3D
 stars.albedo_color=Color(1,1,1,(1.0-air)*(1.0-cover))
 art.field_stars.visible=stars.albedo_color.a>0.001
 env.ambient_light_energy=lerpf(0.40,0.88,maxf(air,cover*0.63))
 env.fog_enabled=cover>0.001
 env.fog_mode=Environment.FOG_MODE_DEPTH
 env.fog_depth_begin=9.0
 env.fog_depth_end=lerpf(165.0,48.0,cover)
 env.fog_light_color=Color("c0cfd0")
 env.fog_light_energy=0.75
 env.fog_density=cover*0.92
 env.fog_sky_affect=cover

func hits_island(pos:Vector3) -> bool:
 for i in air_zones.size():
  var zone:=air_zones[i]
  var local:=pos-Vector3(zone.x,zone.y,zone.z)
  if local.y > zone.w*0.70+4 or local.y < -island_depths[i]*1.1-4:continue
  var flat:=Vector2(local.x,local.z)
  var planar:=flat/Vector2(1,0.90)
  var a:=planar.angle();var seed_angle:=i*1.7
  var edge:=zone.w*coast.rim(a,seed_angle)
  var r:=maxf(0,planar.length()-2.5)/edge
  if r>1.0:continue
  # Room for flying below the tapering shelf, including close to its spilling lip.
  var underside:=coast.SEA_Y-island_depths[i]*pow(maxf(0,1-r*r),0.72)
  if local.y<underside-3.1:continue
  var fraction:=planar.length()/(zone.w*coast.headland(a,seed_angle))
  var surface:=coast.relief(flat,zone.w,seed_angle,fraction) if fraction<1.0 else maxf(coast.SEA_Y,coast.seabed(flat,zone.w,seed_angle))
  if local.y<surface+3.1:return true
 return false

func reset(site:int) -> void:
 berth=clampi(site,0,BERTHS.size()-1);destination=1-berth if berth<2 else 2
 avionics.docked(berth)
 mode=Mode.BERTH;location=BERTHS[berth];attitude=dock_basis(berth)
 velocity=Vector3.ZERO;turn_rate=Vector3.ZERO;stick=Vector2.ZERO;throttle=0
 sync_view()

func dock_basis(site:int) -> Basis:return Basis(Vector3.UP,PI if site==1 else 0.0)

func clearance() -> String:
 if avionics.transit>0 or avionics.charge>0:return "Shift drive active"
 if avionics.cruise:return "Disengage cruise"
 if avionics.deployed:return "Stow hardpoints"
 if destination!=1 and avionics.permit!=destination:return "Request docking clearance"
 if avionics.target!=destination:return "Select the landing site"
 var offset:Vector3=location-BERTHS[destination]
 if Vector2(offset.x,offset.z).length()>8 or offset.y>9 or offset.y< -0.3:return "Approach the pad"
 if velocity.length()>2.5:return "Slow below 2.5 m/s"
 if attitude.y.dot(Vector3.UP)<0.94:return "Level the ship"
 return ""

func interact() -> void:
 if mode==Mode.BERTH:
  mode=Mode.DEPARTING;destination=1-berth if berth<2 else 2
 elif mode==Mode.FLYING and clearance().is_empty():
  mode=Mode.LANDING
 else:return
 from=Transform3D(attitude,location);transition=0;throttle=0;velocity=Vector3.ZERO;turn_rate=Vector3.ZERO

func tick(dt:float,axes:Vector2,yaw:float,power:float,strafe:Vector2,brake:bool) -> void:
 avionics.advance(dt)
 if mode==Mode.BERTH:return
 if avionics.transit>0 or avionics.charge>0:
  sync_view();return
 if mode!=Mode.FLYING:
  transition=minf(1,transition+dt/1.5)
  var goal:Vector3=BERTHS[destination] if mode==Mode.LANDING else from.origin+Vector3.UP*6
  var blend:=smoothstep(0,1,transition)
  location=from.origin.lerp(goal,blend);stick=Vector2.ZERO
  if mode==Mode.LANDING:attitude=from.basis.slerp(dock_basis(destination),blend)
  if transition>=1:
   if mode==Mode.LANDING:reset(destination)
   else:mode=Mode.FLYING
 else:
  stick=stick.move_toward(axes.limit_length(),dt*5)
  throttle=0 if brake else clampf(throttle+power*dt*0.8,-0.32,1)
  var rates:=Vector3(stick.y*0.82,-yaw*0.85,-stick.x*1.4)
  turn_rate=turn_rate.move_toward(rates,dt*3.5)
  attitude=(attitude*Basis(Quaternion.from_euler(turn_rate*dt))).orthonormalized()
  var speed:=22.0
  if avionics.cruise:speed=155.0
  elif avionics.boost>0:speed=52.0
  if brake:avionics.cruise=false;avionics.boost=0
  var command:=Vector3(strafe.x*8,strafe.y*8,-throttle*speed) if avionics.enabled[0] else Vector3.ZERO
  velocity=velocity.move_toward(Vector3.ZERO if brake else attitude*command,dt*(maxf(15,velocity.length()*1.5) if brake else (55 if avionics.cruise else 8)))
  var next:=location+velocity*dt
  if next.distance_to(avionics.ORIGINS[avionics.sector])>3600 and next.distance_squared_to(avionics.ORIGINS[avionics.sector])>location.distance_squared_to(avionics.ORIGINS[avionics.sector]):
   next=location;throttle=0;velocity=Vector3.ZERO;avionics.say("Sector boundary · Use the shift drive")
  if hits_island(next):
   avionics.impact(velocity.length());avionics.cruise=false
   velocity=Vector3.ZERO;throttle=0;next=location
  for box in obstacles:
   if box.has_point(next) or box.intersects_segment(location,next)!=null:
    avionics.impact(velocity.length());avionics.cruise=false
    velocity=Vector3.ZERO;throttle=0;next=location;break
  location=next
 sync_view()

func sync_view() -> void:
 transform=Transform3D(attitude,location).inverse()
 art.field_stars.basis=attitude.transposed()
 art.sky_environment.sky_rotation=attitude.transposed().get_euler()
 update_air()
 var sky:=art.sky_environment.sky.sky_material as ShaderMaterial
 if sky_sector!=avionics.sector:
  sky_sector=avionics.sector;sky.set_shader_parameter("sector_shift",float(sky_sector))
 var glow:=sin(PI*avionics.transit/2.0)
 if not is_equal_approx(glow,sky_jump):
  sky_jump=glow;sky.set_shader_parameter("jump_glow",glow)

func readout() -> String:
 if mode==Mode.BERTH:return NAMES[berth]+"   ·   Docked"
 if mode==Mode.DEPARTING:return "Releasing berth"
 if mode==Mode.LANDING:return "Docking   ·   "+NAMES[destination]
 var ray:Vector3=attitude.inverse()*(BERTHS[destination]-location)
 var bearing:=rad_to_deg(atan2(ray.x,-ray.z))
 var elevation:=rad_to_deg(atan2(ray.y,Vector2(ray.x,ray.z).length()))
 var text:="%s   %d m     %+.0f° / %+.0f°     %.1f m/s"%[NAMES[destination],roundi(ray.length()),bearing,elevation,velocity.length()]
 if ray.length()<14 and not clearance().is_empty():text+="   ·   "+clearance()
 return text
