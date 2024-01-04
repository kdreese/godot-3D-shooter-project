shader_type spatial;

render_mode blend_add, unshaded;

void fragment() {
	ALBEDO = vec3(1.0, 0.0, 0.0);
	//ALPHA = 0.5 + 0.3 * sin(10.0 * TIME) * dot(NORMAL, VIEW);
	ALPHA = 1.0 - dot(NORMAL, VIEW);
	ALPHA *= ALPHA;
	ALPHA = (0.5 + 0.3 * sin(10.0 * TIME)) * ALPHA;
}
