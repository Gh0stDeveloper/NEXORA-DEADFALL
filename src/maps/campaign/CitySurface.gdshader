shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.6, 0.58, 0.52, 1.0);
varying float surface_kind;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void vertex() {
	surface_kind = INSTANCE_CUSTOM.x;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 p = abs(world_normal.y) > 0.5 ? world_position.xz : vec2(world_position.x + world_position.z, world_position.y);
	float broad = noise(p * 0.36);
	float grain = hash(floor(p * 65.0));
	vec3 color = base_color.rgb * COLOR.rgb * (0.82 + broad * 0.24 + grain * 0.13);
	if (surface_kind == 1) {
		float earth = smoothstep(0.43, 0.67, noise(p * 0.065) + noise(p * 0.6) * 0.18);
		color = mix(vec3(0.23, 0.31, 0.13), vec3(0.37, 0.29, 0.19), earth) * (0.73 + grain * 0.38 + broad * 0.25);
	} else if (surface_kind == 2) {
		float fissure = 1.0 - smoothstep(0.012, 0.035, abs(sin(p.x * 0.45 + noise(p * 0.16) * 6.0)));
		color *= 1.0 - fissure * 0.42;
	} else if (surface_kind == 3) {
		vec2 tile = p * vec2(2.8, 5.2);
		tile.x += mod(floor(tile.y), 2.0) * 0.5;
		vec2 edge = min(fract(tile), 1.0 - fract(tile));
		float mortar = 1.0 - smoothstep(0.025, 0.05, min(edge.x, edge.y));
		color = mix(color, vec3(0.32, 0.30, 0.25), mortar * 0.85);
	} else if (surface_kind == 4) {
		float seams = step(0.985, fract(p.x * 0.65)) + step(0.985, fract(p.y * 0.65));
		color *= 1.0 - min(seams, 1.0) * 0.35;
	}
	ALBEDO = color;
	ROUGHNESS = 0.93;
}
