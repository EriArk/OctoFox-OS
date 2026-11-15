# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipInterior
extends RefCounted
# Original, editable geometry. Units are metres; +Z runs from lounge to cabins.
const PAPER = Color("e7e0d3")
const TRIM = Color("354a49")
const WOOD = Color("a47c55")
const BRASS = Color("d0ac72")
# One shallow oval pressure hull; rooms are clipped by its actual footprint.
const HULL_RADII = Vector2(5.3,6.2)
const HULL_CENTER = Vector2(0,0.6)
const ROOMS = {
 "Cockpit": Rect2(-1.85,-5.6,3.7,3.6), "Lounge": Rect2(-5.3,-2.0,10.6,3.1),
 "Workshop": Rect2(-5.3,1.1,4.45,2.5), "Gallery": Rect2(0.85,1.1,4.45,2.5),
 "Bedroom": Rect2(-4.7,3.6,3.85,3.2), "Wardrobe": Rect2(0.85,3.6,3.85,3.2),
 "Passage": Rect2(-0.85,1.1,1.7,5.7)}
const DOORS = [Vector2(-0.85,2.3),Vector2(0.85,2.3),Vector2(-0.85,4.8),Vector2(0.85,4.8)]

static func inside_hull(point:Vector2,margin:float=0.0) -> bool:
 var normalized=(point-HULL_CENTER)/(HULL_RADII-Vector2.ONE*margin)
 return normalized.length_squared()<1.0

const ITEMS = ["armchair","low-table","plant","lamp","stool","books","rug"]
var materials: Dictionary = {}
var meshes: Dictionary = {}
var grain_textures:Dictionary={}

func grain_texture(wood:bool) -> NoiseTexture2D:
 if grain_textures.has(wood):return grain_textures[wood]
 var noise=FastNoiseLite.new();noise.seed=1411;noise.frequency=0.12;noise.fractal_octaves=3
 var texture=NoiseTexture2D.new();texture.width=128;texture.height=128;texture.seamless=true;texture.noise=noise
 var ramp=Gradient.new();ramp.set_color(0,Color("c2b39d") if wood else Color("e3ded3"));ramp.set_color(1,Color.WHITE)
 texture.color_ramp=ramp;grain_textures[wood]=texture;return texture

func material(color: Color, glow: bool=false) -> StandardMaterial3D:
 var key = str(color)+str(glow)
 if materials.has(key): return materials[key]
 var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.62
 if color==BRASS:m.metallic=0.65;m.roughness=0.30
 elif color==PAPER:m.metallic=0.08;m.roughness=0.55
 elif color==Color("637580"):m.metallic=0.30;m.roughness=0.48
 if color in [WOOD,Color("897c69"),Color("b5734d"),Color("c77f50"),Color("698773"),Color("b36549"),Color("b36343")]:
  var wood=color==WOOD
  m.albedo_texture=grain_texture(wood);m.uv1_triplanar=true;m.uv1_world_triplanar=true
  m.uv1_scale=Vector3(0.45,9,9) if wood else Vector3.ONE*18
  m.roughness=0.70 if wood else 0.95
 if glow: m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.3
 materials[key]=m;return m

func rounded_box(size:Vector3) -> ArrayMesh:
 var key=str(size)
 if meshes.has(key):return meshes[key]
 var half=size*0.5;var bevel=min(0.045,min(size.x,min(size.y,size.z))*0.26)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for axis in 3:
  var u=(axis+1)%3;var v=(axis+2)%3
  for side in [-1.0,1.0]:
   var us:Array[float]=[];var vs:Array[float]=[]
   for k in 4:
    us.append(-half[u]+bevel*k/3.0);vs.append(-half[v]+bevel*k/3.0)
   for k in 4:
    us.append(half[u]-bevel+bevel*k/3.0);vs.append(half[v]-bevel+bevel*k/3.0)
   for i in 7:
    for j in 7:
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
 shape.bottom_radius=radius;shape.top_radius=radius if top<0 else top;shape.height=height;shape.radial_segments=64
 mesh.mesh=shape;mesh.position=pos;mesh.material_override=material(color);parent.add_child(mesh);return mesh

func label(parent: Node3D, text: String, pos: Vector3, rotation: float=0.0, size: int=48, ink:Color=TRIM) -> void:
 var l=Label3D.new();l.text=text;l.position=pos;l.rotation.y=rotation;l.font_size=size;l.pixel_size=0.004
 l.modulate=ink;l.outline_size=0;l.no_depth_test=false;l.double_sided=false;parent.add_child(l)

# Smooth structural profiles. No downloaded room meshes or texture sheets.
func beam(parent:Node3D, a:Vector3, b:Vector3, radius:float, color:Color, glow:bool=false) -> void:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius
 shape.height=a.distance_to(b);shape.radial_segments=24
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

