# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipInterior
extends RefCounted
# Original, editable geometry. Units are metres; +Z runs from lounge to cabins.
const PAPER = Color("d4cbbb")
const TRIM = Color("354650")
const WOOD = Color("a77c56")
const BRASS = Color("d0ac72")
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
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.62
 if color==BRASS:m.metallic=0.65;m.roughness=0.30
 elif color==PAPER:m.metallic=0.08;m.roughness=0.46
 elif color==Color("637580"):m.metallic=0.30;m.roughness=0.48
 if glow: m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.3
 materials[key]=m;return m

func rounded_box(size:Vector3) -> ArrayMesh:
 var key=str(size)
 if meshes.has(key):return meshes[key]
 var half=size*0.5;var bevel=min(0.18,min(size.x,min(size.y,size.z))*0.28)
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

# Smooth structural profiles. No downloaded room meshes or texture sheets.
func beam(parent:Node3D, a:Vector3, b:Vector3, radius:float, color:Color, glow:bool=false) -> void:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius
 shape.height=a.distance_to(b);shape.radial_segments=16
 var mesh=MeshInstance3D.new();mesh.mesh=shape;mesh.position=(a+b)*0.5
 mesh.quaternion=Quaternion(Vector3.UP,(b-a).normalized());mesh.material_override=material(color,glow);parent.add_child(mesh)

func tube(parent:Node3D, points:Array[Vector3], radius:float, color:Color, glow:bool=false) -> void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Share the same cross-section at every joint, avoiding gaps between segments.
 var frames:Array[Basis]=[]
 for i in points.size():
  var axis=(points[min(i+1,points.size()-1)]-points[max(i-1,0)]).normalized()
  var across=axis.cross(Vector3.FORWARD).normalized()
  if across.length_squared()<0.1:across=axis.cross(Vector3.UP).normalized()
  frames.append(Basis(across,axis.cross(across).normalized(),axis))
 for i in range(points.size()-1):
  for j in 12:
   var normals:Array[Vector3]=[];var vertices:Array[Vector3]=[]
   for pair in [[i,j],[i,j+1],[i+1,j+1],[i+1,j]]:
    var frame=frames[pair[0]];var angle=pair[1]*TAU/12
    var normal=frame.x*cos(angle)+frame.y*sin(angle)
    normals.append(normal);vertices.append(points[pair[0]]+normal*radius)
   for k in [0,2,1,0,3,2]:st.set_normal(normals[k]);st.add_vertex(vertices[k])
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(color,glow);parent.add_child(mesh)

func arch(parent:Node3D, x:float, z:float, width:float, spring:float, rise:float, radius:float, color:Color, glow:bool=false) -> void:
 var path:Array[Vector3]=[]
 for i in 49:
  var a=PI*i/48;path.append(Vector3(x-width*0.5*cos(a),spring+rise*sin(a),z))
 tube(parent,path,radius,color,glow)

func vault(parent:Node3D, x:float, from_z:float, to_z:float, width:float, spring:float, rise:float) -> void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 48:
  var a=PI*i/48;var b=PI*(i+1)/48
  var first=Vector3(x-width*0.5*cos(a),spring+rise*sin(a),from_z)
  var next=Vector3(x-width*0.5*cos(b),spring+rise*sin(b),from_z)
  var vertices=[first,next,next+Vector3(0,0,to_z-from_z),first+Vector3(0,0,to_z-from_z)]
  for k in [0,2,1,0,3,2]:
   var angle=a if k in [0,3] else b
   st.set_normal(Vector3(cos(angle)/ (width*0.5),-sin(angle)/rise,0).normalized());st.add_vertex(vertices[k])
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(Color("aaa999"));parent.add_child(mesh)

