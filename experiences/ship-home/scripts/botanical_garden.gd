# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D

const PLANTS = ["sunbell","tideflower","starbloom"]
const NAMES = ["Sunbell","Tideflower","Starbloom"]
const COLORS = ["saffron","sea-glass","aurora"]
const SWATCHES = [Color("#dfae43"),Color("#479b91"),Color("#7966c2")]
const SHORES = ["Echo Orchard","Table Isle","Cinder Garden"]
const SITES = [1,3,5]
const PATCH_OFFSET = Vector3(-3.1,-5.35,12.0)
const BLOOMS = 5

var home:Node
var plant:=-1
var active:=false
var selected:=0
var picked:Array[int]=[]
var ripe:Array[int]=[]
var day:=-1
var built_plant:=-1
var next_day_check:=0
var blossoms:Array[Node3D]=[]
var stems:=Node3D.new()
var ring:=MeshInstance3D.new()
var view:=Camera3D.new()
var help:=Label.new()
var message:=""
var sphere:=SphereMesh.new()

static func today() -> int:
 return floori(Time.get_unix_time_from_system()/86400.0)

static func valid_samples(value:Variant, catalogue:Array=PLANTS) -> bool:
 if not value is Dictionary:return false
 for key in value:
  if key not in catalogue or not value[key] is Dictionary:return false
  var entry:Dictionary=value[key]
  if not entry.get("days") is Array or not whole_day(entry.get("last")):return false
  var previous:=-1
  for d in entry.days:
   if not whole_day(d) or d<=previous:return false
   previous=int(d)
 return true

static func whole_day(value:Variant) -> bool:
 return (value is int or value is float) and value>=0 and value<=4000000 and value==int(value)

func configure(scene:Node,layer:CanvasLayer) -> void:
 home=scene;sphere.radius=0.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6
 add_child(stems);add_child(ring);add_child(view)
 var cursor:=TorusMesh.new();cursor.inner_radius=0.19;cursor.outer_radius=0.205;cursor.rings=36;cursor.ring_segments=6
 ring.mesh=cursor;ring.material_override=home.art.material(Color("#fff0b0"),true);ring.hide()
 view.near=0.045;view.fov=50
 help.add_theme_stylebox_override("normal",home.prompts.skin(Color("#142d33ef"),9,14,9))
 help.add_theme_font_size_override("font_size",21)
 help.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(help);help.hide()
 get_viewport().size_changed.connect(position_help)
 hide()

func set_site(site:int) -> void:
 close()
 plant=SITES.find(site)
 visible=plant>=0
 if not visible:return
 var flight=home.flight
 global_transform=flight.global_transform*Transform3D(Basis(Vector3.UP,2.32),flight.BERTHS[site]+PATCH_OFFSET)
 prepare_flowers()

func oval(parent:Node3D,at:Vector3,size_m:Vector3,tint:Color) -> MeshInstance3D:
 var part:=MeshInstance3D.new();part.mesh=sphere;part.position=at;part.scale=size_m
 part.material_override=home.art.material(tint);parent.add_child(part);return part

