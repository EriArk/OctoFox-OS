# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## One shoreline drives the rock shelf, beach, lagoon, pouring lips and spray.
const SEGMENTS := 96
const FALLS := [Vector2(2, 8), Vector2(18, 4), Vector2(29, 12), Vector2(49, 6), Vector2(63, 10), Vector2(83, 5)]
var water := ShaderMaterial.new()
var falls := ShaderMaterial.new()
var spray := ShaderMaterial.new()
var land := StandardMaterial3D.new()
var plant_meshes: Dictionary[String, Mesh] = {}
const BOTANICAL_COLORS := {
 "grass": Color("759c66"), "leafsGreen": Color("72a077"), "woodBark": Color("946e57"),
 "colorYellow": Color("ffd46c"), "colorPurple": Color("af83b4")
}
var clock := 0.0

func _init() -> void:
 water.shader = preload("res://shaders/island_water.gdshader")
 falls.shader = preload("res://shaders/island_falls.gdshader")
 spray.shader = preload("res://shaders/island_spray.gdshader")
 land.vertex_color_use_as_albedo = true
 land.roughness = 0.94

func animate(delta: float) -> void:
 clock += delta
 for material in [water, falls, spray]:
  material.set_shader_parameter("flow_time", clock)

func point(angle: float, radial: float, height: float, seed_angle: float) -> Vector3:
 var shape := 1.0 + 0.10*sin(3*angle+seed_angle) + 0.055*cos(5*angle-seed_angle) + 0.025*sin(9*angle)
 return Vector3(cos(angle)*radial*shape, height, sin(angle)*radial*shape*0.90)

func begin(material: Material) -> SurfaceTool:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(material)
 return surface

func finish(root: Node3D, surface: SurfaceTool, label: String) -> MeshInstance3D:
 surface.index()
 var node := MeshInstance3D.new()
 node.name = label
 node.mesh = surface.commit()
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(node)
 return node

func vertex(surface: SurfaceTool, pos: Vector3, uv: Vector2, color: Color, normal: Vector3) -> void:
 surface.set_color(color)
 surface.set_normal(normal)
 surface.set_uv(uv)
 surface.add_vertex(pos)

