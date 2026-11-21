# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## One shoreline drives the rock shelf, beach, lagoon, pouring lips and spray.
const SEGMENTS := 112
const SEA_RADIUS := 2.85
const SEA_Y := -0.95
const PAD_FROM_CENTER := Vector2(-30,48)
const CLOUD_HEIGHT := 0.64
const FALLS := [Vector2(3,5),Vector2(21,4),Vector2(39,8),Vector2(62,5),Vector2(84,7),Vector2(101,4)]
var water := ShaderMaterial.new()
var falls := ShaderMaterial.new()
var spray := ShaderMaterial.new()
var land := ShaderMaterial.new()
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
 land.shader=preload("res://shaders/island_terrain.gdshader")

func animate(delta: float) -> void:
 clock += delta
 for material in [water, falls, spray]:
  material.set_shader_parameter("flow_time", clock)

# Separate coastlines for the land and for the suspended body of water.
func headland(a: float, seed_angle: float) -> float:
 var t := a+seed_angle
 return 0.97+0.22*sin(3*t+0.5)+0.15*cos(5*t-0.7)+0.07*sin(8*t)+0.025*cos(15*t)

func rim(a: float, seed_angle: float) -> float:
 return SEA_RADIUS*(1.0+0.06*cos(3*a-seed_angle)+0.032*sin(7*a+seed_angle))

func polar(a: float, distance: float) -> Vector2:
 return Vector2(cos(a)*distance,sin(a)*distance*0.90)

func mound(p: Vector2, center: Vector2, widths: Vector2) -> float:
 return exp(-((p-center)/widths).length_squared())

func relief(pos: Vector2, radius: float, seed_angle: float, fraction: float) -> float:
 var p := (pos/radius).rotated(seed_angle)
 # A broken backbone, a saddle through it, and a second headland across the bay.
 var ridge := mound(p,Vector2(-0.18,-0.23+0.12*sin(p.x*4.0)),Vector2(0.54,0.25))
 var crag := mound(p,Vector2(0.20,-0.22),Vector2(0.19,0.24))
 var bluff := mound(p,Vector2(0.51,0.27),Vector2(0.25,0.27))
 var folds := 0.78+0.22*cos(p.x*15+p.y*6)+0.10*sin(p.y*21)
 var h := radius*(0.31*ridge*folds+0.21*crag+0.21*bluff+0.035*(1+sin(9*p.x+2*sin(p.y*5))))
 # The smaller islands have their own skyline: a broad mesa, a hollow summit,
 # and two long parallel spurs. The orchard keeps the broken ridge.
 if seed_angle>4.0:
  h=radius*(0.23*mound(p,Vector2(-0.23,0),Vector2(0.15,0.52))+0.19*mound(p,Vector2(0.19,-0.09),Vector2(0.19,0.55)))*folds
 elif seed_angle>3.0:
  var summit:=(p/Vector2(0.68,0.56)).length()
  h=radius*0.29*exp(-pow((summit-0.66)*3.4,2))*folds
 elif seed_angle>1.0:
  h=radius*0.27*smoothstep(0.12,0.60,ridge+0.37*crag)*(0.94+0.06*folds)
 h *= 1.0-smoothstep(0.74,1.0,fraction)
 var river_x:=0.32+0.16*sin(4.0*p.y)+0.085*p.y
 var valley:float=1.0-smoothstep(0.035,0.135,absf(p.x-river_x))
 valley*=smoothstep(-0.33,-0.12,p.y)
 var lake:=mound(p,Vector2(0.19,-0.153),Vector2(0.205,0.152))
 h=lerpf(h,SEA_Y-1.8,maxf(valley,smoothstep(0.24,0.69,lake)))
 if is_zero_approx(seed_angle):
  # A level approach along the valley floor leads to the existing pad and lift.
  var corridor := Vector2(PAD_FROM_CENTER.x,maxf(pos.y,PAD_FROM_CENTER.y))
  h *= smoothstep(17.0,34.0,pos.distance_to(corridor))
 return h

func seabed(pos: Vector2, radius: float, seed_angle: float) -> float:
 # Offshore stacks break the surface at the mouth of the northern inlet.
 var p := (pos/radius).rotated(seed_angle)
 var stacks := 0.29*mound(p,Vector2(-0.54,-1.37),Vector2(0.13,0.12))
 stacks += 0.21*mound(p,Vector2(-0.78,-1.48),Vector2(0.10,0.14))
 stacks += 0.14*mound(p,Vector2(0.93,0.91),Vector2(0.13,0.085))
 return SEA_Y+radius*(stacks-0.055)

