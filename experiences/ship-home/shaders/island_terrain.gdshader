// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded;
varying vec3 stone_pos;
varying vec3 face;
void vertex(){ stone_pos=VERTEX;face=NORMAL; }
void fragment(){
 vec3 n=normalize(face);
 vec2 p=stone_pos.xz;
 float slope=1.0-smoothstep(0.53,0.91,n.y);
 float bed=sin(stone_pos.y*0.81+2.1*sin(p.x*0.13)+1.7*sin(p.y*0.095));
 float grain=sin(dot(p,vec2(1.61,1.17))+2.6*sin(p.y*0.73))*cos(p.y*1.37);
 float detail=1.0-smoothstep(0.6,2.0,fwidth(p.x)+fwidth(p.y));
 float sun=dot(n,normalize(vec3(-0.47,0.77,-0.42)));
 vec3 rock=COLOR.rgb*(0.82+0.25*sun+0.031*bed*slope+0.035*grain*detail);
 rock+=vec3(0.025,0.022,0.025)*slope;
 ALBEDO=rock;
}
