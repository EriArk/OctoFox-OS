# SPDX-License-Identifier: GPL-3.0-or-later
extends Node3D
const POS=Vector3(1.53,1.095,5.42)
var home:Node
var client:Node
var shown:Dictionary={}
var mesh_root:Node3D
var serial:=0
var pending:=false

func configure(ship:Node,host:Node) -> void:
 home=ship;client=host;position=POS;rotation.y=PI
 client.trophy_reply.connect(receive)
 client.trophies_disconnected.connect(reset)
 var timer:=Timer.new();add_child(timer);timer.wait_time=60
 timer.timeout.connect(restore);timer.start()

func owned() -> Array:
 return [] if shown.is_empty() else [shown]

func reset() -> void:
 serial+=1;pending=false;render({})

func restore() -> void:
 if not home.store.trophy_key.is_empty() and not pending:read(false)

func read(advance:bool) -> void:
 if pending:return
 if home.profile.is_empty() or client.profile_id!=home.profile or not client.trophies_supported:
  if advance:home.notify("Game trophies need a connected profile and trophy service.")
  return
 var args:Dictionary={"limit":1}
 var key:String=home.store.trophy_key
 if key!="":args["after" if advance else "key"]=key
 pending=true;serial+=1
 client.read_trophies(args,serial,advance)

func receive(ticket:int,advance:bool,result:Dictionary,error:String) -> void:
 if ticket!=serial or not pending:return
 pending=false
 if error!="" or not result.get("items") is Array:
  render({})
  if advance:home.notify("Could not load trophies. Check your account and try again.")
  return
 var rows:Array=result.items
 var row:Dictionary={} if rows.is_empty() else rows[0]
 if not row.is_empty() and (row.get("earned")!=true or row.get("shape") not in ["cup","medal","plaque"] or not row.get("key") is String or row.key==""):
  render({});return
 var key:String=row.get("key","")
 if not advance and key!="" and key!=home.store.trophy_key:return
 if key!=home.store.trophy_key:
  var previous:String=home.store.trophy_key
  home.store.trophy_key=key
  if not home.store.save(home.rows):
   home.store.trophy_key=previous;render({});home.notify(home.store.error);return
 render(row)
 if advance:home.notify(row.get("title","Trophy shelf empty"))

func render(row:Dictionary) -> void:
 if row==shown:return
 shown=row
 if is_instance_valid(mesh_root):
  remove_child(mesh_root);mesh_root.queue_free();mesh_root=null
 if row.is_empty():return
 var art=home.art
 mesh_root=Node3D.new();add_child(mesh_root)
 art.cylinder(mesh_root,Vector3.UP*0.021,0.116,0.042,art.WALNUT)
 match row.shape:
  "cup":
   art.cylinder(mesh_root,Vector3.UP*0.085,0.041,0.090,art.BRASS,0.021)
   art.cylinder(mesh_root,Vector3.UP*0.163,0.035,0.086,art.BRASS,0.090)
   art.cylinder(mesh_root,Vector3.UP*0.207,0.076,0.002,art.WALNUT)
   for side in [-1,1]:
    var handle:Array[Vector3]=[Vector3(side*0.070,0.193,0),Vector3(side*0.112,0.192,0),Vector3(side*0.100,0.159,0),Vector3(side*0.051,0.144,0)]
    art.tube(mesh_root,handle,0.008,art.BRASS)
  "medal":
   for side in [-1,1]:
    art.beam(mesh_root,Vector3(side*0.062,0.247,0),Vector3(0,0.155,0),0.015,art.ENAMEL)
   var medal=art.cylinder(mesh_root,Vector3.UP*0.121,0.057,0.014,art.BRASS)
   medal.rotation.x=PI/2
  "plaque":
   art.box(mesh_root,Vector3.UP*0.133,Vector3(0.176,0.16,0.027),art.BRASS)
   art.box(mesh_root,Vector3(0,0.133,0.018),Vector3(0.15,0.132,0.012),art.ENAMEL)
 art.box(mesh_root,Vector3(0,0.033,0.104),Vector3(0.17,0.04,0.012),art.BRASS)
 art.batch_static(mesh_root)
 var plate:=Label3D.new();mesh_root.add_child(plate)
 plate.text=str(row.title).left(20);plate.position=Vector3(0,0.034,0.112)
 plate.font_size=24;plate.pixel_size=0.00048;plate.outline_size=0;plate.modulate=art.NIGHT
