// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float flow_time;
varying float arc;
void vertex() { arc = COLOR.r; }
void fragment() {
 float x=UV.x, drop=UV.y;
 float ripple=sin(22.0*x+arc*19.0+0.48*sin(drop*6.0-flow_time*2.2));
 float thread=0.5+0.5*sin(83.0*x+10.0*sin(x*11.0+arc*23.0)+arc*37.0+ripple+1.8*sin(x*16.0+drop*2.1-flow_time*0.44));
 float stream=smoothstep(0.45,0.93,thread)*(1.0-smoothstep(0.09,0.32,fwidth(x)));
 float pulse=0.5+0.5*cos(drop*20.0-flow_time*5.6+3.0*ripple);
 float ragged=0.80+0.10*ripple+0.085*thread;
 float edge=smoothstep(0.0,0.09,min(x,1.0-x));
 float veil=(1.0-smoothstep(ragged-0.22,ragged,drop))*edge;
 ALBEDO=mix(vec3(0.035,0.29,0.38),vec3(0.68,0.89,0.81),clamp(0.20+0.24*stream+0.18*pulse+0.22*(1.0-smoothstep(0.0,0.1,drop)),0.0,1.0));
 ALPHA=veil*(0.64+0.18*stream+0.13*pulse);
}
