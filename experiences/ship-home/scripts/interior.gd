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
 "Cockpit": Rect2(-1.85,-5.6,3.7,3.6), "Studio": Rect2(-5.3,-2.0,10.6,8.8)}
const LIFT = Vector2(-1.6,3.65)
const SHAFT_RADIUS = 0.84
const LOWER_Y = -2.65
const BOOTH = Vector3(2.45,0,3.95)

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

func panel(parent:Node3D, vertices:Array[Vector3], color:Color, solid:bool=false) -> MeshInstance3D:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Facing is explicit in the vertex ordering; collision uses the same surface.
 for i in range(1,vertices.size()-1):
  var normal=(vertices[i]-vertices[0]).cross(vertices[i+1]-vertices[0]).normalized()
  for k in [0,i+1,i]:st.set_normal(normal);st.add_vertex(vertices[k])
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(color);parent.add_child(mesh)
 if solid:mesh.create_trimesh_collision()
 return mesh

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
 var underside=SurfaceTool.new();underside.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roof_mesh=SurfaceTool.new();roof_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roof=Node3D.new();roof.name="HullRoof";parent.add_child(roof)
 for i in 144:
  var a=i*TAU/144;var b=(i+1)*TAU/144
  var pa=HULL_CENTER+Vector2(sin(a),-cos(a))*HULL_RADII
  var pb=HULL_CENTER+Vector2(sin(b),-cos(b))*HULL_RADII
  # An annulus around the lift leaves a real shaft through the pressure deck.
  var ia=LIFT+(pa-LIFT).normalized()*SHAFT_RADIUS
  var ib=LIFT+(pb-LIFT).normalized()*SHAFT_RADIUS
  for point in [ia,pa,pb,ia,pb,ib]:
   floor_mesh.set_normal(Vector3.UP);floor_mesh.add_vertex(Vector3(point.x,0,point.y))
  for point in [ib,pb,pa,ib,pa,ia]:
   underside.set_normal(Vector3.DOWN);underside.add_vertex(Vector3(point.x,-0.14,point.y))
  var shaft_normal=Vector3(LIFT.x-ia.x,0,LIFT.y-ia.y).normalized()
  for vertex in [Vector3(ia.x,0,ia.y),Vector3(ib.x,0,ib.y),Vector3(ib.x,-0.14,ib.y),Vector3(ia.x,0,ia.y),Vector3(ib.x,-0.14,ib.y),Vector3(ia.x,-0.14,ia.y)]:
   underside.set_normal(shaft_normal);underside.add_vertex(vertex)
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
 var deck=MeshInstance3D.new();deck.mesh=floor_mesh.commit();deck.material_override=material(Color("897c69")).duplicate();deck.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;parent.add_child(deck);deck.create_trimesh_collision()
 for collider in deck.find_children("*","CollisionShape3D",true,false):
  collider.shape.backface_collision=true
 var liner=MeshInstance3D.new();liner.mesh=underside.commit();liner.material_override=material(Color("59666a")).duplicate();liner.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;parent.add_child(liner)
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
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(Color("45515a"));parent.add_child(mesh)
 var cap:Array[Vector3]=[]
 for point in rings[-1]:cap.append(point)
 cap.reverse();panel(parent,cap,TRIM)
 var rim:Array[Vector3]=[]
 for point in rings[-2]:rim.append(point)
 rim.append(rim[0]);tube(parent,rim,0.012,BRASS)
 var body=StaticBody3D.new();var collider=CollisionShape3D.new();var bounds=BoxShape3D.new()
 bounds.size=Vector3(width,0.82,depth);collider.shape=bounds;collider.position.y=0.41;body.add_child(collider);parent.add_child(body)

# Rounded octagonal sections describe the castings and upholstery. Each row is
# (height, half-width, front Z, back Z), so the chair narrows through the waist.
func formed_shell(parent:Node3D,rows:Array[Vector4],color:Color) -> void:
 var previous: Array[Vector3]=[]
 for row in rows:
  var x:=row.y;var f:=row.z;var b:=row.w
  var bevel:=minf(x*0.42,(b-f)*0.30)
  var ring:Array[Vector3]=[]
  for point:Vector2 in [Vector2(-x+bevel,f),Vector2(x-bevel,f),Vector2(x,f+bevel),Vector2(x,b-bevel),Vector2(x-bevel,b),Vector2(-x+bevel,b),Vector2(-x,b-bevel),Vector2(-x,f+bevel)]:
   ring.append(Vector3(point.x,row.x,point.y))
  if previous.is_empty():panel(parent,ring,color)
  else:
   for j in ring.size():
    var k:=(j+1)%ring.size()
    panel(parent,[previous[j],ring[j],ring[k],previous[k]],color)
  previous=ring
 previous.reverse();panel(parent,previous,color)

