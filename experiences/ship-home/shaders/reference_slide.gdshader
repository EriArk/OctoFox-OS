shader_type canvas_item;
uniform bool loach = false;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 // Staggered rows of overlapping scale impressions. Only the exposed edge
 // and a few concentric ridges are visible under transmitted light.
 vec2 grid = p * (loach ? vec2(2.9, 3.8) : vec2(1.9, 2.6));
 float row = floor(grid.y);
 float ridge = 0.0;
 float margin = 0.0;
 for (int i=0; i<2; i++) {
  float band = row - float(i);
  vec2 cell = vec2(fract(grid.x + 0.5 * mod(band, 2.0)) - 0.5, grid.y-band);
  float radius = length(cell * vec2(1.34, 0.63));
  float edge = 1.0-smoothstep(0.006,0.034,abs(radius-0.74));
  float growth = pow(0.5+0.5*cos(42.0*radius),6.0);
  margin=max(margin,edge);
  ridge=max(ridge,growth*smoothstep(0.16,0.58,radius)*(1.0-smoothstep(0.69,0.76,radius)));
 }
 vec3 tone = loach ? vec3(0.86,0.65,0.43) : vec3(0.64,0.87,0.79);
 vec3 field = tone * (0.95 - margin*0.56 - ridge*0.23) * (1.0-0.20*r*r);
 float rim=smoothstep(0.94,0.98,r);
 COLOR=vec4(mix(field,vec3(0.10,0.17,0.18),rim),1.0-smoothstep(0.985,1.0,r));
}
