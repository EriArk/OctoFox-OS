shader_type spatial;
render_mode unshaded;
uniform float phase = 0.0;
uniform vec4 shallows : source_color = vec4(0.23, 0.67, 0.63, 1.0);
uniform vec4 depths : source_color = vec4(0.055, 0.22, 0.30, 1.0);

void fragment() {
    float ray = sin(UV.x * 24.0 + UV.y * 3.3 + 0.55 * sin(UV.x * 11.0 + phase));
    float caustic = smoothstep(0.76, 1.0, ray) * (1.0 - UV.y);
    float light = 0.12 + 0.70 * (1.0 - UV.y) * (1.0 - UV.y);
    ALBEDO = mix(depths.rgb, shallows.rgb, light + caustic * 0.16);
}
