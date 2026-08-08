shader_type canvas_item;
render_mode blend_add;

// 자개 — 편광.
//
// **이 셰이더는 색을 만들지 않는다.** 색은 실제 자개 사진이 가지고 있고,
// 여기서 하는 일은 그 색을 **어느 위상에서 읽을지** 정하는 것뿐이다.
// 노이즈 함수로 무늬를 합성하는 것과 정반대의 방향이고, 앞의 두 판본이
// 「수학 같다」는 평가를 받은 자리가 정확히 거기다.
//
// 원본은 **검은 바탕**에 생성했다. 가산 합성이므로 검은 자리가 곧 투명이고
// 알파 매트를 뽑을 필요가 없다.

uniform sampler2D src : source_color, filter_linear_mipmap;

// GDScript 가 누적해서 밀어 넣는다. TIME 을 직접 쓰면 속도를 바꾸는 순간 위상이 튄다.
uniform float phase = 0.0;

uniform float glow = 0.0;   // 0 평상 ~ 1 호버
uniform float dead = 0.0;   // 1 이면 편광이 죽어 그냥 조개껍질이 된다
uniform float sweep = -1.0; // 판을 훑는 빛의 자리(UV.x). -1 이면 없음
uniform float sweep_width = 0.20;
uniform float gain = 1.0;

// 사진의 색을 얼마나 남길지. 띠는 원판의 결이 살아야 하고,
// 낱개 조각은 원판이 희읍스름해서 그대로 두면 종잇조각으로 보인다.
uniform float material_mix = 0.80;

// 원판에서 **잘라 올 구간**. 띠를 통째로 늘이면 판이 넓어질수록 조각이 굵어지는데,
// 실제 나전에서 조각 크기는 판 크기와 무관하다. 조각 크기를 고정하고 대신
// 넓은 판이 원판의 더 긴 구간을 가져가게 한다.
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);

// 띠가 오른쪽으로 가며 **흩어져 사라진다.**
//
// 판 아래를 가로지르는 균일한 조각 행렬은 자개가 아니라 **진행 막대**로 읽힌다
// (2차 렌더에서 실제로 그랬다). 조각이 이미 낱개로 끊겨 있으므로 오른쪽을 서서히
// 지우기만 하면, 촘촘하던 상감이 조각 몇 개로 흩어지다 끊기는 구성이 된다.
uniform float dissolve_from = 1.0;

// 상감을 세로로 세운다. 원판의 조각은 세로로 긴 막대라, 눕히면 조각이 위에서 아래로
// 쌓인 **이음매**가 된다. 글자 밑을 가로지르는 띠는 자개가 아니라 자막 판으로 읽혔다.
uniform bool vertical = false;

// 간섭색. 차가운 쪽 좁은 대역만 쓴다 — 채도를 풀면 즉시 무지개가 되고
// 무지개는 싸구려다. 여덟 칸 중 금은 한 칸뿐이라 드물게만 나온다.
vec3 ramp_stop(int i) {
	if (i == 0) { return vec3(0.624, 0.902, 0.824); } // 민트
	if (i == 1) { return vec3(0.498, 0.831, 0.941); } // 시안
	if (i == 2) { return vec3(0.498, 0.831, 0.941); } // 시안
	if (i == 3) { return vec3(0.753, 0.682, 0.910); } // 라일락
	if (i == 4) { return vec3(0.753, 0.682, 0.910); } // 라일락
	if (i == 5) { return vec3(0.910, 0.933, 0.941); } // 은 — 여기 한 칸뿐
	if (i == 6) { return vec3(0.890, 0.702, 0.416); } // 금 — 여기 한 칸뿐
	return vec3(0.624, 0.902, 0.824);                 // 민트로 되돌아온다
}

vec3 iridescence(float t) {
	float u = fract(t) * 8.0;
	int i = int(floor(u));
	float f = fract(u);
	// 계단이 보이지 않게 다듬는다. 진주층의 간섭은 층이 아니라 연속이다.
	f = f * f * (3.0 - 2.0 * f);
	return mix(ramp_stop(i), ramp_stop(int(mod(float(i) + 1.0, 8.0))), f);
}

void fragment() {
	vec2 duv = vertical ? vec2(UV.y, UV.x) : UV;
	vec4 s = texture(src, uv_offset + duv * uv_scale);
	float l = dot(s.rgb, vec3(0.299, 0.587, 0.114));

	// 검은 바탕은 검게 둔다. 그 자리가 곧 투명이다.
	float mask = smoothstep(0.05, 0.18, l);
	if (mask <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// **사진의 휘도가 간섭 램프의 좌표다.** 위상을 옮기면 같은 조각이 다른 색이 된다.
		vec3 iri = iridescence(l * 2.1 + phase);

		// 사진이 가진 색을 완전히 버리지는 않는다. 재료를 만드는 것이 아니라 움직이는 것이다.
		vec3 col = mix(s.rgb, iri * (0.45 + 0.75 * l), material_mix);

		float lit = 1.0 + glow * 0.45;
		if (sweep > -0.5) {
			// 띠의 조각이 애초에 낱개로 끊겨 있으므로, 빛이 지나가면
			// **조각이 차례로 켜진다.** stagger 를 코드로 짤 필요가 없다.
			float d = abs(duv.x - sweep);
			lit += 0.85 * (1.0 - smoothstep(0.0, sweep_width, d));
		}
		col *= lit * mask * gain * (1.0 - smoothstep(dissolve_from, 1.0, duv.x));

		// 비활성 — 편광이 죽는다. 흐려지는 것이 아니라 재료가 죽는 것이다.
		col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))) * 0.80, dead);

		COLOR = vec4(col, 1.0);
	}
}