func panel(parent:Node3D, vertices:Array[Vector3], color:Color, solid:bool=false) -> MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Facing is explicit in the vertex ordering; collision uses the same surface.
 for i in range(1,vertices.size()-1):
  var normal=(vertices[i]-vertices[0]).cross(vertices[i+1]-vertices[0]).normalized()
  for k in [0,i+1,i]:st.set_normal(normal);st.add_vertex(vertices[k])
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(color);parent.add_child(mesh)
 if solid:mesh.create_trimesh_collision()
 return mesh

func bulkhead(parent:Node3D,a:Vector2,b:Vector2,height:float=2.65) -> void:
 var middle=(a+b)*0.5;var length=a.distance_to(b)
 var root=Node3D.new();root.position=Vector3(middle.x,0,middle.y)
 root.rotation.y=-atan2(b.y-a.y,b.x-a.x);parent.add_child(root)
 box(root,Vector3(0,height/2,0),Vector3(length,height,0.14),PAPER,true)
 for side in [-1,1]:
  box(root,Vector3(0,0.30,side*0.085),Vector3(length,0.60,0.04),WOOD)
  box(root,Vector3(0,0.64,side*0.11),Vector3(length,0.025,0.025),BRASS)

func hatch(parent:Node3D,x:float,z:float,title:String,facing:float) -> void:
 var root=Node3D.new();root.position=Vector3(x,0,z);root.rotation.y=facing;parent.add_child(root)
 for side in [-1,1]:
  box(root,Vector3(side*0.72,0.92,0),Vector3(0.16,1.84,0.28),TRIM,true)
  box(root,Vector3(side*0.64,0.95,0.16),Vector3(0.025,1.65,0.025),Color("e6bd80"),false,true)
 arch(root,0,0,1.44,1.84,0.34,0.10,PAPER)
 arch(root,0,0.12,1.29,1.84,0.28,0.018,Color("e6bd80"),true)
 box(root,Vector3(0,2.47,0),Vector3(1.62,0.65,0.20),PAPER,true)
 label(root,title,Vector3(0,2.31,0.13),0,23)

# A pressure-wall bay follows the outer ellipse between its structural joints.
# Render curvature sits outside the original chord collision, never in the aisle.
func curved_wall(parent:Node3D,width:float,low:float,high:float,color:Color,offset:float=0.0) -> void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var sag=width*width/44.0
 for i in 16:
  var vertices:Array[Vector3]=[];var normals:Array[Vector3]=[]
  for spec in [[i,low],[i+1,low],[i+1,high],[i,high]]:
   var t=float(spec[0])/16;var y=float(spec[1]);var x=(t-0.5)*width
   vertices.append(Vector3(x,y,y/2.35*0.34-sag*4*t*(1-t)+offset))
   normals.append(Vector3(-8*sag*x/(width*width),-0.34/2.35,1).normalized())
  for k in [0,2,1,0,3,2]:st.set_normal(normals[k]);st.add_vertex(vertices[k])
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(color);parent.add_child(mesh)

func curved_rail(parent:Node3D,width:float,y:float,radius:float,color:Color,glow:bool=false) -> void:
 var points:Array[Vector3]=[]
 for i in 17:
  var t=float(i)/16
  points.append(Vector3((t-0.5)*width,y,y/2.35*0.34-width*width/44.0*4*t*(1-t)+0.025))
 tube(parent,points,radius,color,glow)