const SEAT_RAIL=Vector3(0,0.10,-0.37)
var helm_root:Node3D
var stick:Node3D
var throttle:Node3D
var left_grip:Marker3D
var right_grip:Marker3D
var horizon_dial:Node3D
var ladder:Node3D
var radar:Node3D
var contact:MeshInstance3D
var field_stars:MultiMeshInstance3D
var sky_environment:Environment

func pilot_seat(root:Node3D) -> void:
 var frame:=Color("364854");var leather:=Color("784e3a");var pad:=Color("b5734d")
 # Twin slide rails and a shock pedestal below the single-piece seat pan.
 for side in [-1,1]:
  box(root,Vector3(side*0.25,0.055,0.30),Vector3(0.09,0.085,0.84),frame)
  strut(root,Vector3(side*0.24,0.10,0.55),Vector3(side*0.18,0.37,0.16),0.066,0.075,BRASS)
 cylinder(root,Vector3(0,0.23,0.34),0.23,0.28,frame,0.16)
 formed_shell(root,[Vector4(0.35,0.27,0.03,0.69),Vector4(0.43,0.34,0.15,0.76),Vector4(0.48,0.32,0.15,0.74)],frame)
 box(root,Vector3(0,0.45,0.44),Vector3(0.58,0.12,0.50),leather,true)
 box(root,Vector3(0,0.50,0.41),Vector3(0.49,0.086,0.40),pad)
 # The reclined back, scapular wings and neck cushion follow the same rake.
 var back:=Node3D.new();back.position=Vector3(0,0.47,0.50);back.rotation.x=0.16;root.add_child(back)
 formed_shell(back,[Vector4(0,0.27,0,0.15),Vector4(0.22,0.29,0,0.18),Vector4(0.53,0.39,0,0.20),Vector4(0.68,0.36,0.02,0.20),Vector4(0.79,0.20,0.045,0.17)],frame)
 box(back,Vector3(0,0.36,0.08),Vector3(0.55,0.74,0.15),frame,true)
 for i in 4:
  box(back,Vector3(0,0.10+i*0.145,-0.017),Vector3(0.40+0.032*i,0.136,0.11),pad)
 box(back,Vector3(0,0.81,0.065),Vector3(0.40,0.23,0.15),leather)
 # An inset rear service panel and the shoulder handle are visible on boarding.
 box(back,Vector3(0,0.42,0.197),Vector3(0.37,0.39,0.028),Color("24343c"))
 for i in 4:
  box(back,Vector3(0,0.32+i*0.064,0.217),Vector3(0.24-i*0.014,0.018,0.021),Color("637580"))
 tube(back,[Vector3(-0.16,0.68,0.17),Vector3(-0.13,0.71,0.226),Vector3(0.13,0.71,0.226),Vector3(0.16,0.68,0.17)],0.022,BRASS)
 for side in [-1,1]:
  var cheek=box(back,Vector3(side*0.274,0.43,-0.022),Vector3(0.12,0.41,0.15),leather)
  cheek.rotation.z=-side*0.19
  var bolster=box(root,Vector3(side*0.29,0.53,0.35),Vector3(0.12,0.13,0.51),leather)
  bolster.rotation.z=side*0.15
  strut(back,Vector3(side*0.18,0.63,-0.085),Vector3(side*0.115,0.10,-0.087),0.043,0.016,Color("333a3a"))
  box(back,Vector3(side*0.12,0.15,-0.099),Vector3(0.055,0.062,0.018),BRASS)
  strut(back,Vector3(side*0.23,0.09,0.18),Vector3(side*0.29,0.56,0.21),0.052,0.045,Color("637580"))
  box(back,Vector3(side*0.22,0.61,0.204),Vector3(0.14,0.040,0.018),BRASS)
  strut(root,Vector3(side*0.32,0.42,0.57),Vector3(side*0.38,0.70,0.38),0.06,0.075,frame)
  box(root,Vector3(side*0.38,0.71,0.30),Vector3(0.13,0.075,0.41),leather)