func surface_point(angle: float, distance: float, y: float) -> Vector3:
 var pos := polar(angle,distance)
 return Vector3(pos.x,y,pos.y)

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
 # The same sampled vertices form the visible ridges, beach and walking surface.
 var rows: Array[PackedVector3Array] = []
 var tints: Array[PackedColorArray] = []
 const MEADOW := 30
 const SHELF := 19
 for row in range(MEADOW+SHELF+6):
  var points := PackedVector3Array()
  var colors := PackedColorArray()
  for j in SEGMENTS:
   var a := TAU*j/SEGMENTS
   var shore := radius*headland(a,seed_angle)
   var edge := radius*rim(a,seed_angle)
   var distance: float
   var height: float
   var tint: Color
   if row<=MEADOW:
    var fraction := float(row)/MEADOW
    distance=shore*fraction
    height=relief(polar(a,distance),radius,seed_angle,fraction)
    tint=Color("7ca06d").lerp(Color("b9c688"),0.5+0.5*sin(a*6+fraction*9)*fraction)
    var strata := 0.5+0.5*sin(height*0.33+a*2.0)
    var rock := Color("97878a").lerp(Color("c1ab92"),strata*0.29)
    tint=tint.lerp(rock,smoothstep(0.12,0.29,height/radius))
    tint=tint.lerp(Color("afa583"),smoothstep(-0.3,1.8,-height))
    tint=tint.lerp(Color("dfcd9e"),smoothstep(0.87,1.0,fraction))
   elif row<=MEADOW+SHELF:
    var fraction := pow(float(row-MEADOW)/SHELF,1.3)
    distance=lerpf(shore,edge,fraction)
    var estuary:=relief(polar(a,shore),radius,seed_angle,1.0)
    height=lerpf(estuary,seabed(polar(a,distance),radius,seed_angle),smoothstep(0.0,0.095,fraction))
    height=lerpf(height,SEA_Y-0.25,smoothstep(0.90,1.0,fraction))
    tint=Color("d9c598").lerp(Color("ab9989"),smoothstep(0.02,0.13,fraction))
    tint=tint.lerp(Color("92a477"),smoothstep(0.04,0.13,height/radius))
   else:
    var band := row-MEADOW-SHELF-1
    var weathering := 1.0+0.055*sin(a*9+seed_angle)+0.037*cos(a*13+band)
    distance=edge*[0.986,0.91,0.74,0.43,0.0][band]
    height=SEA_Y-depth*[0.08,0.22,0.42,0.73,1.0][band]*weathering
    if band==4:height=SEA_Y-depth
    tint=Color(["baa188","847784","796b78","636778","465666"][band])
   points.append(surface_point(a,distance,height))
   colors.append(tint.srgb_to_linear())
  rows.append(points)
  tints.append(colors)
 for j in SEGMENTS:
  var k := (j+1)%SEGMENTS
  for row in rows.size()-1:
   var corners := [rows[row][j],rows[row+1][j],rows[row+1][k],rows[row][k]]
   var colors := [tints[row][j],tints[row+1][j],tints[row+1][k],tints[row][k]]
   for tri in [[0,1,2],[0,2,3]]:
    if (row==0 and tri[1]==2) or (row==rows.size()-2 and tri[1]==1):continue
    var normal: Vector3=(corners[tri[2]]-corners[tri[0]]).cross(corners[tri[1]]-corners[tri[0]]).normalized()
    for index in tri:vertex(terrain,corners[index],Vector2.ZERO,colors[index],normal)
  # A continuous water level also fills the channels and tarns cut into the land.
  vertex(lagoon,Vector3.UP*SEA_Y,Vector2(-1,0),Color.WHITE,Vector3.UP)
  for end in [j,k]:
   var angle:float=TAU*end/SEGMENTS
   vertex(lagoon,surface_point(angle,radius*headland(angle,seed_angle),SEA_Y),Vector2(-1,0),Color.WHITE,Vector3.UP)
  # Four subdivision rings keep the surf band close to the shore at this scale.
  var bands := [0.0,0.035,0.12,0.84,1.0]
  for n in bands.size()-1:
   for index in [0,1,2,0,2,3]:
    var a := TAU*(j+int(index>=2))/SEGMENTS
    var band: float = bands[n+int(index==1 or index==2)]
    var distance := radius*lerpf(headland(a,seed_angle),rim(a,seed_angle),band)
    vertex(lagoon,surface_point(a,distance,SEA_Y),Vector2(a/TAU,band),Color.WHITE,Vector3.UP)
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
     var radial := rim(angle,seed_angle)+0.035*sin(v*PI*0.68)
     var height := SEA_Y-depth*length_scale*v*v
     vertex(sheets,surface_point(angle,radius*radial,height),Vector2(u,v),Color(float(i)/FALLS.size(),0,0),Vector3.UP)
  for j in 8:
   var fraction := fmod(j*0.618+i*0.26,1.0)
   var angle := TAU*(arc.x+arc.y*(0.10+fraction*0.80))/SEGMENTS
   var base := surface_point(angle,radius*(rim(angle,seed_angle)+0.035),SEA_Y-depth*length_scale*(0.48+0.24*fraction))
   cloud.set_instance_transform(i*8+j,Transform3D(Basis(Vector3.UP,PI*0.5-angle),base))
   cloud.set_instance_custom_data(i*8+j,Color(fmod(j*0.382+i*0.342,1.0),clampf(radius/100.0,0.23,1.0),0))
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
 for i in 76:
  var a := TAU*i/76.0+rng.randf_range(-0.08,0.08)
  patches.append(surface_point(a,radius*headland(a,seed_angle)*rng.randf_range(0.18,0.94),0))
 for model in species:
  var plants: Array[Transform3D] = []
  var count := 5 if model=="grass_large" else 3
  for cluster in patches.size():
   for i in count:
    var pos := patches[cluster]+Vector3(rng.randf_range(-0.85,0.85),0,rng.randf_range(-0.85,0.85))
    var flat := Vector2(pos.x,pos.z)
    if is_zero_approx(seed_angle) and flat.distance_to(PAD_FROM_CENTER)<10:continue
    var planar := flat/Vector2(1,0.90)
    pos.y=relief(flat,radius,seed_angle,planar.length()/(radius*headland(planar.angle(),seed_angle)))
    if pos.y<0.02:continue
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

