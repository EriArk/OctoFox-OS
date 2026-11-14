# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipInterior
extends RefCounted
# Original, editable geometry. Units are metres; +Z runs from lounge to cabins.
const PAPER = Color("d9d2b7")
const TRIM = Color("315455")
const WOOD = Color("8f6547")
const BRASS = Color("bb9564")
const ROOMS = {
 "Lounge": Rect2(-6,-10,12,10), "Workshop": Rect2(-9,0,7,7),
 "Gallery": Rect2(2,0,7,7), "Bedroom": Rect2(-9,7,7,7),
 "Wardrobe": Rect2(2,7,7,7), "Passage": Rect2(-2,0,4,14)}
const ITEMS = ["armchair","low-table","plant","lamp","stool","books","rug"]
var materials: Dictionary = {}
var meshes: Dictionary = {}

func material(color: Color, glow: bool=false) -> StandardMaterial3D:
 var key = str(color)+str(glow)
 if materials.has(key): return materials[key]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.8
 if glow: m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.3
 materials[key]=m;return m

func rounded_box(size:Vector3) -> ArrayMesh:
 var key=str(size)
 if meshes.has(key):return meshes[key]
 var half=size*0.5;var bevel=min(0.07,min(size.x,min(size.y,size.z))*0.22)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for axis in 3:
  var u=(axis+1)%3;var v=(axis+2)%3
  for side in [-1.0,1.0]:
   var us=[-half[u],-half[u]+bevel,half[u]-bevel,half[u]]
   var vs=[-half[v],-half[v]+bevel,half[v]-bevel,half[v]]
   for i in 3:
    for j in 3:
     var corners=[]
     for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
      var p=Vector3.ZERO;p[axis]=half[axis]*side;p[u]=us[pair[0]];p[v]=vs[pair[1]]
      var inner=p.clamp(-half+Vector3.ONE*bevel,half-Vector3.ONE*bevel)
      var normal=(p-inner).normalized();corners.append([inner+normal*bevel,normal])
     var order=[0,2,1,0,3,2] if side>0 else [0,1,2,0,2,3]
     for k in order:st.set_normal(corners[k][1]);st.add_vertex(corners[k][0])
 var result=st.commit();meshes[key]=result;return result

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool=false, glow: bool=false) -> MeshInstance3D:
 var mesh=MeshInstance3D.new()
 mesh.mesh=rounded_box(size);mesh.position=pos;mesh.material_override=material(color,glow);parent.add_child(mesh)
 if solid:
  var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
  var collider=CollisionShape3D.new();var bounds=BoxShape3D.new();bounds.size=size
  collider.shape=bounds;body.add_child(collider);mesh.add_child(body)
 return mesh

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float=-1.0) -> MeshInstance3D:
 var mesh=MeshInstance3D.new();var shape=CylinderMesh.new()
 shape.bottom_radius=radius;shape.top_radius=radius if top<0 else top;shape.height=height;shape.radial_segments=24
 mesh.mesh=shape;mesh.position=pos;mesh.material_override=material(color);parent.add_child(mesh);return mesh

func label(parent: Node3D, text: String, pos: Vector3, rotation: float=0.0, size: int=48) -> void:
 var l=Label3D.new();l.text=text;l.position=pos;l.rotation.y=rotation;l.font_size=size;l.pixel_size=0.004
 l.modulate=Color("f3e5bc");l.outline_size=0;l.no_depth_test=false;l.double_sided=false;parent.add_child(l)

func window(parent: Node3D, pos: Vector3, width: float, angle: float=0.0) -> void:
 var root=Node3D.new();root.position=pos;root.rotation.y=angle;parent.add_child(root)
 box(root,Vector3(0,0.28,0),Vector3(width,0.56,0.28),TRIM,true)
 box(root,Vector3(0,3.6,0),Vector3(width,0.4,0.28),TRIM,true)
 box(root,Vector3(0,0.59,0),Vector3(width,0.06,0.35),BRASS)
 for x in [-width/2,width/2]:
  box(root,Vector3(x,2.0,0),Vector3(0.18,3.6,0.3),PAPER,true)
 box(root,Vector3(0,3.35,0.07),Vector3(width-0.2,0.035,0.03),Color("eac997"),false,true)
 # Invisible collider: panorama remains clear and characters cannot leave the hull.
 var glass=StaticBody3D.new();var c=CollisionShape3D.new();var s=BoxShape3D.new();s.size=Vector3(width,3.8,0.12)
 c.shape=s;glass.position.y=1.9;glass.add_child(c);root.add_child(glass)

