# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShipInterior
extends RefCounted
# Original, editable geometry. Units are metres; +Z runs from lounge to cabins.
const PAPER = Color("e7e0d3")
const TRIM = Color("354a49")
const ENAMEL = Color("225b60")
const NIGHT = Color("273e48")
const COPPER = Color("bd815d")
const SEA_GLASS = Color("91dfd4")
const LAMP = Color("ffd5a2")
const WOOD = Color("a47c55")
const WALNUT = Color("996344")
const WEAVE = Color("59493c")
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
var deck_finish:=ShaderMaterial.new()

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
 elif color==ENAMEL or color==COPPER or color==NIGHT:
  m.metallic=0.45 if color==COPPER else 0.22;m.roughness=0.33 if color==ENAMEL else 0.46
 elif color==PAPER:m.metallic=0.08;m.roughness=0.55
 elif color==Color("637580"):m.metallic=0.30;m.roughness=0.48
 if color in [WOOD,Color("897c69"),Color("b5734d"),Color("c77f50"),Color("698773"),Color("b36549"),Color("b36343")]:
  var wood=color==WOOD
  m.albedo_texture=grain_texture(wood);m.uv1_triplanar=true;m.uv1_world_triplanar=true
  m.uv1_scale=Vector3(0.45,9,9) if wood else Vector3.ONE*18
  m.roughness=0.70 if wood else 0.95
 if color==WALNUT or color==WEAVE:
  var veneer:=color==WALNUT
  m.albedo_color=Color.WHITE
  m.albedo_texture=preload("res://assets/cabin/walnut-veneer.png") if veneer else preload("res://assets/cabin/bronze-weave.png")
  m.uv1_triplanar=true
  m.uv1_scale=Vector3(0.90,1.45,1.45) if veneer else Vector3.ONE*19.0
  m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  m.roughness=0.44 if veneer else 0.79
  m.metallic=0.0 if veneer else 0.16
 if glow: m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=1.3
 materials[key]=m;return m

# All bevels use the same normals, octants and triangles. Only the distance
# between opposite corners changes when fitting a box to a fixture.
var bevel_normals:=PackedVector3Array()
var bevel_corners:=PackedVector3Array()
var bevel_indices:=PackedInt32Array()

func _build_bevel_template() -> void:
 for axis in 3:
  var u:=(axis+1)%3;var v:=(axis+2)%3
  for side in [-1,1]:
   var base:=bevel_normals.size()
   for i in 8:
    for j in 8:
     var corner:=Vector3.ZERO
     corner[axis]=side;corner[u]=-1 if i<4 else 1;corner[v]=-1 if j<4 else 1
     var normal:=corner
     normal[u]=float(i-3 if i<4 else i-4)/3.0
     normal[v]=float(j-3 if j<4 else j-4)/3.0
     bevel_corners.append(corner);bevel_normals.append(normal.normalized())
   for i in 7:
    for j in 7:
     var n:=base+8*i+j
     for offset in ([0,9,8,0,1,9] if side>0 else [0,8,9,0,9,1]):
      bevel_indices.append(n+offset)

func rounded_box(size:Vector3) -> ArrayMesh:
 if meshes.has(size):return meshes[size]
 if bevel_normals.is_empty():_build_bevel_template()
 var half:=size*0.5
 var bevel:=minf(0.045,minf(size.x,minf(size.y,size.z))*0.26)
 var inner:=half-Vector3.ONE*bevel
 var vertices:=PackedVector3Array()
 vertices.resize(bevel_normals.size())
 for i in vertices.size():vertices[i]=bevel_corners[i]*inner+bevel_normals[i]*bevel
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=bevel_normals;arrays[Mesh.ARRAY_INDEX]=bevel_indices
 var result:=ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 meshes[size]=result
 return result

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

# Thin formed faceplates use a rounded outline and share the fixed cabin material batches.
func face_outline(size:Vector2,radius:float) -> Array[Vector3]:
 var contour:Array[Vector3]=[]
 var r:=minf(radius,minf(size.x,size.y)*0.5)
 for corner in 4:
  var mid_angle:float=(corner+0.5)*PI/2
  var center:=Vector2(signf(cos(mid_angle)),signf(sin(mid_angle)))*(size*0.5-Vector2.ONE*r)
  for step in 7:
   var angle:float=(corner+step/6.0)*PI/2
   var point:=center+Vector2(cos(angle),sin(angle))*r
   contour.append(Vector3(point.x,point.y,0))
 return contour

