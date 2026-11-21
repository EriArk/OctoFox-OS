// SPDX-License-Identifier: GPL-3.0-or-later
shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*4375.5);}
void sky(){
 vec3 d=normalize(EYEDIR);
 vec2 uv=vec2(atan(d.z,d.x)/6.2831853,asin(d.y)/3.141593);
 vec2 cell=uv*vec2(600.,300.);
 float h=hash(floor(cell));
 float star=step(.981,h)*exp(-19.*dot(fract(cell)-.5,fract(cell)-.5));
 float mist=exp(-5.*abs(d.y+.36*d.x+.12*sin(4.*d.z)));
 COLOR=vec3(.006,.012,.024)+mist*vec3(.016,.014,.039)+star*mix(vec3(.28,.44,.67),vec3(.83,.73,.53),h);
}