func portal(parent: Node3D, x: float, z: float, title: String, facing: float) -> void:
 var root=Node3D.new();root.position=Vector3(x,0,z);root.rotation.y=facing;parent.add_child(root)
 for side in [-1,1]:
  box(root,Vector3(side*1.12,1.65,0),Vector3(0.18,3.3,0.32),TRIM,true)
  box(root,Vector3(side*1.02,1.6,0.18),Vector3(0.025,2.7,0.02),Color("e6c18a"),false,true)
 box(root,Vector3(0,3.2,0),Vector3(2.4,0.45,0.32),TRIM,true)
 label(root,title,Vector3(0,3.12,0.2),0,38)

func build(parent: Node3D) -> void:
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_SKY
 var sky=Sky.new();var sky_mat=ShaderMaterial.new();sky_mat.shader=load("res://shaders/space.gdshader");sky.sky_material=sky_mat
 env.environment.sky=sky;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("c8d5dc");env.environment.ambient_light_energy=0.65
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;parent.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);sun.light_color=Color("ffe6be");sun.light_energy=1.2
 sun.shadow_enabled=true;sun.directional_shadow_max_distance=38;parent.add_child(sun)
 var planet=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=52;sphere.height=104;sphere.radial_segments=64;sphere.rings=32
 planet.mesh=sphere;planet.position=Vector3(-30,8,-145)
 var pm=ShaderMaterial.new();pm.shader=load("res://shaders/planet.gdshader");planet.material_override=pm;parent.add_child(planet)
 for title in ROOMS:
  var r:Rect2=ROOMS[title];var c=r.get_center();var tint=WOOD if title!="Passage" else Color("667573")
  box(parent,Vector3(c.x,-0.14,c.y),Vector3(r.size.x,0.28,r.size.y),tint,true)
  box(parent,Vector3(c.x,3.87,c.y),Vector3(r.size.x,0.18,r.size.y),PAPER,true)
  # Broad wood planks, shared material, no textures or per-frame work.
  if title!="Passage":
   for i in range(int(r.size.x/0.65)):
    box(parent,Vector3(r.position.x+i*0.65+0.3,0.005,c.y),Vector3(0.014,0.012,r.size.y-0.12),Color("74563f"))
  box(parent,Vector3(c.x,3.74,c.y),Vector3(1.5,0.04,0.45),Color("ead7af"),false,true)
  var light=OmniLight3D.new();light.position=Vector3(c.x,2.95,c.y);light.light_color=Color("ffe2b1");light.light_energy=0.65;light.omni_range=7;parent.add_child(light)
 window(parent,Vector3(0,0,-10),12)
 window(parent,Vector3(-6,0,-6.5),7,PI/2);window(parent,Vector3(6,0,-6.5),7,PI/2)
 for x in [-6,6]:box(parent,Vector3(x,1.9,-1.5),Vector3(0.24,3.8,3),PAPER,true)
 for x in [-9,9]:
  window(parent,Vector3(x,0,3.5),7,PI/2);window(parent,Vector3(x,0,10.5),7,PI/2)
 for x in [-5.5,5.5]:
  box(parent,Vector3(x,1.9,0),Vector3(7,3.8,0.22),PAPER,true)
  box(parent,Vector3(x,1.9,7),Vector3(7,3.8,0.22),PAPER,true)
 box(parent,Vector3(0,1.9,14),Vector3(18,3.8,0.25),PAPER,true)
 for x in [-2,2]:
  for part in [[0,2.3],[4.7,9.3],[11.7,14]]:
   box(parent,Vector3(x,1.9,(part[0]+part[1])*0.5),Vector3(0.22,3.8,part[1]-part[0]),PAPER,true)
 portal(parent,-2,3.5,"WORKSHOP",PI/2);portal(parent,2,3.5,"GALLERY",-PI/2)
 portal(parent,-2,10.5,"CABIN",PI/2);portal(parent,2,10.5,"WARDROBE",-PI/2)
 label(parent,"MAKE YOURSELF AT HOME",Vector3(0,2.9,13.82),PI,52)
 # Low wall rails and inset panels give the cabins a ship-like structure.
 for x in [-1.84,1.84]:
  box(parent,Vector3(x,0.3,7),Vector3(0.07,0.32,13.7),TRIM)
  box(parent,Vector3(x,2.8,7),Vector3(0.045,0.035,13.7),BRASS)
 # Fixed kitchen and daybed in the shared room.
 for x in [-4.7,-3.3]:
  box(parent,Vector3(x,0.49,-0.6),Vector3(1.35,0.98,0.8),TRIM,true)
  box(parent,Vector3(x,1.02,-0.6),Vector3(1.4,0.1,0.85),BRASS)
  box(parent,Vector3(x,0.55,-1.02),Vector3(0.85,0.025,0.04),BRASS)
 cylinder(parent,Vector3(-4.6,1.2,-0.6),0.13,0.26,Color("ead9ae"))
 box(parent,Vector3(3.6,0.43,-2.2),Vector3(3,0.65,1.2),Color("bc7751"),true)
 box(parent,Vector3(3.6,0.95,-1.65),Vector3(3,0.7,0.28),Color("d99161"),true)
 for x in [2.8,3.7,4.4]:box(parent,Vector3(x,0.82,-2.05),Vector3(0.6,0.18,0.65),Color("d7b880"))
 # Cushions, shelves and small everyday objects.
 for x in [2.65,4.45]:
  var cushion=box(parent,Vector3(x,1.05,-1.95),Vector3(0.58,0.55,0.20),Color("78998c"))
  cushion.rotation.z=0.12 if x<3 else -0.12
 for y in [1.8,2.45]:
  box(parent,Vector3(4.3,y,-0.22),Vector3(2.6,0.1,0.48),WOOD)
 for i in 7:
  var book=box(parent,Vector3(3.3+i*0.22,2.02,-0.25),Vector3(0.15,0.35+0.05*(i%3),0.25),[TRIM,BRASS,Color("b47659")][i%3])
 cylinder(parent,Vector3(-3.4,1.2,-0.55),0.09,0.18,Color("5e817b"))
 # Workshop benches and tool rack.
 box(parent,Vector3(-5.5,0.95,1.0),Vector3(4.7,0.18,1.15),WOOD,true)
 for x in [-7.4,-3.6]:box(parent,Vector3(x,0.45,1),Vector3(0.25,0.9,0.8),TRIM,true)
 box(parent,Vector3(-5.5,2.05,0.2),Vector3(4.7,1.25,0.08),TRIM)
 for x in [-6.8,-6.1,-5.4,-4.7]:
  box(parent,Vector3(x,2.0,0.32),Vector3(0.10,0.55,0.08),BRASS)
  box(parent,Vector3(x,2.25,0.32),Vector3(0.3,0.12,0.08),BRASS)
 label(parent,"WORKBENCH",Vector3(-5.5,2.9,0.33),0,44)
 # Gallery displays are empty until backed by actual owned rewards.
 for x in [3.5,5.4,7.3]:
  box(parent,Vector3(x,0.55,1.1),Vector3(1.1,1.1,0.85),TRIM,true)
  box(parent,Vector3(x,1.13,1.1),Vector3(1.18,0.08,0.93),BRASS)
  box(parent,Vector3(x,2.25,0.2),Vector3(1.18,1.25,0.1),BRASS)
  box(parent,Vector3(x,2.25,0.27),Vector3(1.02,1.09,0.04),Color("28454b"))
 label(parent,"YOUR STORIES BELONG HERE",Vector3(5.5,3.2,0.3),0,35)
 # Bedroom: upholstered bed, desk and shelves.
 box(parent,Vector3(-6.8,0.30,11.3),Vector3(2.6,0.6,3.5),WOOD,true)
 box(parent,Vector3(-6.8,0.68,11.3),Vector3(2.45,0.35,3.3),Color("d8c9a9"))
 box(parent,Vector3(-6.8,0.9,11.0),Vector3(2.48,0.12,2.5),Color("698883"))
 box(parent,Vector3(-6.8,1.2,13.1),Vector3(2.8,1.8,0.24),TRIM,true)
 for x in [-7.4,-6.2]:box(parent,Vector3(x,0.94,12.55),Vector3(0.95,0.22,0.55),Color("eee1be"))
 box(parent,Vector3(-3.5,0.9,12.7),Vector3(1.9,0.12,0.9),WOOD,true)
 for x in [-4.3,-2.7]:box(parent,Vector3(x,0.45,12.7),Vector3(0.1,0.9,0.7),TRIM,true)
 # Wardrobe: full-height mirrors, hanging rails, storage.
 for x in [3.2,7.8]:
  box(parent,Vector3(x,1.45,13.5),Vector3(1.6,2.9,0.6),TRIM,true)
  for y in [0.6,1.4,2.2]:box(parent,Vector3(x,y,13.16),Vector3(1.45,0.06,0.7),WOOD)
 box(parent,Vector3(5.5,1.65,13.7),Vector3(1.8,3.1,0.15),BRASS)
 box(parent,Vector3(5.5,1.65,13.6),Vector3(1.6,2.9,0.05),Color("7a9caa"))
 label(parent,"WARDROBE",Vector3(5.5,3.35,13.5),PI,42)

