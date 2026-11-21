# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Landing collar, interlocked vestibule, main hall and aft workroom.
const Art=preload("res://scripts/interior.gd")
const LOCKS=[9.35,13.0]
const HEIGHT:=3.85
const WALL=Color("ced1bd")
const FRAME=Color("364f55")
const FLOOR=Color("4c6263")
const GLOW=Color("f7ca8e")
const PORTS={
 0:["LANTERN STATION","ARRIVALS","DISPATCH",Color("50918b")],
 2:["PRISM ANCHORAGE","CHART ROOM","SIGNAL OFFICE",Color("827b9f")],
 4:["CINDER ANCHORAGE","CREW HALL","SERVICE SHOP",Color("a76a4d")],
 6:["LANTERN BIOSTATION","LIVE COLLECTION","SAMPLE LAB",Color("468d80")]}
var art:ShipInterior
var port:int
var doors:Array=[]
var openings:Array[float]=[0,0]
var lamps:Array[SpotLight3D]=[]

func block(at:Vector3,size:Vector3,tint:Color,solid:=false,glow:=false) -> MeshInstance3D:
 var mesh:=art.box(self,at,size,tint,false,glow)
 if solid:
  var body:=StaticBody3D.new();body.collision_layer=8;body.collision_mask=0
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box
  body.add_child(shape);body.position=at;add_child(body)
 return mesh

func light(at:Vector3,aim:Vector3,color:Color,energy:float,reach:float) -> void:
 var lamp:=art.fixture_light(self,at,aim,color,energy,reach,65);lamp.visible=false;lamps.append(lamp)

func bulkhead(z:float,width:float,opening:float,title:String) -> void:
 var wing:=(width-opening)*0.5
 for side in [-1,1]:
  block(Vector3(side*(opening+wing)*0.5,HEIGHT/2,z),Vector3(wing,HEIGHT,0.32),WALL,true)
  block(Vector3(side*(opening*0.5+0.10),1.33,z),Vector3(0.20,2.66,0.41),FRAME)
 block(Vector3(0,3.22,z),Vector3(opening,1.26,0.34),FRAME,true)
 for side in [-1,1]:
  art.label(self,title,Vector3(0,2.97,z+side*0.18),PI if side<0 else 0.0,28,Art.PAPER)

func build(flight,index:int) -> void:
 port=index;art=flight.art
 var accent:Color=PORTS[port][3]
 block(Vector3(0,-0.24,17.25),Vector3(8.4,0.48,18.6),FLOOR,true)
 block(Vector3(0,-0.13,8.22),Vector3(3.3,0.26,2.5),FLOOR,true)
 block(Vector3(0,HEIGHT+0.07,19.80),Vector3(8.48,0.33,13.68),accent,true)
 block(Vector3(0,HEIGHT+0.02,11.15),Vector3(3.76,0.29,4.03),FRAME,true)
 bulkhead(LOCKS[0],3.66,1.96,"AIRLOCK");bulkhead(LOCKS[1],8.36,1.96,PORTS[port][1])
 bulkhead(20.72,8.36,2.17,PORTS[port][2])
 block(Vector3(0,HEIGHT/2,26.42),Vector3(8.40,HEIGHT,0.24),WALL,true)
 for side in [-1,1]:
  block(Vector3(side*1.77,HEIGHT/2,11.16),Vector3(0.23,HEIGHT,3.67),WALL,true)
  block(Vector3(side*1.636,1.18,11.16),Vector3(0.040,0.18,3.64),accent)
  for z in [15.02,18.86,23.60]:
   var span:=3.84 if z<20 else 5.84
   var x:float=side*4.09
   block(Vector3(x,0.50,z),Vector3(0.28,1.0,span),WALL,true)
   block(Vector3(x,3.31,z),Vector3(0.28,1.08,span),WALL,true)
   for edge in [-1,1]:
    block(Vector3(x,1.88,z+edge*(span/2-0.34)),Vector3(0.29,1.80,0.70),WALL,true)
   var window:=block(Vector3(x,1.88,z),Vector3(0.13,1.80,span-1.30),Art.SEA_GLASS,true)
   var glass:=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
   glass.albedo_color=Color(0.27,0.53,0.58,0.18);glass.roughness=0.18
   window.mesh=window.mesh.duplicate();window.mesh.surface_set_material(0,glass);window.material_override=null
   for y in [1.0,2.77]:
    block(Vector3(x,y,z),Vector3(0.42,0.13,span),Art.BRASS)
  for z in [13.1,16.96,20.72,26.38]:
   block(Vector3(side*3.91,1.91,z),Vector3(0.26,3.82,0.19),FRAME)
  block(Vector3(side*3.72,3.58,19.8),Vector3(0.34,0.27,13.3),FRAME)
  block(Vector3(side*3.61,3.42,19.8),Vector3(0.08,0.04,13.1),GLOW,false,true)
  block(Vector3(side*1.32,0.013,10.35),Vector3(0.052,0.024,4.9),GLOW,false,true)
  for z in [14.2,18.5,23.7]:
   block(Vector3(side*4.23,2.0,z),Vector3(0.23,4.10,0.20),accent)
 for z in [11.1,15.5,19.4,23.9]:
  block(Vector3(0,3.72,z),Vector3(1.4,0.12,0.32),FRAME)
  block(Vector3(0,3.64,z),Vector3(1.15,0.045,0.21),GLOW,false,true)
 light(Vector3(0,3.6,15),Vector3(0,1.0,16),Color("ffe4bf"),2.3,6)
 light(Vector3(0,3.6,24),Vector3(0,0.9,23),Color("cce8e5"),2.3,6)
 # Blast collar at the dock mouth and chamfered shoulders over the pressure doors.
 for side in [-1,1]:
  var jamb:=block(Vector3(side*1.62,1.79,9.1),Vector3(0.38,3.6,0.32),FRAME)
  jamb.rotation.z=-side*0.065
  block(Vector3(side*1.62,1.52,8.92),Vector3(0.09,1.62,0.04),GLOW,false,true)
  var shoulder:=block(Vector3(side*3.90,3.81,19.72),Vector3(1.05,0.55,13.68),accent)
  shoulder.rotation.z=-side*0.48
  for z in [14.0,18.6,23.2]:
   var strap:=block(Vector3(side*3.85,3.95,z),Vector3(1.17,0.51,0.15),FRAME)
   strap.rotation.z=shoulder.rotation.z
  # Layered recessed heat exchangers run down either side of the aft module.
  block(Vector3(side*4.58,1.05,24.10),Vector3(1.09,1.48,3.94),FRAME)
  for fin in 10:
   block(Vector3(side*4.86,1.11,22.43+fin*0.365),Vector3(1.10,1.51,0.10),accent)
 block(Vector3(0,3.89,9.12),Vector3(3.61,0.26,0.49),FRAME)
 art.label(self,PORTS[port][0],Vector3(0,3.55,9.173),PI,36,FRAME)
 # Upper equipment fairings and a rear mast break up the pressure hull silhouette.
 for side in [-1,1]:
  art.beam(self,Vector3(side*2.60,4.1,14.0),Vector3(side*2.60,4.1,25),0.30,FRAME)
  for z in [15,20,24]:block(Vector3(side*2.6,4.17,z),Vector3(0.84,0.42,0.2),Art.BRASS)
 art.cylinder(self,Vector3(-2.65,4.56,25),0.42,1.08,FRAME,0.19)
 art.beam(self,Vector3(-2.65,5,25),Vector3(-2.65,7.2,25),0.075,Art.COPPER)
 art.cylinder(self,Vector3(-2.65,7.23,25),0.11,0.16,GLOW)
 block(Vector3(0,3.52,12.78),Vector3(6.0,0.66,0.28),accent)
 art.label(self,PORTS[port][0],Vector3(0,3.53,12.62),PI,62,Art.PAPER)
 flight.solid(position+Vector3(0,1.9,19.8),Vector3(8.42,4.4,13.8))
 flight.solid(position+Vector3(0,1.9,11.15),Vector3(3.68,4.0,3.7))
 if port!=6:fit_port(accent)

