// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color;
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
 vec2 p=UV*2.-1.;
 float r=dot(p,p);
 ALBEDO=tint.rgb;
 ALPHA=tint.a*exp(-4.4*r)*(1.-smoothstep(.57,1.,r));
}
