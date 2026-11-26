shader_type sky;
render_mode use_half_res_pass;

uniform float daylight : hint_range(0.0, 1.0) = 0.72;
uniform float dusk_strength : hint_range(0.0, 1.0) = 0.0;
uniform float weather_amount : hint_range(0.0, 1.0) = 0.12;
uniform float cloud_motion = 0.0035;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += vec2(dot(p, p + vec2(45.32)));
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; i++) {
        value += noise2(p) * amplitude;
        p = p * 2.03 + vec2(17.7, 9.2);
        amplitude *= 0.5;
    }
    return value;
}

void sky() {
    vec3 direction = normalize(EYEDIR);
    float height = smoothstep(-0.10, 0.78, direction.y);
    vec3 day_top = vec3(0.13, 0.39, 0.69);
    vec3 day_horizon = vec3(0.69, 0.82, 0.91);
    vec3 dusk_top = vec3(0.31, 0.22, 0.44);
    vec3 dusk_horizon = vec3(0.98, 0.48, 0.28);
    vec3 night_top = vec3(0.012, 0.025, 0.065);
    vec3 night_horizon = vec3(0.055, 0.085, 0.14);
    vec3 day_sky = mix(day_horizon, day_top, height);
    vec3 dusk_sky = mix(dusk_horizon, dusk_top, height);
    vec3 night_sky = mix(night_horizon, night_top, height);
    float day_weight = smoothstep(0.015, 0.54, daylight);
    vec3 base_sky = mix(night_sky, day_sky, day_weight);
    base_sky = mix(base_sky, dusk_sky, clamp(dusk_strength, 0.0, 1.0) * 0.94);

    // Sky processors must use branch-based outputs instead of early returns.
    if (AT_CUBEMAP_PASS) {
        COLOR = base_sky;
    } else if (AT_HALF_RES_PASS) {
        vec2 cloud_uv = direction.xz / max(0.16, direction.y + 0.30);
        cloud_uv = cloud_uv * 0.34 + vec2(TIME * cloud_motion, TIME * cloud_motion * 0.31);
        float broad_cloud = fbm2(cloud_uv * 1.45);
        float fine_cloud = fbm2(cloud_uv * 3.8 + vec2(6.4, 12.1));
        float cloud_field = broad_cloud * 0.70 + fine_cloud * 0.30;
        float cover_threshold = mix(0.66, 0.43, clamp(weather_amount, 0.0, 1.0));
        float cloud_mask = smoothstep(cover_threshold, cover_threshold + 0.15, cloud_field);
        cloud_mask *= smoothstep(-0.03, 0.20, direction.y);
        vec3 cloud_color = mix(vec3(0.18, 0.23, 0.32), vec3(0.92, 0.95, 0.98), day_weight);
        cloud_color = mix(cloud_color, vec3(0.39, 0.45, 0.53), clamp(weather_amount, 0.0, 1.0) * 0.78);
        COLOR = cloud_color;
        ALPHA = cloud_mask * 0.74;
    } else {
        vec3 color = base_sky;
        if (LIGHT0_ENABLED) {
            float sun_dot = max(dot(direction, LIGHT0_DIRECTION), 0.0);
            float sun_disk = pow(sun_dot, 440.0);
            vec3 sun_tint = mix(vec3(1.0, 0.72, 0.44), LIGHT0_COLOR, day_weight);
            color += sun_tint * sun_disk * (0.65 + daylight * 2.0);
            color += sun_tint * pow(sun_dot, 16.0) * 0.025 * daylight;
        }
        vec2 star_uv = vec2(atan(direction.z, direction.x), asin(clamp(direction.y, -1.0, 1.0))) * 118.0;
        float star_seed = hash21(floor(star_uv));
        float star = step(0.9984, star_seed) * smoothstep(0.08, 0.48, direction.y);
        float night_weight = 1.0 - smoothstep(0.015, 0.28, daylight);
        color += vec3(0.58, 0.72, 1.0) * star * night_weight * 0.72;
        COLOR = color + HALF_RES_COLOR.rgb * HALF_RES_COLOR.a;
    }
}