func rebuild(bloom_day:int) -> void:
 built_plant=plant
 for part in stems.get_children():part.free()
 blossoms.clear();picked.clear();ripe.clear();day=bloom_day
 var rng:=RandomNumberGenerator.new();rng.seed=day*7919+plant*131
 var first:=rng.randi_range(0,BLOOMS-1)
 ripe.append(first);ripe.append((first+rng.randi_range(1,BLOOMS-1))%BLOOMS)
 # A sheltered pocket of soil, low foliage and stones anchors the tall stalks.
 var bed:=Node3D.new();stems.add_child(bed)
 var moss:Color=[Color("#698252"),Color("#658a79"),Color("#78677c")][plant]
 oval(bed,Vector3(0,-0.07,0),Vector3(2.85,0.34,1.23),moss.darkened(0.29))
 for n in 17:
  var a:=n*2.40
  var base:=Vector3(1.18*cos(a),0.035,0.45*sin(a))
  var clump:=oval(bed,base,Vector3(0.28+0.075*cos(n),0.15+0.06*sin(n),0.21),moss.lightened(0.10*sin(a)))
  clump.rotation.y=a
  if n%3==1:oval(bed,base+Vector3(0.13,0.025,0.08),Vector3(0.16,0.11,0.13),Color("#899082"))
  for j in 3:
   var blade:=oval(bed,base+Vector3(j*0.036,0.09,0),Vector3(0.042,0.20+0.11*cos(n+j),0.025),moss.lightened(0.18))
   blade.rotation.z=0.47*cos(a+j);blade.rotation.x=0.29*sin(a)
 home.art.batch_static(bed)
 var leaf:=Color("#47735b")
 for i in BLOOMS:
  var stem:=Node3D.new();stems.add_child(stem)
  var x:=(i-2)*0.49
  var base:=Vector3(x+0.075*sin(i*3.1),0.045,0.24*cos(i*2.0))
  var top:=base+Vector3(0.07*sin(i*2.4),0.65+0.15*sin(1.7*i),0)
  home.art.beam(stem,base,top,0.019,leaf)
  for side in [-1,1]:
   var blade:=oval(stem,base.lerp(top,0.39+side*0.09)+Vector3.RIGHT*side*0.10,Vector3(0.13,0.36,0.065),leaf.lightened(0.12))
   blade.rotation.z=-side*(0.68+0.13*cos(i));blade.rotation.y=0.37*sin(i+side)
  var twig:=top.lerp(base,0.48)
  var tip:=twig+Vector3(0.17*cos(i*2),0.11,0.12)
  home.art.beam(stem,twig,tip,0.009,leaf)
  oval(stem,tip,Vector3(0.072,0.105,0.068),leaf.lightened(0.18))
  var sepal:=oval(stem,top,Vector3(0.13,0.12,0.11),leaf);sepal.rotation.z=0.22
  home.art.batch_static(stem)
  var head:=Node3D.new();stems.add_child(head);head.position=top+Vector3.UP*0.04
  blossoms.append(head)
  var open:=i in ripe
  var petals:int=[6,5,8][plant]
  var tint:Color=SWATCHES[plant].lightened(0.19)
  # Flower faces tilt toward the clearing, so petal shape reads from the picking camera.
  var face:=Node3D.new();head.add_child(face);face.rotation.x=0.70
  for j in petals:
   var angle:=TAU*j/petals
   var radial:=Vector3(cos(angle),0,sin(angle))
   var petal:=oval(face,radial*(0.105 if open else 0.039)+Vector3.UP*(0.025 if open else 0.07),
     Vector3(0.18 if open else 0.082,0.048 if open else 0.19,0.085 if plant!=1 else 0.14),tint if open else tint.darkened(0.25))
   petal.rotation.y=-angle
  if open:
   oval(face,Vector3.UP*0.06,Vector3(0.105,0.078,0.105),Color("#f8ca62"))
   for j in 3:
    var angle:=TAU*j/3
    oval(face,Vector3(0.035*cos(angle),0.097,0.035*sin(angle)),Vector3.ONE*0.036,Color("#fff1b7"))
  home.art.batch_static(head)
func prepare_flowers() -> void:
 var current_day:=today()
 if day!=current_day or built_plant!=plant:rebuild(current_day)
 picked.clear()
 var available:=not harvested()
 for i in ripe:blossoms[i].visible=available

func harvested() -> bool:
 var patch:Dictionary=home.store.botany.get(PLANTS[plant],{})
 return int(patch.get("last",-1))==day or patch.get("days",[]).any(func(sample):return int(sample)==day)

func tick() -> void:
 if visible and not active and Time.get_ticks_msec()>=next_day_check:
  next_day_check=Time.get_ticks_msec()+1000
  if today()!=day:prepare_flowers()

func position_help() -> void:
 if active:
  help.reset_size()
  help.position=Vector2(25,help.get_viewport_rect().size.y-help.size.y-23)

func open() -> void:
 if plant<0:return
 prepare_flowers()
 if harvested():
  home.notify("Picked today · new blossoms tomorrow (UTC)");return
 active=true;selected=0;message="Pick two open flowers with pollen"
 home.walker.stationary=true;home.walker.hide()
 home.Exterior.configure_camera(view,false)
 view.position=Vector3(0,1.31,2.35);view.look_at(to_global(Vector3(0,0.41,0)));view.make_current()
 ring.show();help.show();refresh()

func close() -> void:
 if not active:return
 active=false;ring.hide();help.hide()
 home.walker.show();home.walker.stationary=false;home.walker.camera.make_current()
 prepare_flowers()

func refresh() -> void:
 ring.position=blossoms[selected].position+Vector3(0,-0.035,0.01)
 ring.rotation.x=0.70
 var controls:="← →  Select     A  Pick     B  Leave" if home.prompts.gamepad else "← →  Select     F  Pick     Esc  Leave"
 help.text="%s   ·   %d / 2\n%s\n%s"%[NAMES[plant],picked.size(),message,controls]
 position_help()

func control(event:InputEvent) -> void:
 if event.is_action_pressed("cancel_ship"):close();return
 if event.is_action_pressed("ui_left",true) or event.is_action_pressed("rotate_left"):
  selected=posmod(selected-1,BLOOMS)
 elif event.is_action_pressed("ui_right",true) or event.is_action_pressed("rotate_right"):
  selected=(selected+1)%BLOOMS
 elif event.is_action_pressed("interact"):
  if selected not in ripe:message="Closed bud · leave it to open"
  elif selected in picked:message="This flower has been picked"
  else:
   if picked.size()==1:
    var error:String=home.store.record_harvest(home.rows,PLANTS[plant],day)
    if error!="":message=error;refresh();return
    close();home.notify(NAMES[plant]+" sample saved · process at the refinery");return
   picked.append(selected);blossoms[selected].hide();message="Find the other open flower"
 refresh()
