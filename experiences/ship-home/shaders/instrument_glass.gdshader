// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D display : source_color, filter_linear, repeat_disable;
const vec2 TEXEL = vec2(1.0 / 600.0, 1.0 / 360.0);

vec3 phosphor(vec2 uv){
 vec3 col=texture(display,uv).rgb;
 return col*smoothstep(0.25,0.72,max(col.r,max(col.g,col.b)));
}

void fragment(){
 vec3 core=texture(display,UV).rgb;
 vec3 halo=vec3(0.0);
 // Keep the glow inside neighbouring texels so narrow lettering has a single edge.
 for(int j=0;j<4;j++){
  float angle=float(j)*1.5707963;
  vec2 axis=vec2(cos(angle),sin(angle));
  vec2 diagonal=vec2(axis.x-axis.y,axis.x+axis.y);
  halo+=phosphor(UV+axis*TEXEL)*0.065;
  halo+=phosphor(UV+diagonal*TEXEL*1.35)*0.028;
 }
 ALBEDO=core+halo*(1.0-0.68*clamp(max(core.r,max(core.b,core.g)),0.0,1.0));
}
