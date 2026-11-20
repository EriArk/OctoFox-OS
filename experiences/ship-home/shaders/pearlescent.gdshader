shader_type spatial;
uniform vec4 pigment : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0);
uniform float sheen = 0.5;
void fragment() {
    float angle = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
    ALBEDO = mix(pigment.rgb, edge.rgb, angle * sheen);
    METALLIC = 0.42;
    ROUGHNESS = 0.29;
    CLEARCOAT = 0.55;
}
