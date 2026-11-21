# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Art=preload("res://scripts/interior.gd")
const Computer=preload("res://scripts/ship_computer.gd")
const SAMPLES=["sunbell","tideflower","starbloom","bauxite","magnetite","livewell"]
const TINTS=[Color("e0ad56"),Color("77b5ad"),Color("a69ac3"),Color("be7955"),Color("8c9ca4"),Color("599ba8")]
var art:ShipInterior
var cargo:=Node3D.new()
var sockets:=Node3D.new()
var payloads:Dictionary={}
var mounts:Dictionary={}
var targets:Dictionary={}

func build_fixed(room:Node3D,builder:ShipInterior) -> void:
 art=builder
 for rack in [cargo,sockets]:
  var angle:=deg_to_rad(247.5 if rack==cargo else 67.5)
  room.add_child(rack);rack.position=Vector3(sin(angle),0,cos(angle))*2.25;rack.rotation.y=angle+PI
  art.box(rack,Vector3(0,1.00,0.07),Vector3(1.68,1.70,0.26),Art.NIGHT,true)
  for x in [-0.81,0.81]:
   art.box(rack,Vector3(x,1.00,0.19),Vector3(0.075,1.77,0.36),Art.TRIM,true)
   art.box(rack,Vector3(x,1.02,0.375),Vector3(0.026,1.53,0.012),Art.COPPER)
  art.box(rack,Vector3(0,1.80,0.21),Vector3(1.7,0.17,0.34),Art.WALNUT)
  art.label(rack,"CARGO HOLD" if rack==cargo else "DRIVE MODULES",Vector3(0,1.80,0.386),0,29,Art.PAPER)
 for y in [0.42,1.08]:
  art.box(cargo,Vector3(0,y,0.29),Vector3(1.56,0.07,0.39),Art.TRIM,true)
  art.box(cargo,Vector3(0,y,0.489),Vector3(1.54,0.026,0.015),Art.BRASS)
 for i in SAMPLES.size():
  var p:=Vector3((i%3-1)*0.50,1.12 if i<3 else 0.46,0.30)
  art.label(cargo,SAMPLES[i].to_upper(),p+Vector3(0,0.48,-0.085),0,13,Art.PAPER)
  mounts[SAMPLES[i]]=p
 targets.cargo=cargo.to_global(Vector3(0,1.03,0.46))
 for i in Computer.KITS.size():
  var x:float=(i-0.5)*0.77
  var kit:String=Computer.KITS[i]
  var p:=Vector3(x,1.01,0.22);mounts[kit]=p
  art.faceplate(sockets,p,Vector2(0.69,0.99),0.09,Color("15282c"))
  art.bezel(sockets,p+Vector3.BACK*0.015,Vector2(0.69,0.99),0.09,0.037,Art.BRASS)
  for side in [-1,1]:
   art.box(sockets,p+Vector3(side*0.24,0,0.037),Vector3(0.055,0.76,0.055),Art.TRIM)
  for tooth in 5:
   art.box(sockets,p+Vector3((tooth-2)*0.07,-0.22,0.045),Vector3(0.038,0.15,0.06),Art.COPPER)
  art.label(sockets,kit.to_upper(),p+Vector3(0,-0.63,0.015),0,21,Art.PAPER)
  targets[kit]=sockets.to_global(p+Vector3.BACK*0.31)

func build_payloads() -> void:
 for i in SAMPLES.size():
  var sku:String=SAMPLES[i]
  var item:=Node3D.new();cargo.add_child(item);item.position=mounts[sku]
  if i<3:
   art.cylinder(item,Vector3.UP*0.19,0.143,0.33,TINTS[i])
   for y in [0.037,0.35]:art.cylinder(item,Vector3.UP*y,0.158,0.055,Art.BRASS)
   art.box(item,Vector3(0,0.21,0.137),Vector3(0.12,0.072,0.019),Art.PAPER)
  else:
   art.box(item,Vector3.UP*0.19,Vector3(0.41,0.36,0.28),TINTS[i])
   art.box(item,Vector3.UP*0.37,Vector3(0.43,0.038,0.30),Art.TRIM)
   if sku=="livewell":art.faceplate(item,Vector3(0,0.19,0.145),Vector2(0.31,0.15),0.052,Art.SEA_GLASS)
   else:
    for x in [-0.11,0.11]:art.box(item,Vector3(x,0.19,0.145),Vector3(0.044,0.35,0.02),Art.BRASS)
  art.batch_static(item);payloads[sku]=item
 for i in Computer.KITS.size():
  var kit:String=Computer.KITS[i]
  var item:=Node3D.new();sockets.add_child(item);item.position=mounts[kit]
  art.box(item,Vector3(0,0,0.125),Vector3(0.565,0.83,0.22),Art.ENAMEL if i==0 else Color("98634f"))
  art.bezel(item,Vector3(0,0,0.238),Vector2(0.54,0.80),0.06,0.021,Art.BRASS)
  for y in [-0.23,0.23]:
   art.box(item,Vector3(0,y,0.30),Vector3(0.14,0.083,0.15),Art.TRIM)
  art.beam(item,Vector3(0,-0.25,0.375),Vector3(0,0.25,0.375),0.046,Art.BRASS)
  art.box(item,Vector3(0.16,0.28,0.24),Vector3(0.075,0.025,0.014),Art.SEA_GLASS,false,true)
  art.batch_static(item);payloads[kit]=item

func sync(store:ShipLayoutStore,installed:Array) -> void:
 for sku in SAMPLES:
  if sku=="livewell":payloads[sku].visible=store.fish.any(func(row):return row.place!="tank")
  else:payloads[sku].visible=not store.field_cargo(sku).get(sku,{}).get("days",[]).is_empty()
 for kit in Computer.KITS:payloads[kit].visible=kit in installed

func nearest(p:Vector2) -> String:
 var reach:=0.85
 var result:=""
 for id in targets:
  var at:Vector3=targets[id];var distance:=p.distance_to(Vector2(at.x,at.z))
  if distance<reach:reach=distance;result=id
 return result
