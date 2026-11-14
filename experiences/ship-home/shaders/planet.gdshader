// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded;
varying vec3 sphere_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { sphere_position=VERTEX; }
void fragment() {
 vec3 n=normalize(sphere_position);
 float broad=noise(n*6.0);
 vec3 p=n*vec3(15.0,36.0,15.0)+vec3(broad*3.0);
 float cloud=noise(p)*0.6+noise(p*2.1)*0.28+noise(p*4.2)*0.12;
 float bands=sin(n.y*24.0+broad*2.0)*0.5+0.5;
 vec3 c=mix(vec3(0.20,0.18,0.39),vec3(0.63,0.52,0.79),smoothstep(0.25,0.73,cloud));
 c+=vec3(0.06,0.035,0.065)*bands;
 float light=clamp(dot(n,normalize(vec3(-0.6,0.4,0.7))),0.09,1.0);
 float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.8);
 ALBEDO=c*light+vec3(0.26,0.38,0.70)*rim*0.7;
}