# The cloud banks occupy a real ellipsoid in sector space. Parallax and the
# overlapping near/far wisps are visible from a moving cockpit on any heading.
func cloud_boundary(parent: Node3D, center: Vector3, shell: float, seed_angle: float) -> ShaderMaterial:
 var banks := MultiMesh.new()
 banks.transform_format=MultiMesh.TRANSFORM_3D
 banks.use_custom_data=true
 var quad := QuadMesh.new()
 quad.size=Vector2.ONE
 var material := ShaderMaterial.new()
 material.shader=preload("res://shaders/entry_cloud.gdshader")
 quad.material=material
 banks.mesh=quad
 banks.instance_count=240
 var rng := RandomNumberGenerator.new()
 rng.seed=20261121+roundi(seed_angle*100)
 for i in banks.instance_count:
  var y := (2.0*i+1.0)/banks.instance_count-1.0
  var azimuth := i*2.399963+seed_angle
  var radial := sqrt(1.0-y*y)
  var dir := Vector3(cos(azimuth)*radial,y*CLOUD_HEIGHT,sin(azimuth)*radial)
  # Weather fronts form broken arcs rather than an outlined, uniform envelope.
  var front:=0.5+0.5*sin(azimuth*3.0+2.7*y+seed_angle)*cos(y*4.0-azimuth)
  var pos := dir*shell*(rng.randf_range(0.89,1.03)+0.10*(front-0.5))
  var scale_m := Vector3(rng.randf_range(0.35,0.64),rng.randf_range(0.17,0.33),0.30)*shell
  banks.set_instance_transform(i,Transform3D(Basis.from_scale(scale_m),pos))
  banks.set_instance_custom_data(i,Color(rng.randf(),front,0))
 var bank := MultiMeshInstance3D.new()
 bank.name="AtmosphereClouds"
 bank.multimesh=banks
 bank.extra_cull_margin=shell*0.34
 bank.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 bank.position=center
 parent.add_child(bank,true)
 return material