func footprint(id: String) -> Vector2:
 return {"armchair":Vector2(1.25,1.25),"low-table":Vector2(1.6,1.0),"plant":Vector2(0.7,0.7),"lamp":Vector2(0.5,0.5),"stool":Vector2(0.65,0.65),"books":Vector2(0.5,0.38),"rug":Vector2(2.8,2.0)}.get(id,Vector2.ONE)

func furniture(id: String, solid: bool=true) -> Node3D:
 var root=Node3D.new();root.set_meta("item",id)
 match id:
  "armchair":
   box(root,Vector3(0,0.36,0),Vector3(1.15,0.5,1.1),WOOD)
   box(root,Vector3(0,0.66,0),Vector3(0.9,0.18,0.9),Color("d18b5c"))
   box(root,Vector3(0,0.98,0.45),Vector3(1.15,0.8,0.23),Color("c0784e"))
   for x in [-0.52,0.52]:box(root,Vector3(x,0.75,0),Vector3(0.16,0.5,1.1),Color("b86d45"))
  "low-table":
   box(root,Vector3(0,0.48,0),Vector3(1.5,0.12,0.9),WOOD)
   for x in [-0.57,0.57]:
    for z in [-0.28,0.28]:cylinder(root,Vector3(x,0.22,z),0.045,0.44,BRASS)
  "plant":
   cylinder(root,Vector3(0,0.22,0),0.28,0.44,Color("b77551"),0.36)
   for i in 7:
    var angle=i*TAU/7
    var leaf=box(root,Vector3(sin(angle)*0.18,0.72,cos(angle)*0.18),Vector3(0.14,0.65,0.07),Color("66896b"))
    leaf.rotation=Vector3(sin(angle)*0.45,angle,cos(angle)*0.4)
  "lamp":
   cylinder(root,Vector3(0,0.04,0),0.23,0.08,TRIM)
   cylinder(root,Vector3(0,0.8,0),0.025,1.6,BRASS)
   cylinder(root,Vector3(0,1.58,0),0.36,0.35,Color("ead5a6"),0.22)
  "stool":
   cylinder(root,Vector3(0,0.6,0),0.32,0.16,Color("8eaa92"))
   for i in 3:
    var a=i*TAU/3;cylinder(root,Vector3(sin(a)*0.2,0.27,cos(a)*0.2),0.035,0.54,WOOD)
  "books":
   for i in 4:box(root,Vector3(0,0.045+i*0.075,0),Vector3(0.42,0.07,0.3),[Color("a55e48"),Color("d4b978"),TRIM,Color("6e8d80")][i])
  "rug":box(root,Vector3(0,0.015,0),Vector3(2.8,0.025,2.0),Color("b5a077"))
 if solid and id!="rug":
  var body=StaticBody3D.new();body.collision_layer=2;body.collision_mask=0
  var c=CollisionShape3D.new();var b=BoxShape3D.new();var f=footprint(id)
  b.size=Vector3(f.x,1.0 if id=="armchair" else 0.6,f.y);c.shape=b;c.position.y=b.size.y/2
  body.add_child(c);root.add_child(body)
 return root

func batch_static(parent:Node3D) -> void:
 # One mesh per shared material for fixed room geometry; collision bodies stay.
 # Movable furniture and the host avatar are created afterwards and stay separate.
 var groups:Dictionary={}
 var originals:Array[MeshInstance3D]=[]
 for node in parent.find_children("*","MeshInstance3D",true,false):
  if not node.material_override is StandardMaterial3D:continue
  var id=node.material_override.get_instance_id()
  if not groups.has(id):
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   groups[id]=[surface,node.material_override]
  var local=parent.global_transform.affine_inverse()*node.global_transform
  groups[id][0].append_from(node.mesh,0,local)
  originals.append(node)
 for node in originals:
  for child in node.get_children():child.reparent(parent,true)
  node.get_parent().remove_child(node);node.queue_free()
 for group in groups.values():
  var mesh=MeshInstance3D.new();mesh.mesh=group[0].commit();mesh.material_override=group[1];parent.add_child(mesh)