func scope_arc(parent:Node3D,origin:Vector3,radius:float,start:float,end:float,color:Color,wire:float) -> void:
 var path:Array[Vector3]=[]
 for i in 49:
  var a:=lerpf(start,end,i/48.0)
  path.append(origin+Vector3(sin(a)*radius,0,cos(a)*radius))
 tube(parent,path,wire,color,true)

func flight_deck(root:Node3D) -> void:
 var graphite:=Color("283945");var inset:=Color("18262e");var amber:=Color("d3833a")
 # A single recessed island ties chair rails, side consoles and dash to the deck.
 formed_shell(root,[Vector4(0.006,0.86,-1.14,0.94),Vector4(0.029,0.83,-1.12,0.92)],Color("475453"))
 for side in [-1,1]:
  strut(root,Vector3(side*0.81,0.53,-0.98),Vector3(side*1.28,0.51,-1.45),0.12,0.14,graphite)
 # A low wraparound coaming with an inclined, open-faced navigation scope.
 var dash:=Node3D.new();dash.position=Vector3(0,0,-0.84);root.add_child(dash)
 formed_shell(dash,[Vector4(0.38,0.49,-0.09,0.13),Vector4(0.72,0.94,-0.22,0.19),Vector4(0.80,1.02,-0.24,0.20),Vector4(0.84,0.96,-0.21,0.18)],graphite)
 box(dash,Vector3(0,0.67,0),Vector3(1.72,0.26,0.34),graphite,true)
 var scope:=Node3D.new();scope.position=Vector3(0,0.895,0.018);scope.rotation.x=0.22;dash.add_child(scope)
 radar=scope
 cylinder(scope,Vector3.ZERO,0.265,0.045,graphite)
 cylinder(scope,Vector3.UP*0.024,0.252,0.012,inset)
 var center:=Vector3.UP*0.042
 for radius in [0.08,0.155,0.235]:scope_arc(scope,center,radius,0,TAU,amber if radius>0.20 else Color("805733"),0.0024)
 for i in 12:
  var direction:=Vector3(sin(i*TAU/12),0,cos(i*TAU/12))
  beam(scope,center+direction*0.205,center+direction*0.233,0.003,amber,true)
 for i in 4:
  var d:=Vector3(sin(i*PI/2),0,cos(i*PI/2))
  beam(scope,center+d*0.078,center+d*0.205,0.002,Color("795d3a"),true)
 for x in [-0.042,0.042]:beam(scope,center+Vector3(x,0.001,0.036),center+Vector3(0,0.002,-0.045),0.004,amber,true)
 # Idle instruments use engraved scales and our own saucer's wire silhouette.
 for side in [-1,1]:
  var dial:=Node3D.new();dial.position=Vector3(side*0.56,0.916,0.015)
  dial.rotation=Vector3(0.38,-side*0.24,0);dash.add_child(dial)
  var bezel=box(dial,Vector3.ZERO,Vector3(0.43,0.045,0.32),inset)
  if side>0:
   scope_arc(bezel,Vector3.UP*0.032,0.13,PI*0.72,PI*2.28,Color("996837"),0.003)
   var outline:Array[Vector3]=[]
   for i in 41:
    var a:=i*TAU/40;outline.append(Vector3(0.096*cos(a),0.056,0.056*sin(a)))
   tube(dial,outline,0.004,amber,true)
   for axis in [Vector2(0.093,0),Vector2(0,0.053)]:
    var dome:Array[Vector3]=[]
    for i in 17:
     var a:=i*PI/16
     dome.append(Vector3(axis.x*cos(a),0.056+0.042*sin(a),axis.y*cos(a)))
    tube(dial,dome,0.0028,amber,true)
  else:
   horizon_dial=dial
   tube(dial,[Vector3(-0.038,0.041,0),Vector3(0,0.041,0.024),Vector3(0.038,0.041,0)],0.004,Color("8bb6b1"),true)
  # Recessed louvers under the tilted instrument castings.
  for j in 4:
   box(dash,Vector3(side*(0.43+j*0.083),0.757,0.193),Vector3(0.049,0.022,0.014),inset)
 root=helm_root
 for side in [-1,1]:
  var wing:=Node3D.new()
  wing.position=Vector3(side*0.32,0.0,0.13);wing.scale=Vector3(0.66,0.88,0.63);root.add_child(wing)
  console_pod(wing,0.32,0.94)
  for j in 3:
   box(wing,Vector3(-0.08+0.08*j,0.798,-0.34),Vector3(0.055,0.027,0.075),graphite)
  var pedal=box(root,Vector3(side*0.13,0.18,-0.045),Vector3(0.13,0.045,0.19),graphite);pedal.rotation.x=0.27
  for i in 3:box(pedal,Vector3(0,0.027,-0.055+i*0.046),Vector3(0.10,0.008,0.012),BRASS)

