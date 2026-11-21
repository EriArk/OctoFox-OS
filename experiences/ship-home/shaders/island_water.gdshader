// SPDX-License-Identifier: GPL-3.0-or-later
// Shore wash and distance-filtered glints adapted from Bazaar's sea shader.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float flow_time;
uniform vec4 shallows : source_color = vec4(0.47,0.85,0.78,1.0);
uniform vec4 channel : source_color = vec4(0.10,0.51,0.61,1.0);
uniform vec4 crest : source_color = vec4(0.88,0.97,0.88,1.0);
varying vec2 shore_pos;
void vertex() { shore_pos = VERTEX.xz; }
void fragment() {
 vec2 p = shore_pos;
 float wave = sin(p.x*1.1+p.y*0.7+flow_time*0.7)*sin(p.y*1.3-flow_time*0.45);
 float depth = smoothstep(0.015,0.26,UV.y + wave*0.006);
 float shoals = 0.5+0.5*sin(p.x*0.10+sin(p.y*0.08))*cos(p.y*0.14);
 depth *= 1.0-0.35*shoals*(1.0-smoothstep(0.10,0.48,UV.y));
 float current=0.5+0.5*sin(p.x*0.038+p.y*0.021+1.6*sin(p.y*0.053));
 float shelf=smoothstep(0.32,0.94,0.60*shoals+0.40*current)*(1.0-smoothstep(0.25,0.85,UV.y));
 vec3 offshore=mix(channel.rgb,vec3(0.025,0.18,0.29),smoothstep(0.09,0.78,UV.y)*(0.42+0.44*current));
 vec3 water=mix(shallows.rgb,offshore,depth);
 water=mix(water,shallows.rgb,shelf*0.47);
 if(UV.x<0.0){ water=mix(channel.rgb,shallows.rgb,0.39+0.26*current); }

 float wash = UV.y*186.0 + wave*1.1-flow_time*1.35;
 float strand = smoothstep(0.81,1.0,sin(wash))*(1.0-smoothstep(0.02,0.085,UV.y));
 strand *= 1.0-smoothstep(0.35,1.5,fwidth(wash));
 float phase = p.y*3.1+sin(p.x*2.3)+flow_time*0.8;
 float glint = smoothstep(0.92,1.0,sin(phase))*smoothstep(0.22,0.92,wave)*(1.0-smoothstep(0.15,1.1,fwidth(phase)));
 float lip = smoothstep(0.987,0.999,UV.y+0.0015*wave);
 float comb=sin(p.y*0.55+sin(p.x*0.32)+flow_time*0.34);
 float whitecap=smoothstep(0.92,0.995,comb)*smoothstep(0.4,0.86,sin(p.x*0.83+p.y*0.22))*current;
 whitecap*=1.0-smoothstep(0.45,1.5,fwidth(p.x)+fwidth(p.y));
 ALBEDO=mix(water,crest.rgb,(UV.x<0.0?0.0:strand*0.53)+glint*0.31+lip*0.66+whitecap*0.18);
}
