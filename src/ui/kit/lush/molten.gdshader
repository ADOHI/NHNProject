shader_type canvas_item;
// **용광(鎔光) — 층 열한 겹.** 그림 파일 0, 전부 여기서 나온다.
//
// docs/design/20-ui-kit.md §20.27.
//
// 앞의 여섯 안이 「담백함의 여섯 종류」였던 이유가 **한 부품에 재료가 하나**여서였다.
// 화려한 UI 는 단추 하나에 층이 대여섯 겹 쌓인다. 여기서는 열한 겹이다.
//
//  1 바탕 세로 그러데이션        7 열 아지랑이 (uv 를 흔든다)
//  2 중심에서 퍼지는 용광 코어    8 불티 입자 (떠오른다)
//  3 안쪽 빛 (가장자리→안)       9 색수차 (채널마다 가장자리가 어긋난다)
//  4 바깥 번짐 (bloom 후광)     10 비네트
//  5 가장자리 하이라이트 한 줄   11 눌림 안쪽 그림자 뒤집힘
//  6 미세 그레인
//
// **실루엣도 셰이더가 만든다.** 둥근 사각형 SDF 라 꼭짓점이 필요 없고,
// 그래서 **번짐이 판 밖으로 나갈 수 있다** — 도형으로 그리면 못 하는 것이다.
//
// gl_compatibility 에서 돌아야 한다(웹 빌드). 화면 텍스처를 안 읽는 이유가 그것이다 —
// 번짐을 **거리로 계산**하지 이미 그려진 것을 흐리지 않는다.

uniform float clock = 0.0;

// 0..1. 마우스가 올라간 정도와 눌린 정도.
uniform float hover = 0.0;
uniform float press = 0.0;
uniform float dim = 0.0;

// 판의 픽셀 크기와 모서리 반지름. 노드는 이보다 `bleed` 만큼 크다.
uniform vec2 plate = vec2(160.0, 46.0);
uniform float radius = 6.0;

// 번짐이 판 밖으로 나갈 여유(px).
uniform float bleed = 26.0;

uniform vec3 core_hot : source_color = vec3(1.0, 0.86, 0.52);
uniform vec3 core_warm : source_color = vec3(0.93, 0.42, 0.13);
uniform vec3 shell : source_color = vec3(0.16, 0.07, 0.06);
uniform vec3 rim : source_color = vec3(1.0, 0.74, 0.36);

// 불티를 낼 것인가. 큰 판에만 켠다 — 작은 판에서는 입자가 글자를 먹는다.
uniform float embers = 1.0;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 within = fract(p);
	within = within * within * (3.0 - 2.0 * within);
	float a = hash1(cell);
	float b = hash1(cell + vec2(1.0, 0.0));
	float c = hash1(cell + vec2(0.0, 1.0));
	float d = hash1(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, within.x), mix(c, d, within.x), within.y);
}

