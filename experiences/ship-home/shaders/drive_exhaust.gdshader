shader_type spatial;
render_mode unshaded, blend_add, cull_back, shadows_disabled, fog_disabled;
uniform float power : hint_range(0.0, 1.0) = 0.0;
varying float along;
void vertex() {
    along = clamp(VERTEX.y + 0.5, 0.0, 1.0);
    float cells = cos(along * 30.0 - TIME * 5.0);
    VERTEX.xz *= 1.0 + 0.22 * cells * sin(along * 3.14159);
    VERTEX.y = along * mix(0.45, 6.1, power);
}
void fragment() {
    float core = pow(1.0 - along, 3.2);
    float band = pow(0.5 + 0.5 * cos(along * 30.0 - TIME * 5.0), 3.0);
    float centre = abs(dot(normalize(NORMAL), normalize(VIEW)));
    vec3 plasma = mix(vec3(0.11, 0.32, 1.0), vec3(0.17, 0.91, 1.0), band);
    ALBEDO = mix(plasma, vec3(0.86, 1.0, 1.0), core);
    ALPHA = (0.50 + 0.50 * power) * (1.0 - along) *
            (0.12 + 0.54 * core + 0.40 * band + 0.22 * centre);
}
