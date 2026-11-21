// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled, depth_draw_never;
uniform vec4 tint: source_color = vec4(0.54,0.9,0.84,1.0);
void fragment(){
 vec2 p=abs((UV-0.5)*vec2(0.694,0.454))-vec2(0.296,0.176);
 float dist=abs(length(max(p,vec2(0)))+min(max(p.x,p.y),0.0)-0.004);
 float bloom=0.54*exp(-dist*430.0)+0.18*exp(-dist*128.0);
 ALBEDO=tint.rgb;
 ALPHA=bloom*(1.0-smoothstep(0.029,0.045,dist));
}
