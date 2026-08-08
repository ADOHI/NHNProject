shader_type canvas_item;

// 방향 B — **파편(facet).** 원시 도형은 면이고, 그 면을 자르는 것은 직선뿐이다.
//
// 방향 A(등고선)와 정반대로 세웠다.
//   A 는 곡선 · 획만 · 면 없음        B 는 직선 · 면 있음 · 곡선 없음
//   A 는 요소가 장을 밀어 올린 자리    B 는 요소가 장을 **쪼갠** 자리
//
// 화면 전체에 균열망(Voronoi 경계)이 깔려 있다. 요소는 그 균열을 자기 쪽으로
// 끌어당겨 셀을 잘게 부순다. 그래서 "가까이 있다"는 것이 **파편이 촘촘하다**로 보인다.
// 모서리는 둥글지 않고 **모따기**로 잘린다 — 곡선이 한 군데도 없어야 한다.
//
// gl_compatibility(WebGL2): 컴퓨트 없음, 반복은 상수 상한.

const int MAX_ELEMENTS = 16;

uniform vec2 field_size = vec2(1280.0, 720.0);
uniform int element_count = 0;
uniform vec4 element_rect[MAX_ELEMENTS];
uniform vec4 element_form[MAX_ELEMENTS];
uniform vec4 element_state[MAX_ELEMENTS];
// x: 호버(0~1)
uniform vec4 element_pulse[MAX_ELEMENTS];

uniform vec4 ground_color : source_color = vec4(0.039, 0.043, 0.051, 1.0);
uniform vec4 line_low : source_color = vec4(0.239, 0.310, 0.384, 1.0);
uniform vec4 line_mid : source_color = vec4(0.400, 0.384, 0.345, 1.0);
uniform vec4 line_high : source_color = vec4(0.902, 0.871, 0.788, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.294, 0.149, 1.0);


// 모따기 사각형. 둥근 모서리를 쓰지 않는 것이 이 방향의 첫 번째 규칙이다.
float sd_chamfer(vec2 p, vec2 half_size, float cut) {
	vec2 q = abs(p) - half_size;
	return max(max(q.x, q.y), (q.x + q.y + cut) * 0.70710678);
}


vec2 hash2(vec2 p) {
	vec2 h = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(h) * 43758.5453);
}


// 균열망. 셀 경계까지의 거리를 픽셀로 돌려준다.
//
// 씨앗이 시간에 따라 천천히 돈다. 그래서 아무도 건드리지 않아도 균열이
// **다시 그어진다** — 조각이 붙었다 떨어지고, 삼거리가 옮겨 간다.
// 평행이동이 아니라 위상이 바뀌는 움직임이라 흐르는 무늬로 보이지 않는다.
float crack_distance(vec2 p, float cell, float t) {
	vec2 g = p / cell;
	vec2 base = floor(g);
	vec2 f = g - base;
	float first = 8.0;
	float second = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 offset = vec2(float(i), float(j));
			vec2 h = hash2(base + offset);
			vec2 site = offset + 0.5 + 0.40 * sin(t * 0.42 + 6.2831853 * h);
			float dist = length(site - f);
			if (dist < first) {
				second = first;
				first = dist;
			} else if (dist < second) {
				second = dist;
			}
		}
	}
	return (second - first) * cell;
}


