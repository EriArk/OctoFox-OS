// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D display : source_color, filter_linear, repeat_disable;
const vec2 TEXEL = vec2(1.0 / 600.0, 1.0 / 360.0);
vec3 phosphor(vec2 uv){
 vec3 col=texture(display,uv).rgb;
 return col*smoothstep(0.18,0.68,max(col.r,max(col.g,col.b)));
}
void fragment(){
 vec3 core=texture(display,UV).rgb;
 vec3 halo=vec3(0.0);
 for(int j=0;j<4;j++){
  vec2 axis=vec2(cos(float(j)*1.5707963),sin(float(j)*1.5707963));
  halo+=phosphor(UV+axis*TEXEL*1.8)*0.13;
  halo+=phosphor(UV+axis*TEXEL*4.2)*0.060;
  halo+=phosphor(UV+axis*TEXEL*7.3)*0.022;
 }
 // Keep the round counters of small numerals open while spilling light onto the glass.
 ALBEDO=core+halo*(1.0-0.68*clamp(max(core.r,max(core.b,core.g)),0.0,1.0));
}
