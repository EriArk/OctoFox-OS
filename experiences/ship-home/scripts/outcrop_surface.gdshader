shader_type spatial;
render_mode cull_disabled;

uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
varying vec3 rock_position;

void vertex() {
 rock_position = VERTEX;
}

void fragment() {
 vec2 plane = vec2(rock_position.x + rock_position.z * 0.38, rock_position.y);
 float cloud = texture(grain, plane * 0.64).r;
 float grit = texture(grain, plane * 4.8).r;
 float bedding = plane.y * 4.3 + plane.x * 0.47 + cloud * 0.59;
 float lamina = smoothstep(0.78, 0.92, cos(bedding * 6.283));
 float fleck = smoothstep(0.65, 0.84, grit) * smoothstep(0.47, 0.62, cloud);
 vec3 stone = pow(COLOR.rgb, vec3(1.65)) * (0.58 + 0.67 * cloud + 0.30 * grit);
 ALBEDO = mix(stone * (1.0 - 0.23 * lamina), vec3(0.70,0.60,0.45), 0.26 * fleck);
 ROUGHNESS = 0.92 - 0.20 * fleck;
}
