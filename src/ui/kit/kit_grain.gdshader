shader_type canvas_item;

// 방향 C — **알갱이(grain).** 원시 도형은 점이다. 선도 면도 한 군데 없다.
//
//   A(등고선) 는 선으로,  B(파편) 는 면으로,  C 는 **점으로만** 그린다.
//
// 화면 전체에 일정한 간격(격자 8px)의 점자리가 깔려 있다. 요소는 그 자리에 앉은
// 알갱이를 키운다. **윤곽선이 없다** — 알갱이가 커져 서로 맞붙으면 그것이 곧 면이고,
// 작아져 떨어지면 그것이 곧 여백이다. 그래서 규격이 셀 수 있는 수(칸 수)로 존재한다.
//
// 격자 간격이 곧 규격의 원자이므로, 버튼 하나는 "가로 아홉 칸 세로 여섯 칸" 처럼
// 읽힌다. 두 버튼이 붙으면 사이의 알갱이가 함께 커져 다리가 놓이고,
// 떨어지면 사이가 완전히 비어 각자 섬이 된다.
//
// gl_compatibility(WebGL2): 컴퓨트 없음, 반복은 상수 상한.

const int MAX_ELEMENTS = 16;

uniform vec2 field_size = vec2(1280.0, 720.0);
uniform int element_count = 0;
uniform vec4 element_rect[MAX_ELEMENTS];
uniform vec4 element_form[MAX_ELEMENTS];
uniform vec4 element_state[MAX_ELEMENTS];
uniform vec4 element_pulse[MAX_ELEMENTS];

uniform vec4 ground_color : source_color = vec4(0.039, 0.043, 0.051, 1.0);
uniform vec4 line_low : source_color = vec4(0.239, 0.310, 0.384, 1.0);
uniform vec4 line_mid : source_color = vec4(0.400, 0.384, 0.345, 1.0);
uniform vec4 line_high : source_color = vec4(0.902, 0.871, 0.788, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.294, 0.149, 1.0);

// 점자리의 간격. 규격의 원자(8px)와 같은 수다.
uniform float pitch = 8.0;


float sd_round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}


vec2 hash2(vec2 p) {
	vec2 h = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(h) * 43758.5453);
}


void fragment() {
	vec2 p = UV * field_size;
	float t = TIME;

	// 알갱이를 키우는 힘. 요소가 가까울수록, 높을수록 크다.
	float charge = 0.0;
	float pull = 0.0;
	float accent_weight = 0.0;
	vec2 pull_to = p;

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

		float d = sd_round_box(p - center, half_size, form.y);

		// 안쪽은 꽉 차고 바깥은 **칸 단위로** 줄어든다.
		// 감쇠를 격자 간격의 배수로 잡아야 "몇 칸 떨어졌는가"가 눈에 세어진다.
		float fall = clamp(1.0 - max(d, 0.0) / (pitch * 5.0), 0.0, 1.0);
		charge = max(charge, clamp(lift * 0.42, 0.0, 1.0) * fall);

		// 호버 — 알갱이가 한 칸 더 멀리까지 커진다.
		float wide = clamp(1.0 - max(d, 0.0) / (pitch * 9.0), 0.0, 1.0);
		charge = max(charge, element_pulse[i].x * 0.85 * wide);

		// 포커스 — 커진 알갱이의 **고리 하나가 격자를 따라 바깥으로 행진한다.**
		// 격자가 이산적이라 물결이 매끄럽게 번지지 않고 칸에서 칸으로 옮겨 앉는다.
		if (state.x > 0.001) {
			float ring = max(d, 0.0);
			float wave = sin(ring * 0.10 - t * 3.4);
			float reach = 1.0 - smoothstep(0.0, pitch * 16.0, ring);
			float crest = clamp(wave, 0.0, 1.0) * reach * state.x;
			charge = max(charge, crest * 0.9);
			accent_weight = max(accent_weight, crest);
		}

		// 눌림 — 알갱이가 줄어들며 가운데로 빨려 들어간다.
		if (state.y > 0.001) {
			float grip = state.y * (1.0 - smoothstep(-2.0, pitch * 2.0, d));
			if (grip > pull) {
				pull = grip;
				pull_to = center;
			}
		}
	}

	// 바탕에도 아주 작은 알갱이가 깔린다. 0 으로 두면 요소 밖이 완전한 공백이 되어
	// 화면의 대부분이 죽는다. 이 알갱이들이 제자리에서 맴도는 것이 이 방향의 idle 이다.
	charge = clamp(max(charge, 0.14) - pull * 0.55, 0.0, 1.0);

	// 알갱이 하나를 찍는다. 이웃 칸까지 봐야 자리 흔들림으로 넘어온 것을 놓치지 않는다.
	vec2 lattice = p / pitch;
	vec2 base = floor(lattice);
	float ink = 0.0;
	float radius = pitch * 0.64 * charge;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = base + vec2(float(i), float(j));
			vec2 h = hash2(cell);
			// 차오를수록 **자리를 잡는다.** 흐트러진 채로 커지면 알갱이가 서로 겹쳐
			// 얼룩이 되고, 그 위에 판 글자가 갉아먹혀 읽히지 않는다.
			float settle = 1.0 - charge * 0.85;
			vec2 site = (cell + vec2(0.5)) * pitch + (h - vec2(0.5)) * pitch * 0.35 * settle;

			// idle — 알갱이가 제자리에서 아주 조금 **돈다.**
			// 흐르지 않고 맴돌기 때문에 화면이 어디로도 가지 않으면서 살아 있다.
			float spin = t * 1.25 + 6.2831853 * h.x;
			site += vec2(cos(spin), sin(spin * 0.83 + h.y * 3.1)) * (0.35 + 2.1 * settle);

			// 눌리면 자리 자체가 중심 쪽으로 끌려간다.
			site = mix(site, pull_to, pull * 0.22);

			ink = max(ink, 1.0 - smoothstep(radius - 0.9, radius + 0.9, length(p - site)));
		}
	}

	vec3 dot_color = mix(line_mid.rgb, line_high.rgb, smoothstep(0.25, 0.9, charge));
	dot_color = mix(dot_color, line_low.rgb, pull);
	dot_color = mix(dot_color, accent_color.rgb, clamp(accent_weight * 1.3, 0.0, 1.0));

	vec3 color = mix(ground_color.rgb, dot_color, clamp(ink, 0.0, 1.0));

	float grain = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	color += (grain - 0.5) * 0.008;

	COLOR = vec4(color, 1.0);
}