func faceplate(parent:Node3D,at:Vector3,size:Vector2,radius:float,color:Color,glow:=false) -> MeshInstance3D:
 var plate:=panel(parent,face_outline(size,radius),color);plate.position=at
 if glow:plate.material_override=material(color,true)
 return plate

# A bent veneer casing with rounded corners and a rolled front lip.
# The supplied origin is the front face; the shell extends behind it.
func veneer_case(parent:Node3D, at:Vector3, size:Vector2, depth:float, radius:float) -> void:
 var lip:=minf(0.012,depth*0.18)
 var front:=face_outline(size-Vector2.ONE*(2.0*lip),radius-lip)
 var shoulder:=face_outline(size,radius)
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in front.size():
  var j:=(i+1)%front.size()
  var sections: Array[Vector3]=[front[i],shoulder[i]+Vector3.FORWARD*lip,shoulder[i]+Vector3.FORWARD*(depth-lip),front[i]+Vector3.FORWARD*depth]
  var next: Array[Vector3]=[front[j],shoulder[j]+Vector3.FORWARD*lip,shoulder[j]+Vector3.FORWARD*(depth-lip),front[j]+Vector3.FORWARD*depth]
  for k in 3:
   for point in [sections[k],next[k],next[k+1],sections[k],next[k+1],sections[k+1]]:surface.add_vertex(point)
 surface.generate_normals()
 var shell:=MeshInstance3D.new()
 shell.mesh=surface.commit();shell.material_override=material(WALNUT);shell.position=at;parent.add_child(shell)
 faceplate(parent,at,size-Vector2.ONE*(2.0*lip),radius-lip,WALNUT)
 var back:=faceplate(parent,at+Vector3.FORWARD*depth,size-Vector2.ONE*(2.0*lip),radius-lip,WALNUT)
 back.rotation.y=PI

func bezel(parent:Node3D,at:Vector3,size:Vector2,radius:float,lip:float,color:Color) -> void:
 var outer:=face_outline(size,radius)
 var inner:=face_outline(size-Vector2.ONE*2*lip,maxf(0.015,radius-lip))
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in outer.size():
  var j:=(i+1)%outer.size()
  for v in [outer[i],inner[j],outer[j],outer[i],inner[i],inner[j]]:
   st.set_normal(Vector3.BACK)
   st.add_vertex(v + Vector3.BACK*(lip*0.17 if v==inner[i] or v==inner[j] else 0.0))
 var frame:=MeshInstance3D.new();frame.mesh=st.commit();frame.position=at
 frame.material_override=material(color);parent.add_child(frame)

func enamel_print(parent:Node3D,texture:Texture2D,size:Vector2) -> MeshInstance3D:
 var panel_mesh:=QuadMesh.new();panel_mesh.size=size
 var finish:=StandardMaterial3D.new();finish.albedo_texture=texture;finish.roughness=0.8
 finish.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 finish.metallic_specular=0.12
 var print_mesh:=MeshInstance3D.new();print_mesh.mesh=panel_mesh;print_mesh.material_override=finish
 parent.add_child(print_mesh);return print_mesh

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

func hull_segment(parent:Node3D,a:Vector2,b:Vector2,glazed:bool, panoramic:bool=false, brace:bool=false, route_chart:=false) -> void:
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
 # The raised valance and recessed teal waist connect the individual bays into one liner.
 curved_wall(root,width,2.14 if not panoramic else 2.23,h,ENAMEL,0.046)
 curved_rail(root,width,2.30,0.018,COPPER)
 if not panoramic:
  curved_wall(root,width,0.52,0.79,ENAMEL,0.032)
  var rib:Array[Vector3]=[Vector3(-width/2,0.10,0.085),Vector3(-width/2,0.79,0.16),
   Vector3(-width/2+0.075,0.98,0.21),Vector3(-width/2+0.075,2.00,0.34),Vector3(-width/2,2.24,0.41)]
  tube(root,rib,0.047,NIGHT)
  if not glazed:
   var at:=Vector3(0,1.46,0.252)
   faceplate(root,at,Vector2(width*0.77,1.06),0.16,Color("947e66")).rotation.x=0.144
   faceplate(root,at+Vector3(0,0,0.009),Vector2(width*0.73,1.022),0.15,Color("d5cbb5")).rotation.x=0.144
   if route_chart:
    var chart:=enamel_print(root,preload("res://assets/cabin/route-inlay.svg"),Vector2(width*0.70,width*0.437))
    chart.position=at+Vector3(0,0,0.025);chart.rotation.x=0.144
 else:
  curved_wall(root,width,0.18,0.50,ENAMEL,0.045)
  # Position the segmented guide lights directly in the curved sill.
  for i in 3:
   var x:float=width*(i-1)*0.11
   var inset_z:float=0.37*inset/h-width*width/44.0*(1.0-4*x*x/(width*width))+0.052
   faceplate(root,Vector3(x,0.37,inset_z),Vector2(width*0.078,0.021),0.01,SEA_GLASS,true).rotation.x=0.144

