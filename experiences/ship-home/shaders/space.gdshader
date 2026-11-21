shader_type sky;
render_mode use_debanding;
uniform sampler2D coast : source_color, filter_linear, repeat_disable;
uniform float local_air = 0.0;
float hash(vec3 p) { p=fract(p*vec3(123.34,456.21,78.91)); p+=dot(p,p+45.32); return fract(p.x*p.y*p.z); }
float cloud_noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(vec3(i,5.0)),hash(vec3(i+vec2(1,0),5.0)),f.x),
            mix(hash(vec3(i+vec2(0,1),5.0)),hash(vec3(i+vec2(1),5.0)),f.x),f.y);
}
void sky() {
 vec3 d=normalize(EYEDIR);
 float haze=pow(max(0.0,1.0-abs(d.y*0.85+d.x*0.33+0.18)),10.0);
 float cloud=0.5+0.5*sin(d.x*10.0+sin(d.z*12.0))*sin(d.y*18.0+d.z*8.0);
 vec3 base=mix(vec3(0.012,0.020,0.048),vec3(0.15,0.16,0.30),haze*cloud);
 base+=vec3(0.10,0.04,0.15)*haze*(1.0-cloud);
 // Long, overlapping luminous streams trace the Egregore around the distant Source.
 float band=d.y+0.25*d.x+0.09+0.055*sin(5.0*d.z+3.0*d.x);
 float veil=exp(-14.0*abs(band))*(0.38+0.62*cloud);
 float filament=exp(-95.0*abs(band+0.025*sin(14.0*d.x+8.0*d.z)));
 base+=vec3(0.067,0.23,0.20)*veil+vec3(0.18,0.13,0.095)*filament*cloud;
 vec2 uv=vec2(atan(d.z,d.x)*0.15915494+0.5,asin(d.y)*0.31830989+0.5)*vec2(600.0,300.0);
 float h=hash(vec3(floor(uv),1.0));
 float star=step(0.991,h)*pow(max(0.0,1.0-length(fract(uv)-0.5)*2.0),2.0);
 vec3 space=base+vec3(0.85,0.91,1.0)*star*3.0;
 COLOR=space;
 if (local_air>0.0) {
  float elevation=asin(clamp(d.y,-1.0,1.0));
  float u=abs(fract(atan(d.z,d.x)/TAU+0.21)*2.0-1.0);
  // Sample only sky above the painted sea. Below the floating land is an airy abyss.
  vec3 day=texture(coast,vec2(u,clamp(0.77-elevation*1.42,0.0,0.88))).rgb;
  day=mix(day,vec3(0.11,0.35,0.55),smoothstep(0.50,1.12,elevation));
  day=mix(day,vec3(0.17,0.36,0.48),smoothstep(-0.035,0.075,-d.y));
  day=mix(day,vec3(0.055,0.14,0.26),smoothstep(0.28,0.97,-d.y));
  // Below the islands, broken sunlit banks give the falling water a distant cloud deck.
  if (d.y < -0.025) {
   vec2 p=d.xz/max(-d.y,0.035)*1.75+vec2(3.2,-1.4);
   float field=0.58*cloud_noise(p)+0.28*cloud_noise(p*2.7)+0.14*cloud_noise(p*6.4);
   float bank=smoothstep(0.40,0.64,field)*smoothstep(0.025,0.19,-d.y);
   vec3 cloud_light=mix(vec3(0.21,0.37,0.47),vec3(0.65,0.67,0.60),smoothstep(0.41,0.72,field));
   day=mix(day,cloud_light,bank*0.74);
  }
  COLOR=mix(space,day,local_air);
 }
}