func build(parent: Node3D, center: Vector3, radius: float, depth: float, seed_angle: float) -> MeshInstance3D:
 var root := Node3D.new()
 root.name = "OpenIsland"
 parent.add_child(root, true)
 root.position = center
 var terrain := begin(land)
 var lagoon := begin(water)
 # Section from meadow to beach, submerged shelf, then down into the layered underside.
 var section := [Vector2(0,0), Vector2(0.82,0), Vector2(0.90,-0.009), Vector2(0.975,-0.058),
  Vector2(1.12,-0.12), Vector2(1.19,-0.045), Vector2(1.16,-0.19), Vector2(1.06,-0.28),
  Vector2(1.02,-0.34), Vector2(0.92,-0.53), Vector2(0.72,-0.62), Vector2(0.49,-0.82), Vector2(0.12,-1.0),Vector2(0,-1.04)]
 var colors := ["86ad84","a6bb88","ddc79c","e2cb98","9fa98c","ada185","917d75","c39c85","776a77","8f7e87","766a80","51566b","414e61","414e61"]
 for i in SEGMENTS:
  var a := TAU*i/SEGMENTS
  var b := TAU*(i+1)/SEGMENTS
  for j in range(section.size()-1):
   var band: Vector2 = section[j]
   var next: Vector2 = section[j+1]
   var corners := [point(a,band.x*radius,band.y*depth,seed_angle),point(a,next.x*radius,next.y*depth,seed_angle),
    point(b,next.x*radius,next.y*depth,seed_angle),point(b,band.x*radius,band.y*depth,seed_angle)]
   for corner in corners.size():
    var pos: Vector3 = corners[corner]
    var weathering := clampf((-pos.y/depth-0.06)*3.0,0,1)
    var bearing := atan2(pos.z,pos.x)
    var ledge := 1.0+weathering*(0.048*cos(13*bearing)+0.037*cos(7*bearing+seed_angle+pos.y/depth*7.0))
    pos.x *= ledge
    pos.z *= ledge
    pos.y += weathering*depth*0.045*cos(bearing*5.0+seed_angle)
    corners[corner] = pos
   var normal: Vector3 = (corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
   if j == section.size()-2:normal=Vector3.DOWN
   var tint := 0.97+0.03*sin(a*7.0+float(j)*0.6)
   var indices := [0,1,2] if j==0 else ([0,2,3] if j==section.size()-2 else [0,1,2,0,2,3])
   for k in indices:
    var ring := j+1 if k==1 or k==2 else j
    vertex(terrain,corners[k],Vector2.ZERO,Color(colors[ring]).darkened(1.0-tint).srgb_to_linear(),normal)
  for k in [0,1,2,0,2,3]:
   var outer: bool = k==1 or k==2
   var angle := a if k<2 else b
   var pos := point(angle,radius*(1.19 if outer else 0.93),-0.039*depth,seed_angle)
   vertex(lagoon,pos,Vector2(angle/TAU,float(outer)),Color.WHITE,Vector3.UP)
 var ground := finish(root,terrain,"Terrain")
 finish(root,lagoon,"Water")
 var sheets := begin(falls)
 var cloud := MultiMesh.new()
 cloud.transform_format = MultiMesh.TRANSFORM_3D
 cloud.use_custom_data = true
 var puff := QuadMesh.new()
 puff.size = Vector2(2.1,1.4)
 puff.material = spray
 cloud.mesh = puff
 cloud.instance_count = FALLS.size()*8
 for i in FALLS.size():
  var arc: Vector2 = FALLS[i]
  var length_scale := 0.68+0.16*sin(i*3.4+seed_angle)
  for j in int(arc.y):
   for row in 5:
    for k in [0,1,2,0,2,3]:
     var u := (j+float(k==2 or k==3))/arc.y
     var v := (row+float(k==1 or k==2))/5.0
     var angle := TAU*(arc.x+u*arc.y)/SEGMENTS
     var radial := 1.19+0.054*sin(v*PI*0.68)
     var height := -depth*(0.039+length_scale*v*v)
     vertex(sheets,point(angle,radius*radial,height,seed_angle),Vector2(u,v),Color(float(i)/FALLS.size(),0,0),Vector3.UP)
  for j in 8:
   var fraction := fmod(j*0.618+i*0.26,1.0)
   var angle := TAU*(arc.x+arc.y*(0.10+fraction*0.80))/SEGMENTS
   var base := point(angle,radius*(1.235+0.024*fraction),-depth*(0.039+length_scale*(0.48+0.24*fraction)),seed_angle)
   cloud.set_instance_transform(i*8+j,Transform3D(Basis(Vector3.UP,PI*0.5-angle),base))
   cloud.set_instance_custom_data(i*8+j,Color(fmod(j*0.382+i*0.342,1.0),clampf(radius/25.0,0.23,0.85),0))
 finish(root,sheets,"Waterfalls")
 var mist := MultiMeshInstance3D.new()
 mist.name = "RisingSpray"
 mist.multimesh = cloud
 mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mist.extra_cull_margin = 8.0
 root.add_child(mist)
 return ground


# Cluster small plants in the meadow and leave the landing pad and its lifts clear.
# Each species draws in one batch per island, including on the mobile renderer.
func plant_shore(ground: MeshInstance3D, radius: float, seed_angle: float) -> void:
 var root := ground.get_parent() as Node3D
 var rng := RandomNumberGenerator.new()
 rng.seed = 15103+roundi(seed_angle*100)
 var species := ["grass_large","plant_bushLarge","flower_yellowA","flower_purpleA"]
 var patches: Array[Vector3] = []
 for i in 20:
  var a := TAU*i/20.0+rng.randf_range(-0.08,0.08)
  patches.append(point(a,radius*rng.randf_range(0.70,0.825),0,seed_angle))
 for model in species:
  var plants: Array[Transform3D] = []
  var count := 5 if model=="grass_large" else 3
  for cluster in patches.size():
   for i in count:
    var pos := patches[cluster]+Vector3(rng.randf_range(-0.85,0.85),0,rng.randf_range(-0.85,0.85))
    if radius>12 and Vector2(pos.x+2,pos.z-3).length()<9.3:continue
    var size_m := rng.randf_range(0.9,2.6)
    if model=="plant_bushLarge":
     if cluster%3!=0:continue
     size_m *= 1.55
    if model.begins_with("flower") and (cluster%2==0)!=(model=="flower_yellowA"):continue
    plants.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size_m),pos-Vector3.UP*0.035))
  plant_batch(root,model,plants)

func plant_batch(parent: Node3D, model: String, transforms: Array[Transform3D]) -> void:
 if transforms.is_empty():return
 if not plant_meshes.has(model):
  var scene := load("res://assets/islands/"+model+".glb") as PackedScene
  var sample := scene.instantiate() as Node3D
  var source := sample.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
  var mesh := source.mesh.duplicate() as Mesh
  for i in mesh.get_surface_count():
   # The Nature Kit GLBs export leaves and petals as fully metallic.
   var material := mesh.surface_get_material(i).duplicate() as StandardMaterial3D
   var original := mesh.surface_get_material(i).resource_name
   material.metallic = 0
   material.roughness = 0.96
   material.albedo_color = BOTANICAL_COLORS.get(original,material.albedo_color)
   mesh.surface_set_material(i,material)
  plant_meshes[model] = mesh
  sample.free()
 var instances := MultiMesh.new()
 instances.transform_format = MultiMesh.TRANSFORM_3D
 instances.mesh = plant_meshes[model]
 instances.instance_count = transforms.size()
 for i in transforms.size():instances.set_instance_transform(i,transforms[i])
 var grove := MultiMeshInstance3D.new()
 grove.multimesh = instances
 grove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(grove)