func saucer(parent:Node3D,staged:=false) -> void:
 var floor_mesh=SurfaceTool.new();floor_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var underside=SurfaceTool.new();underside.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roof_mesh=SurfaceTool.new();roof_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var roof=Node3D.new();roof.name="HullRoof";parent.add_child(roof)
 for i in 144:
  if staged and i%12==0:await parent.get_tree().process_frame
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
   hull_segment(parent,pa,end,i in [24,30,36,72,102,108,114],i in [0,6,12,126,132,138],i in [12,126,132],i in [18,120])
 var deck=MeshInstance3D.new();deck.mesh=floor_mesh.commit()
 deck_finish.shader=preload("res://shaders/cabin_deck.gdshader");deck_finish.set_shader_parameter("grain",grain_texture(true))
 deck.material_override=deck_finish;parent.add_child(deck);deck.create_trimesh_collision()
 for collider in deck.find_children("*","CollisionShape3D",true,false):
  collider.shape.backface_collision=true
 var liner=MeshInstance3D.new();liner.mesh=underside.commit();liner.material_override=material(Color("59666a")).duplicate();liner.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;parent.add_child(liner)
 var ceiling=MeshInstance3D.new();ceiling.mesh=roof_mesh.commit();ceiling.material_override=material(NIGHT);roof.add_child(ceiling);ceiling.create_trimesh_collision()
 # Broad curved ceiling cassettes follow the pressure dome. Their exposed borders
 # reveal the dark backing and the indirect perimeter light between the two tiers.
 for bay in 12:
  var a:=TAU*bay/12
  ceiling_leaf(roof,a,0.24,0.70,PAPER if bay%3 else Color("c8bc9f"))
  ceiling_leaf(roof,a,0.738,0.974,ENAMEL)
  var cove:Array[Vector3]=[]
  for i in 15:
   cove.append(ceiling_point(a+0.028+(TAU/12-0.056)*i/14.0,0.72,0.040))
  tube(roof,cove,0.021,LAMP if bay not in [0,1,10,11] else SEA_GLASS,true)

func ceiling_point(angle:float,r:float,drop:float) -> Vector3:
 var p:=HULL_CENTER+Vector2(sin(angle),-cos(angle))*(HULL_RADII-Vector2.ONE*0.34)*r
 return Vector3(p.x,3.03-0.68*r*r-drop,p.y)

func ceiling_leaf(parent:Node3D,angle:float,inner:float,outer:float,color:Color) -> void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings:=[inner,inner+0.018,outer-0.018,outer]
 for i in 12:
  for k in 3:
   for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
    var band:int=k+corner.y;var step:int=i+corner.x
    var gap:=0.013 if band in [0,3] else 0.005
    var a:float=angle+gap+(TAU/12-2*gap)*step/12.0
    var depth:=0.034 if band in [0,3] or step in [0,12] else 0.078
    var v:=ceiling_point(a,rings[band],depth)
    st.set_normal(Vector3(-0.23*sin(a),-1,0.20*cos(a)).normalized());st.add_vertex(v)
 var mesh:=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(color);parent.add_child(mesh)

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
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material(WALNUT);parent.add_child(mesh)
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
var helm_keys:Array[Node3D]=[]
var radar:Node3D
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
 var scope:=Node3D.new();scope.position=Vector3(0,0.868,0.018);scope.rotation.x=0.22;scope.scale=Vector3.ONE*0.84;dash.add_child(scope)
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
 # These low switch faces carry flight telemetry and open the side drawers.
 for side in [-1,1]:
  var key:=Node3D.new()
  key.position=Vector3(side*0.47,0.908,0.045)
  key.rotation=Vector3(-0.71,-side*0.20,0)
  dash.add_child(key);helm_keys.append(key)
  veneer_case(key,Vector3.ZERO,Vector2(0.454,0.166),0.031,0.027)
  faceplate(key,Vector3.BACK*0.002,Vector2(0.437,0.151),0.018,inset)
  bezel(key,Vector3.BACK*0.003,Vector2(0.437,0.151),0.018,0.004,BRASS)
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
# Fixed housings share the cabin mesh batches.
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

