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
 float depth = smoothstep(0.08,0.75,UV.y + wave*0.065);
 vec3 water = mix(shallows.rgb,channel.rgb,depth);
 float wash = UV.y*24.0 + wave*1.1-flow_time*1.35;
 float strand = smoothstep(0.81,1.0,sin(wash))*(1.0-smoothstep(0.34,0.62,UV.y));
 strand *= 1.0-smoothstep(0.35,1.5,fwidth(wash));
 float phase = p.y*3.1+sin(p.x*2.3)+flow_time*0.8;
 float glint = smoothstep(0.92,1.0,sin(phase))*smoothstep(0.22,0.92,wave)*(1.0-smoothstep(0.15,1.1,fwidth(phase)));
 float lip = smoothstep(0.91,0.995,UV.y+0.016*wave);
 ALBEDO = mix(water,crest.rgb,strand*0.53+glint*0.31+lip*0.66);
}