void fragment() {
	vec2 p = UV * field_size;
	float t = TIME;

	float charge = 0.0;
	float plate = 0.0;
	float edge = 0.0;
	float split = 0.0;
	float sunk = 0.0;
	float accent = 0.0;

	for (int i = 0; i < element_count; i++) {
		vec4 rect = element_rect[i];
		vec4 form = element_form[i];
		vec4 state = element_state[i];

		vec2 center = rect.xy + rect.zw * 0.5;
		vec2 half_size = rect.zw * 0.5;
		float skirt = form.z;
		float lift = form.x - state.w;

		vec2 reject = abs(p - center) - half_size - vec2(skirt * 4.0);
		if (max(reject.x, reject.y) > 0.0) {
			continue;
		}

		vec2 rel = p - center;
		// 모따기 폭도 고도에서 나온다. 높은 것일수록 크게 잘려 나간다.
		float d = sd_chamfer(rel, half_size, 5.0 + lift * 2.5);

		// 균열을 끌어당기는 힘. 요소에서 멀어질수록 곧게 준다.
		charge = max(charge, lift * clamp(1.0 - max(d, 0.0) / (skirt * 3.2), 0.0, 1.0));

		float sign_lift = step(0.05, lift);
		plate = max(plate, (1.0 - smoothstep(-1.5, 0.5, d)) * sign_lift);
		sunk = max(sunk, (1.0 - smoothstep(-1.5, 0.5, d)) * state.y);

		// 윤곽은 **잘린 자국**이다. 굵기 하나, 흔들림 없음.
		edge = max(edge, (1.0 - smoothstep(0.6, 2.0, abs(d))) * sign_lift);

		// 호버 — 조각이 한 겹 더 갈라진다. 안쪽으로 들어온 두 번째 현이 생기고,
		// 그 현은 가만히 있지 않고 안팎으로 오간다.
		float inner = 5.0 + 4.0 * sin(t * 1.6);
		split = max(split, (1.0 - smoothstep(0.5, 1.8, abs(d + inner))) * element_pulse[i].x);

		// 포커스 — 밝은 조각 하나가 **모서리를 따라 돌면서 꺾인다.**
		// 원둘레를 도는 것이 아니라 현을 갈아타므로 매끄럽지 않고 각이 진다.
		if (state.x > 0.001) {
			float arc = fract(atan(rel.y, rel.x) * 0.15915494 - t * 0.26);
			float run = smoothstep(0.0, 0.03, arc) * (1.0 - smoothstep(0.13, 0.19, arc));
			accent = max(accent, run * (1.0 - smoothstep(0.6, 2.6, abs(d))) * state.x);
		}
	}

	// 균열망은 **두 개의 고정된 배율**을 겹쳐 만든다.
	//
	// 셀 크기를 자리마다 연속으로 바꿔 보았더니 같은 씨앗 격자가 픽셀마다 다른
	// 배율로 잘려 무늬가 통째로 부서졌다 — 파편이 아니라 잡음이 된다.
	// 배율은 고정해 두고 **가는 망을 요소 곁에서만 드러내면** 같은 말을 할 수 있다.
	// 그래서 "가까이 있다"가 여전히 **파편이 촘촘하다**로 보인다.
	float coarse = 1.0 - smoothstep(0.0, 1.8, crack_distance(p, 156.0, t));
	float fine = 1.0 - smoothstep(0.0, 1.5, crack_distance(p, 44.0, t * 1.3));
	float near = clamp(charge / 2.2, 0.0, 1.0);
	float crack_ink = max(coarse * 0.75, fine * near);

	// 눌림 — 조각이 안으로 무너진다. 가장 잔 망이 드러나고 면이 뒤집혀 밝아진다.
	float shards = 1.0 - smoothstep(0.0, 1.4, crack_distance(p, 19.0, t * 1.9));
	crack_ink = max(crack_ink, shards * sunk);

	vec3 color = ground_color.rgb;
	// 면. 요소 안쪽은 바탕보다 아주 조금 밝은 판이고, 눌리면 뒤집혀 밝아진다.
	color = mix(color, line_low.rgb * 0.42, plate * 0.55);
	color = mix(color, line_high.rgb * 0.78, sunk);
	color = mix(color, line_mid.rgb, crack_ink);
	color = mix(color, line_high.rgb, clamp(edge + split, 0.0, 1.0));
	color = mix(color, accent_color.rgb, accent);

	float grain = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	color += (grain - 0.5) * 0.008;

	COLOR = vec4(color, 1.0);
}
