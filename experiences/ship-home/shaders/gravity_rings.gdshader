shader_type spatial;
render_mode unshaded, blend_add, shadows_disabled;

uniform float cycle = 0.0;
uniform float travel = 3.75;
varying float pulse;

void vertex() {
    float age = fract(cycle + INSTANCE_CUSTOM.r);
    float spread = mix(0.78, 1.52, age);
    VERTEX.xz *= spread;
    VERTEX.y -= age * travel;
    pulse = smoothstep(0.0, 0.09, age) * (1.0 - smoothstep(0.72, 1.0, age));
}

void fragment() {
    float core = abs(dot(normalize(NORMAL), normalize(VIEW)));
    ALBEDO = mix(vec3(0.09, 0.60, 0.68), vec3(0.59, 1.0, 0.86), core * core);
    ALPHA = pulse * (0.24 + 0.73 * core);
}
