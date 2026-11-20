# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
## Fixed furnishings share the hull batches. Moving parts are added afterwards.
const Art = preload("res://scripts/interior.gd")
const INK = Color("283d47")
const MINT = Color("86e4cf")
const CERAMIC = Color("e8d4ba")
var art: ShipInterior
var printer: Node3D
var toolhead: Node3D
var aquarium: Node3D
var fish: Array[Node3D] = []
var booth: Node3D
const EXIT_CENTER:=Vector2(0.56,1.14)
const EXIT_RADIUS:=0.73
const AMBER:=Color("efb868")
var exit_lift:AnimatableBody3D
var suspension:=Node3D.new()
var lift: AnimatableBody3D
var drape: ShaderMaterial
var time := 0.0
var scan := 0.0

func module(pos: Vector3, yaw: float) -> Node3D:
 var node := Node3D.new()
 node.position = pos
 node.rotation.y = yaw
 add_child(node)
 return node

func ring(parent: Node3D, pos: Vector3, r: float, wire: float, color: Color, glow := false) -> void:
 var path: Array[Vector3] = []
 for i in 65:
  var angle := TAU*i/64
  path.append(pos + Vector3(cos(angle)*r,0,sin(angle)*r))
 art.tube(parent,path,wire,color,glow)

func oval(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 var sphere := SphereMesh.new()
 sphere.radius=0.5; sphere.height=1.0; sphere.radial_segments=16; sphere.rings=8
 mesh.mesh=sphere; mesh.scale=size; mesh.position=pos
 mesh.material_override=art.material(color); parent.add_child(mesh)
 return mesh

func build_fixed(builder: ShipInterior) -> void:
 art=builder
 berth()
 printer=module(Vector3(-2.85,0,1.48),0.45)
 art.box(printer,Vector3(0,0.43,0),Vector3(1.13,0.85,0.76),INK,true)
 art.box(printer,Vector3(0,0.86,0),Vector3(1.36,0.10,0.89),CERAMIC)
 art.cylinder(printer,Vector3(0,0.94,0),0.36,0.055,Art.TRIM)
 ring(printer,Vector3(0,0.975,0),0.30,0.012,MINT,true)
 for x in [-0.53,0.53]:
  art.box(printer,Vector3(x,1.25,-0.29),Vector3(0.095,0.72,0.16),CERAMIC)
  art.beam(printer,Vector3(x,1.58,-0.29),Vector3(x,1.58,0.29),0.032,Art.BRASS)
 for i in 5:
  art.box(printer,Vector3(-0.40+0.068*i,0.39,0.387),Vector3(0.027,0.22,0.02),Art.BRASS)
 var spool=art.cylinder(printer,Vector3(0.51,0.43,0.14),0.14,0.18,Color("b7774e"));spool.rotation.z=PI/2
 var chassis=art.box(printer,Vector3(-0.20,1.10,-0.32),Vector3(0.39,0.20,0.045),INK)
 for i in 3:
  art.box(chassis,Vector3(-0.04,0.05-0.044*i,0.03),Vector3(0.22-0.04*i,0.013,0.008),MINT,false,true)
 art.beam(printer,Vector3(-0.53,1.56,0.01),Vector3(0.53,1.56,0.01),0.034,Art.BRASS)
 var glass=art.box(printer,Vector3(0,0.77,0.411),Vector3(0.79,0.15,0.032),Art.TRIM)
 art.box(glass,Vector3(-0.12,0,0.023),Vector3(0.42,0.029,0.008),MINT,false,true)
 for x in [0.18,0.25,0.32]:
  art.box(glass,Vector3(x,0,0.024),Vector3(0.026,0.04,0.009),Art.BRASS)
 tank()
 booth=module(Art.BOOTH,-2.6)
 art.cylinder(booth,Vector3(0,0.037,0),0.82,0.074,INK)
 ring(booth,Vector3(0,0.078,0),0.70,0.012,MINT,true)
 ring(booth,Vector3(0,2.08,0),0.79,0.038,Art.BRASS)
 for x in [-0.37,0.37]:
  art.beam(booth,Vector3(x,0,-0.67),Vector3(x,2.08,-0.67),0.035,Art.TRIM)
 lower_deck()

func berth() -> void:
 var bay:=module(Vector3(0,0,5.67),PI)
 # The mattress sits inside a deep lined recess with a continuous outer fascia.
 art.box(bay,Vector3(0,1.05,-0.53),Vector3(3.75,2.08,0.14),INK,true)
 art.box(bay,Vector3(0,0.28,0),Vector3(3.74,0.55,1.03),Art.WOOD,true)
 art.box(bay,Vector3(0,1.96,0),Vector3(3.74,0.22,1.07),CERAMIC,true)
 for side in [-1,1]:
  art.box(bay,Vector3(side*1.25,1.23,0),Vector3(0.10,1.40,1.0),CERAMIC,true)
  art.box(bay,Vector3(side*1.82,1.18,0),Vector3(0.09,1.53,1.0),CERAMIC,true)
  for y in [0.65,1.07,1.50]:
   art.box(bay,Vector3(side*1.53,y,0.08),Vector3(0.47,0.045,0.80),Art.WOOD)
   art.box(bay,Vector3(side*1.53,y-0.024,0.37),Vector3(0.39,0.012,0.016),Color("ffce81"),false,true)
 # Continue the aft liner up to the overhead and out into the curved hull.
 # In local space +Z faces the room; both cheek panels follow its taper.
 for side in [-1,1]:
  var wing:=Node3D.new();bay.add_child(wing)
  wing.position=Vector3(side*1.86,0,0.46);wing.rotation.y=-side*0.63
  art.box(wing,Vector3(side*0.56,1.11,0),Vector3(1.15,2.20,0.14),CERAMIC,true)
  art.box(wing,Vector3(side*0.56,0.24,0.085),Vector3(1.15,0.44,0.05),Art.WOOD)
  art.box(wing,Vector3(side*0.56,1.60,0.082),Vector3(1.06,0.024,0.02),Art.BRASS)
  art.box(bay,Vector3(side*0.85,0.27,0.525),Vector3(1.61,0.41,0.036),Color("895e42"))
  art.box(bay,Vector3(side*0.85,0.42,0.552),Vector3(0.57,0.024,0.024),Art.BRASS)
 # A single fitted lintel meets the rising roof over the central recess.
 var fascia: Array[Vector3]=[Vector3(-1.87,2.02,0.48),Vector3(1.87,2.02,0.48)]
 for i in 25:
  var x:float=1.87-3.74*i/24
  fascia.append(Vector3(x,2.52-0.069*x*x,0.48))
 art.panel(bay,fascia,CERAMIC)
 art.box(bay,Vector3(0,0.64,0.04),Vector3(2.36,0.20,0.92),CERAMIC)
 var quilt_color:=Color("527d79")
 # One continuous quilt drapes over the front of the berth. Quilted channels
 # and a rolled hem give a soft silhouette at handheld resolutions.
 var quilt:=SurfaceTool.new();quilt.begin(Mesh.PRIMITIVE_TRIANGLES)
 var profile: Array[Vector2]=[Vector2(-0.38,0.756),Vector2(-0.14,0.78),Vector2(0.18,0.79),Vector2(0.43,0.77),Vector2(0.50,0.746),Vector2(0.52,0.70),Vector2(0.52,0.62)]
 for col in 56:
  for row in profile.size()-1:
   for uv in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
    var u:float=(col+uv.x)/56.0;var v:Vector2=profile[row+uv.y]
    var fold:=0.027*sin(PI*7*u)*sin(PI*7*u)
    quilt.set_smooth_group(0)
    quilt.add_vertex(Vector3(-1.17+1.72*u,v.y+fold,v.x+fold*0.16))
 quilt.generate_normals()
 var cover:=MeshInstance3D.new();cover.mesh=quilt.commit()
 cover.material_override=art.material(quilt_color).duplicate();cover.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;bay.add_child(cover)
 for x in [-1.09,-1.035]:
  var trim:Array[Vector3]=[]
  for v in profile:trim.append(Vector3(x,v.y+0.025,v.x+0.004))
  art.tube(bay,trim,0.008,Art.BRASS)
 var pillow=oval(bay,Vector3(0.83,0.82,0.025),Vector3(0.65,0.22,0.78),Color("eed5ae"))
 pillow.rotation.z=-0.12
 art.beam(bay,Vector3(1.13,1.33,-0.35),Vector3(1.04,1.48,-0.18),0.026,Art.BRASS)
 oval(bay,Vector3(1.04,1.47,-0.16),Vector3(0.17,0.11,0.15),CERAMIC)
 art.strip_lamp(bay,Vector3(0,1.82,-0.22),1.96)
 for y in [1.06,1.26,1.46]:
  art.box(bay,Vector3(0,y,-0.415),Vector3(2.24,0.17,0.075),Color("698773"))

func tank() -> void:
 aquarium=module(Vector3(4.15,0,1.82),-1.89)
 var width:=2.75
 art.box(aquarium,Vector3(0,0.33,0),Vector3(width,0.66,0.76),Art.TRIM,true)
 art.box(aquarium,Vector3(0,1.20,-0.32),Vector3(width,1.14,0.09),Color("17545c"))
 art.box(aquarium,Vector3(0,1.79,0),Vector3(width,0.11,0.77),CERAMIC)
 art.box(aquarium,Vector3(0,0.70,0),Vector3(width,0.10,0.76),Art.BRASS)
 for side in [-1,1]:
  art.box(aquarium,Vector3(side*1.34,1.23,0),Vector3(0.07,1.07,0.73),Art.TRIM)
 art.box(aquarium,Vector3(0,1.72,0),Vector3(2.52,0.027,0.48),MINT,false,true)
 art.box(aquarium,Vector3(0,0.78,0),Vector3(2.59,0.09,0.65),Color("ba9e70"))
 for i in 16:
  var x:float=-1.17+0.153*i
  var h:float=0.18+0.22*(0.5+0.5*cos(i*1.81))
  var base:=Vector3(x,0.80,-0.16+0.05*sin(i))
  oval(aquarium,base,Vector3(0.16,0.12,0.14),Color("76867c"))
  art.tube(aquarium,[base,base+Vector3(-0.04,h*0.45,0.02),base+Vector3(0.055,h,0)],0.021,Color("5ab89b"))
 for i in 7:
  var x:float=-1.11+i*0.39
  var rock=oval(aquarium,Vector3(x,0.83+0.025*cos(i),0.12*sin(i)),Vector3(0.23+0.07*sin(i),0.20,0.24),Color("727d80"))
  rock.rotation.z=i*0.43
 for i in 9:
  var x:float=0.78+0.09*(i%3)-1.62*(i/6)
  var y:float=0.91+0.075*(i%4)
  var leaf=oval(aquarium,Vector3(x+0.10*sin(i),y,-0.08),Vector3(0.060,0.30+0.06*(i%3),0.038),Color("7eac74"))
  leaf.rotation.z=0.62*cos(i*2.1)
 var pane=art.box(aquarium,Vector3(0,1.24,0.35),Vector3(2.62,1.04,0.018),MINT)
 var glass:=StandardMaterial3D.new()
 glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 glass.albedo_color=Color(0.23,0.77,0.83,0.13);glass.roughness=0.13
 pane.material_override=glass
 # Include the front glazing in solid collision without an opaque front panel.
 var block:=CollisionShape3D.new()
 var bounds:=BoxShape3D.new();bounds.size=Vector3(width,1.78,0.77)
 var body:=StaticBody3D.new();aquarium.add_child(body);body.add_child(block)
 block.shape=bounds;block.position.y=0.89

func lower_deck() -> void:
 var room:=module(Vector3(-0.52,Art.LOWER_Y,2.22),0)
 var radius:=2.53
 # Cut the second shaft through the service floor. The original lift still
 # comes to rest on the opposite side of this room.
 var opening:=Vector3(EXIT_CENTER.x-room.position.x,0,EXIT_CENTER.y-room.position.z)
 var floor_surface:=SurfaceTool.new();floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 64:
  var a:=TAU*i/64;var b:=TAU*(i+1)/64
  var edge_a:=Vector3(cos(a),0,sin(a))*radius;var edge_b:=Vector3(cos(b),0,sin(b))*radius
  var lip_a:=opening+(edge_a-opening).normalized()*EXIT_RADIUS
  var lip_b:=opening+(edge_b-opening).normalized()*EXIT_RADIUS
  for point in [lip_a,edge_b,lip_b,lip_a,edge_a,edge_b]:
   floor_surface.set_normal(Vector3.UP);floor_surface.add_vertex(point)
  for point in [lip_b,edge_b,lip_a,edge_b,edge_a,lip_a]:
   floor_surface.set_normal(Vector3.DOWN);floor_surface.add_vertex(point+Vector3.DOWN*0.14)
  for point in [lip_a,lip_b,lip_b+Vector3.DOWN*0.14,lip_a,lip_b+Vector3.DOWN*0.14,lip_a+Vector3.DOWN*0.14]:
   floor_surface.set_normal((opening-Vector3(point.x,0,point.z)).normalized());floor_surface.add_vertex(point)
 var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=floor_surface.commit()
 floor_mesh.material_override=art.material(Color("525e61"));room.add_child(floor_mesh);floor_mesh.create_trimesh_collision()
 ring(room,opening+Vector3.UP*0.014,EXIT_RADIUS+0.026,0.024,Art.BRASS)
 var signpost:=module(Vector3(EXIT_CENTER.x+0.48,Art.LOWER_Y,EXIT_CENTER.y-0.65),-0.58)
 art.box(signpost,Vector3(0,0.69,0),Vector3(0.075,1.38,0.075),Art.TRIM,true)
 art.box(signpost,Vector3(0,1.35,0),Vector3(0.67,0.24,0.075),INK)
 art.label(signpost,"DOCK LIFT",Vector3(0,1.35,0.043),0,25,AMBER)
 for i in 40:
  var a:=TAU*(i+0.5)/40
  var radial:=Vector3(sin(a),0,cos(a))
  var panel=art.box(room,radial*radius+Vector3.UP*1.27,Vector3(0.42,2.54,0.11),Color("52666a") if i%5 else INK,true)
  panel.rotation.y=a
 for i in 8:
  var angle:=TAU*i/8
  var radial:=Vector3(sin(angle),0,cos(angle))
  var rib=art.box(room,radial*(radius-0.10)+Vector3.UP*1.27,Vector3(0.11,2.44,0.12),INK)
  rib.rotation.y=angle
  var light_bar=art.box(room,radial*(radius-0.18)+Vector3.UP*1.73,Vector3(0.036,0.32,0.022),Color("e2b57d"),false,true)
  light_bar.rotation.y=angle

 for y in [0.14,1.96,2.46]:
  ring(room,Vector3.UP*y,radius-0.09,0.022,MINT if y==1.96 else Art.BRASS,y==1.96)
 var light:=OmniLight3D.new();room.add_child(light)
 light.position.y=1.92;light.light_color=Color("b6dcda");light.light_energy=0.9;light.omni_range=4
 ring(self,Vector3(Art.LIFT.x,0.015,Art.LIFT.y),Art.SHAFT_RADIUS+0.035,0.029,Art.BRASS)

func set_exit_height(height:float) -> void:
 exit_lift.position.y=height
 suspension.scale.y=maxf(0.005,Art.LOWER_Y-height)

func build_moving(dock:Node3D) -> void:
 lift=AnimatableBody3D.new();lift.sync_to_physics=false;add_child(lift)
 lift.position=Vector3(Art.LIFT.x,0,Art.LIFT.y)
 art.cylinder(lift,Vector3.DOWN*0.077,0.836,0.15,INK)
 for i in 9:
  var z:float=(i-4)*0.114
  art.box(lift,Vector3(0,0.006,z),Vector3(0.79-absf(z)*0.58,0.009,0.024),Art.TRIM)
 for x in [-0.48,0.48]:
  art.box(lift,Vector3(x,0.008,0),Vector3(0.035,0.012,0.46),Art.BRASS)
 ring(lift,Vector3.UP*0.004,0.74,0.012,MINT,true)
 var collision:=CollisionShape3D.new();var disk:=CylinderShape3D.new()
 disk.radius=0.838;disk.height=0.15;collision.shape=disk;collision.position.y=-0.075;lift.add_child(collision)
 exit_lift=AnimatableBody3D.new();exit_lift.sync_to_physics=false;exit_lift.collision_layer=1|preload("res://scripts/ship_exterior.gd").HULL_COLLISION
 exit_lift.position=Vector3(EXIT_CENTER.x,Art.LOWER_Y,EXIT_CENTER.y);dock.add_child(exit_lift)
 art.cylinder(exit_lift,Vector3.DOWN*0.069,EXIT_RADIUS-0.009,0.14,INK)
 ring(exit_lift,Vector3.UP*0.006,0.61,0.018,AMBER,true)
 for z in [-0.21,0.08]:
  art.tube(exit_lift,[Vector3(-0.21,0.012,z+0.095),Vector3(0,0.012,z-0.04),Vector3(0.21,0.012,z+0.095)],0.021,AMBER,true)
 for side in [-1,1]:
  var post=art.box(exit_lift,Vector3(side*0.56,0.41,0.20),Vector3(0.06,0.82,0.07),INK)
  art.box(post,Vector3(0,0.38,0),Vector3(0.077,0.055,0.085),AMBER,false,true)
  art.beam(exit_lift,Vector3(side*0.56,0.78,0.2),Vector3(side*0.56,0.78,-0.20),0.030,Art.BRASS)
 suspension.position=exit_lift.position;dock.add_child(suspension)
 for side in [-1,1]:
  art.cylinder(suspension,Vector3(side*0.56,-0.5,0.20),0.042,1.0,Art.BRASS)
  art.cylinder(suspension,Vector3(side*0.56,-0.18,0.20),0.060,0.36,INK)
 set_exit_height(Art.LOWER_Y)
 var lamp:=OmniLight3D.new();exit_lift.add_child(lamp);lamp.position.y=1.7
 lamp.light_color=AMBER;lamp.light_energy=0.65;lamp.omni_range=3.4
 var pad:=CylinderShape3D.new();pad.radius=EXIT_RADIUS-0.009;pad.height=0.14
 var shape:=CollisionShape3D.new();shape.shape=pad;shape.position.y=-0.07;exit_lift.add_child(shape)
 toolhead=Node3D.new();printer.add_child(toolhead)
 art.box(toolhead,Vector3(0,1.49,0.01),Vector3(0.20,0.15,0.17),Art.TRIM)
 art.cylinder(toolhead,Vector3(0,1.36,0.01),0.022,0.12,Art.BRASS,0.065)
 var probe=art.cylinder(toolhead,Vector3(0,1.13,0.01),0.006,0.30,MINT)
 probe.name="ScanBeam";probe.material_override=art.material(MINT,true);probe.hide()
 for i in 6:
  var swimmer:=Node3D.new();aquarium.add_child(swimmer);fish.append(swimmer)
  var color:Color=[Color("f3b763"),Color("f48878"),Color("bbded9")][i%3]
  oval(swimmer,Vector3.ZERO,Vector3(0.23,0.11,0.065),color)
  var tail=art.panel(swimmer,[Vector3(-0.08,0,0),Vector3(-0.19,0.076,0),Vector3(-0.17,-0.068,0)],color)
  tail.material_override=art.material(color).duplicate();tail.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
  oval(swimmer,Vector3(-0.018,0.052,0),Vector3(0.085,0.05,0.018),color)
  for side in [-1,1]:
   oval(swimmer,Vector3(0.070,0.018,0.027*side),Vector3.ONE*0.027,INK)
 drape=ShaderMaterial.new();drape.shader=preload("res://shaders/drape.gdshader")
 for side in [-1,1]:
  var surface:=PlaneMesh.new();surface.size=Vector2.ONE;surface.subdivide_width=63;surface.subdivide_depth=1
  var curtain:=MeshInstance3D.new();curtain.mesh=surface;curtain.material_override=drape
  curtain.custom_aabb=AABB(Vector3(-0.86,0,-0.86),Vector3(1.72,2.15,1.72))
  curtain.scale.x=side;booth.add_child(curtain)

func animate(delta: float) -> void:
 time+=delta
 for i in fish.size():
  var phase:float=time*(0.38+0.025*i)+i*1.07
  fish[i].position=Vector3(sin(phase)*(0.73+0.06*(i%4)),1.09+0.09*(i%4)+0.034*sin(phase*2+i),0.05+0.092*cos(phase))
  fish[i].rotation.y=atan2(0.092*sin(phase),(0.73+0.06*(i%4))*cos(phase))
 toolhead.get_node("ScanBeam").visible=scan>0
 if scan>0:
  scan=maxf(0,scan-delta)
  toolhead.position.x=0.38*sin((2.4-scan)*TAU/2.4)
