# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

const SITES = {3:0, 5:1, 10:0, 11:1, 14:0}
const ORES = ["bauxite", "magnetite"]
const METALS = ["Aluminium", "Steel"]
const SHORES = ["Table Isle, Meridian Rift or Ember Isle", "Cinder Garden or Kiln Caldera"]
const FACE = [Vector2(-1.23,0.06), Vector2(-1.33,0.52), Vector2(-0.90,0.93),
 Vector2(-0.34,1.09), Vector2(0.31,1.01), Vector2(0.86,0.89),
 Vector2(1.28,0.46), Vector2(1.08,0.05)]
const SEAM = [Vector2(-1.09,0.30),Vector2(-0.73,0.46),Vector2(-0.46,0.43),
 Vector2(-0.12,0.64),Vector2(0.21,0.57),Vector2(0.61,0.67),Vector2(1.03,0.48)]
const CUTS = [1, 4, 5]
const TOLERANCE = 0.13
const OFFSET = Vector3(3.5,-5.35,12.0)

var home:Node
var index := -1
var active := false
var cut := 0
var phase := 0.0
var mining_day := 0
var next_day_check := 0
var obstacle := StaticBody3D.new()
var stone_material := ShaderMaterial.new()
var geology := Node3D.new()
var deposits:Array[Node3D] = []
var cursor := Node3D.new()
var target := MeshInstance3D.new()
var view := Camera3D.new()
var help := Label.new()

func configure(ship:Node, layer:CanvasLayer) -> void:
 home=ship
 var noise:=FastNoiseLite.new();noise.seed=193;noise.frequency=0.075
 var grain:=NoiseTexture2D.new();grain.width=128;grain.height=128;grain.seamless=true;grain.noise=noise
 stone_material.shader=preload("res://scripts/outcrop_surface.gdshader")
 stone_material.set_shader_parameter("grain",grain)
 var hull:=ConvexPolygonShape3D.new()
 var corners:=PackedVector3Array()
 for point:Vector2 in FACE:
  corners.append(Vector3(point.x,point.y,0.31))
  corners.append(Vector3(point.x*0.84,point.y*1.10,-0.34))
 hull.points=corners
 var collision:=CollisionShape3D.new();collision.shape=hull
 obstacle.collision_mask=0;obstacle.collision_layer=0;obstacle.add_child(collision);add_child(obstacle)
 add_child(geology);add_child(cursor);add_child(target);add_child(view)
 for side in [-1,1]:
  home.art.beam(cursor,Vector3(0,side*0.047,0),Vector3(0,side*0.13,0),0.009,Color("#bafaff"),true)
 var circle:=TorusMesh.new()
 circle.inner_radius=0.114;circle.outer_radius=TOLERANCE;circle.rings=32;circle.ring_segments=6
 target.mesh=circle;target.rotation.x=PI/2
 target.material_override=home.art.material(Color("#ffe3a1"),true)
 view.near=0.04;view.fov=42
 help.add_theme_stylebox_override("normal",home.prompts.skin(Color("#12282ff2"),9,14,9))
 help.add_theme_font_size_override("font_size",21)
 help.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(help)
 help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 help.grow_vertical=Control.GROW_DIRECTION_BEGIN;help.position.x=24;help.offset_bottom=-22
 cursor.hide();target.hide();help.hide();hide()

# The planar front face is also the cutting surface. The trailing facets sink into the bank.
func rock(parent:Node3D, at:Vector3, dimensions:Vector3, tint:Color) -> void:
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var front:=Vector3(-0.24,0.53,0.31)
 var back:=Vector3(0.07,0.42,-0.79)
 for i in FACE.size():
  var a:Vector2=FACE[i];var b:Vector2=FACE[(i+1)%FACE.size()]
  var p:=Vector3(a.x,a.y,0.31);var q:=Vector3(b.x,b.y,0.31)
  var r:=Vector3(a.x*0.84,a.y*1.10,-0.34+0.08*sin(i))
  var s:=Vector3(b.x*0.84,b.y*1.10,-0.34+0.08*sin((i+1)%FACE.size()))
  var triangles=[[p,q,front],[p,r,s],[p,s,q],[r,back,s]]
  for j in triangles.size():
   var points:Array=triangles[j]
   var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
   for v:Vector3 in points:
    surface.set_color(tint.lightened(0.08+0.08*sin(i*7+j*2)))
    surface.set_normal(normal);surface.add_vertex(v)
 var part:=MeshInstance3D.new()
 part.mesh=surface.commit()
 part.material_override=stone_material;part.position=at;part.scale=dimensions;parent.add_child(part)