# Bearings are fixed to the consoles; these two moving assemblies are built after the cabin batch.
func moving_controls() -> void:
 stick=Node3D.new();throttle=Node3D.new();left_grip=Marker3D.new();right_grip=Marker3D.new()
 ladder=Node3D.new();horizon_dial.add_child(ladder)
 for i in range(-2,3):
  var span:=0.125 if i==0 else (0.072 if absi(i)==1 else 0.043)
  for edge in [-1,1]:
   beam(ladder,Vector3(edge*0.015,0.032,i*0.032),Vector3(edge*span,0.032,i*0.032),0.0028,Color("d3833a"),true)
 contact=box(radar,Vector3(0,0.052,-0.2),Vector3(0.018,0.012,0.018),Color("8dffe3"),false,true)
 for side in [-1,1]:
  var lever:=stick if side>0 else throttle
  helm_root.add_child(lever);lever.position=Vector3(side*0.265,0.715,0.18)
  cylinder(helm_root,lever.position,0.063,0.036,TRIM)
  var top:=Vector3(-side*0.018,0.090,0)
  strut(lever,Vector3.ZERO,top,0.034,0.036,TRIM)
  if side>0:
   var handle=cylinder(lever,top+Vector3.UP*0.018,0.025,0.105,Color("303e45"),0.031)
   handle.rotation.x=-0.12
   cylinder(lever,top+Vector3.UP*0.074,0.019,0.012,BRASS)
  else:
   var bar=box(lever,top,Vector3(0.095,0.047,0.060),Color("303e45"))
   for offset in [-0.027,0.027]:box(bar,Vector3(offset,0.025,0),Vector3(0.009,0.003,0.04),BRASS)
  var marker:=right_grip if side>0 else left_grip
  lever.add_child(marker);marker.position=top+Vector3(0,0.020,0)

func deflect(axes:Vector2,power:float) -> void:
 stick.rotation=Vector3(-axes.y*0.29,0,-axes.x*0.29)
 throttle.rotation.x=-power*0.54

