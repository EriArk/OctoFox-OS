// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float r=length(p), a=atan(p.y,p.x);
 float edge=smoothstep(.055,.14,r)*(1.0-smoothstep(.73,.99,r));
 float warp=r+.016*sin(3.0*a+6.0*r)+.007*cos(7.0*a-8.0*r);
 float dust=.5+.5*sin(warp*156.0+2.7*sin(a*4.0-warp*17.0));
 float thread=pow(.5+.5*cos(warp*257.0-3.0*a+.6*sin(a*8.0+TIME*.05)),10.0);
 float lane=exp(-pow((warp-.67)*11.0,2.0))+.55*exp(-pow((warp-.47)*18.0,2.0));
 float inner=exp(-pow((warp-.145)*13.0,2.0));
 vec3 dye=mix(vec3(.14,.19,.65),vec3(.12,.57,.64),.5+.5*cos(2.0*a+warp*7.0));
 dye=mix(dye,vec3(.67,.18,.49),.5+.5*sin(3.0*a-warp*12.0));
 dye=mix(dye,vec3(1.0,.55,.15),(1.0-smoothstep(.06,.42,r)));
 ALBEDO=dye*(.72+thread)+inner*vec3(1.0,.52,.13);
 ALPHA=edge*(.11+.30*lane+.19*dust*lane+.40*thread*lane+.85*inner);
}
