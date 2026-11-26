shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_water : source_color = vec4(0.10, 0.34, 0.44, 0.44);
uniform vec4 deep_water : source_color = vec4(0.025, 0.12, 0.24, 0.53);
uniform float wave_speed = 1.35;
uniform float wave_scale = 0.12;
uniform float reflection_strength = 0.62;

varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float wave_a = sin(VERTEX.x * 0.43 + TIME * wave_speed);
    float wave_b = cos(VERTEX.z * 0.37 - TIME * wave_speed * 0.78);
    VERTEX.y += (wave_a + wave_b) * 0.012;
}

void fragment() {
    float wave_a = sin(world_position.x * 0.47 + TIME * wave_speed) * 0.5 + 0.5;
    float wave_b = cos(world_position.z * 0.39 - TIME * wave_speed * 0.81) * 0.5 + 0.5;
    float shimmer = clamp(wave_a * 0.56 + wave_b * 0.44, 0.0, 1.0);
    vec3 water_rgb = mix(shallow_water.rgb, deep_water.rgb, smoothstep(0.22, 0.9, shimmer));
    ALBEDO = water_rgb;
    METALLIC = 0.10;
    ROUGHNESS = mix(0.30, 0.16, shimmer);
    SPECULAR = reflection_strength;
    NORMAL = normalize(vec3(sin(world_position.x * 0.28 + TIME) * wave_scale, 1.0, cos(world_position.z * 0.24 - TIME * 0.8) * wave_scale));
    ALPHA = mix(shallow_water.a, deep_water.a, shimmer);
}
