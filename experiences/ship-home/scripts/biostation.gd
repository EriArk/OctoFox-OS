# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Survey hall beyond the landing circle. The clear central aisle connects to the boarding lift.
const Art=preload("res://scripts/interior.gd")
const SITE:=6
const BIOLOGIST:=Vector3(0.60,0,15.35)
const SCOPE:=Vector3(-1.44,1.18,24.1)
const FRAME=Color("375461")
const LIGHT=Color("9ce4cd")
var studio:Node3D
var keeper:Node3D
var swimmers:Array[Node3D]=[]
var phase:=0.0

func build(flight) -> void:
 var art:ShipInterior=flight.art
 # Stepped pressure hull beneath the berth and the two observation drums.
 art.cylinder(self,Vector3(0,-1.52,14.7),4.85,2.6,Art.TRIM,6.7)
 art.cylinder(self,Vector3(0,-2.91,14.7),4.38,0.24,Art.COPPER)
 var deck=art.box(self,Vector3(0,-0.24,14.6),Vector3(12.8,0.48,16.4),FRAME)
 flight.walk_surface(deck)
 flight.solid(flight.to_local(global_position)+deck.position-Vector3.UP*1.5,Vector3(12.8,3,16.4))
 for side in [-1,1]:
  var x:float=side*5.80
  var p:=Vector3(x,0.45,15.1)
  flight.walk_surface(art.cylinder(self,p,2.55,1.0,Art.ENAMEL))
  flight.solid(flight.to_local(global_position)+p+Vector3.UP,Vector3(4.9,4.3,4.9))
  for y in [0.98,2.95]:art.cylinder(self,Vector3(x,y,15.1),2.49,0.12,Art.BRASS)
  var glass:=StandardMaterial3D.new()
  glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(0.27,0.72,0.79,0.17)
  glass.roughness=0.20;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
  var shell:=CylinderMesh.new();shell.bottom_radius=2.42;shell.top_radius=2.42;shell.height=1.92;shell.radial_segments=28;shell.cap_bottom=false;shell.cap_top=false;shell.material=glass
  var pane:=MeshInstance3D.new();pane.mesh=shell;pane.position=Vector3(x,1.97,15.1);add_child(pane)
  var cap:=SphereMesh.new();cap.radius=2.41;cap.height=4.82;cap.is_hemisphere=true;cap.material=glass
  var dome:=MeshInstance3D.new();dome.mesh=cap;dome.position=Vector3(x,2.99,15.1);dome.scale.y=0.55;add_child(dome)
  for j in 10:
   var radial:=Vector3(sin(j*TAU/10),0,cos(j*TAU/10))
   var rim:=Vector3(x,2.98,15.1)+radial*2.44
   art.beam(self,rim-Vector3.UP*2,rim,0.063,FRAME)
   var arc:Array[Vector3]=[]
   for n in 9:
    var t:=PI*n/16
    arc.append(Vector3(x,2.99+1.35*sin(t),15.1)+radial*2.44*cos(t))
   art.tube(self,arc,0.055,Art.BRASS)
  art.cylinder(self,Vector3(x,4.35,15.1),0.37,0.12,LIGHT)
  for z in [8,19,22]:
   art.box(self,Vector3(side*6.16,0.52,z),Vector3(0.09,1.04,0.09),Art.BRASS)
  flight.walk_surface(art.box(self,Vector3(side*6.16,0.96,15),Vector3(0.10,0.13,14.1),Art.BRASS))
  art.box(self,Vector3(side*1.58,0.014,10.45),Vector3(0.055,0.025,6),LIGHT,false,true)
 # Hydroponic sample beds in the port dome. The starboard dome houses the live collection.
 for i in 12:
  var t:=i*2.39996
  var base:=Vector3(-5.80+1.62*cos(t),0.97,15.1+1.62*sin(t))
  var tip:=base+Vector3(0.17*cos(t),0.62+0.57*absf(sin(t)),0.22*sin(t))
  art.beam(self,base,tip,0.039,Color("538776"))
  for j in 3:
   var leaf:=art.cylinder(self,base.lerp(tip,0.45+j*0.18),0.20,0.40,Color("a3ce89"),0.03)
   leaf.rotation.z=0.92 if (i+j)%2 else -0.92
  art.cylinder(self,tip,0.15,0.14,Color("eab477"),0.07)
 flight.walk_surface(art.box(self,Vector3(0,0.58,17.1),Vector3(3.28,1.16,0.78),Art.ENAMEL))
 art.box(self,Vector3(0,1.17,17.1),Vector3(3.48,0.10,0.94),Art.WALNUT)
 art.label(self,"FIELD COLLECTION",Vector3(0,0.72,16.69),PI,40,Art.PAPER)
 # Bench instruments for measuring and logging the live collection.
 var screen:=Node3D.new();add_child(screen);screen.position=Vector3(0.97,1.70,17.11);screen.rotation.y=PI-0.14
 art.box(screen,Vector3(0,-0.36,-0.01),Vector3(0.14,0.39,0.17),FRAME)
 art.veneer_case(screen,Vector3.ZERO,Vector2(0.92,0.59),0.09,0.065)
 art.faceplate(screen,Vector3.BACK*0.008,Vector2(0.81,0.46),0.036,Art.NIGHT)
 art.label(screen,"LIVE COLLECTION",Vector3(0,0.155,0.023),0,15,LIGHT)
 for i in 5:
  var x:float=-0.29+0.14*i
  art.beam(screen,Vector3(x,-0.095,0.021),Vector3(x,0.025+0.043*cos(i*1.8),0.021),0.014,LIGHT,true)
 art.box(self,Vector3(-0.56,1.27,17.09),Vector3(1.19,0.11,0.38),Art.PAPER)
 for i in 12:
  var x:float=-1.09+i*0.092
  art.box(self,Vector3(x,1.33,16.98),Vector3(0.014,0.014,0.094 if i%3==0 else 0.05),FRAME)
 for i in 3:
  var jar:=Vector3(-1.30+i*0.18,1.36,17.26)
  art.cylinder(self,jar,0.060,0.29,Color("8cc5b8"));art.cylinder(self,jar+Vector3.UP*0.15,0.065,0.025,Art.BRASS)
 prepare_lab(flight)
 var body:=StaticBody3D.new();body.position=BIOLOGIST;body.collision_layer=flight.WALK_LAYER;add_child(body)
 var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.27;capsule.height=1.52
 shape.shape=capsule;shape.position.y=0.76;body.add_child(shape)