func hatch(parent:Node3D, x:float,z:float,title:String,facing:float) -> void:
 var root=Node3D.new();root.position=Vector3(x,0,z);root.rotation.y=facing;parent.add_child(root)
 # Pressure frame: rounded shoulders and a low sill, with the full walking gap.
 for side in [-1,1]:
  box(root,Vector3(side*1.12,1.20,0),Vector3(0.22,2.4,0.48),TRIM,true)
  box(root,Vector3(side*1.12,1.2,0.16),Vector3(0.16,2.3,0.28),PAPER)
  box(root,Vector3(side*1.00,1.27,0.22),Vector3(0.035,1.9,0.03),Color("a8dbca"),false,true)
 arch(root,0,0,2.24,2.4,0.65,0.18,PAPER)
 arch(root,0,0.21,2.03,2.4,0.54,0.025,Color("a8dbca"),true)
 box(root,Vector3(0,3.35,0),Vector3(2.42,0.58,0.42),PAPER,true)
 box(root,Vector3(0,0.025,0),Vector3(2.15,0.05,0.46),Color("6f898d"))
 label(root,title,Vector3(0,3.18,0.24),0,32)
 for side in [-1,1]:box(root,Vector3(side*1.27,1.12,0.25),Vector3(0.13,0.34,0.04),BRASS)

func window(parent:Node3D,pos:Vector3,width:float,angle:float=0.0) -> void:
 var root=Node3D.new();root.position=pos;root.rotation.y=angle;parent.add_child(root)
 # A deep sill and curved crown make the opening part of a pressure hull.
 box(root,Vector3(0,0.28,0),Vector3(width,0.56,0.45),PAPER,true)
 box(root,Vector3(0,0.59,0.10),Vector3(width,0.07,0.48),PAPER)
 box(root,Vector3(0,3.6,0),Vector3(width,0.38,0.48),PAPER,true)
 for side in [-1,1]:
  box(root,Vector3(side*width/2,1.95,0),Vector3(0.34,3.5,0.55),PAPER,true)
  for y in [0.85,2.85]:
   box(root,Vector3(side*width/2,y,0.06),Vector3(0.44,0.12,0.60),BRASS)
  box(root,Vector3(side*width/2,1.95,0.31),Vector3(0.16,0.92,0.08),TRIM)
  box(root,Vector3(side*width/2,1.95,0.36),Vector3(0.055,0.71,0.025),Color("78c7f3"),false,true)
  var corner=box(root,Vector3(side*(width/2-0.22),3.23,0.08),Vector3(0.16,0.62,0.38),PAPER)
  corner.rotation.z=-side*PI/4
 box(root,Vector3(0,3.33,0.19),Vector3(width-0.75,0.035,0.025),Color("bfe4de"),false,true)
 box(root,Vector3(0,0.42,0.24),Vector3(width-0.5,0.025,0.025),Color("e6b881"),false,true)
 var body=StaticBody3D.new();var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(width,3.8,0.12)
 c.shape=shape;body.position.y=1.9;body.add_child(c);root.add_child(body)

func console(parent:Node3D) -> void:
 var root=Node3D.new();root.position=Vector3(0,0,-7.65);parent.add_child(root)
 # Cockpit island follows the panorama, with central pilot position and wings.
 for i in range(-2,3):
  var pod=Node3D.new();pod.position=Vector3(i*1.36,0,-0.18*abs(i));pod.rotation.y=-i*0.10;root.add_child(pod)
  box(pod,Vector3(0,0.49,0),Vector3(1.30,0.98,0.76),PAPER,true)
  box(pod,Vector3(0,0.11,0),Vector3(1.38,0.16,0.83),Color("172a34"))
  var desk=box(pod,Vector3(0,1.03,-0.05),Vector3(1.39,0.16,1.06),PAPER,true);desk.rotation.x=-0.12
  var screen=Node3D.new();screen.position=Vector3(0,1.28,-0.32);screen.rotation.x=-0.24;pod.add_child(screen)
  box(screen,Vector3.ZERO,Vector3(0.97,0.56,0.08),Color("132a35"))
  box(screen,Vector3(0,0,0.047),Vector3(0.84,0.42,0.012),Color("56371b"),false,true)
  if i==0:
   for radius in [0.065,0.13,0.185]:
    var circle:Array[Vector3]=[]
    for k in 65:
     var a=k*TAU/64;circle.append(Vector3(cos(a)*radius,sin(a)*radius,0.062))
    tube(screen,circle,0.0035,Color("ffd086"),true)
  # Minimal original instrument marks, not a busy wall of fake text.
  for j in (0 if i==0 else 4):
   box(screen,Vector3(-0.30+j*0.20,-0.08,0.058),Vector3(0.08,0.08+0.055*((j+i+5)%4),0.006),Color("ffc46d"),false,true)
  box(screen,Vector3(0,0.14,0.058),Vector3(0.62,0.012,0.005),Color("e1bd7f"),false,true)
  for j in 5:
   cylinder(pod,Vector3(-0.46+j*0.23,1.15,0.31),0.035,0.04,BRASS if j==4 else Color("668b95"))
  box(pod,Vector3(0,0.78,0.40),Vector3(1.03,0.025,0.025),Color("f3b85e"),false,true)
 # Pilot yoke and a built-in padded pedestal seat.
 beam(root,Vector3(0,1.1,0.36),Vector3(0,1.32,0.62),0.035,TRIM)
 beam(root,Vector3(-0.23,1.32,0.62),Vector3(0.23,1.32,0.62),0.038,TRIM)
 for side in [-1,1]:beam(root,Vector3(side*0.23,1.25,0.62),Vector3(side*0.23,1.47,0.62),0.045,Color("b17c58"))
 cylinder(root,Vector3(0,0.28,1.45),0.20,0.56,TRIM)
 box(root,Vector3(0,0.60,1.45),Vector3(0.86,0.23,0.80),Color("c08c67"),true)
 box(root,Vector3(0,1.10,1.80),Vector3(0.90,1.05,0.22),Color("c08c67"),true)
 for side in [-1,1]:box(root,Vector3(side*0.53,0.89,1.46),Vector3(0.14,0.12,0.70),TRIM)
 # Floor frame and nose designation.
 label(root,"O C T O F O X   /   0 1",Vector3(0,0.48,0.43),0,26)

