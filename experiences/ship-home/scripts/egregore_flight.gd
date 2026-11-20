# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Navigation is in sector metres. Keep the furnished, walkable cabin in its local physics frame.
enum Mode { BERTH, DEPARTING, FLYING, LANDING }
const GROUND_Y:=-5.35
const WALK_LAYER:=8
const BERTHS=[Vector3.ZERO,Vector3(0,0,-96)]
const NAMES=["Lantern Station","Echo Orchard"]
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
  if i==0:
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
   island(site,Vector3(2,-3.902,-3),18,11,true)
   for j in 5:
    var angle:=PI+0.53*j
    var p:=Vector3(cos(angle)*12, -3.9, sin(angle)*12-4)
    var crown:=p+Vector3(j%2,5.0+j%3,-0.6)
    var trunk=art.cylinder(site,(p+crown)*0.5,0.34,p.distance_to(crown),Color("815b64"),0.24)
    trunk.quaternion=Quaternion(Vector3.UP,(crown-p).normalized());walk_surface(trunk)
    for side in [-1,1]:
     var tip:=crown+Vector3(side*1.8,1.3,0.5)
     art.beam(site,crown-Vector3.UP*1.5,tip,0.2,Color("815b64"))
     var tint:=Color("b486b3") if j%2 else Color("77aea5")
     foliage(site,tip,Vector3(2.9,1.4,2.2),tint)
     foliage(site,tip+Vector3(side*0.65,0.85,0.35),Vector3(1.75,1.05,1.65),tint.lightened(0.12))
    solid(site.position+p+Vector3.UP*4,Vector3(7,9,5))
 # Disconnected strata mark the outskirts of the orchard.
 for p in [Vector3(38,-4,-114),Vector3(-47,15,-149),Vector3(53,25,-186)]:
  island(self,p,8.5,7.5)
 art.batch_static(self)
 reset(0)

func foliage(parent:Node3D,at:Vector3,radii:Vector3,tint:Color) -> void:
 var crown:=MeshInstance3D.new();var sphere:=SphereMesh.new()
 sphere.radius=1;sphere.height=2;sphere.radial_segments=16;sphere.rings=8
 crown.mesh=sphere;crown.position=at;crown.scale=radii
 crown.material_override=art.material(tint);parent.add_child(crown)

func solid(center:Vector3,size_m:Vector3) -> void:
 # Conservative hull clearance, including the service deck beneath the ship.
 obstacles.append(AABB(center-size_m*0.5,size_m).grow(3.1))

func walk_surface(mesh:MeshInstance3D) -> void:
 mesh.create_trimesh_collision()
 var body:=mesh.get_child(mesh.get_child_count()-1) as StaticBody3D
 body.collision_layer=WALK_LAYER;body.collision_mask=0

func island(parent:Node3D,center:Vector3,radius:float,depth:float,walkable:=false) -> void:
 var strata=[Color("4a535f"),Color("725e76"),Color("9c7a87"),Color("749e91")]
 var previous:Array[Vector3]=[]
 for ring in 5:
  var points:Array[Vector3]=[]
  for j in 16:
   var angle:=TAU*j/16
   var r:float=radius*[0.08,0.56,0.90,1.0,0.93][ring]*(1.0+0.12*sin(3*angle)+0.08*cos(5*angle))
   points.append(center+Vector3(cos(angle)*r,depth*[-1.0,-0.76,-0.32,-0.12,0.0][ring],sin(angle)*r*0.90))
  if ring>0:
   for j in 16:
    var k:=(j+1)%16
    art.panel(parent,[previous[j],points[j],points[k],previous[k]],strata[ring-1])
  previous=points
 previous.reverse()
 var crown:=art.panel(parent,previous,strata.back())
 if walkable:walk_surface(crown)
 solid(parent.position+center-Vector3.UP*depth*0.5,Vector3(radius*1.6,depth,radius*1.4))

func reset(site:int) -> void:
 berth=clampi(site,0,BERTHS.size()-1);destination=1-berth
 mode=Mode.BERTH;location=BERTHS[berth];attitude=dock_basis(berth)
 velocity=Vector3.ZERO;turn_rate=Vector3.ZERO;stick=Vector2.ZERO;throttle=0
 sync_view()

func dock_basis(site:int) -> Basis:return Basis(Vector3.UP,PI if site==1 else 0.0)

func clearance() -> String:
 var offset:Vector3=location-BERTHS[destination]
 if Vector2(offset.x,offset.z).length()>8 or offset.y>9 or offset.y< -0.3:return "Approach the pad"
 if velocity.length()>2.5:return "Slow below 2.5 m/s"
 if attitude.y.dot(Vector3.UP)<0.94:return "Level the ship"
 return ""

func interact() -> void:
 if mode==Mode.BERTH:
  mode=Mode.DEPARTING;destination=1-berth
 elif mode==Mode.FLYING and clearance().is_empty():
  mode=Mode.LANDING
 else:return
 from=Transform3D(attitude,location);transition=0;throttle=0;velocity=Vector3.ZERO;turn_rate=Vector3.ZERO

func tick(dt:float,axes:Vector2,yaw:float,power:float,strafe:Vector2,brake:bool) -> void:
 if mode==Mode.BERTH:return
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
  var command:=Vector3(strafe.x*8,strafe.y*8,-throttle*22)
  velocity=velocity.move_toward(Vector3.ZERO if brake else attitude*command,dt*(15 if brake else 8))
  var next:=location+velocity*dt
  for box in obstacles:
   if box.has_point(next) or box.intersects_segment(location,next)!=null:
    velocity=Vector3.ZERO;throttle=0;next=location;break
  location=next
 sync_view()

func sync_view() -> void:
 transform=Transform3D(attitude,location).inverse()
 var target:Vector3=attitude.inverse()*(BERTHS[destination]-location)
 var disc:=Vector2(target.x,target.z).limit_length(80)*0.0027
 var up:=attitude.transposed()*Vector3.UP
 art.ladder.rotation.y=atan2(up.x,up.y)
 art.ladder.position.z=clampf(up.z,-1,1)*0.046
 art.contact.position=Vector3(disc.x,0.052,disc.y)
 art.field_stars.basis=attitude.transposed()
 art.sky_environment.sky_rotation=attitude.transposed().get_euler()

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
