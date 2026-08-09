shader_type canvas_item;
render_mode blend_mul;
// **어둡게 하는 층** — 주사선 · 인터레이스 · 필름 결 · 비네트.
//
// docs/design/20-ui-kit.md §20.29.
//
// ## 왜 층이 둘인가
//
// 브라운관 덮개는 **어둡게도 하고 밝게도 한다** — 주사선은 깎고 훑는 띠는 더한다.
// 섞기(blend_mix) 한 겹으로는 둘 중 하나만 된다. 그래서 곱하기 층과 더하기 층으로 나눴다.
//
// ## 화면 텍스처를 안 읽는다
//
// `gl_compatibility`(웹 빌드)에서 그대로 돈다. 아래 그림을 흐리지 않고 자기 무늬만 얹는다.

uniform float clock = 0.0;
uniform vec2 card = vec2(660.0, 700.0);

// 주사선 간격(px)과 짙기.
uniform float line_gap = 3.0;
uniform float line_depth = 0.42;

// 셀 필름의 결.
uniform float film = 1.0;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 at = UV * card;
	float keep = 1.0;

	// ── 주사선. 줄 사이가 깎인다.
	float line = fract(at.y / line_gap);
	keep -= smoothstep(0.34, 0.5, abs(line - 0.5)) * line_depth;

	// ── 인터레이스 떨림. 두 필드가 아주 조금 다르게 깜빡인다.
	float field = step(0.5, fract(at.y / (line_gap * 2.0)));
	keep -= field * 0.045 * (0.5 + 0.5 * sin(clock * 29.0));

	// ── 필름 결. 세로로 긴 결이 아주 옅게 흐른다.
	keep -= film * hash1(vec2(floor(at.x * 0.5), floor(clock * 8.0))) * 0.022;

	// ── 비네트. 브라운관은 구석이 어둡다.
	vec2 off = (UV - vec2(0.5)) * 2.0;
	keep -= pow(clamp(dot(off, off) * 0.5, 0.0, 1.0), 2.2) * 0.45;

	COLOR = vec4(vec3(clamp(keep, 0.0, 1.0)), 1.0);
}