# A practical fixture aims in its parent's local space. The cockpit key is the
# single shadow caster on the upper deck; the smaller fittings use short throws.
func fixture_light(parent:Node3D, origin:Vector3, aim:Vector3, tint:Color, energy:float, reach:float, angle:float) -> SpotLight3D:
 var lamp:=SpotLight3D.new()
 lamp.position=origin
 lamp.light_color=tint
 lamp.light_energy=energy
 lamp.spot_range=reach
 lamp.spot_angle=angle
 lamp.spot_angle_attenuation=0.85
 parent.add_child(lamp)
 lamp.look_at(parent.to_global(aim),parent.global_basis.z.normalized() if absf((aim-origin).normalized().y)>0.98 else Vector3.UP)
 return lamp

func strip_lamp(parent:Node3D,pos:Vector3,length:float) -> void:
 box(parent,pos,Vector3(length,0.085,0.14),TRIM)
 box(parent,pos+Vector3(0,-0.048,0),Vector3(length-0.12,0.018,0.085),Color("ffdfa7"),false,true)
 for side in [-1,1]:box(parent,pos+Vector3(side*(length/2-0.04),0,0),Vector3(0.035,0.09,0.15),BRASS)

func lighting_details(parent:Node3D) -> void:
 var roof=parent.get_node("HullRoof")
 # Flush orbital lens at the centre of the saucer, held by a copper retaining ring.
 var lens_center:=Vector3(0,2.88,HULL_CENTER.y)
 cylinder(roof,lens_center+Vector3.UP*0.06,1.17,0.16,ENAMEL,1.25)
 cylinder(roof,lens_center,1.07,0.065,COPPER,1.12)
 cylinder(roof,lens_center-Vector3.UP*0.045,1.02,0.05,NIGHT)
 for band in [0.91,0.66,0.26]:
  var path:Array[Vector3]=[]
  for i in 73:
   var a:=TAU*i/72
   path.append(lens_center+Vector3(cos(a)*band,-0.077,sin(a)*band))
  tube(roof,path,0.019 if band==0.91 else 0.009,LAMP if band==0.91 else SEA_GLASS,true)
 for i in 8:
  var a:=i*TAU/8.0+0.28;var radius:float=[0.66,0.26,0.91][i%3]
  cylinder(roof,lens_center+Vector3(cos(a)*radius,-0.078,sin(a)*radius),0.039 if i%3 else 0.068,0.02,COPPER)
 for x in [-2.65,2.65]:halo(roof,Vector3(x,2.57,2.5),0.29)
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
func fittings(parent:Node3D) -> void:
 # Owner: machinery is beneath the deck. Only flush service access remains above it.
 for side in [-1,1]:
  var hatch_plate=box(parent,Vector3(side*2.4,0.012,-2.6),Vector3(1.1,0.02,0.75),Color("8d795e"))
  for x in [-0.44,0.44]:
   for z in [-0.27,0.27]:cylinder(hatch_plate,Vector3(x,0.014,z),0.018,0.006,Color("89979a"))
  box(hatch_plate,Vector3(0,0.014,0),Vector3(0.18,0.008,0.025),TRIM)
 # Two-person dinette fitted into the forward starboard shoulder.
 var booth=Node3D.new();booth.position=Vector3(3.35,0,-0.62);booth.rotation.y=-0.50;parent.add_child(booth)
 rest_anchor(booth,"bench",Vector3(-0.35,0.64,0.04),Vector3(-0.6,0,0.93))
 box(booth,Vector3(0,0.26,0),Vector3(1.75,0.52,0.72),TRIM,true)
 box(booth,Vector3(0,0.57,0),Vector3(1.74,0.14,0.73),Color("c77f50"))
 box(booth,Vector3(0,0.88,-0.29),Vector3(1.78,0.65,0.18),ENAMEL)
 for side in [-1,1]:
  faceplate(booth,Vector3(side*0.425,0.88,-0.188),Vector2(0.80,0.48),0.11,Color("698773"))
  bezel(booth,Vector3(side*0.425,0.88,-0.18),Vector2(0.80,0.48),0.11,0.018,Color("acb49a"))
 # The portable table serves both this banquette and the facing lounge chair.
 for side in [-1,1]:
  box(booth,Vector3(side*0.83,0.69,-0.01),Vector3(0.13,0.19,0.59),WOOD)
  box(booth,Vector3(side*0.83,0.76,-0.01),Vector3(0.14,0.055,0.58),Color("b5734d"))
 # Upholstery seams and a practical reading strip finish the fitted dinette.
 for x in [-0.56,0.56]:
  tube(booth,[Vector3(x,1.12,-0.33),Vector3(x,1.84,-0.33),Vector3(x,1.91,-0.24)],0.022,TRIM)
 strip_lamp(booth,Vector3(0,1.91,-0.24),1.22)
 fixture_light(booth,Vector3(0.38,1.84,-0.20),Vector3(-0.15,0.66,0.12),Color("ffc489"),1.65,2.6,48)
 # Small galley integrated into the opposite shoulder, with overhead storage.
 var galley=Node3D.new();galley.position=Vector3(-3.65,0,-0.85);galley.rotation.y=0.5;parent.add_child(galley)
 box(galley,Vector3(0,0.42,0),Vector3(1.7,0.84,0.64),Color("74917b"),true)
 box(galley,Vector3(0,0.88,0.085),Vector3(1.74,0.08,0.87),WALNUT)
 # Lidded ceramic cups nest in a brass rack at the end of the breakfast ledge.
 for i in 2:
  var at:=Vector3(0.57+i*0.15,0.976,0.33)
  cylinder(galley,at,0.052,0.11,PAPER,0.063)
  cylinder(galley,at+Vector3.UP*0.059,0.061,0.012,ENAMEL)
 # Clear counter edge and a footrail make a perch without another table.
 tube(galley,[Vector3(-0.63,0.24,0.32),Vector3(-0.63,0.24,0.48),Vector3(0.63,0.24,0.48),Vector3(0.63,0.24,0.32)],0.019,BRASS)
 box(galley,Vector3(0,1.91,-0.23),Vector3(1.7,0.52,0.3),ENAMEL)
 faceplate(galley,Vector3(0,1.28,-0.26),Vector2(1.67,0.70),0.11,NIGHT)
 bezel(galley,Vector3(0,1.28,-0.244),Vector2(1.67,0.70),0.11,0.035,COPPER)
 strip_lamp(galley,Vector3(0,1.62,-0.14),1.47)
 fixture_light(galley,Vector3(-0.30,1.55,-0.12),Vector3(0,0.81,0.21),Color("ffdda5"),1.3,2.4,59)
 for x in [-0.56,0,0.56]:
  box(galley,Vector3(x,0.44,0.329),Vector3(0.52,0.70,0.025),Color("7f9c85"))
  faceplate(galley,Vector3(x,1.91,-0.065),Vector2(0.51,0.43),0.080,PAPER)
  faceplate(galley,Vector3(x,1.79,-0.060),Vector2(0.27,0.033),0.014,BRASS)
 for x in [-0.52,0,0.52]:box(galley,Vector3(x,0.5,0.33),Vector3(0.42,0.035,0.025),BRASS)
 box(galley,Vector3(0.3,0.93,0),Vector3(0.5,0.025,0.40),Color("243b43"))
 # Induction rings, sink and a curved tap share the compact galley surface.
 for x in [0.15,0.43]:
  var hob=cylinder(galley,Vector3(x,0.949,0),0.105,0.009,Color("679da2"))
  cylinder(hob,Vector3(0,0.006,0),0.081,0.008,TRIM)
 box(galley,Vector3(-0.41,0.944,0.10),Vector3(0.41,0.018,0.30),TRIM)
 tube(galley,[Vector3(-0.58,0.94,-0.08),Vector3(-0.58,1.18,-0.08),Vector3(-0.55,1.22,0.07),Vector3(-0.52,1.18,0.10)],0.018,BRASS)

