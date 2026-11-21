# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const R:=preload("res://scripts/egregore_regions.gd")
const LAYER:=1<<15
var field:Node3D
var ribbons:=SurfaceTool.new()

func material(tint:Color) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new()
 m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=tint
 return m

func instance(parent:Node3D,geometry:Mesh,ink:Material,at:Vector3) -> void:
 var node:=MeshInstance3D.new();node.mesh=geometry;node.material_override=ink
 node.layers=LAYER;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node);node.position=at

func mist(at:Vector3,span:float,color:Color) -> void:
 var cloud:=QuadMesh.new();cloud.size=Vector2.ONE*span
 var ink:=ShaderMaterial.new();ink.shader=preload("res://shaders/atlas_mist.gdshader")
 ink.set_shader_parameter("tint",color)
 instance(field,cloud,ink,at)

func ready_field() -> void:
 field=Node3D.new();add_child(field)
 var disc:=PlaneMesh.new();disc.size=Vector2(107,107)
 var dust:=ShaderMaterial.new();dust.shader=preload("res://shaders/atlas_disk.gdshader")
 instance(field,disc,dust,Vector3.ZERO)
 var core:=SphereMesh.new();core.radius=2.9;core.height=5.8
 instance(field,core,material(Color("ffdfa4")),Vector3.ZERO)
 mist(Vector3.ZERO,32,Color("ff9b4377"))
 for side in [-1,1]:
  mist(Vector3.UP*side*7.2,19,Color("f7986740"))
  mist(Vector3.UP*side*15,22,Color("9f81d433"))
 ribbons.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rng:=RandomNumberGenerator.new();rng.seed=23118
 # Field lines emerge at the poles and turn back into the equatorial ring.
 for hemisphere in [-1,1]:
  for strand in 48:
   var phase:=rng.randf_range(0,TAU)
   var reach:=rng.randf_range(14,44)
   var height:=rng.randf_range(11,25)
   var dye:=Color("7f78dc").lerp(Color("5baebc"),rng.randf())
   if strand%3==0:dye=Color("e99563")
   var pts:=PackedVector3Array()
   for j in 61:
    var t:=j/60.0
    var radius:=reach*pow(sin(t*PI*.5),1.8)
    var angle:=phase+0.72*t+0.13*sin(t*PI)
    pts.append(Vector3(cos(angle)*radius,hemisphere*(height*sin(PI*t)+2.0*(1-t)),sin(angle)*radius))
   ribbon(pts,dye,rng.randf_range(.075,.17),true)
 for i in R.CENTRES.size():
  var at:Vector3=R.CENTRES[i]
  var tangent:=Vector3(-at.z,0,at.x).normalized()
  var radial:=tangent.cross(Vector3.UP)
  mist(at,16,Color(R.TINTS[i],.56))
  for bend in [-1,1]:mist(at+bend*tangent*4.8,12,Color(R.TINTS[i],.26))
  for strand in 21:
   var phase:=rng.randf_range(0,TAU)
   var shift:=rng.randf_range(-1.5,1.5)
   var pts:=PackedVector3Array()
   for j in 51:
    var t:=j/50.0
    var spread:=sin(PI*t)
    var angle:=t*TAU+phase
    pts.append(at+tangent*(t-.5)*15+radial*(shift+cos(angle)*2.4)*spread+Vector3.UP*sin(angle)*spread*1.7)
   ribbon(pts,R.TINTS[i],rng.randf_range(.035,.09),false)
 var phosphor:=StandardMaterial3D.new()
 phosphor.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;phosphor.vertex_color_use_as_albedo=true
 phosphor.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;phosphor.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;phosphor.cull_mode=BaseMaterial3D.CULL_DISABLED
 instance(field,ribbons.commit(),phosphor,Vector3.ZERO)
 ribbons.clear()

func ribbon(points:PackedVector3Array,dye:Color,width:float,polar:bool) -> void:
 for i in range(1,points.size()):
  var a:=points[i-1];var b:=points[i]
  var t:=i/float(points.size()-1)
  var axis:=(b-a).cross(Vector3(.2,.94,.28)).normalized()*width
  var shade:=Color("ffc67b").lerp(dye,smoothstep(.08,.58,t)) if polar else dye
  shade.a=(.20+.64*sin(PI*t)) if polar else (.14+.78*sin(PI*t))
  for v in [a-axis,b-axis,b+axis,a-axis,b+axis,a+axis]:
   ribbons.set_color(shade);ribbons.add_vertex(v)