func console(parent:Node3D) -> void:
 var root:=Node3D.new();root.position=Vector3(0,0,-3.75);parent.add_child(root)
 helm_root=Node3D.new();helm_root.position=SEAT_RAIL;root.add_child(helm_root)
 flight_deck(root);pilot_seat(helm_root)
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
 # Two-person dinette fitted into the forward starboard shoulder.
 var booth=Node3D.new();booth.position=Vector3(3.35,0,-0.62);booth.rotation.y=-0.50;parent.add_child(booth)
 box(booth,Vector3(0,0.26,0),Vector3(1.75,0.52,0.72),TRIM,true)
 box(booth,Vector3(0,0.57,0),Vector3(1.74,0.14,0.73),Color("c77f50"))
 box(booth,Vector3(0,0.88,-0.29),Vector3(1.78,0.65,0.18),Color("698773"))
 # The portable table serves both this banquette and the facing lounge chair.
 for side in [-1,1]:
  box(booth,Vector3(side*0.83,0.69,-0.01),Vector3(0.13,0.19,0.59),WOOD)
  box(booth,Vector3(side*0.83,0.76,-0.01),Vector3(0.14,0.055,0.58),Color("b5734d"))
 # Upholstery seams and a practical reading strip finish the fitted dinette.
 for x in [-0.55,0,0.55]:
  box(booth,Vector3(x,0.94,-0.185),Vector3(0.012,0.42,0.008),Color("9cad8b"))
 for x in [-0.56,0.56]:
  tube(booth,[Vector3(x,1.12,-0.33),Vector3(x,1.84,-0.33),Vector3(x,1.91,-0.24)],0.022,TRIM)
 strip_lamp(booth,Vector3(0,1.91,-0.24),1.22)
 # Small galley integrated into the opposite shoulder, with overhead storage.
 var galley=Node3D.new();galley.position=Vector3(-3.65,0,-0.85);galley.rotation.y=0.5;parent.add_child(galley)
 box(galley,Vector3(0,0.42,0),Vector3(1.7,0.84,0.64),Color("74917b"),true)
 box(galley,Vector3(0,0.88,0.085),Vector3(1.74,0.08,0.87),WOOD)
 # Clear counter edge and a footrail make a perch without another table.
 tube(galley,[Vector3(-0.63,0.24,0.32),Vector3(-0.63,0.24,0.48),Vector3(0.63,0.24,0.48),Vector3(0.63,0.24,0.32)],0.019,BRASS)
 box(galley,Vector3(0,1.91,-0.23),Vector3(1.7,0.52,0.3),PAPER)
 strip_lamp(galley,Vector3(0,1.62,-0.14),1.47)
 for x in [-0.56,0,0.56]:
  box(galley,Vector3(x,0.44,0.329),Vector3(0.52,0.70,0.025),Color("7f9c85"))
  box(galley,Vector3(x,1.90,-0.068),Vector3(0.52,0.44,0.025),Color("e2cdae"))
 for x in [-0.52,0,0.52]:box(galley,Vector3(x,0.5,0.33),Vector3(0.42,0.035,0.025),BRASS)
 box(galley,Vector3(0.3,0.93,0),Vector3(0.5,0.025,0.40),Color("243b43"))
 # Induction rings, sink and a curved tap share the compact galley surface.
 for x in [0.15,0.43]:
  var hob=cylinder(galley,Vector3(x,0.949,0),0.105,0.009,Color("679da2"))
  cylinder(hob,Vector3(0,0.006,0),0.081,0.008,TRIM)
 box(galley,Vector3(-0.41,0.944,0.10),Vector3(0.41,0.018,0.30),TRIM)
 tube(galley,[Vector3(-0.58,0.94,-0.08),Vector3(-0.58,1.18,-0.08),Vector3(-0.55,1.22,0.07),Vector3(-0.52,1.18,0.10)],0.018,BRASS)

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
 stars.multimesh=field;parent.add_child(stars);field_stars=stars;sky_environment=env.environment
 env.environment.sky=sky;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("eee5d6");env.environment.ambient_light_energy=0.40
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;parent.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-28,0);sun.light_color=Color("c1d4e8");sun.light_energy=0.22
 sun.shadow_enabled=false;sun.directional_shadow_max_distance=38;parent.add_child(sun)
 var bridge_light=SpotLight3D.new();bridge_light.position=Vector3(0,2.75,-1.8);bridge_light.rotation_degrees.x=-90
 bridge_light.light_color=Color("ffe1b8");bridge_light.light_energy=0.70;bridge_light.spot_range=6;bridge_light.spot_angle=65
 bridge_light.shadow_enabled=true;bridge_light.shadow_bias=0.08;bridge_light.shadow_normal_bias=1.5;parent.add_child(bridge_light)
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
   # Shield the light at eye level; aim the reading head toward the seating.
   var head:=Node3D.new();head.position=Vector3(0,1.56,-0.09);head.rotation.x=0.57;root.add_child(head)
   cylinder(head,Vector3(0,0.049,0),0.205,0.17,Color("698773"),0.092)
   cylinder(head,Vector3(0,-0.036,0),0.209,0.025,BRASS)
   var lens=cylinder(head,Vector3(0,-0.050,0),0.184,0.008,Color("e4c294"))
   lens.material_override=material(Color("e4c294"),true)
  "stool":
   cylinder(root,Vector3(0,0.6,0),0.32,0.16,Color("8eaa92"))
   for i in 3:
    var a=i*TAU/3;cylinder(root,Vector3(sin(a)*0.2,0.27,cos(a)*0.2),0.035,0.54,WOOD)
  "books":
   for i in 4:box(root,Vector3(0,0.045+i*0.075,0),Vector3(0.42,0.07,0.3),[Color("a55e48"),Color("d4b978"),TRIM,Color("6e8d80")][i])
  "rug":
   var pad=cylinder(root,Vector3(0,0.015,0),1.4,0.025,Color("a8634a"));pad.scale.z=0.7
   for r in [1.27,1.32]:
    var edge:Array[Vector3]=[]
    for i in 65:edge.append(Vector3(cos(i*TAU/64)*r,0.029,sin(i*TAU/64)*r*0.7))
    tube(root,edge,0.006,Color("cea27d"))
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
