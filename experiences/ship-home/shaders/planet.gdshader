shader_type spatial;
render_mode unshaded;
varying vec3 sphere_position;
void vertex() { sphere_position=VERTEX; }
void fragment() {
 vec3 n=normalize(sphere_position);
 float swirl=sin(n.x*13.0+n.z*7.0)*0.06+sin(n.z*29.0-n.x*11.0)*0.025;
 float bands=sin((n.y+swirl)*35.0)*0.5+0.5;
 float fine=sin((n.y+swirl*0.6)*125.0)*0.5+0.5;
 vec3 c=mix(vec3(0.13,0.30,0.38),vec3(0.55,0.68,0.67),smoothstep(0.15,0.85,bands));
 c=mix(c,vec3(0.83,0.67,0.45),smoothstep(0.67,0.93,bands)*0.65);
 c+=vec3(0.04,0.05,0.05)*fine;
 float light=clamp(dot(n,normalize(vec3(-0.6,0.4,0.7))),0.045,1.0);
 float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.8);
 ALBEDO=c*light+vec3(0.16,0.43,0.65)*rim*0.7;
}