func build(parent:Node3D) -> void:
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_SKY
 var sky=Sky.new();var sky_mat=ShaderMaterial.new();sky_mat.shader=load("res://shaders/space.gdshader");sky.sky_material=sky_mat
 var stars=MultiMeshInstance3D.new();var star_mesh=SphereMesh.new();star_mesh.radius=0.18;star_mesh.height=0.36;star_mesh.radial_segments=6;star_mesh.rings=3
 var star_mat=StandardMaterial3D.new();star_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_mat.vertex_color_use_as_albedo=true
 star_mesh.material=star_mat;var field=MultiMesh.new();field.transform_format=MultiMesh.TRANSFORM_3D;field.use_colors=true;field.mesh=star_mesh;field.instance_count=850
 var rng=RandomNumberGenerator.new();rng.seed=14112026
 for i in field.instance_count:
  var y=rng.randf_range(-0.75,0.85);var angle=rng.randf_range(0,TAU);var radial=sqrt(1-y*y)
  var point=Vector3(cos(angle)*radial,y,sin(angle)*radial)*260
  field.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(0.6,2.4)),point))
  field.set_instance_color(i,Color("d4dfff") if i%3 else Color("ffe6c5"))
 stars.multimesh=field;parent.add_child(stars)
 env.environment.sky=sky;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("a4becd");env.environment.ambient_light_energy=0.38
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;parent.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-28,0);sun.light_color=Color("b5d5ec");sun.light_energy=0.45
 sun.shadow_enabled=false;sun.directional_shadow_max_distance=38;parent.add_child(sun)
 var bridge_light=SpotLight3D.new();bridge_light.position=Vector3(0,4.05,-4.4);bridge_light.rotation_degrees.x=-90
 bridge_light.light_color=Color("ffe1b8");bridge_light.light_energy=0.85;bridge_light.spot_range=11;bridge_light.spot_angle=65
 bridge_light.shadow_enabled=true;bridge_light.shadow_bias=0.08;bridge_light.shadow_normal_bias=1.5;parent.add_child(bridge_light)
 var planet=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=48;sphere.height=96;sphere.radial_segments=96;sphere.rings=48
 planet.mesh=sphere;planet.position=Vector3(32,11,-165)
 var pm=ShaderMaterial.new();pm.shader=load("res://shaders/planet.gdshader");planet.material_override=pm;parent.add_child(planet)
 var rings=MeshInstance3D.new();var ring_mesh=SurfaceTool.new();ring_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in 192:
  var a=i*TAU/192;var b=(i+1)*TAU/192
  var points=[Vector3(cos(a)*54,0,sin(a)*54),Vector3(cos(a)*86,0,sin(a)*86),Vector3(cos(b)*86,0,sin(b)*86),Vector3(cos(b)*54,0,sin(b)*54)]
  for k in [0,2,1,0,3,2]:ring_mesh.set_normal(Vector3.UP);ring_mesh.set_uv(Vector2(0 if k in [0,3] else 1,0));ring_mesh.add_vertex(points[k])
 rings.mesh=ring_mesh.commit();rings.position=planet.position;rings.rotation=Vector3(0.42,0,-0.18)
 var rm=ShaderMaterial.new();rm.shader=load("res://shaders/rings.gdshader");rings.material_override=rm;parent.add_child(rings)
 for position in [Vector3(-58,28,-170),Vector3(7,37,-125)]:
  var moon=MeshInstance3D.new();var ball=SphereMesh.new();ball.radius=3.4;ball.height=6.8;ball.radial_segments=32
  moon.mesh=ball;moon.position=position;moon.material_override=material(Color("a293bc"));parent.add_child(moon)
 for title in ROOMS:
  var r:Rect2=ROOMS[title];var c=r.get_center()
  box(parent,Vector3(c.x,-0.14,c.y),Vector3(r.size.x,0.28,r.size.y),Color("414f5a"),true)
  # Inset deck plates, no wall-to-wall domestic floorboards.
  for ix in range(int(r.size.x/1.4)):
   for iz in range(int(r.size.y/1.8)):
    box(parent,Vector3(r.position.x+0.72+ix*1.4,0.006,r.position.y+0.92+iz*1.8),Vector3(1.35,0.016,1.74),Color("637580"))
  var light=OmniLight3D.new();light.position=Vector3(c.x,3.0,c.y);light.light_color=Color("ffe0b6");light.light_energy=0.65;light.omni_range=7;parent.add_child(light)
  if title!="Passage":
   vault(parent,c.x,r.position.y,r.end.y,r.size.x,3.20,1.20 if title=="Lounge" else 0.65)
   for z in [r.position.y+0.25,c.y,r.end.y-0.25]:
    arch(parent,c.x,z,r.size.x,3.2,1.2 if title=="Lounge" else 0.65,0.12,TRIM)
    arch(parent,c.x,z+0.14,r.size.x-0.3,3.19,1.1 if title=="Lounge" else 0.54,0.027,Color("e8c99c"),true)
  else:
   vault(parent,0,0,14,4,3.15,0.65)
   for z in [0.2,3.5,7,10.5,13.7]:arch(parent,0,z,4,3.15,0.65,0.12,TRIM)
 window(parent,Vector3(0,0,-10),12)
 # Curved mullions bend overhead: bridge canopy rather than house glazing.
 for side in [-1,1]:
  var path:Array[Vector3]=[]
  for i in 33:
   var t=float(i)/32;path.append(Vector3(side*(5.7-2.1*t),0.6+3.75*t,-9.85+0.85*t*t))
  tube(parent,path,0.13,PAPER)
  window(parent,Vector3(side*6,0,-6.5),7,PI/2)
  box(parent,Vector3(side*6,1.9,-1.5),Vector3(0.24,3.8,3),PAPER,true)
 for x in [-9,9]:
  window(parent,Vector3(x,0,3.5),7,PI/2);window(parent,Vector3(x,0,10.5),7,PI/2)
 for x in [-5.5,5.5]:
  for z in [0,7]:
   box(parent,Vector3(x,1.9,z),Vector3(7,3.8,0.22),PAPER,true)
   box(parent,Vector3(x,0.40,z+0.13),Vector3(6.7,0.8,0.16),TRIM)
   box(parent,Vector3(x,2.8,z+0.13),Vector3(6.6,0.035,0.025),BRASS)
 box(parent,Vector3(0,1.9,14),Vector3(18,3.8,0.25),PAPER,true)
 for x in [-2,2]:
  for part in [[0,2.3],[4.7,9.3],[11.7,14]]:
   var center=(part[0]+part[1])*0.5;var length=part[1]-part[0]
   box(parent,Vector3(x,1.9,center),Vector3(0.22,3.8,length),PAPER,true)
   box(parent,Vector3(x-sign(x)*0.14,0.42,center),Vector3(0.16,0.8,length),TRIM)
   box(parent,Vector3(x-sign(x)*0.24,0.83,center),Vector3(0.045,0.03,max(0.1,length-0.3)),Color("e5bd81"),false,true)
 hatch(parent,-2,3.5,"02  /  WORKSHOP",PI/2);hatch(parent,2,3.5,"03  /  GALLERY",-PI/2)
 hatch(parent,-2,10.5,"04  /  CABIN",PI/2);hatch(parent,2,10.5,"05  /  WARDROBE",-PI/2)
 # Broad pressure arch separates the observation bridge from the living spine.
 arch(parent,0,-0.12,4,2.65,0.9,0.16,TRIM)
 for x in [-1.93,1.93]:box(parent,Vector3(x,1.25,-0.12),Vector3(0.28,2.5,0.42),TRIM,true)
 for x in [-0.75,0.75]:box(parent,Vector3(x,0.025,7),Vector3(0.028,0.02,13.2),Color("9fc9bc"),false,true)
 # A sealed aft service bulkhead makes the ship's spine readable.
 box(parent,Vector3(0,1.55,13.7),Vector3(2.5,3.1,0.18),TRIM,true)
 for x in [-0.62,0.62]:box(parent,Vector3(x,1.55,13.58),Vector3(1.17,2.8,0.08),Color("627c82"))
 label(parent,"06  /  ENGINEERING",Vector3(0,3.28,13.55),PI,32)
 for x in [-0.9,0.9]:box(parent,Vector3(x,1.55,13.50),Vector3(0.025,0.6,0.025),BRASS,false,true)
 console(parent)
 # Profile Orbit motif: a circular deck inset with a brass rim and blue light.
 cylinder(parent,Vector3(0,0.013,-2.7),1.64,0.010,BRASS)
 cylinder(parent,Vector3(0,0.019,-2.7),1.56,0.008,PAPER)
 for side in [-1,1]:
  var path:Array[Vector3]=[]
  for i in 33:
   var a=side*PI/2-0.6+i*1.2/32;path.append(Vector3(sin(a)*1.77,0.025,-2.7+cos(a)*1.77))
  tube(parent,path,0.022,Color("8dd7ff"),true)
 arch(parent,0,-9.84,11.9,3.2,1.18,0.14,PAPER)
 arch(parent,0,-9.68,11.65,3.20,1.06,0.028,Color("9ad5fc"),true)
 # Fitted lounge pod and galley behind the cockpit, with warm upholstery.
 for i in 5:
  var seat=Node3D.new();seat.position=Vector3(4.35,0,-1.30-i*0.68);seat.rotation.y=-PI/2;parent.add_child(seat)
  box(seat,Vector3(0,0.29,0),Vector3(0.66,0.58,1.2),TRIM,true)
  box(seat,Vector3(0,0.67,0),Vector3(0.65,0.20,1.0),Color("c7956d"))
  box(seat,Vector3(0,1.02,0.48),Vector3(0.66,0.74,0.20),Color("8ea99c"))
 cylinder(parent,Vector3(3.05,0.35,-2.8),0.16,0.7,TRIM)
 cylinder(parent,Vector3(3.05,0.75,-2.8),0.66,0.10,WOOD)
 for x in [-4.7,-3.3]:
  box(parent,Vector3(x,0.49,-0.6),Vector3(1.35,0.98,0.8),TRIM,true)
  box(parent,Vector3(x,1.02,-0.6),Vector3(1.4,0.1,0.85),WOOD)
  box(parent,Vector3(x,0.55,-1.02),Vector3(0.85,0.025,0.04),BRASS)
 box(parent,Vector3(-4.0,2.45,-0.20),Vector3(2.8,0.85,0.42),TRIM)
 box(parent,Vector3(-4.0,2.02,-0.20),Vector3(2.5,0.025,0.30),Color("ebce9e"),false,true)
 cylinder(parent,Vector3(-4.6,1.2,-0.6),0.13,0.26,Color("ead9ae"))
 label(parent,"01  /  OBSERVATION",Vector3(-4,1.68,-0.26),PI,28)
 # Workshop: integrated equipment rack and tool bench.
 box(parent,Vector3(-5.5,0.95,1.0),Vector3(4.7,0.18,1.15),PAPER,true)
 for x in [-7.4,-3.6]:box(parent,Vector3(x,0.45,1),Vector3(0.65,0.9,0.8),TRIM,true)
 box(parent,Vector3(-5.5,2.05,0.2),Vector3(4.7,1.25,0.12),TRIM)
 for x in [-6.8,-6.1,-5.4,-4.7]:
  box(parent,Vector3(x,2.0,0.32),Vector3(0.10,0.55,0.08),BRASS)
  box(parent,Vector3(x,2.25,0.32),Vector3(0.3,0.12,0.08),BRASS)
 box(parent,Vector3(-5.5,2.77,0.25),Vector3(4.7,0.06,0.4),Color("ead5aa"),false,true)
 label(parent,"FABRICATION",Vector3(-5.5,3.12,0.33),0,36)
 # Recessed trophy niches; no invented rewards.
 for x in [3.5,5.4,7.3]:
  box(parent,Vector3(x,1.65,0.35),Vector3(1.5,2.75,0.36),TRIM)
  box(parent,Vector3(x,0.63,0.8),Vector3(1.42,1.2,1.03),Color("536c73"),true)
  box(parent,Vector3(x,1.25,0.8),Vector3(1.45,0.06,1.06),BRASS)
  box(parent,Vector3(x,2.8,0.58),Vector3(1.15,0.025,0.025),Color("a9d8ca"),false,true)
 label(parent,"COLLECTION ARCHIVE",Vector3(5.5,3.23,0.60),0,34)
 # Sleep pod: thick rounded enclosure, illuminated inner rim, textile lining.
 box(parent,Vector3(-6.8,0.30,11.3),Vector3(2.8,0.6,3.5),TRIM,true)
 box(parent,Vector3(-6.8,0.68,11.3),Vector3(2.45,0.35,3.3),Color("d8c9a9"))
 box(parent,Vector3(-6.8,0.9,11.0),Vector3(2.48,0.12,2.5),Color("698f91"))
 box(parent,Vector3(-6.8,1.2,13.1),Vector3(2.8,1.8,0.24),TRIM,true)
 for x in [-7.4,-6.2]:box(parent,Vector3(x,0.94,12.55),Vector3(0.95,0.22,0.55),Color("eee1be"))
 for z in [9.5,13.0]:
  arch(parent,-6.8,z,3.0,1.1,1.45,0.16,PAPER)
  arch(parent,-6.8,z-0.08,2.7,1.1,1.32,0.025,Color("e6bb8a"),true)
 box(parent,Vector3(-3.5,0.9,12.7),Vector3(1.9,0.12,0.9),WOOD,true)
 for x in [-4.3,-2.7]:box(parent,Vector3(x,0.45,12.7),Vector3(0.1,0.9,0.7),TRIM,true)
 # Wardrobe is an outfitting bay with curved frames and enclosed lockers.
 for x in [3.2,7.8]:
  box(parent,Vector3(x,1.45,13.5),Vector3(1.6,2.9,0.6),TRIM,true)
  for y in [0.6,1.4,2.2]:box(parent,Vector3(x,y,13.16),Vector3(1.45,0.06,0.7),Color("657c83"))
  box(parent,Vector3(x,2.87,13.13),Vector3(1.2,0.03,0.03),Color("b9d6cd"),false,true)
 box(parent,Vector3(5.5,1.65,13.7),Vector3(1.8,3.1,0.15),TRIM)
 box(parent,Vector3(5.5,1.65,13.6),Vector3(1.6,2.9,0.05),Color("4d707f"))
 arch(parent,5.5,13.47,2.1,2.5,0.7,0.08,BRASS)
 label(parent,"OUTFITTING",Vector3(5.5,3.42,13.5),PI,34)

