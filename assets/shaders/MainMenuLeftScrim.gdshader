shader_type canvas_item;

uniform vec4 shade_color : source_color = vec4(0.008, 0.018, 0.035, 0.96);
uniform float fade_start : hint_range(0.0, 1.0) = 0.18;
uniform float fade_end : hint_range(0.0, 1.0) = 0.73;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.18;

void fragment() {
    float left_fade = 1.0 - smoothstep(fade_start, fade_end, UV.x);
    float vignette_x = smoothstep(0.0, 0.28, UV.x) * (1.0 - smoothstep(0.72, 1.0, UV.x));
    float vignette_y = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
    float vignette = 1.0 - vignette_strength * vignette_x * vignette_y;
    float alpha = clamp(left_fade * shade_color.a + (1.0 - vignette) * 0.55, 0.0, 0.97);
    COLOR = vec4(shade_color.rgb, alpha);
}