func hull_segment(parent:Node3D,a:Vector2,b:Vector2,glazed:bool, panoramic:bool=false, brace:bool=false) -> void:
 var root=Node3D.new();var center=(a+b)*0.5;var width=a.distance_to(b)
 root.position=Vector3(center.x,0,center.y);root.rotation.y=-atan2(b.y-a.y,b.x-a.x);parent.add_child(root)
 var h=2.35;var inset=0.34
 # Sloping pressure wall, with a shaped aperture cut into an opaque panel.
 if panoramic:
  # Continuous bow canopy: only a low sill and upper rail between the facets.
  for span in [[0.0,0.58],[2.22,h]]:
   var lo=span[0];var hi=span[1]
   curved_wall(root,width,lo,hi,PAPER)
  for y in [0.60,2.21]:curved_rail(root,width,y,0.045,TRIM)
  if brace:
   strut(root,Vector3(-width/2+0.14,0.58,0.10),Vector3(-width/2-0.10,2.23,0.34),0.065,0.09,TRIM)
 elif glazed:
  # Smooth tapered oval glazing, with a real opening in the opaque pressure wall.
  var w=width*0.43;var cy=1.48;var ry=0.40
  var angles:Array[float]=[]
  for i in 64:angles.append(i*TAU/64)
  # Include the four outer corners so the surrounding wall has no tiny gaps.
  for corner in [Vector2(-width/2,-cy),Vector2(width/2,-cy),Vector2(width/2,h-cy),Vector2(-width/2,h-cy)]:angles.append(fposmod(corner.angle(),TAU))
  angles.sort()
  var rim:Array[Vector3]=[];var outside_ring:Array[Vector3]=[]
  for angle in angles:
   var ray=Vector2(cos(angle),sin(angle))
   var extent=min(width*0.5/max(abs(ray.x),0.0001),(h-cy if ray.y>0 else cy)/max(abs(ray.y),0.0001))
   var outer=Vector2(0,cy)+ray*extent
   var inner=Vector2(ray.x*w*(0.94+0.06*ray.y),cy+ray.y*ry)
   outside_ring.append(Vector3(outer.x,outer.y,outer.y/h*inset))
   rim.append(Vector3(inner.x,inner.y,inner.y/h*inset))
  for i in rim.size():
   var j=(i+1)%rim.size()
   panel(root,[outside_ring[i],outside_ring[j],rim[j],rim[i]],PAPER)
  rim.append(rim[0]);tube(root,rim,0.045,TRIM)
  var seal:Array[Vector3]=[]
  for v in rim:seal.append(v+Vector3(0,0,0.033))
  tube(root,seal,0.012,BRASS)
 else:
  curved_wall(root,width,0,h,PAPER)
 # The whole wall remains solid, including glazing. Hidden geometry is collision-only.
 var boundary=panel(root,[Vector3(-width/2,0,0),Vector3(width/2,0,0),Vector3(width/2,h,inset),Vector3(-width/2,h,inset)],PAPER,true)
 boundary.visible=false;boundary.set_meta("collision_only",true)
 curved_wall(root,width,0.0,0.44,WOOD,0.015)
 curved_rail(root,width,0.48,0.022,Color("edc58b"),true)
 if not panoramic:beam(root,Vector3(-width/2,0,0.06),Vector3(-width/2,h,inset+0.03),0.025,TRIM)

func saucer(parent:Node3D) -> void:
 var floor_mesh=SurfaceTool.new();floor_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roof_mesh=SurfaceTool.new();roof_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roof=Node3D.new();roof.name="HullRoof";parent.add_child(roof)
 for i in 144:
  var a=i*TAU/144;var b=(i+1)*TAU/144
  var pa=HULL_CENTER+Vector2(sin(a),-cos(a))*HULL_RADII
  var pb=HULL_CENTER+Vector2(sin(b),-cos(b))*HULL_RADII
  for point in [Vector3(HULL_CENTER.x,0,HULL_CENTER.y),Vector3(pa.x,0,pa.y),Vector3(pb.x,0,pb.y)]:
   floor_mesh.set_normal(Vector3.UP);floor_mesh.add_vertex(point)
  for ring in 16:
   var vertices:Array[Vector3]=[]
   for spec in [[a,ring],[b,ring],[b,ring+1],[a,ring+1]]:
    var r=float(spec[1])/16;var p=HULL_CENTER+Vector2(sin(spec[0]),-cos(spec[0]))*(HULL_RADII-Vector2.ONE*0.34)*r
    vertices.append(Vector3(p.x,3.03-0.68*r*r,p.y))
   for k in [0,1,2,0,2,3]:
    var v=vertices[k];var q=Vector2(v.x,v.z)-HULL_CENTER;var radii=HULL_RADII-Vector2.ONE*0.34
    roof_mesh.set_normal(Vector3(-1.36*q.x/(radii.x*radii.x),-1,-1.36*q.y/(radii.y*radii.y)).normalized());roof_mesh.add_vertex(v)
  # Six smooth deck segments share one structural porthole bay.
  if i%6==0:
   var end=HULL_CENTER+Vector2(sin(a+TAU/24),-cos(a+TAU/24))*HULL_RADII
   hull_segment(parent,pa,end,i in [30,72,108],i in [0,6,12,126,132,138],i in [12,126,132])
 var deck=MeshInstance3D.new();deck.mesh=floor_mesh.commit();deck.material_override=material(Color("897c69"));parent.add_child(deck);deck.create_trimesh_collision()
 var ceiling=MeshInstance3D.new();ceiling.mesh=roof_mesh.commit();ceiling.material_override=material(PAPER);roof.add_child(ceiling);ceiling.create_trimesh_collision()
 for r in [0.40,0.74,0.96]:
  var path:Array[Vector3]=[];var light:Array[Vector3]=[]
  for i in 97:
   var a=i*TAU/96;var p=HULL_CENTER+Vector2(sin(a),-cos(a))*(HULL_RADII-Vector2.ONE*0.34)*r
   path.append(Vector3(p.x,2.99-0.68*r*r,p.y));light.append(Vector3(p.x,2.93-0.68*r*r,p.y))
  tube(roof,path,0.045,Color("b2a184"))
  if r!=0.40:tube(roof,light,0.022,Color("f4cc94"),true)
 # Radial structural ribs make the curved plan readable from inside.
 for i in 8:
  var a=i*TAU/8;var path:Array[Vector3]=[]
  for k in 25:
   var r=float(k)/24;var p=HULL_CENTER+Vector2(sin(a),-cos(a))*(HULL_RADII-Vector2.ONE*0.34)*r
   path.append(Vector3(p.x,2.97-0.68*r*r,p.y))
  tube(roof,path,0.032,Color("c9b898"))

