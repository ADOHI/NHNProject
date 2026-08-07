shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// **인쇄판.** 이 게임 화면은 그려지는 것이 아니라 여기서 **찍힌다.**
//
// 다른 셰이더처럼 화면 위에 효과를 덧씌우는 것이 아니다. 화면에 이미 그려진 모든 것을
// 다시 읽어서 **두 장의 인쇄판(먹판 · 별색판)으로 분해하고 망점으로 재구성한다.**
// 글자도, 괘선도, 사진도, 버튼도 전부 점으로 다시 태어난다.
//
// 그래서 이 파일은 후처리가 아니라 **이 화면의 렌더링 모델**이다.
// 화면 어디를 확대해도 점이 나온다는 사실 하나가 이 게임의 인상을 만든다.
//
// 여기서 하는 일 네 가지 — 전부 형태를 만드는 일이지 색을 보정하는 일이 아니다.
//
//   1. 접힘   지면은 접혀 있다. 접힌 자리를 지나는 것은 실제로 **어긋난다**
//   2. 찢김   새 판을 찍을 때 지면이 찢어지고 두 쪽이 벌어졌다 다시 맞는다
//   3. 망점   모든 계조를 점 크기로 뭉갠다. 부드러운 그라디언트가 존재할 수 없다
//   4. 충격   누른 자리에서 파문이 퍼져 지나간 자국을 남긴다
//
// gl_compatibility 에서 화면을 되읽는 것은 hint_screen_texture 로 가능하다
// (엔진이 백버퍼 복사를 넣어 준다). 컴퓨트 셰이더도 미분도 쓰지 않는다.

#include "res://src/ui/style/shaders/press.gdshaderinc"

uniform sampler2D sheet : hint_screen_texture, repeat_disable, filter_linear;

uniform vec4 paper_color : source_color = vec4(0.910, 0.878, 0.804, 1.0);
uniform vec4 ink_color : source_color = vec4(0.086, 0.071, 0.055, 1.0);
uniform vec4 spot_color : source_color = vec4(0.827, 0.141, 0.165, 1.0);

// 망점 간격(px). 이 값이 곧 이 인쇄기의 선수다.
uniform float pitch = 3.2;

// 별색판이 어긋나는 자리(px). 화면 전체가 같은 방향으로 어긋난다.
uniform vec2 slip = vec2(4.0, -3.0);

// **선수가 부는 정도.** 1 이면 점이 아주 굵어 아무것도 안 읽힌다.
// 새 판을 찍을 때 1 에서 0 으로 내려오면 지면이 점에서 그림으로 **자라난다.**
uniform float swell : hint_range(0.0, 1.0) = 0.0;

// 부는 앞머리가 화면을 가로지르는 방향. 왼쪽이 먼저 마르고 오른쪽이 늦게 마른다.
uniform float swell_lead = 0.85;

// **찢김.** 지면이 갈라져 위아래가 서로 어긋난다.
uniform float tear : hint_range(0.0, 1.0) = 0.0;
uniform float tear_line = 0.46;

// 지면의 접힘. 판의 이동·배율을 따라오므로 끌면 접힌 자리도 함께 흐른다.
uniform vec2 view_pan = vec2(0.0);
uniform float view_zoom = 1.0;
uniform float fold_pitch = 1180.0;
uniform float fold_shift = 1.6;

// 눌린 자리에서 퍼지는 파문. w 가 0 이면 꺼져 있다.
uniform vec4 shock = vec4(0.0, 0.0, 0.0, 0.0);

// 지면이 접힌 자리까지의 거리(-0.5 ~ 0.5 칸 단위)와 그 칸 번호.
vec2 fold_cell(vec2 frag) {
	float zoom = max(view_zoom, 0.05);
	float sheet_x = (frag.x - view_pan.x) / zoom;
	float cell = sheet_x / max(fold_pitch, 40.0);
	return vec2(fract(cell) - 0.5, floor(cell));
}

