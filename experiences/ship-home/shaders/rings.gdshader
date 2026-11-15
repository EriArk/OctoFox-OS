// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
 float r=UV.x;
 float bands=0.65+0.13*sin(r*95.0)+0.045*sin(r*230.0);
 float gap=1.0-smoothstep(0.49,0.505,r)*(1.0-smoothstep(0.54,0.555,r));
 ALBEDO=mix(vec3(0.34,0.28,0.48),vec3(0.85,0.72,0.71),bands)*gap;
 ALPHA=smoothstep(0.0,0.02,r)*(1.0-smoothstep(0.95,1.0,r))*bands*0.8*gap;
}