func strut(parent:Node3D,a:Vector3,b:Vector3,width:float,depth:float,color:Color) -> void:
 var member=box(parent,(a+b)*0.5,Vector3(width,a.distance_to(b),depth),color)
 member.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

func console_pod(parent:Node3D,width:float,depth:float) -> void:
 # Rounded metal side consoles, with a thin rolled edge and a recessed base.
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings:Array=[]
 for layer in [[0.18,0.72],[0.24,0.78],[0.65,1.0],[0.71,1.0],[0.75,0.93]]:
  var contour:Array[Vector3]=[];var radius=0.105*layer[1]
  for corner in 4:
   var sx=1.0 if corner in [0,3] else -1.0
   var sz=1.0 if corner in [0,1] else -1.0
   for step in 9:
    var angle=corner*PI/2+step*PI/16
    var x=sx*(width*0.5*layer[1]-radius)+cos(angle)*radius
    var z=sz*(depth*0.5*layer[1]-radius)+sin(angle)*radius
    contour.append(Vector3(x,layer[0]-z/depth*0.14,z))
  rings.append(contour)
 for layer in range(rings.size()-1):
  for j in 36:
   var next=(j+1)%36
   var vertices=[rings[layer][j],rings[layer][next],rings[layer+1][next],rings[layer+1][j]]
   for k in [0,1,2,0,2,3]:st.add_vertex(vertices[k])
 # Top faces upward, with a separate normal from the rounded side wall.
 st.generate_normals()
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(PAPER);parent.add_child(mesh)
 var cap:Array[Vector3]=[]
 for point in rings[-1]:cap.append(point)
 cap.reverse();panel(parent,cap,TRIM)
 var rim:Array[Vector3]=[]
 for point in rings[-2]:rim.append(point)
 rim.append(rim[0]);tube(parent,rim,0.012,BRASS)
 var body=StaticBody3D.new();var collider=CollisionShape3D.new();var bounds=BoxShape3D.new()
 bounds.size=Vector3(width,0.82,depth);collider.shape=bounds;collider.position.y=0.41;body.add_child(collider);parent.add_child(body)

func instrument(parent:Node3D,pos:Vector3,angle:float,radar:bool=false) -> void:
 var root=Node3D.new();root.position=pos;root.rotation=Vector3(-0.45,angle,0);parent.add_child(root)
 box(root,Vector3.ZERO,Vector3(0.58,0.30,0.025),Color("15232d"))
 box(root,Vector3(0,0,0.016),Vector3(0.53,0.25,0.003),Color("15232d"))
 var ink=Color("bf7937")
 if radar:
  for radius in [0.04,0.075,0.108]:
   var points:Array[Vector3]=[]
   for k in 65:points.append(Vector3(cos(k*TAU/64)*radius,sin(k*TAU/64)*radius,0.022))
   tube(root,points,0.0015,ink,true)
  for side in [-1,1]:box(root,Vector3(side*0.19,0,0.022),Vector3(0.065,0.003,0.002),ink,false,true)
 else:
  # Idle linework only: no invented fuel, destination, ownership or flight state.
  for y in [-0.075,0.01,0.09]:
   box(root,Vector3(-0.11,y,0.022),Vector3(0.20,0.003,0.002),ink,false,true)
   box(root,Vector3(0.15,y,0.022),Vector3(0.10,0.003,0.002),Color("557f8b"),false,true)
 for x in [-0.26,0.26]:box(root,Vector3(x,-0.11,0.023),Vector3(0.008,0.015,0.002),ink,false,true)

