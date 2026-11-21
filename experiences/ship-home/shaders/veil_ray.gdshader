shader_type spatial;
render_mode cull_disabled;
varying vec3 mantle;
void vertex(){
 mantle=VERTEX;
 float wing=pow(abs(VERTEX.x)/7.1,1.65);
 VERTEX.y+=wing*(1.30*sin(TIME*1.95-abs(VERTEX.x)*0.42-VERTEX.z*0.19));
 VERTEX.x+=0.42*smoothstep(2.0,8.0,VERTEX.z)*sin(TIME*1.95-VERTEX.z*0.65);
}
void fragment(){
 float span=abs(mantle.x)/7.1;
 float fringe=smoothstep(0.60,0.98,span);
 float ribs=pow(max(0.0,cos(mantle.z*3.5-span*10.0)),9.0)*smoothstep(0.10,0.33,span);
 float eyes=1.0-smoothstep(0.07,0.20,length(vec2(abs(mantle.x)-0.83,mantle.z+2.65)));
 vec3 blue=vec3(0.027,0.17,0.29), sea=vec3(0.11,0.78,0.63), lilac=vec3(0.56,0.33,0.78);
 ALBEDO=mix(blue,lilac,fringe*0.74);
 EMISSION=ALBEDO*0.39+sea*(ribs*0.65+eyes*1.8)+lilac*fringe*0.42;
 ROUGHNESS=0.42;
}
