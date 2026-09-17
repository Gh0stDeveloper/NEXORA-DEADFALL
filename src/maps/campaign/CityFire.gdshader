shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	float height = 1.0 - UV.y;
	float sway = sin(height * 10.0 - TIME * 5.3) * 0.075 + sin(height * 18.0 + TIME * 3.1) * 0.035;
	float edge = abs(UV.x - 0.5 + sway) / max(0.03, (1.0 - height) * 0.46);
	float flame = (1.0 - smoothstep(0.45, 1.0, edge)) * smoothstep(0.0, 0.1, height) * (1.0 - smoothstep(0.7, 1.0, height));
	vec3 color = mix(vec3(1.0, 0.78, 0.16), vec3(0.95, 0.12, 0.015), height);
	ALBEDO = color;
	EMISSION = color * 2.0;
	ALPHA = flame * (0.8 + sin(TIME * 13.0 + height * 20.0) * 0.12);
}