func console(parent:Node3D) -> void:
 var root=Node3D.new();root.position=Vector3(0,0,-3.75);parent.add_child(root)
 # HOTAS-like controls and angled side panels surround one low pilot seat.
 for side in [-1,1]:
  var wing=Node3D.new();wing.position=Vector3(side*0.76,0,0.02);wing.rotation.y=side*0.27;root.add_child(wing)
  console_pod(wing,0.50,1.35)
  instrument(wing,Vector3(0,1.00,-0.44),side*0.40)
  for j in 4:
   box(wing,Vector3(-0.14+j*0.095,0.78,-0.10),Vector3(0.06,0.015,0.08),Color("778b91"))
   box(wing,Vector3(-0.14+j*0.095,0.795,-0.10),Vector3(0.025,0.003,0.008),Color("bd8146"),false,true)
  box(wing,Vector3(0,0.76,0.28),Vector3(0.23,0.035,0.23),Color("17232c"))
  if side>0:
   strut(wing,Vector3(0,0.80,0.28),Vector3(-0.025,1.01,0.24),0.04,0.04,TRIM)
   var grip=box(wing,Vector3(-0.025,1.05,0.24),Vector3(0.085,0.13,0.075),Color("1a242d"));grip.rotation.x=-0.20
   cylinder(wing,Vector3(-0.025,1.12,0.24),0.018,0.008,Color("c0894c"))
  else:
   for x in [-0.07,0.07]:strut(wing,Vector3(x,0.80,0.26),Vector3(x,0.92,0.16),0.02,0.025,TRIM)
   box(wing,Vector3(0,0.94,0.16),Vector3(0.20,0.065,0.09),Color("17232c"))
 # Low brow leaves the panorama clear; its centre display sits beneath eye level.
 var brow=box(root,Vector3(0,0.77,-0.86),Vector3(1.65,0.065,0.40),TRIM,true);brow.rotation.x=-0.14
 instrument(root,Vector3(0,0.94,-0.87),0,true)
 for x in [-0.56,0.56]:instrument(root,Vector3(x,0.94,-0.79),-x*0.5)
 label(root,"STANDBY",Vector3(0,0.68,-0.63),0,17,BRASS)
 # Formed seat shell: separate fabric pads, exposed frame and harness.
 for x in [-0.20,0.20]:box(root,Vector3(x,0.15,0.35),Vector3(0.075,0.30,0.65),TRIM)
 box(root,Vector3(0,0.43,0.35),Vector3(0.64,0.065,0.66),PAPER,true)
 box(root,Vector3(0,0.49,0.35),Vector3(0.50,0.055,0.53),Color("b5734d"))
 var back=Node3D.new();back.position=Vector3(0,0.86,0.65);back.rotation.x=0.10;root.add_child(back)
 box(back,Vector3.ZERO,Vector3(0.64,0.82,0.12),PAPER,true)
 for y in [-0.20,0.12]:box(back,Vector3(0,y,-0.045),Vector3(0.49,0.27,0.04),Color("b5734d"))
 box(back,Vector3(0,0.47,0),Vector3(0.39,0.18,0.12),Color("b5734d"))
 for side in [-1,1]:
  strut(back,Vector3(side*0.17,0.37,-0.075),Vector3(side*0.08,-0.29,-0.075),0.035,0.012,Color("25323c"))
  strut(root,Vector3(side*0.34,0.40,0.62),Vector3(side*0.34,0.69,0.47),0.035,0.04,TRIM)
  box(root,Vector3(side*0.34,0.70,0.36),Vector3(0.075,0.035,0.37),TRIM)
 # Foot pedals and deck rails remain low; no freestanding walls around the cockpit.
 for side in [-1,1]:
  var foot=box(root,Vector3(side*0.17,0.13,-0.22),Vector3(0.19,0.035,0.25),Color("6b7b7e"));foot.rotation.x=0.30
  box(root,Vector3(side*0.42,0.025,0.27),Vector3(0.04,0.03,1.1),TRIM)
 # Two outer canopy spars carry a small overhead panel, leaving the centre open.
 for side in [-1,1]:
  strut(parent,Vector3(side*2.65,0.60,-4.65),Vector3(side*1.25,2.55,-3.5),0.065,0.10,TRIM)
 box(parent,Vector3(0,2.60,-3.40),Vector3(1.20,0.07,0.32),TRIM)
 for x in [-0.35,0,0.35]:box(parent,Vector3(x,2.55,-3.40),Vector3(0.20,0.015,0.15),Color("6c777b"))

