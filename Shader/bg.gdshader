shader_type canvas_item;

uniform float speed : hint_range(0.0, 2.0) = 0.3;
uniform float wave : hint_range(0.0, 0.01) = 0.002;
uniform float pulse : hint_range(0.0, 0.5) = 0.15;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * 20.0 + TIME * speed * 3.0) * wave;
	uv.y += cos(uv.x * 20.0 + TIME * speed * 2.0) * wave;

	vec4 col = texture(TEXTURE, uv);
	float p = 1.0 + sin(TIME * speed * 2.0 + uv.x * 6.0) * pulse;
	col.rgb *= tint.rgb * p;

	COLOR = col;
}