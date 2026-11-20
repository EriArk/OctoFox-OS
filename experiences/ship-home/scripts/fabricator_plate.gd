# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## One cached outfit atlas; cartridges and the drafting grid only redraw on selection.
const ATLAS = preload("res://assets/fabricator/garments.png")
const TINTS = [Color("#edc39f"),Color("#9fd5c3"),Color("#a9c8e1"),Color("#bdadc9")]
var row := 0
var column := 0
var cartridge := false
var gridded := false

func present(index: int, part: int, material_view: bool) -> void:
 row=index;column=part;cartridge=material_view;queue_redraw()

func _draw() -> void:
 var grid:=Color("#385458")
 if gridded:
  draw_rect(Rect2(Vector2.ZERO,size),Color("#233d41"))
  for x in range(0,int(size.x),28):draw_line(Vector2(x,0),Vector2(x,size.y),grid,1.0,true)
  for y in range(0,int(size.y),28):draw_line(Vector2(0,y),Vector2(size.x,y),grid,1.0,true)
  for sx in [0,1]:
   for sy in [0,1]:
    var corner:=Vector2(8 if sx==0 else size.x-8,8 if sy==0 else size.y-8)
    draw_line(corner,corner+Vector2(13*(1-sx*2),0),Color("#91a7a1"),1.5)
    draw_line(corner,corner+Vector2(0,13*(1-sy*2)),Color("#91a7a1"),1.5)
 var side:=minf(size.x,size.y)
 if cartridge:
  draw_set_transform(size/2,-0.15,Vector2.ONE*side/132)
  draw_cartridge()
  draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
 else:
  var cell:=ATLAS.get_height()/3
  draw_texture_rect_region(ATLAS,Rect2((size-Vector2.ONE*side)/2,Vector2.ONE*side),Rect2(column*cell,row*cell,cell,cell))

func draw_cartridge() -> void:
 var tint:Color=TINTS[row]
 var body:=PackedVector2Array([Vector2(-53,-18),Vector2(-43,-28),Vector2(36,-28),Vector2(51,-18),Vector2(51,19),Vector2(41,27),Vector2(-44,27),Vector2(-53,17)])
 draw_colored_polygon(body,Color("#9bb1aa"))
 draw_rect(Rect2(-50,-16,99,34),Color("#415c60"))
 draw_rect(Rect2(-35,-14,69,29),tint.darkened(0.35))
 # The inspection window shows the feedstock: fibre, filament, or metal strips.
 if row<2:
  for i in 9:
   var px:float=-28+i*7
   if row==0:
    draw_line(Vector2(px-4,-11),Vector2(px+4,11),tint,3,true)
    draw_line(Vector2(px+4,-11),Vector2(px-4,11),tint.lightened(0.12),1,true)
   else:draw_arc(Vector2(px,0),9,-PI*0.5,PI*0.5,13,tint,2,true)
 else:
  for i in 4:
   var y:float=-10+i*6
   draw_line(Vector2(-29,y),Vector2(30,y),tint,3,true)
 for px in [-49,35]:
  draw_rect(Rect2(px,-21,12,43),Color("#263f44"))
  for y in [-15,-7,1,9]:draw_line(Vector2(px+2,y),Vector2(px+10,y),Color("#879f9a"),1.5,true)
 draw_rect(Rect2(50,-8,7,16),Color("#d1af75"))
 draw_line(Vector2(-36,-24),Vector2(32,-24),Color("#e2e7d5"),1.5,true)
