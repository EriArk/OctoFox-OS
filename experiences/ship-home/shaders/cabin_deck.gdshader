shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform vec4 timber : source_color = vec4(0.48, 0.355, 0.27, 1.0);
uniform vec4 runner : source_color = vec4(0.115, 0.255, 0.26, 1.0);
uniform vec4 binding : source_color = vec4(0.76, 0.57, 0.33, 1.0);
varying vec2 plan;

void vertex() {
    plan = VERTEX.xz;
}

void fragment() {
    float course = floor(plan.x / 0.34);
    vec2 board = vec2(plan.x / 0.34, plan.y / 2.12 + fract(course * 0.382));
    vec2 joint = min(fract(board), 1.0 - fract(board)) * vec2(0.34, 2.12);
    float aa = max(fwidth(plan.x) + fwidth(plan.y), 0.001);
    float seam = 1.0 - smoothstep(0.0, 0.003 + min(aa, 0.014), min(joint.x, joint.y));
    float figure = texture(grain, vec2(plan.x * 3.4 + course * 0.27, plan.y * 0.25)).r;
    vec3 wood = timber.rgb * (0.68 + 0.38 * figure + 0.13 * fract(course * 0.618)) * (1.0 - 0.16 * seam);
    // Cut the ends of the inset runner to the same radius as the interior trim.
    vec2 end = abs(plan - vec2(0.0, 0.62)) - vec2(0.66, 3.80);
    float edge = length(max(end, vec2(0.0))) + min(max(end.x, end.y), 0.0) - 0.18;
    float cloth = 1.0 - smoothstep(-aa, aa, edge);
    float piping = 1.0 - smoothstep(0.005, 0.012 + aa, abs(edge + 0.047));
    vec3 weave = runner.rgb * (0.78 + 0.26 * texture(grain, plan * 6.0).r);
    float rib = sin(103.0 * (plan.y + abs(plan.x) * 0.48)) * (1.0 - smoothstep(0.014, 0.045, aa));
    weave *= 1.0 + rib * 0.045;
    float end_motif = abs(abs(plan.y - 0.62) - 3.54 + abs(plan.x) * 0.33);
    float stitch = 1.0 - smoothstep(0.007, 0.011 + aa, abs(end_motif - 0.045));
    weave = mix(weave, binding.rgb, stitch * 0.48 * (1.0 - smoothstep(0.65, 0.70, abs(plan.x))));
    ALBEDO = mix(wood, mix(weave, binding.rgb, 0.78 * piping), cloth);
    ROUGHNESS = mix(0.54, 0.92, cloth);
}
