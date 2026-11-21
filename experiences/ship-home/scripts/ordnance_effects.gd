# SPDX-License-Identifier: GPL-3.0-or-later
extends MeshInstance3D
## Arcade tracers in sector coordinates. The same endpoints drive damage and light.
var strokes:=ImmediateMesh.new()
var eye:=Vector3.ZERO
func _ready() -> void:
 var glow:=StandardMaterial3D.new()
 glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.vertex_color_use_as_albedo=true
 glow.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 glow.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 glow.cull_mode=BaseMaterial3D.CULL_DISABLED
 material_override=glow
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mesh=strokes
 hide()

func streak(start:Vector3,finish:Vector3,radius:float,color:Color) -> void:
 var across:=(finish-start).cross(eye-start).normalized()
 if across.length_squared()<0.01:across=Vector3.RIGHT
 var edge:=across*radius
 for pt in [start-edge,finish-edge,finish+edge,start-edge,finish+edge,start+edge]:
  strokes.surface_set_color(color);strokes.surface_add_vertex(pt)

func refresh(a) -> void:
 visible=a.pulse_time>0 or a.missile_time>0 or a.incoming>0 or a.flare_time>0
 if not visible:return
 eye=a.f.location+a.f.attitude*Vector3(0,1.2,-3.9)
 strokes.clear_surfaces()
 strokes.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 if a.pulse_time>0:
  var t:float=1.0-a.pulse_time/a.burst_span
  if a.shot_group==a.Group.PULSE:
   streak(a.burst_from.lerp(a.burst_to,maxf(0,t-0.10)),a.burst_from.lerp(a.burst_to,maxf(t,0.003)),0.48,Color("ffd494"))
  else:
   streak(a.burst_from,a.burst_to,0.047,Color("50decf39"))
   streak(a.burst_from,a.burst_to,0.014,Color("a4fff4"))
 if a.missile_time>0:
  var t:float=1-a.missile_time/a.FLIGHT_TIME
  var goal:Vector3=a.position_of(a.WARDEN)
  streak(a.missile_from.lerp(goal,maxf(0,t-0.09)),a.missile_from.lerp(goal,maxf(t,0.003)),0.82,Color("ffc27a"))
 if a.incoming>0:
  var p:Vector3=a.incoming_point()
  streak(p,p+(a.incoming_from-a.f.location).normalized()*8,0.68,Color("ff817d"))
 if a.flare_time>0:
  for arm in [a.f.attitude.x,a.f.attitude.y]:
   var half:Vector3=arm*(1.0-a.flare_time/0.65)*8
   streak(a.flare_at-half,a.flare_at+half,0.38,Color("9efaff"))
 strokes.surface_end()
