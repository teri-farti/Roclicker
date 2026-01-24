shader_type canvas_item;

uniform float offset;

void fragment() {
	vec2 uv = UV;
	uv.y += sin(uv.x * 10.0 + offset) * 0.02;
	COLOR = texture(TEXTURE, uv);
}