func build(parent:Node3D,space:Node3D,staged:=false) -> void:
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_SKY
 var sky=Sky.new()
 # Rough cabin materials only need a low-resolution reflection cubemap.
 sky.radiance_size=Sky.RADIANCE_SIZE_64
 var sky_mat=ShaderMaterial.new();sky_mat.shader=load("res://shaders/space.gdshader");sky.sky_material=sky_mat
 sky_mat.set_shader_parameter("coast",preload("res://assets/islands/archipelago.jpg"))
 var stars=MultiMeshInstance3D.new();var star_mesh=SphereMesh.new();star_mesh.radius=0.18;star_mesh.height=0.36;star_mesh.radial_segments=6;star_mesh.rings=3
 var star_mat=StandardMaterial3D.new();star_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;star_mat.vertex_color_use_as_albedo=true
 star_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 star_mesh.material=star_mat;var field=MultiMesh.new();field.transform_format=MultiMesh.TRANSFORM_3D;field.use_colors=true;field.mesh=star_mesh;field.instance_count=850
 var rng=RandomNumberGenerator.new();rng.seed=14112026
 for i in field.instance_count:
  var y=rng.randf_range(-0.75,0.85);var angle=rng.randf_range(0,TAU);var radial=sqrt(1-y*y)
  var point=Vector3(cos(angle)*radial,y,sin(angle)*radial)*1900
  field.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(7.3*rng.randf_range(0.6,2.4))),point))
  field.set_instance_color(i,Color("d4dfff") if i%3 else Color("ffe6c5"))
 stars.multimesh=field;space.add_child(stars);field_stars=stars;sky_environment=env.environment
 env.environment.sky=sky;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("eee5d6");env.environment.ambient_light_energy=0.40
 env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;space.add_child(env)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-28,0);sun.light_color=Color("c1d4e8");sun.light_energy=0.22
 sun.shadow_enabled=false;sun.directional_shadow_max_distance=38;space.add_child(sun)
 await saucer(parent,staged)
 if staged:await parent.get_tree().process_frame
 console(parent)
 if staged:await parent.get_tree().process_frame
 fittings(parent);lighting_details(parent)
 # Rake the chair and brass from the overhead optics. A dim cyan return under
 # the coaming separates the controls from the glass at night.
 var key:=fixture_light(parent,Vector3(-0.34,2.48,-3.39),Vector3(0.16,0.79,-4.26),Color("ffd3a4"),1.36,3.7,48)
 key.light_specular=0.48
 key.shadow_enabled=true;key.shadow_bias=0.06;key.shadow_normal_bias=1.1
 for side in [-1,1]:
  box(helm_root,Vector3(side*0.44,0.59,-0.37),Vector3(0.23,0.012,0.023),SEA_GLASS,false,true)
 fixture_light(helm_root,Vector3(0,0.62,-0.37),Vector3(0,0.27,0.18),Color("76c9cf"),0.68,1.6,64)
 var ceiling:=OmniLight3D.new();parent.add_child(ceiling)
 ceiling.position=Vector3(0,2.65,HULL_CENTER.y)
 ceiling.light_color=Color("ffdcbb");ceiling.light_energy=0.43;ceiling.omni_range=3.8