func footprint(id: String) -> Vector2:
 return {"armchair":Vector2(1.25,1.25),"low-table":Vector2(1.6,1.0),"plant":Vector2(0.7,0.7),"lamp":Vector2(0.5,0.5),"stool":Vector2(0.65,0.65),"books":Vector2(0.5,0.38),"rug":Vector2(2.8,2.0)}.get(id,Vector2.ONE)

func furniture(id: String, solid: bool=true) -> Node3D:
 var root=Node3D.new();root.set_meta("item",id)
 match id:
  "armchair":
   cylinder(root,Vector3(0,0.08,0),0.42,0.16,TRIM)
   cylinder(root,Vector3(0,0.28,0),0.14,0.40,BRASS)
   cylinder(root,Vector3(0,0.51,0),0.54,0.16,Color("bd906b"))
   # Curved pressure-moulded shell wraps around the padded seat.
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in 48:
    var a=-PI*0.64+i*PI*1.28/48;var b=-PI*0.64+(i+1)*PI*1.28/48
    for radius in [0.56,0.62]:
     var va=Vector3(sin(a)*radius,0,cos(a)*radius);var vb=Vector3(sin(b)*radius,0,cos(b)*radius)
     var vertices=[va+Vector3.UP*0.43,vb+Vector3.UP*0.43,vb+Vector3.UP*(0.85+0.28*cos(b)),va+Vector3.UP*(0.85+0.28*cos(a))]
     var order=[0,2,1,0,3,2] if radius>0.6 else [0,1,2,0,2,3]
     for k in order:
      var normal=Vector3(vertices[k].x,0,vertices[k].z).normalized()*(1 if radius>0.6 else -1)
      surface.set_normal(normal);surface.add_vertex(vertices[k])
   var mesh=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=material(PAPER);root.add_child(mesh)
   var rim:Array[Vector3]=[]
   for i in 49:
    var a=-PI*0.64+i*PI*1.28/48;rim.append(Vector3(sin(a)*0.59,0.85+0.28*cos(a),cos(a)*0.59))
   tube(root,rim,0.035,Color("bd906b"))
  "low-table":
   cylinder(root,Vector3(0,0.04,0),0.38,0.08,TRIM)
   cylinder(root,Vector3(0,0.24,0),0.07,0.45,BRASS)
   var top=cylinder(root,Vector3(0,0.49,0),0.78,0.09,WOOD);top.scale.z=0.6
  "plant":
   cylinder(root,Vector3(0,0.22,0),0.27,0.44,PAPER,0.34)
   cylinder(root,Vector3(0,0.40,0),0.345,0.06,BRASS)
   for i in 9:
    var angle=i*TAU/9
    var leaf=MeshInstance3D.new();var shape=SphereMesh.new();shape.radius=0.1;shape.height=0.64;shape.radial_segments=12;shape.rings=8
    leaf.mesh=shape;leaf.scale=Vector3(0.8,1,0.45);leaf.position=Vector3(sin(angle)*0.16,0.68,cos(angle)*0.16)
    leaf.rotation=Vector3(sin(angle)*0.45,angle,cos(angle)*0.4);leaf.material_override=material(Color("618b7a"));root.add_child(leaf)
  "lamp":
   cylinder(root,Vector3(0,0.04,0),0.23,0.08,TRIM)
   cylinder(root,Vector3(0,0.8,0),0.035,1.6,BRASS)
   var light=MeshInstance3D.new();var capsule=CapsuleMesh.new();capsule.radius=0.14;capsule.height=0.5
   light.mesh=capsule;light.position=Vector3(0,1.6,0);light.material_override=material(Color("f3d6a4"),true);root.add_child(light)
   for y in [1.34,1.86]:cylinder(root,Vector3(0,y,0),0.16,0.06,PAPER)
  "stool":
   cylinder(root,Vector3(0,0.6,0),0.32,0.16,Color("8eaa92"))
   for i in 3:
    var a=i*TAU/3;cylinder(root,Vector3(sin(a)*0.2,0.27,cos(a)*0.2),0.035,0.54,WOOD)
  "books":
   for i in 4:box(root,Vector3(0,0.045+i*0.075,0),Vector3(0.42,0.07,0.3),[Color("a55e48"),Color("d4b978"),TRIM,Color("6e8d80")][i])
  "rug":
   var pad=cylinder(root,Vector3(0,0.015,0),1.4,0.025,Color("9b8c73"));pad.scale.z=0.7
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
  # Primitive meshes are indexed; our authored meshes may be unindexed.
  # Mixing those directly loses unindexed geometry once a group has indices.
  var source=node.mesh
  var indices=source.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
  if indices==null or indices.is_empty():
   var indexed=SurfaceTool.new();indexed.create_from(source,0);indexed.index();source=indexed.commit()
  groups[id][0].append_from(source,0,local)
  originals.append(node)
 for node in originals:
  for child in node.get_children():child.reparent(parent,true)
  node.get_parent().remove_child(node);node.queue_free()
 for group in groups.values():
  var mesh=MeshInstance3D.new();mesh.mesh=group[0].commit();mesh.material_override=group[1];parent.add_child(mesh)
