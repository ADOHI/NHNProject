shader_type canvas_item;
render_mode blend_mix, unshaded;

// 스케치용 종이면. 신문 용지의 섬유 · 잉크 얼룩 · 압판 그늘.
// 채택되면 src/ui/style/shaders/ 로 정식 이식한다.

uniform vec4 paper_color : source_color = vec4(0.910, 0.878, 0.804, 1.0);
uniform vec4 shade_color : source_color = vec4(0.824, 0.780, 0.678, 1.0);
uniform float fibre = 0.036;

float press_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 값 잡음 하나. 큰 얼룩을 만든다.
float press_blob(vec2 p) {
	vec2 cell = floor(p);
	vec2 frac = fract(p);
	frac = frac * frac * (3.0 - 2.0 * frac);
	float a = press_hash(cell);
	float b = press_hash(cell + vec2(1.0, 0.0));
	float c = press_hash(cell + vec2(0.0, 1.0));
	float d = press_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, frac.x), mix(c, d, frac.x), frac.y);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;

	// 잉크가 고르게 먹지 않는다. 큰 얼룩과 가는 섬유가 겹친다.
	float blot = press_blob(p * 0.006);
	float streak = press_blob(vec2(p.x * 0.002, p.y * 0.05));

	vec3 col = mix(paper_color.rgb, shade_color.rgb, blot * 0.42 + streak * 0.16);

	// 압판 그늘. 가장자리가 눌려 어둡다.
	float platen = 1.0 - smoothstep(0.34, 1.08, length((UV - vec2(0.5)) * vec2(1.16, 1.0)));
	col *= mix(0.88, 1.02, platen);

	col += vec3(press_hash(floor(p)) - 0.5) * fibre;

	COLOR = vec4(col, 1.0);
}
