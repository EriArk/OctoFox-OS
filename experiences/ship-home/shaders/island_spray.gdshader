// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float flow_time;
varying float phase;
varying float seed;
void vertex() {
 seed=INSTANCE_CUSTOM.r;
 phase=fract(flow_time*(0.14+0.045*seed)+seed);
 // Instances carry a radial basis. Drift out from the cliff, then lift in the air.
 float spread=INSTANCE_CUSTOM.g*11.0;
 vec3 drift=vec3(0.26*sin(phase*4.0+seed*29.0),phase*phase*1.85,phase*1.55)*spread;
 vec4 center=MODELVIEW_MATRIX*vec4(drift,1.0);
 center.xy += VERTEX.xy*spread*(0.65+1.25*phase);
 POSITION=PROJECTION_MATRIX*center;
}
void fragment() {
 vec2 q=UV*2.0-1.0;
 float wiggle=0.15*sin(q.x*7.0+seed*22.0+phase*1.5)*cos(q.y*6.0-seed*16.0);
 float plume=1.0-smoothstep(0.30,0.92,length(q*vec2(0.93,1.12))+wiggle);
 ALBEDO=mix(vec3(0.42,0.69,0.75),vec3(0.89,0.94,0.85),clamp(0.6-q.y*0.45,0.0,1.0));
 ALPHA=plume*smoothstep(0.0,0.25,phase)*(1.0-smoothstep(0.56,1.0,phase))*0.49;
}