func footprint(id: String) -> Vector2:
 return {"armchair":Vector2(1.25,1.25),"low-table":Vector2(1.6,1.0),"plant":Vector2(0.7,0.7),"lamp":Vector2(0.5,0.5),"stool":Vector2(0.65,0.65),"books":Vector2(0.5,0.38),"rug":Vector2(2.8,2.0)}.get(id,Vector2.ONE)

func rest_anchor(parent:Node3D,kind:String,at:Vector3,approach:Vector3) -> void:
 var seat:=Marker3D.new();parent.add_child(seat);seat.position=at
 seat.set_meta("rest",kind);seat.set_meta("approach",approach-at)
 seat.add_to_group("ship_rest")

func furniture(id: String, solid: bool=true) -> Node3D:
 var root=Node3D.new();root.set_meta("item",id)
 match id:
  "armchair":
   if solid:rest_anchor(root,"armchair",Vector3(0,0.59,0),Vector3(0,0,-1.05))
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

func batch_static(parent:Node3D,staged:=false) -> void:
 # One mesh per shared material for fixed room geometry; collision bodies stay.
 # Movable furniture and the host avatar are created afterwards and stay separate.
 if parent.has_node("HullRoof"):await batch_static(parent.get_node("HullRoof"),staged)
 var deadline:=Time.get_ticks_usec()+6000
 var groups:Dictionary={}
 var originals:Array[MeshInstance3D]=[]
 for node in parent.find_children("*","MeshInstance3D",true,false):
  if staged and Time.get_ticks_usec()>=deadline:
   await parent.get_tree().process_frame
   deadline=Time.get_ticks_usec()+6000
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
  if staged and Time.get_ticks_usec()>=deadline:
   await parent.get_tree().process_frame
   deadline=Time.get_ticks_usec()+6000
  var mesh=MeshInstance3D.new();mesh.mesh=group[0].commit();mesh.material_override=group[1];parent.add_child(mesh)
