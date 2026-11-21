// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform float presence = 0.0;
varying float seed;
varying float near_fade;
void vertex() {
 seed = INSTANCE_CUSTOM.r;
 vec4 center = MODELVIEW_MATRIX * vec4(0.0,0.0,0.0,1.0);
 float width=length(MODEL_MATRIX[0].xyz), height=length(MODEL_MATRIX[1].xyz);
 float relative=length(center.xyz)/width;
 float front=mix(0.04,1.0,smoothstep(0.34,0.78,INSTANCE_CUSTOM.g));
 near_fade=mix(front,1.0,presence)*smoothstep(0.07,0.60,relative)*mix(1.0,0.45,smoothstep(1.4,4.0,relative));
 center.xy+=VERTEX.xy*vec2(width,height);
 POSITION=PROJECTION_MATRIX*center;
}
float hash(vec2 p){ return fract(sin(dot(p,vec2(17.53,63.71)))*4375.13); }
float soft_noise(vec2 p){
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fragment(){
 vec2 p = UV*2.0-1.0;
 vec2 offset=vec2(seed*41.0,seed*17.0);
 float billows=soft_noise(p*3.4+offset)*0.62+soft_noise(p*8.1+offset)*0.27+soft_noise(p*18.0+offset)*0.11;
 float density=1.0-length(p*vec2(1.02,1.10))+(billows-0.55)*0.91;
 float contour=smoothstep(0.06,0.57,density);
 float light=clamp(0.50-0.43*p.y+0.43*(billows-0.4),0.0,1.0);
 ALBEDO=mix(vec3(0.24,0.38,0.50),vec3(0.90,0.84,0.72),light);
 ALPHA=contour*near_fade*presence*0.77;
}
