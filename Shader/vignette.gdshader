shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.05, 1.0) = 0.5;
uniform float inner_radius : hint_range(0.0, 0.7) = 0.3;
uniform vec4 tint : source_color = vec4(0.02, 0.0, 0.08, 1.0);

void fragment() {
	float dist = length(UV - vec2(0.5));
	float v = smoothstep(inner_radius, inner_radius + softness, dist);
	COLOR = vec4(tint.rgb, v * intensity);
}