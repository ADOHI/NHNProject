shader_type canvas_item;
render_mode blend_mix, unshaded;

// 방 하나에 실린 **사진 한 칸.** 그 방 카메라의 그림을 지면에 앉힌 것이다.
//
// **여기서 셰이더는 질감이 아니라 도형 자체를 만든다.**
// 사각형을 그려 놓고 그 안에 무늬를 넣는 것이 아니라, 사각형의 **윤곽이 망점에서 나온다.**
//
//   원판이 있는 칸  가장자리가 또렷한 사각형이다
//   원판이 없는 칸  가장자리가 점으로 **부서져 있다.** 도형이 다 인쇄되지 못했다
//
// 그래서 "모른다"는 색이 흐린 것도 글자가 없는 것도 아니고
// **형태가 아직 다 생기지 않은 것**이 된다. 이 게임의 공짜 정보는 전부 결함이 있고
// (docs/design/13-information-design.md §13.6), 그 결함이 도형의 결함이 된다.
//
// 비용: 146x76 짜리가 판에 스무 칸 남짓. 다 합쳐 20 만 화소가 안 된다.

#include "res://src/ui/style/shaders/press.gdshaderinc"

uniform vec2 cell_size = vec2(146.0, 76.0);

uniform vec4 paper_color : source_color = vec4(0.957, 0.933, 0.871, 1.0);
uniform vec4 ink_color : source_color = vec4(0.086, 0.071, 0.055, 1.0);
uniform vec4 spot_color : source_color = vec4(0.827, 0.141, 0.165, 1.0);

// 0 이면 아무것도 모르는 방, 1 이면 내가 서 있는 방.
uniform float certainty : hint_range(0.0, 1.0) = 0.0;

// 가장 고운 선수와 가장 거친 선수(px). design_tokens.gd 의 SCREEN_* 와 짝이다.
uniform float screen_fine = 3.0;
uniform float screen_coarse = 12.0;

// 이 방이 지금 송출되고 있는가. 별색판은 오직 이 값으로만 들어온다.
uniform float onair : hint_range(0.0, 1.0) = 0.0;

// 별색판이 어긋난 자리(px).
uniform vec2 slip = vec2(4.0, -3.0);

uniform float press_period = 2.2;

void fragment() {
	vec2 p = UV * cell_size;
	float doubt = 1.0 - clamp(certainty, 0.0, 1.0);

	// 선수. 모르는 칸일수록 굵다. 굵기가 아주 느리게 흔들리는 것은
	// 인쇄기가 그 칸에서 자리를 못 잡고 있다는 뜻이다.
	float wobble = 1.0 + sin(TIME * 1.1 + cell_size.x * 0.05) * 0.07 * doubt;
	float pitch = mix(screen_fine, screen_coarse, doubt) * wobble;

	// 그림의 농도. 아는 칸은 밝고 고르며, 모르는 칸은 얼룩덜룩 짙다.
	float blot = press_blob(p * 0.06 + cell_size * 0.013);
	float density = mix(0.09, 0.21, doubt) + blot * (0.04 + 0.11 * doubt);
	float black = press_plate(p, 0.2618, pitch, density);

	// --- 윤곽이 부서진다 -------------------------------------------------
	// 안쪽은 온전하고, 가장자리로 갈수록 **점이 있는 자리만 남는다.**
	// 부서지는 폭이 선수를 따라가므로 모르는 칸일수록 크게 헐어 있다.
	float inside = press_inside(p, cell_size);
	float fray_width = 1.5 + pitch * 2.4 * doubt;
	float solid = smoothstep(0.0, fray_width, inside);
	float crumb = press_plate(p, 0.2618, pitch, 0.62);
	float alpha = mix(crumb, 1.0, solid) * step(-0.5, inside);

	// 송출 중인 칸은 별색판이 위쪽 띠에 한 번 더 얹힌다.
	// 숫자가 있는 아래쪽을 물들이면 사실이 오염된다.
	float top = 1.0 - smoothstep(0.0, 16.0, p.y);
	float beat = press_beat(TIME, press_period);
	float spot = press_plate(p + slip, 0.7854, max(pitch, 3.0), top * onair * (0.35 + 0.65 * beat));

	vec3 col = paper_color.rgb;
	col = mix(col, spot_color.rgb, spot * 0.9);
	col = mix(col, ink_color.rgb, black);

	COLOR = vec4(col, alpha);
}
