shader_type canvas_item;
render_mode blend_mix, unshaded;

// **금박.** 「금」 한 글자를 종이에 눌러 찍은 금박이고, 그 박에 금이 가 있다.
//
// 이 셰이더는 이 게임에서 **인쇄판을 통과하지 않는 유일한 것**이다
// (docs/design/21-title.md §21.3). 근거는 인쇄 공정 그대로다 —
// 박은 잉크가 아니라 **다 찍은 종이 위에 열과 압력으로 눌러 붙이는 것**이라
// 판(먹 · 별색)의 뒤에 온다. 그래서 노드 순서에서도 PressPlate 뒤에 앉는다.
//
// 그 결과 화면에 위계가 하나 생긴다.
//
//   화면의 모든 것은 망점이다. **금만 점이 아니다.**
//   사람도 악마도 글자도 신문에 실린 그림이고, 금 하나만 실물이다.
//
// 그리고 값싼 신문지는 박을 붙들지 못한다. 그래서 **금은 반드시 금이 간다.**
// 제목의 두 뜻이 재료 하나에서 동시에 나온다.
//
// gl_compatibility(WebGL 2) 전용. 미분도 화면 되읽기도 쓰지 않는다.

#include "res://src/ui/style/shaders/press.gdshaderinc"

// 「금」 글자를 담은 판. 알파만 쓴다.
uniform sampler2D glyph : hint_default_transparent, filter_linear, repeat_disable;

// **금이 간 자리.** UV 공간의 꺾은선이고, 글자를 가장자리에서 가장자리까지 건넌다.
// 한가운데서 끊기면 어느 쪽이 어느 조각인지 정할 수 없어 갈라지지 않는다.
uniform vec2 seam[10];
uniform int seam_count = 0;

// **벌어진 정도.** 두 조각이 금에 수직으로 이만큼 떨어진다.
uniform float open = 0.0;

// **어긋난 정도.** 두 조각이 금을 따라 미끄러진다.
//
// 이 게임의 서명이 오정합이고(docs/design/18-visual-identity.md §18.3),
// 제목이 말하려는 것도 같다 — **다시 붙으려다 마지막에 어긋난다.**
// 그래서 머무는 동안 움직이는 값은 `open` 이 아니라 이것이다.
uniform float slip = 0.0;

// 빛의 자리(UV). 커서다. 박을 기울이면 광택이 흐른다.
uniform vec2 light = vec2(0.5, -0.4);

// 박이 떨어져 나간 정도. 금 가까이부터 들뜬다.
uniform float flake = 0.0;

// 폭/높이. UV 로 잰 거리를 실제 비율로 되돌린다.
uniform float aspect = 1.0;

// 결이 흐르는 속도. 0 이면 박이 죽은 금속판으로 보인다.
uniform float seconds = 0.0;

uniform vec4 foil_deep : source_color = vec4(0.243, 0.145, 0.035, 1.0);
uniform vec4 foil_mid : source_color = vec4(0.757, 0.549, 0.180, 1.0);
uniform vec4 foil_high : source_color = vec4(1.0, 0.960, 0.784, 1.0);

// 박의 잘린 자리. 박은 끊어진 데서 눌려 어두워진다 — 종이가 아니라 금속이라서다.
uniform vec4 bruise : source_color = vec4(0.106, 0.063, 0.020, 1.0);


// 금까지의 **부호 있는 거리와 그 자리의 법선.**
//
//   xy = 법선(금에 수직, 화면 비율 보정 전)
//   z  = 거리
//   w  = 어느 쪽인가 (+1 / -1)
//
// 가장 가까운 선분에서 부호를 가져온다. 금이 판을 가로지르는 한 이 판정이 맞는다.
vec4 seam_field(vec2 p) {
	float best = 1e9;
	float side = 1.0;
	vec2 normal = vec2(0.0, 1.0);
	for (int i = 0; i < 9; i++) {
		if (i + 1 >= seam_count) {
			break;
		}
		vec2 a = seam[i];
		vec2 b = seam[i + 1];
		vec2 ab = b - a;
		float span = max(dot(ab, ab), 1e-8);
		float t = clamp(dot(p - a, ab) / span, 0.0, 1.0);
		vec2 near = a + ab * t;
		vec2 away = (p - near) * vec2(aspect, 1.0);
		float d = length(away);
		if (d < best) {
			best = d;
			side = sign(ab.x * (p.y - a.y) - ab.y * (p.x - a.x));
			normal = normalize(vec2(-ab.y, ab.x) + vec2(1e-6));
		}
	}
	return vec4(normal, best, side == 0.0 ? 1.0 : side);
}


