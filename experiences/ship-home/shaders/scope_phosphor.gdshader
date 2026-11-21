// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, depth_draw_never;
void fragment(){
 vec2 p=(UV-0.5)*0.51;
 float r=length(p);
 float d=min(abs(r-0.235),min(abs(r-0.155),abs(r-0.08)));
 ALBEDO=vec3(1.0,0.50,0.14);
 ALPHA=(0.30*exp(-d*240.0)+0.07*exp(-d*90.0))*(1.0-smoothstep(0.241,0.25,r));
}
