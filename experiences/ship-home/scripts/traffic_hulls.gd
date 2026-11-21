# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Shipping lanes share the player's scale and nozzle convention (+Z exhaust).
const STEEL:=Color("425669")
const ICE:=Color("a2e5dc")
const BRASS:=Color("c49a63")

# Each section specifies longitudinal position, half-breadth, half-height and sheer.
static func shell(parent:Node3D,art:ShipInterior,sections:Array,tint:Color) -> void:
 var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var previous:=PackedVector3Array()
 for row:Vector4 in sections:
  var ring:=PackedVector3Array()
  for i in 12:
   var angle:=TAU*i/12
   ring.append(Vector3(cos(angle)*row.y,row.w+sin(angle)*row.z,row.x))
  if not previous.is_empty():
   for i in 12:
    var j:=(i+1)%12
    for pt in [previous[i],ring[i],ring[j],previous[i],ring[j],previous[j]]:mesh.add_vertex(pt)
  previous=ring
 mesh.generate_normals();mesh.index()
 var part:=MeshInstance3D.new();part.mesh=mesh.commit();part.material_override=art.material(tint)
 parent.add_child(part)

static func engine(parent:Node3D,art:ShipInterior,x:float,z:float,port:String) -> void:
 var start:=Vector3(x,-0.18,z-2.3)
 var end:=Vector3(x,-0.18,z)
 art.beam(parent,start,end,0.52,STEEL)
 art.beam(parent,end-Vector3.BACK*0.27,end,0.57,BRASS)
 art.beam(parent,end,end+Vector3.BACK*0.05,0.34,ICE,true)
 var socket:=Marker3D.new();socket.name=port;socket.position=end+Vector3.BACK*0.08;parent.add_child(socket)

static func vessel(parent:Node3D,art:ShipInterior,role:String) -> void:
 var tint:Color={"Courier":Color("d39758"),"Freighter":Color("ad7160"),"Envoy":Color("719a91"),"Surveyor":Color("bcc9c5"),"Pathfinder":Color("648ba3"),"Pirate":Color("89545b")}[role]
 var wide:=role=="Freighter" or role=="Envoy"
 var width:=2.12 if wide else 1.46
 shell(parent,art,[Vector4(-5.2,0.04,0.04,0.02),Vector4(-3.0,width*0.73,0.65,0.11),Vector4(-0.6,width,1.05,0.05),Vector4(2.4,width*0.85,0.81,-0.03),Vector4(3.08,0.03,0.03,0)],tint)
 shell(parent,art,[Vector4(-3.9,0.02,0.02,0.45),Vector4(-2.25,0.91,0.40,0.55),Vector4(-1.15,0.72,0.29,0.83),Vector4(-0.76,0.02,0.02,0.86)],Color("335363"))
 for sign_x in [-1,1]:
  var x:float=sign_x
  var reach:=3.3 if wide else 2.85
  art.beam(parent,Vector3(x*0.75,0.0,0.55),Vector3(x*reach,-0.18,2.20),0.22,STEEL)
  engine(parent,art,x*reach,3.3,"ExhaustPort" if sign_x<0 else "ExhaustStarboard")
  match role:
   "Freighter":
    for i in 3:
     var pod:=Vector3(x*2.35,0.32,-2.68+1.69*i)
     art.box(parent,pod,Vector3(2.02,1.45,1.56),tint)
     for dz in [-0.5,0.5]:art.box(parent,pod+Vector3.BACK*dz,Vector3(2.08,1.51,0.095),BRASS)
   "Envoy":
    var sail:=Node3D.new();parent.add_child(sail);sail.position=Vector3(x*2.6,0.55,0.26);sail.rotation.z=-x*0.48
    shell(sail,art,[Vector4(-3.1,0.02,0.02,0.0),Vector4(-0.45,0.26,1.6,0.72),Vector4(2.2,0.18,0.78,0.5),Vector4(2.7,0.02,0.02,0.3)],Color("86b6a0"))
   "Pirate","Pathfinder","Courier":
    var foil:=Node3D.new();parent.add_child(foil);foil.position=Vector3(x*2.15,0.02,0);foil.rotation.y=x*(-0.40 if role=="Pirate" else 0.48)
    shell(foil,art,[Vector4(-3.2,0.02,0.02,0),Vector4(0.6,0.89,0.14,0.1),Vector4(2.65,0.54,0.17,0.16),Vector4(3.02,0.02,0.02,0.16)],tint)
   "Surveyor":
    art.beam(parent,Vector3(x,0.5,-0.3),Vector3(x*3.8,1.44,-0.8),0.11,BRASS)
    var dish:=art.cylinder(parent,Vector3(x*3.8,1.54,-0.8),0.31,0.48,Color("d1d9cf"),1.03)
    dish.rotation.z=-x*0.42
  art.beam(parent,Vector3(x*0.92,0.55,-2.76),Vector3(x*1.03,0.68,-1.73),0.054,ICE,true)
 art.batch_static(parent)

# A continuous, tapered mantle. The same surface carries the twin wing tips and long tail.
static func ray(parent:Node3D) -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows:Array[PackedVector3Array]=[]
 for i in 45:
  var u:=(i-22)/22.0;var span:=absf(u)
  var nose:=-3.6+5.48*pow(span,1.35)
  var tail:=2.15+1.2*sin(span*PI)+6.4*exp(-pow(span*14.0,2))
  var thickness:=(0.16+0.78*exp(-span*span*12.0))*(1.0-span)+0.017
  var ring:=PackedVector3Array()
  for j in 18:
   var angle:=TAU*j/18.0
   ring.append(Vector3(u*7.1,0.50*span*span+thickness*sin(angle),lerpf(nose,tail,(1-cos(angle))*0.5)))
  rows.append(ring)
 for i in 44:
  for j in 18:
   var k:=(j+1)%18
   for pt:Vector3 in [rows[i][j],rows[i+1][j],rows[i+1][k],rows[i][j],rows[i+1][k],rows[i][k]]:surface.add_vertex(pt)
 surface.generate_normals();surface.index()
 var mantle:=MeshInstance3D.new();mantle.mesh=surface.commit()
 var skin:=ShaderMaterial.new();skin.shader=preload("res://shaders/veil_ray.gdshader")
 mantle.material_override=skin;mantle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mantle.extra_cull_margin=2
 parent.add_child(mantle)