func prepare_lab(flight) -> void:
 var art:ShipInterior=flight.art
 # Continuous counter with a microscope, reference slides and a compact centrifuge.
 flight.walk_surface(art.box(self,Vector3(0,0.55,24.23),Vector3(5.35,1.10,1.22),Art.ENAMEL))
 art.box(self,Vector3(0,1.13,24.23),Vector3(5.49,0.10,1.35),Art.PAPER)
 art.box(self,SCOPE+Vector3.UP*0.035,Vector3(0.61,0.07,0.44),FRAME)
 art.beam(self,SCOPE+Vector3(0.21,0.07,0.13),SCOPE+Vector3(0.21,0.62,0.13),0.065,Art.BRASS)
 art.beam(self,SCOPE+Vector3(0.21,0.62,0.13),SCOPE+Vector3(-0.10,0.60,0.02),0.07,Art.BRASS)
 art.box(self,SCOPE+Vector3(0,0.28,0),Vector3(0.41,0.055,0.30),FRAME)
 art.box(self,SCOPE+Vector3(-0.045,0.316,0),Vector3(0.145,0.012,0.062),Art.SEA_GLASS,false,true)
 art.beam(self,SCOPE+Vector3(-0.08,0.40,0.02),SCOPE+Vector3(-0.08,0.70,0.02),0.071,Art.TRIM)
 # Focusing wheel, revolving objectives and substage light condenser.
 art.beam(self,SCOPE+Vector3(0.09,0.37,0.13),SCOPE+Vector3(0.32,0.37,0.13),0.10,Art.TRIM)
 art.beam(self,SCOPE+Vector3(0.31,0.37,0.13),SCOPE+Vector3(0.35,0.37,0.13),0.058,Art.COPPER)
 art.cylinder(self,SCOPE+Vector3(-0.08,0.48,0.02),0.115,0.09,Art.PAPER)
 for j in 3:
  var nose:=SCOPE+Vector3(-0.08+0.06*cos(TAU*j/3),0.435,0.02+0.06*sin(TAU*j/3))
  art.beam(self,nose,nose+Vector3.DOWN*0.064,0.026,Art.BRASS)
 art.cylinder(self,SCOPE+Vector3(-0.057,0.145,0),0.075,0.055,LIGHT)
 for i in [-1,1]:
  var ocular:=SCOPE+Vector3(-0.08+i*0.045,0.82,-0.1)
  art.beam(self,SCOPE+Vector3(-0.08,0.67,0.02),ocular,0.041,Art.TRIM)
  art.cylinder(self,ocular,0.05,0.044,Art.NIGHT)
 for i in 4:
  var x:float=-0.57+0.16*i
  art.box(self,Vector3(x,1.22,24.09),Vector3(0.13,0.075,0.32),Art.BRASS)
  art.box(self,Vector3(x,1.263,24.08),Vector3(0.085,0.012,0.20),Art.SEA_GLASS)
 art.cylinder(self,Vector3(1.46,1.38,24.23),0.38,0.39,Art.TRIM,0.45)
 art.cylinder(self,Vector3(1.46,1.60,24.23),0.41,0.055,Art.BRASS)
 for j in 8:
  var at:=Vector3(1.46+0.28*cos(TAU*j/8),1.67,24.23+0.28*sin(TAU*j/8))
  art.cylinder(self,at,0.052,0.14,Color("80bcae"))
  art.cylinder(self,at+Vector3.UP*0.074,0.054,0.025,Art.PAPER)
 art.label(self,"MICROSCOPY",Vector3(-1.4,0.88,23.608),PI,24,Art.PAPER)
 art.label(self,"SEPARATION",Vector3(1.45,0.88,23.608),PI,24,Art.PAPER)
 # Wall-mounted archive of sealed vials, sorted by sampling depth.
 for row in 2:
  var y:float=1.44+row*0.60
  art.box(self,Vector3(-1.35,y,26.05),Vector3(3.8,0.08,0.46),Art.WALNUT)
  for i in 8:
   var at:=Vector3(-2.90+0.43*i,y+0.20,26.02)
   art.cylinder(self,at,0.098,0.31,[Color("739c94"),Color("ba9879"),Color("998caa")][i%3])
   art.cylinder(self,at+Vector3.UP*0.17,0.108,0.042,Art.BRASS)
   art.box(self,at+Vector3.FORWARD*0.097,Vector3(0.078,0.089,0.012),Art.PAPER)
 art.label(self,"REFERENCE SLIDES   /   ECHO ORCHARD",Vector3(-1.32,2.76,26.27),PI,37,FRAME)
 # The sample bay shares its water circuit with the adjacent live collection.
 for i in 3:
  var x:float=1.29+i*0.65
  art.cylinder(self,Vector3(x,1.38,25.90),0.22,1.80,Color("63958e"))
  for y in [0.51,2.24]:art.cylinder(self,Vector3(x,y,25.90),0.245,0.12,Art.BRASS)
  art.beam(self,Vector3(x,2.30,25.9),Vector3(x,2.67,25.9),0.072,Art.COPPER)
 art.beam(self,Vector3(1.29,2.66,25.90),Vector3(3.71,2.66,25.90),0.09,Art.COPPER)
 art.label(self,"WATER LOOP",Vector3(2.08,3.0,26.27),PI,31,FRAME)

func _staff() -> void:
 keeper=Node3D.new();keeper.position=BIOLOGIST;keeper.rotation.y=PI;add_child(keeper)
 preload("res://scripts/port_resident.gd").dress(keeper,"Casual_Female",Color("89bbb0"))
 for i in 5:
  var fish:Node3D=studio.make_fish(self,{"id":"%04x1000-1000-4100-8110-000000000000"%(i*1021),"species":"glassfin" if i%2==0 else "loach"})
  fish.scale*=2.5;swimmers.append(fish)

func staff_visible(on:bool) -> void:
 if keeper==null:
  if not on:set_process(false);return
  _staff()
 keeper.visible=on;keeper.process_mode=Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
 for fish in swimmers:fish.visible=on
 set_process(on)

func _process(dt:float) -> void:
 phase=fmod(phase+dt*0.46,TAU*2)
 for i in swimmers.size():
  var t:=phase+i*1.78
  swimmers[i].position=Vector3(5.80+1.43*cos(t),1.74+0.38*sin(2*t+i),15.1+1.30*sin(t))
  swimmers[i].rotation.y=atan2(-1.30*cos(t),-1.43*sin(t))
