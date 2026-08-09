shader_type canvas_item;
render_mode blend_add;
// **밝게 하는 층** — 훑는 띠 · 잔광 · 먼지 · 아주 짧은 색 어긋남.
//
// docs/design/20-ui-kit.md §20.29.
//
// ## 네온이 아니다
//
// 형광 청록·자홍은 2010년대 사이버펑크지 90년대 셀이 아니다.
// **셀 시대의 홀로그램은 인광(燐光)이다** — 브라운관 인이 빛나는 색.
// 색을 갈라도 **채도가 낮은 쪽으로만** 벌린다: 붉은 채널을 살짝 앞세우는 정도다.
// 청록이 튀어나오는 순간 시대가 바뀐다.

uniform float clock = 0.0;
uniform vec2 card = vec2(660.0, 700.0);

// 인광색. 훑는 띠와 잔광이 이 색이다.
uniform vec3 glow : source_color = vec3(1.0, 0.71, 0.29);

uniform float sweep_energy = 1.0;
uniform float film = 1.0;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 at = UV * card;
	vec3 lit = vec3(0.0);

	// ── 훑는 띠. **화면이 살아 있다는 유일한 증거다.**
	float pass_y = fract(clock * 0.21) * (card.y + 300.0) - 150.0;
	lit += glow * exp(-abs(at.y - pass_y) * 0.016) * 0.20 * sweep_energy;
	// 띠 앞머리의 밝은 실선 하나.
	lit += glow * exp(-abs(at.y - pass_y) * 0.30) * 0.34 * sweep_energy;

	// ── 아주 짧은 색 어긋남. 한 프레임짜리고 채도가 낮다.
	float slip = step(0.988, hash1(vec2(floor(clock * 12.0), 3.0)));
	float edge = smoothstep(0.0, 0.4, abs(UV.x - 0.5) * 2.0);
	lit.r += slip * edge * 0.085;
	lit.g += slip * edge * 0.030;

	// ── 먼지. 셀 필름에 붙은 것이라 아주 드물다.
	float dust = step(0.9994, hash1(floor(at * 0.9) + floor(clock * 10.0)));
	lit += vec3(0.95, 0.90, 0.80) * dust * film * 0.45;

	COLOR = vec4(lit, 1.0);
}