func set_site(site:int) -> void:
 close()
 var next:int=SITES.get(site,-1)
 visible=next>=0
 obstacle.collision_layer=home.flight.WALK_LAYER if visible else 0
 if not visible:return
 global_transform=home.flight.global_transform*Transform3D(Basis(Vector3.UP,2.8),home.flight.BERTHS[site]+OFFSET)
 if index!=next:
  index=next
  for child in geology.get_children():child.free()
  deposits.clear()
  var tint:Color=[Color("#944e38"),Color("#3f5061")][index]
  var trace:Color=[Color("#f3bc85"),Color("#adc2db")][index]
  rock(geology,Vector3.ZERO,Vector3.ONE,tint)
  for i in 6:
   var angle:=i*2.4
   rock(geology,Vector3(1.38*cos(angle),0.01,-0.12+0.50*sin(angle)),Vector3(0.22+0.08*cos(i),0.32+0.14*sin(i),0.4),tint.darkened(0.18))
  for i in range(1,SEAM.size()):
   var start:=face_point(SEAM[i-1])
   var end:=face_point(SEAM[i])
   home.art.beam(geology,start,end,0.014+0.004*sin(i),trace)
   var split:=start.lerp(end,0.32+0.1*sin(i))
   var fork:=split+Vector3(-0.09,0.095*cos(i*PI),-0.008)
   home.art.beam(geology,split,fork,0.008,trace.darkened(0.28))
   home.art.beam(geology,fork,fork+Vector3(-0.085,0.025,-0.002),0.004,trace.darkened(0.32))
  for k:int in CUTS:
   var deposit:=Node3D.new();geology.add_child(deposit);deposits.append(deposit)
   for n in 3:
    var fleck:=MeshInstance3D.new();var shard:=PrismMesh.new()
    shard.size=Vector3(0.075+0.03*cos(n),0.12+0.06*sin(n),0.07);fleck.mesh=shard
    fleck.material_override=home.art.material(trace.lightened(n*0.08))
    fleck.position=face_point(SEAM[k])+Vector3((n-1)*0.048,0.04*sin(n),0.018)
    fleck.rotation.z=0.47*(n-1);deposit.add_child(fleck)
 sync_deposit()

func face_point(point:Vector2) -> Vector3:
 return Vector3(point.x,point.y,0.335)

func depleted(day:int) -> bool:
 var batch:Dictionary=home.store.ore.get(ORES[index],{})
 return int(batch.get("last",-1))==day or batch.get("days",[]).any(func(value):return int(value)==day)

func sync_deposit() -> void:
 mining_day=home.garden.today()
 var show_ore:=not depleted(mining_day)
 for node in deposits:node.visible=show_ore

func open() -> void:
 if not visible:return
 sync_deposit()
 if depleted(mining_day):
  home.notify("Vein exhausted · survey again tomorrow (UTC)");return
 active=true;cut=0;phase=0
 home.walker.stationary=true;home.walker.hide()
 home.Exterior.configure_camera(view,false)
 view.position=Vector3(0,1.27,2.65)
 view.look_at(to_global(Vector3(0,0.52,0.3)));view.make_current()
 cursor.show();target.show();help.show()
 aim();hint("Pulse when the cutter crosses the ring")

func hint(message:String) -> void:
 var controls:="A  Pulse     B  Leave" if home.prompts.gamepad else "F  Pulse     Esc  Leave"
 help.text="%s   ·   %d / %d\n%s\n%s"%[ORES[index].capitalize(),cut,CUTS.size(),message,controls]
 help.reset_size();help.position=Vector2(24,help.get_viewport_rect().size.y-help.size.y-22)

func aim() -> void:
 var x:=lerpf(SEAM[0].x,SEAM[-1].x,pingpong(phase,1.0))
 for i in range(1,SEAM.size()):
  if x<=SEAM[i].x:
   var t:=inverse_lerp(SEAM[i-1].x,SEAM[i].x,x)
   cursor.position=face_point(SEAM[i-1].lerp(SEAM[i],t))+Vector3.BACK*0.09
   break
 target.position=face_point(SEAM[CUTS[cut]])+Vector3.BACK*0.08

func tick(delta:float) -> void:
 if not visible:return
 if not active:
  if Time.get_ticks_msec()>=next_day_check:
   next_day_check=Time.get_ticks_msec()+1000
   if mining_day!=home.garden.today():sync_deposit()
  return
 phase+=delta*(0.45+0.045*cut)
 aim()

func control(event:InputEvent) -> void:
 if event.is_action_pressed("cancel_ship"):close();return
 if not event.is_action_pressed("interact"):return
 if Vector2(cursor.position.x,cursor.position.y).distance_to(SEAM[CUTS[cut]])>TOLERANCE:
  hint("Missed the seam · wait for the next sweep");return
 if cut==CUTS.size()-1:
  var problem:String=home.store.record_harvest(home.rows,ORES[index],mining_day)
  if problem!="":hint(problem);return
  close();home.notify(ORES[index].capitalize()+" recovered · refine at the refinery");return
 deposits[cut].hide();cut+=1;aim();hint("Fracture opened · follow the next ring")

func close() -> void:
 if not active:return
 active=false;cursor.hide();target.hide();help.hide()
 home.walker.show();home.walker.stationary=false;home.walker.camera.make_current()
 sync_deposit()