// 둥근 사각형까지의 부호 있는 거리. 음수면 안이다.
float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 node = vec2(plate.x + bleed * 2.0, plate.y + bleed * 2.0);
	vec2 at = UV * node - node * 0.5;

	// ── 7 열 아지랑이. 판 위 공기가 흔들린다. **거리를 재기 전에 흔들어야**
	//    실루엣까지 같이 일렁인다.
	float heat = 0.55 + 0.45 * hover;
	vec2 wobble = vec2(
		value_noise(at * 0.035 + vec2(0.0, clock * 0.9)) - 0.5,
		value_noise(at * 0.030 + vec2(clock * 0.7, 0.0)) - 0.5
	);
	vec2 warped = at + wobble * (2.4 * heat) * (1.0 - press * 0.5);

	float half_lift = press * 1.5;
	vec2 half_size = plate * 0.5 - vec2(half_lift);
	float d = sd_round_box(warped, half_size, radius);

	// ── 9 색수차. 채널마다 실루엣을 조금씩 다른 크기로 재면 가장자리에 색이 갈린다.
	float split = (0.9 + 1.6 * hover) * (1.0 - dim * 0.8);
	float d_r = sd_round_box(warped, half_size + vec2(split), radius);
	float d_b = sd_round_box(warped, half_size - vec2(split), radius);

	float inside = 1.0 - smoothstep(-1.0, 1.0, d);
	vec2 uv = (warped / plate) + vec2(0.5);

	// ── 1 바탕 세로 그러데이션
	vec3 body = mix(shell * 1.55, shell * 0.75, clamp(uv.y, 0.0, 1.0));

	// ── 2 용광 코어. 중심 아래쪽에서 뜨겁게 올라온다.
	float core = exp(-length((uv - vec2(0.5, 0.68)) * vec2(1.35, 2.5)) * 3.1);
	core *= 0.55 + 0.75 * hover + 0.35 * sin(clock * 1.7 + uv.x * 2.0);
	core *= 1.0 - dim * 0.85;
	body += mix(core_warm, core_hot, clamp(core, 0.0, 1.0)) * core * 1.35;

	// ── 3 안쪽 빛. 가장자리에서 안으로 스민다.
	float inner = exp(d * 0.22) * inside;
	body += rim * inner * (0.42 + 0.5 * hover) * (1.0 - dim * 0.8);

	// ── 11 눌리면 안쪽 그림자가 **위에서** 진다. 빛의 방향이 뒤집힌 것이다.
	float sink = exp(d * 0.30) * inside * smoothstep(0.0, 1.0, press);
	body *= 1.0 - sink * 0.85 * step(uv.y, 0.62);

	// ── 5 가장자리 하이라이트 한 줄. 위쪽 변만 밝다.
	float edge = exp(-abs(d) * 0.9);
	float from_top = clamp(1.0 - uv.y * 1.7, 0.0, 1.0);
	body += rim * edge * (0.30 + 0.65 * from_top) * (1.0 - press * 0.7) * (1.0 - dim * 0.7);

	// ── 6 미세 그레인. 매끈한 면은 렌더가 아니라 도형으로 보인다.
	float grain = value_noise(UV * node * 1.6 + clock * 3.0) - 0.5;
	body *= 1.0 + grain * 0.085;

	// ── 10 비네트. 판 안쪽 네 귀퉁이를 눌러 가운데로 눈을 모은다.
	body *= 1.0 - smoothstep(0.35, 0.95, length(uv - vec2(0.5))) * 0.35;

	// ── 8 불티. 판 위로 떠오르고 위에서 사라진다.
	float spark = 0.0;
	if (embers > 0.5) {
		for (int i = 0; i < 7; i++) {
			float id = float(i);
			float lane = hash1(vec2(id, 3.0));
			float life = fract(clock * (0.20 + lane * 0.22) + hash1(vec2(id, 7.0)));
			vec2 seat = vec2(
				(lane - 0.5) * plate.x * 0.86 + sin(life * 6.0 + id) * 7.0,
				plate.y * 0.42 - life * (plate.y * 0.55 + bleed * 1.5)
			);
			float near = length(warped - seat);
			spark += exp(-near * 0.55) * (1.0 - life) * (0.5 + hover);
		}
	}

	// ── 4 바깥 번짐. 판 밖으로 나가는 후광이라 **노드가 판보다 커야** 한다.
	float halo = exp(-max(d, 0.0) * 0.115) * (0.30 + 0.55 * hover) * (1.0 - dim * 0.9);

	vec3 lit = body * inside + core_hot * (halo * 0.55 + spark * 0.9);

	// 색수차를 적용한다 — 빨강은 조금 크게, 파랑은 조금 작게 잘린다.
	float a_r = 1.0 - smoothstep(-1.0, 1.0, d_r);
	float a_b = 1.0 - smoothstep(-1.0, 1.0, d_b);
	lit.r = mix(lit.r, lit.r * 1.12, a_r * (1.0 - inside));
	lit.b *= mix(1.0, 0.86, (1.0 - a_b) * inside);

	float alpha = clamp(inside + halo * 0.85 + spark * 0.8, 0.0, 1.0);
	COLOR = vec4(lit, alpha * (1.0 - dim * 0.55));
}
