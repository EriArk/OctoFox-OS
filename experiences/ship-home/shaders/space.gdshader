shader_type sky;
render_mode use_debanding;
float hash(vec3 p) { p=fract(p*vec3(123.34,456.21,78.91)); p+=dot(p,p+45.32); return fract(p.x*p.y*p.z); }
void sky() {
 vec3 d=normalize(EYEDIR);
 float haze=pow(max(0.0,1.0-abs(d.y*0.85+d.x*0.33+0.18)),10.0);
 float cloud=0.5+0.5*sin(d.x*10.0+sin(d.z*12.0))*sin(d.y*18.0+d.z*8.0);
 vec3 base=mix(vec3(0.012,0.020,0.048),vec3(0.15,0.16,0.30),haze*cloud);
 base+=vec3(0.10,0.04,0.15)*haze*(1.0-cloud);
 vec2 uv=vec2(atan(d.z,d.x)*0.15915494+0.5,asin(d.y)*0.31830989+0.5)*vec2(600.0,300.0);
 float h=hash(vec3(floor(uv),1.0));
 float star=step(0.991,h)*pow(max(0.0,1.0-length(fract(uv)-0.5)*2.0),2.0);
 COLOR=base+vec3(0.85,0.91,1.0)*star*3.0;
}