# Low-profile luminous fixtures: a warm diffuser inside a machined housing.
# These are static batched meshes; room lighting retains its existing six lights.
func halo(parent:Node3D,pos:Vector3,radius:float) -> void:
 var root=Node3D.new();root.position=pos;parent.add_child(root)
 cylinder(root,Vector3(0,0.17,0),0.035,0.30,BRASS)
 cylinder(root,Vector3(0,0.045,0),radius*0.72,0.07,PAPER)
 cylinder(root,Vector3(0,0.005,0),radius*0.40,0.03,WOOD)
 for spec in [[radius,0.036,TRIM,false],[radius-0.046,0.025,Color("ffe0a6"),true],[radius+0.043,0.008,BRASS,false]]:
  var path:Array[Vector3]=[]
  for i in 97:path.append(Vector3(cos(i*TAU/96)*spec[0],-0.035,sin(i*TAU/96)*spec[0]))
  tube(root,path,spec[1],spec[2],spec[3])
 for i in 3:
  var a=i*TAU/3
  beam(root,Vector3(cos(a)*radius*0.55,0.015,sin(a)*radius*0.55),Vector3(cos(a)*radius,-0.015,sin(a)*radius),0.014,BRASS)

func strip_lamp(parent:Node3D,pos:Vector3,length:float) -> void:
 box(parent,pos,Vector3(length,0.085,0.14),TRIM)
 box(parent,pos+Vector3(0,-0.048,0),Vector3(length-0.12,0.018,0.085),Color("ffdfa7"),false,true)
 for side in [-1,1]:box(parent,pos+Vector3(side*(length/2-0.04),0,0),Vector3(0.035,0.09,0.15),BRASS)

func lighting_details(parent:Node3D) -> void:
 var roof=parent.get_node("HullRoof")
 halo(roof,Vector3(0,2.82,0.15),0.54)
 for x in [-2.65,2.65]:halo(roof,Vector3(x,2.55,2.5),0.30)
 for x in [-2.1,2.1]:halo(roof,Vector3(x,2.40,4.6),0.24)
 # Bulkhead luminaires: frosted discs in a ribbed housing, facing the lounge.
 for side in [-1,1]:
  var root=Node3D.new();root.position=Vector3(side*2.5,1.82,0.99);root.rotation.x=-PI/2;parent.add_child(root)
  cylinder(root,Vector3.ZERO,0.22,0.07,TRIM)
  cylinder(root,Vector3(0,0.045,0),0.18,0.025,BRASS)
  var lens=cylinder(root,Vector3(0,0.065,0),0.15,0.025,Color("ffe4b6"))
  lens.material_override=material(Color("ffe4b6"),true)
  for i in 3:
   var a=i*TAU/3
   box(root,Vector3(cos(a)*0.19,0.07,sin(a)*0.19),Vector3(0.025,0.04,0.025),TRIM)
  # Slim panel joints and a fitted colour insert identify the living shoulder.
  box(parent,Vector3(side*2.5,1.14,1.011),Vector3(1.7,0.19,0.025),Color("74917b"))
  for x in [-0.65,-0.56,-0.47]:box(parent,Vector3(side*2.5+x,1.14,0.99),Vector3(0.018,0.11,0.015),BRASS)
 # Bow eyebrow: small amber optics, recessed into the pilot overhead panel.
 for x in [-0.35,0,0.35]:
  cylinder(parent,Vector3(x,2.535,-3.40),0.065,0.025,BRASS)
  var lens=cylinder(parent,Vector3(x,2.518,-3.40),0.048,0.012,Color("ffe0a6"))
  lens.material_override=material(Color("ffe0a6"),true)
 # A gentle deck border replaces the giant triangular floor facets.
 for r in [0.87,0.89]:
  var path:Array[Vector3]=[]
  for i in 145:
   var a=i*TAU/144;var p=HULL_CENTER+Vector2(sin(a),-cos(a))*HULL_RADII*r
   path.append(Vector3(p.x,0.008,p.y))
  tube(parent,path,0.008,Color("d6b57d"))
 # Recessed seams in a narrow central walking strip, not a radial room grid.
 for x in [-0.69,0.69]:beam(parent,Vector3(x,0.006,-1.1),Vector3(x,0.006,5.8),0.008,Color("725c45"))