void fragment() {
	vec2 frag = FRAGCOORD.xy;
	vec2 uv = SCREEN_UV;
	vec2 texel = SCREEN_PIXEL_SIZE;

	// --- 1. 접힘 ---------------------------------------------------------
	// 접힌 자리를 건너가면 종이가 어긋나 있다. 선을 하나 긋는 것이 아니라
	// **거기 있는 그림을 실제로 밀어 버린다.** 칸마다 밀리는 방향이 반대다.
	vec2 fold = fold_cell(frag);
	float lean = (mod(fold.y, 2.0) < 1.0) ? 1.0 : -1.0;
	uv.y += fold.x * fold_shift * texel.y * lean;
	float crease = 1.0 - smoothstep(0.0, 0.012, abs(fold.x));

	// --- 2. 찢김 ---------------------------------------------------------
	// 찢긴 자리는 자로 자른 선이 아니다. 톱니가 있고, 두 쪽이 서로 다른 쪽으로 벌어진다.
	float jag = press_blob(vec2(uv.y * 26.0, 0.0)) - 0.5;
	float rip = tear_line + jag * 0.05;
	float side = step(rip, uv.x) * 2.0 - 1.0;
	float gap = tear * 0.09;
	uv.x += side * gap;
	uv.y += side * gap * 0.22;
	float open = 1.0 - smoothstep(0.0, gap + 0.001, abs(uv.x - rip));
	open *= step(0.001, tear);

	// --- 3. 충격 ---------------------------------------------------------
	// 누른 자리에서 고리 하나가 퍼져 나간다. 지나간 자리의 종이가 밀린다.
	vec2 to_shock = uv - shock.xy;
	float ring = shock.z - length(to_shock * vec2(1.0, texel.x / max(texel.y, 0.00001)));
	float wave = exp(-ring * ring * 900.0) * shock.w;
	uv += normalize(to_shock + vec2(0.0001)) * wave * 0.02;

	vec3 src = texture(sheet, clamp(uv, vec2(0.0), vec2(1.0))).rgb;

	// --- 4. 판 나누기 -----------------------------------------------------
	// 붉은 쪽은 별색판으로, 나머지는 먹판으로 간다.
	// 한 화면에 두 판밖에 없다는 것이 이 지면의 규칙이라, 분해도 둘로만 한다.
	float paper_level = dot(paper_color.rgb, vec3(0.30, 0.59, 0.11));
	float level = dot(src, vec3(0.30, 0.59, 0.11));
	float total = clamp(1.0 - level / max(paper_level, 0.001), 0.0, 1.0);
	float red_bias = clamp((src.r - max(src.g, src.b)) * 4.0, 0.0, 1.0);

	// 잉크는 판에서 항상 조금 번진다. 원고보다 진하게 나오는 것이 정상이다.
	total = clamp(total * 1.06, 0.0, 1.0);
	float black_amount = total * (1.0 - red_bias);
	float spot_amount = total * red_bias;

	// --- 5. 망점 ---------------------------------------------------------
	// 선수가 부는 앞머리. 왼쪽부터 자리를 잡는다.
	float front = clamp(swell * (1.0 + swell_lead) - uv.x * swell_lead, 0.0, 1.0);
	float grade = pitch * (1.0 + front * 9.0);

	// **중간톤만 점으로 뭉갠다.**
	//
	// 실제 신문이 그렇다 — 활자와 괘선은 통짜(선화)로 앉히고 사진만 선수를 걸어 찍는다.
	// 전부 점으로 바꾸면 11px 본문이 통째로 뭉개져서 "인쇄물처럼 보이는 화면"이 아니라
	// 그냥 못 읽는 화면이 된다. 실제로 한 번 그렇게 만들었다.
	//
	// 그리고 이 규칙 덕분에 위계가 하나 더 생긴다 — 사진(방 칸)은 점으로 이루어져 있고
	// 글자와 괘선은 통짜다. 무엇이 계측이고 무엇이 그림인지가 재질로도 갈린다.
	// 문턱을 낮게 잡는다. 11px 본문의 획은 원래 가늘어서, 조금만 점으로 뭉개도
	// 글자가 아니라 얼룩이 된다. **읽히는 것이 먼저다.**
	float solid = smoothstep(0.34, 0.60, total);
	float bare = 1.0 - smoothstep(0.02, 0.10, total);

	float black = mix(press_plate(frag, 0.2618, grade, black_amount), 1.0, solid);
	float spot = mix(press_plate(frag + slip, 0.7854, grade, spot_amount), 1.0, solid);
	black *= (1.0 - bare) * (1.0 - red_bias);
	spot *= (1.0 - bare) * red_bias;
	// 전환 중에는 통짜도 함께 부서진다. 지면 전체가 점에서 자라나야 인쇄로 읽힌다.
	float shatter = press_plate(frag, 0.2618, grade, 1.0 - front * 0.55);
	black = mix(black, black * shatter, front);
	spot = mix(spot, spot * shatter, front);

	vec3 col = paper_color.rgb;
	col = mix(col, spot_color.rgb, spot);
	col = mix(col, ink_color.rgb, black);

	// 접힌 자리와 찢긴 자리에는 먹이 고인다. 종이가 꺾인 곳이라 잉크가 몰린다.
	col = mix(col, ink_color.rgb, crease * 0.16);
	col = mix(col, paper_color.rgb * 1.04, open);
	col = mix(col, ink_color.rgb, smoothstep(0.55, 1.0, open) * 0.7);

	COLOR = vec4(col, 1.0);
}
