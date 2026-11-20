shader_type spatial;
render_mode cull_disabled;
uniform float closure : hint_range(0,1);
varying float pleat;
void vertex(){
 float angle=UV.x*mix(0.44,3.148,closure);
 pleat=cos(UV.x*75.398);
 float radius=0.78+0.022*pleat;
 VERTEX=vec3(sin(angle)*radius,0.11+UV.y*1.94,-cos(angle)*radius);
 NORMAL=normalize(vec3(sin(angle-0.16*sin(UV.x*75.398)),0.,-cos(angle-0.16*sin(UV.x*75.398))));
}
void fragment(){
 float band=step(0.012,UV.y)*step(UV.y,0.022)+step(0.953,UV.y)*step(UV.y,0.962);
 ALBEDO=mix(vec3(0.065,0.22,0.21)*(0.84+0.16*pleat),vec3(0.67,0.44,0.18),band);
 ROUGHNESS=0.85;
}