void fragment() {
	vec2 uv = UV;
	vec4 field = seam_field(uv);
	vec2 normal = field.xy;
	// 금을 따라가는 방향. 어긋남은 이 축에서만 일어난다.
	vec2 along = vec2(-normal.y, normal.x);
	float gap = field.z;
	float side = field.w;

	// 두 조각이 **서로 반대로** 움직인다. 한쪽만 밀면 글자가 이사한 것으로 보인다.
	vec2 shove = (normal * open + along * slip) * 0.5 * side;
	vec2 guv = uv - shove;

	// 판 밖은 글자가 없다. 가장자리 색을 늘려 물리면 글자에 꼬리가 생긴다.
	float inside = step(0.0, guv.x) * step(guv.x, 1.0) * step(0.0, guv.y) * step(guv.y, 1.0);
	vec4 sheet = texture(glyph, guv);
	float a = sheet.a * inside;

	// **잔금.** 판에 흰 글자와 검은 금이 함께 찍혀 있다(foil_glyph.gd `_CrackWeb`).
	// 밝기가 곧 성한 정도다 — 1 이면 성한 박, 0 이면 금이 간 자리.
	float fracture = clamp(1.0 - sheet.r, 0.0, 1.0);

	// **금이 간 자리는 글자를 먹는다.** 벌어진 폭만큼 글자가 없어진다.
	float mouth = open * 0.5;
	a *= smoothstep(mouth, mouth + 0.0035, gap);

	// --- 박이 떨어져 나간다 -------------------------------------------------
	// 값싼 신문지는 박을 못 붙든다. **금이 간 자리부터** 들뜨고 거기서부터 떨어진다.
	// 가장자리를 부드럽게 하지 않는다 — 박은 찢어지는 것이지 흐려지는 것이 아니다.
	float cell = press_blob(guv * vec2(52.0 * aspect, 52.0));
	float weak = max(1.0 - smoothstep(0.0, 0.20, gap), fracture);
	float lost = step(cell, flake * (0.22 + weak * 1.05));
	a *= 1.0 - lost;

	if (a < 0.004) {
		discard;
	}

	// --- 박은 성한 적이 없다 -------------------------------------------------
	// 조사에서 전제가 절반 정정됐다(docs/design/21-title.md §21.6.7).
	// 거친 비도공지 위의 박이 실패하는 **대표 방식은 갈라짐이 아니라 결락**이다 —
	// 종이가 접촉 200ms 안에 접착제를 40% 빨아들여서, 박이 **섬유 봉우리 위에만**
	// 얹히고 골짜기에는 안 붙는다. 그래서 종이 섬유 한 올 크기의 구멍이 남는다.
	//
	// 그러므로 **말끔한 금으로 시작해 갈라지게 하면 안 된다.** 금은 처음부터 이렇다.
	// 실패가 둘이고 범인이 다르다 — 구멍은 **종이**의 것이고 갈라짐은 **압력**의 것이다.
	//
	// 양을 세게 주면 안 된다. 이것은 **결함이지 무늬가 아니다** — 눈에 먼저 띄면
	// 금이 아니라 낡은 텍스처로 보인다. 한 번 30% 로 만들었다가 금을 통째로 잃었다.
	float fibre = press_blob(guv * vec2(340.0 * aspect, 322.0));
	a *= step(0.115, fibre);

	// --- 금박의 결 ---------------------------------------------------------
	// 박은 두들겨 편 금속이라 **한 방향으로 결이 남는다.**
	// 결이 없으면 노란 글자이고, 결이 있어야 금속이 된다.
	float grain = press_blob(guv * vec2(7.0 * aspect, 61.0)) * 0.62
		+ press_blob(guv * vec2(29.0 * aspect, 13.0)) * 0.38;

	// --- 빛과 어둠이 함께 움직인다 -------------------------------------------
	// 빛은 커서다. 그런데 **밝아지기만 하면 그것은 금속이 아니라 발광이다.**
	//
	// 심사자 둘이 같은 진단을 따로 내놨다 — "무엇도 어두워지지 않는다.
	// 실제 금속은 빛을 받는 쪽이 날아가는 **동시에** 반대쪽이 거의 검어지고,
	// 그 사이에 무른 구간이 없다. 지금은 부드러운 얼룩이 밝아질 뿐이라 UI 광택이다."
	//
	// 그래서 면의 기울기를 만들어 빛과 내적한다. 값이 **음수까지 내려가야**
	// 그림자가 하이라이트의 반대편으로 함께 흐른다.
	vec2 to_light = (guv - light) * vec2(aspect, 1.0);
	float reach = length(to_light);
	vec2 lit = normalize(-to_light + vec2(1e-6));
	// 두들겨 편 박의 면. **결이 아니라 넓은 굴곡에서 기울기를 뽑는다.**
	//
	// 처음에 결(7×61, 29×13)에서 바로 기울기를 만들었더니 화소마다 방향이 튀어서
	// 금이 얼룩덜룩한 위장무늬가 됐다. 조명은 **면 단위로 일관**되어야 한다 —
	// 잔결은 색을 흔들 뿐이고, 빛을 받는 것은 넓은 굴곡이다.
	vec2 tilt = normalize(
		vec2(
			press_blob(guv * vec2(2.4 * aspect, 3.1)) - 0.5,
			press_blob(guv * vec2(3.3 * aspect, 2.2) + vec2(17.0)) - 0.5
		) + vec2(1e-6)
	);
	// 대부분은 중간 금이어야 한다. 어두운 쪽은 **빛을 등진 면에만** 나온다 —
	// 흔해지면 금이 아니라 녹슨 쇠가 된다.
	float facing = dot(tilt, lit) * 0.40 + (1.0 - smoothstep(0.05, 1.45, reach)) * 0.66 - 0.02;

	// **띠를 계단으로 끊는다.** 30nm 금속막이 4~8µm 거칠기를 타고 앉으면
	// 정반사 로브가 미세 면들로 쪼개져서, 빛이 매끄럽게 미끄러지지 않고
	// **무리를 켜고 끄며** 지나간다(§21.6.7). 이 지면에는 애초에
	// 근거 없는 그라데이션이 존재할 수 없다(§18.9).
	//
	// 문턱을 좁게 잡는다 — 거울은 중간톤이 거의 없다. 날아간 곳과 검은 곳,
	// 그 사이는 면도날이다. 중간톤만 잔뜩이면 그건 칠한 금속이다.
	vec3 col = foil_mid.rgb;
	col = mix(foil_deep.rgb, col, smoothstep(-0.34, -0.26, facing));
	col = mix(col, foil_high.rgb, smoothstep(0.56, 0.63, facing));
	// 결은 색을 흔들 뿐 위계를 만들지 않는다. 여기서 크게 주면 계단이 뭉개진다.
	col *= 0.90 + grain * 0.20;

	// --- 금이 간 자리의 입술 -----------------------------------------------
	// 끊어진 박은 눌려 어두워진다. 이 한 줄이 없으면 갈라진 것이 아니라
	// 글자 사이에 틈이 있는 것으로 보인다.
	float lip = 1.0 - smoothstep(mouth, mouth + 0.018, gap);
	col = mix(col, bruise.rgb, max(lip, fracture) * 0.86);

	// 떨어져 나간 자리의 언저리도 같은 이유로 어둡다.
	float rim = step(cell, flake * (0.22 + weak * 1.05) + 0.09) * (1.0 - lost);
	col = mix(col, bruise.rgb, rim * 0.55);

	COLOR = vec4(col, a);
}