func fit_port(accent:Color) -> void:
 # An arrivals bench, plotting table or repair bench gives each port a different workspace.
 for side in [-1,1]:
  block(Vector3(side*3.19,0.42,18.2),Vector3(0.86,0.80,2.8),accent,true)
  block(Vector3(side*3.60,0.9,18.2),Vector3(0.16,1.0,2.8),Art.WALNUT)
 block(Vector3(0,0.55,24.9),Vector3(3.8,1.1,1.12),FRAME,true)
 block(Vector3(0,1.14,24.9),Vector3(4.0,0.10,1.30),Art.WOOD)
 if port==2:
  for i in 3:
   art.scope_arc(self,Vector3(0,1.28+i*0.09,24.9),0.25+i*0.22,0,TAU,Art.SEA_GLASS,0.018)
 elif port==4:
  art.beam(self,Vector3(-0.87,1.45,24.9),Vector3(0.87,1.45,24.9),0.27,Art.COPPER)
  for x in [-0.64,0.64]:block(Vector3(x,1.28,24.9),Vector3(0.18,0.24,0.65),accent)
 else:
  for i in 4:block(Vector3(-1.1+i*0.72,1.43,24.94),Vector3(0.52,0.48,0.50),Art.WALNUT)
 art.label(self,PORTS[port][2],Vector3(0,2.42,26.27),PI,51,FRAME)

func mount_doors() -> void:
 for z in LOCKS:
  var leaves:Array[AnimatableBody3D]=[]
  for side in [-1,1]:
   var leaf:=AnimatableBody3D.new();leaf.sync_to_physics=false;leaf.collision_layer=8;leaf.collision_mask=0
   leaf.position=Vector3(side*0.49,1.30,z);add_child(leaf)
   var shape:=CollisionShape3D.new();var panel:=BoxShape3D.new();panel.size=Vector3(0.98,2.6,0.14)
   shape.shape=panel;leaf.add_child(shape)
   art.box(leaf,Vector3.ZERO,panel.size,Art.ENAMEL)
   for face in [-1,1]:
    art.box(leaf,Vector3(-side*0.38,0,face*0.076),Vector3(0.035,2.14,0.013),Art.BRASS)
    art.box(leaf,Vector3(0,0.45,face*0.076),Vector3(0.59,0.09,0.016),Art.SEA_GLASS,false,true)
   art.batch_static(leaf);leaves.append(leaf)
  doors.append(leaves)

func cycle_lock(dt:float,walk_local:Vector3) -> void:
 var in_range:=absf(walk_local.x)<1.56 and absf(walk_local.y)<1.1
 for i in LOCKS.size():
  var near:=in_range and absf(walk_local.z-float(LOCKS[i]))<1.57
  var amount:=move_toward(openings[i],1.0 if near and openings[1-i]==0 else 0.0,dt*2.7)
  if amount==openings[i]:continue
  openings[i]=amount
  for j in 2:doors[i][j].position.x=(2*j-1)*(0.49+amount*1.06)