func fittings(parent:Node3D) -> void:
 # Owner: machinery is beneath the deck. Only flush service access remains above it.
 for side in [-1,1]:
  var hatch_plate=box(parent,Vector3(side*2.4,0.012,-2.6),Vector3(1.1,0.02,0.75),Color("8d795e"))
  for x in [-0.44,0.44]:
   for z in [-0.27,0.27]:cylinder(hatch_plate,Vector3(x,0.014,z),0.018,0.006,Color("89979a"))
  box(hatch_plate,Vector3(0,0.014,0),Vector3(0.18,0.008,0.025),TRIM)
 # Short central access spine; all four rooms share it, not separate corridors.
 for x in [-0.85,0.85]:
  for segment in [[1.1,1.58],[3.02,4.08],[5.52,6.6]]:bulkhead(parent,Vector2(x,segment[0]),Vector2(x,segment[1]))
 for side in [-1,1]:
  bulkhead(parent,Vector2(side*0.85,1.1),Vector2(side*5.1,1.1))
  bulkhead(parent,Vector2(side*0.85,3.6),Vector2(side*4.6,3.6))
 hatch(parent,-0.85,2.3,"WORKSHOP",PI/2);hatch(parent,0.85,2.3,"ARCHIVE",-PI/2)
 hatch(parent,-0.85,4.8,"CABIN",PI/2);hatch(parent,0.85,4.8,"WARDROBE",-PI/2)
 for x in [-0.52,0.52]:box(parent,Vector3(x,0.015,3.55),Vector3(0.02,0.02,5),Color("b9d8c9"),false,true)
 # Aft floor access also serves the under-deck plant, with no machinery cabinet.
 box(parent,Vector3(0,0.012,6.0),Vector3(1.15,0.02,0.65),Color("8d795e"))
 box(parent,Vector3(0,0.026,6.0),Vector3(0.20,0.008,0.025),TRIM)
 # Two-person dinette fitted into the forward starboard shoulder.
 var booth=Node3D.new();booth.position=Vector3(3.35,0,-0.62);booth.rotation.y=-0.50;parent.add_child(booth)
 box(booth,Vector3(0,0.26,0),Vector3(1.75,0.52,0.72),TRIM,true)
 box(booth,Vector3(0,0.57,0),Vector3(1.74,0.14,0.73),Color("c77f50"))
 box(booth,Vector3(0,0.88,-0.29),Vector3(1.78,0.65,0.18),Color("698773"))
 var top=cylinder(booth,Vector3(0,0.74,0.68),0.48,0.07,WOOD);top.scale.x=1.35
 cylinder(booth,Vector3(0,0.36,0.68),0.08,0.72,TRIM)
 # Upholstery seams and a practical reading strip finish the fitted dinette.
 for x in [-0.55,0,0.55]:
  box(booth,Vector3(x,0.94,-0.185),Vector3(0.012,0.42,0.008),Color("9cad8b"))
 strip_lamp(booth,Vector3(0,1.91,-0.24),1.22)
 # Small galley integrated into the opposite shoulder, with overhead storage.
 var galley=Node3D.new();galley.position=Vector3(-3.65,0,-0.85);galley.rotation.y=0.5;parent.add_child(galley)
 box(galley,Vector3(0,0.42,0),Vector3(1.7,0.84,0.64),Color("74917b"),true)
 box(galley,Vector3(0,0.88,0),Vector3(1.74,0.08,0.70),WOOD)
 box(galley,Vector3(0,1.91,-0.23),Vector3(1.7,0.52,0.3),PAPER)
 strip_lamp(galley,Vector3(0,1.62,-0.14),1.47)
 for x in [-0.56,0,0.56]:
  box(galley,Vector3(x,0.44,0.329),Vector3(0.52,0.70,0.025),Color("7f9c85"))
  box(galley,Vector3(x,1.90,-0.068),Vector3(0.52,0.44,0.025),Color("e2cdae"))
 for x in [-0.52,0,0.52]:box(galley,Vector3(x,0.5,0.33),Vector3(0.42,0.035,0.025),BRASS)
 cylinder(galley,Vector3(-0.5,0.98,0),0.08,0.17,PAPER)
 box(galley,Vector3(0.3,0.93,0),Vector3(0.5,0.025,0.40),Color("243b43"))
 # Workshop bench along the short transverse bulkhead.
 box(parent,Vector3(-2.85,0.82,1.48),Vector3(2.65,0.12,0.62),PAPER,true)
 for x in [-3.8,-1.9]:box(parent,Vector3(x,0.4,1.48),Vector3(0.57,0.8,0.6),TRIM,true)
 box(parent,Vector3(-2.85,1.65,1.23),Vector3(2.65,0.97,0.12),TRIM)
 for i in 5:
  var x=-3.75+i*0.43
  box(parent,Vector3(x,1.60,1.32),Vector3(0.05,0.30,0.04),BRASS)
  box(parent,Vector3(x,1.76,1.32),Vector3(0.16,0.06,0.04),BRASS)
 strip_lamp(parent,Vector3(-2.85,2.18,1.41),2.4)
 # Display storage shares a compact bay; empty until real owned rewards connect.
 for x in [1.65,2.65,3.65]:
  box(parent,Vector3(x,1.25,1.30),Vector3(0.87,2.1,0.25),TRIM)
  box(parent,Vector3(x,0.4,1.48),Vector3(0.87,0.8,0.53),Color("7f9c85"),true)
  box(parent,Vector3(x,0.83,1.48),Vector3(0.90,0.04,0.55),BRASS)
  box(parent,Vector3(x,2.22,1.47),Vector3(0.70,0.025,0.025),Color("9dc6c8"),false,true)
 # Single berth follows the tapering aft hull; storage occupies its plinth.
 var berth=Node3D.new();berth.position=Vector3(-2.7,0,4.5);berth.rotation.y=1.10;parent.add_child(berth)
 box(berth,Vector3(0,0.28,0),Vector3(1.0,0.56,1.72),TRIM,true)
 box(berth,Vector3(0,0.61,0),Vector3(0.94,0.16,1.65),Color("c8b99a"))
 box(berth,Vector3(0,0.73,-0.18),Vector3(0.95,0.09,1.25),Color("b36549"))
 box(berth,Vector3(0,0.76,0.55),Vector3(0.78,0.18,0.36),Color("dfd0b1"))
 for z in [-0.88,0.88]:
  arch(berth,0,z,1.10,0.74,0.90,0.075,PAPER)
  arch(berth,0,z-0.06,0.96,0.74,0.80,0.012,Color("d5b58b"),true)
 # Woven cover seams and a small head-end reading light.
 for z in [-0.70,-0.55,-0.40]:box(berth,Vector3(0,0.778,z),Vector3(0.90,0.004,0.022),Color("dba975"))
 strip_lamp(berth,Vector3(0,1.47,0.83),0.65)
 for z in [-0.55,0.18]:box(berth,Vector3(0.51,0.30,z),Vector3(0.025,0.035,0.45),BRASS)
 # Outfitting lockers follow the other aft shoulder, leaving a standing alcove.
 var wardrobe=Node3D.new();wardrobe.position=Vector3(3.05,0,4.9);wardrobe.rotation.y=0.80;parent.add_child(wardrobe)
 for x in [-0.68,0.68]:
  box(wardrobe,Vector3(x,1.02,0),Vector3(0.61,2.04,0.48),TRIM,true)
  for y in [0.45,1.12,1.78]:box(wardrobe,Vector3(x,y,-0.26),Vector3(0.53,0.04,0.25),Color("78908e"))
 box(wardrobe,Vector3(0,1.04,0.12),Vector3(0.64,1.98,0.10),Color("4d707f"),true)
 strip_lamp(wardrobe,Vector3(0,2.10,-0.10),1.95)

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
 env.environment.ambient_light_color=Color("eee5d6");env.environment.ambient_light_energy=0.40
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;parent.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-28,0);sun.light_color=Color("c1d4e8");sun.light_energy=0.22
 sun.shadow_enabled=false;sun.directional_shadow_max_distance=38;parent.add_child(sun)
 var bridge_light=SpotLight3D.new();bridge_light.position=Vector3(0,2.75,-1.8);bridge_light.rotation_degrees.x=-90
 bridge_light.light_color=Color("ffe1b8");bridge_light.light_energy=0.70;bridge_light.spot_range=6;bridge_light.spot_angle=65
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
 saucer(parent);console(parent);fittings(parent);lighting_details(parent)
 # Warm local pools, with no wasteful full-height glazing or cavernous room lights.
 for p in [Vector3(0,2.35,-2.3),Vector3(0,2.5,0.2),Vector3(-2.8,2.2,2.5),Vector3(2.8,2.2,2.5),Vector3(-2.2,2.1,4.8),Vector3(2.2,2.1,4.8)]:
  var light=OmniLight3D.new();light.position=p;light.light_color=Color("ffe1b8");light.light_energy=0.80;light.omni_range=4.0;parent.add_child(light)

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
    var leaf=MeshInstance3D.new();var shape=SphereMesh.new();shape.radius=0.1;shape.height=0.64;shape.radial_segments=24;shape.rings=16
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
   var pad=cylinder(root,Vector3(0,0.015,0),1.4,0.025,Color("b36343"));pad.scale.z=0.7
 if solid and id!="rug":
  var body=StaticBody3D.new();body.collision_layer=2;body.collision_mask=0
  var c=CollisionShape3D.new();var b=BoxShape3D.new();var f=footprint(id)
  b.size=Vector3(f.x,1.0 if id=="armchair" else 0.6,f.y);c.shape=b;c.position.y=b.size.y/2
  body.add_child(c);root.add_child(body)
 return root

func batch_static(parent:Node3D) -> void:
 # One mesh per shared material for fixed room geometry; collision bodies stay.
 # Movable furniture and the host avatar are created afterwards and stay separate.
 if parent.has_node("HullRoof"):batch_static(parent.get_node("HullRoof"))
 var groups:Dictionary={}
 var originals:Array[MeshInstance3D]=[]
 for node in parent.find_children("*","MeshInstance3D",true,false):
  if node.get_meta("collision_only",false) or (parent.name!="HullRoof" and node.find_parent("HullRoof")!=null):continue
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
