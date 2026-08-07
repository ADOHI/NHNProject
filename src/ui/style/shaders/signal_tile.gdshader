shader_type canvas_item;
render_mode blend_mix, unshaded;

// 방 하나의 **신호면**. 카메라가 그 방을 얼마나 잡고 있는지를 질감으로 말한다.
//
// 이 게임의 공짜 정보는 전부 결함이 있다 (docs/design/13-information-design.md §13.6).
// 그 결함을 글자로 설명하는 대신 화면의 상태로 만든다.
//
//   certainty 0 — 아무것도 모르는 방. 주사선이 흐르고 잡음이 낀다
//   certainty 1 — 내가 선 방. 신호가 잠기고 인광이 고르게 깔린다
//
// **잡음의 양이 곧 정보의 양이다.** 그래서 이 움직임은 장식이 아니다.
//
// 비용: 방 하나가 146x76 이고 판에 열 몇 개다. 다 합쳐 20 만 화소가 안 된다.

#include "res://src/ui/style/shaders/facility.gdshaderinc"

uniform vec2 tile_size = vec2(146.0, 76.0);
uniform vec4 cuts = vec4(16.0, 0.0, 0.0, 0.0);

uniform vec4 fill_color : source_color = vec4(0.078, 0.102, 0.094, 1.0);
uniform vec4 signal_color : source_color = vec4(0.310, 0.863, 0.659, 1.0);
uniform vec4 heat_color : source_color = vec4(0.961, 0.220, 0.290, 1.0);

// 0 이면 아무것도 모르는 방, 1 이면 내가 서 있는 방.
uniform float certainty : hint_range(0.0, 1.0) = 0.0;

// 지금 중계되고 있는가. 송출 레이어의 색은 오직 이 값으로만 들어온다.
uniform float heat : hint_range(0.0, 1.0) = 0.0;

uniform float scan_pitch = 3.4;
uniform float pulse_period = 1.9;

void fragment() {
	vec2 p = UV * tile_size;
	float d = ui_chamfer_distance(p, tile_size, cuts);

	float doubt = 1.0 - certainty;

	// 주사선. 모르는 방일수록 빠르게 흐른다.
	float scan = 0.5 + 0.5 * sin((p.y + TIME * 7.0 * doubt) * 6.28318530718 / scan_pitch);

	// 신호 잡음. 12Hz 로 자리를 바꾼다 — 눈이 개별 점을 쫓지 못하는 최소 속도다.
	float noise = ui_hash(floor(p * 0.8) + floor(TIME * 12.0)) - 0.5;

	// 인광은 잘린 모서리 쪽에서 들어온다. 그 자리가 이 타일의 신호 입구다.
	float glow = exp(-length(p) / 96.0);

	// 안쪽 가장자리의 번짐. 윤곽선 자체는 _draw 가 그린다.
	float rim = 1.0 - smoothstep(0.0, 3.0, d);

	// 송출 표시는 위쪽 띠로만 들어온다. 숫자가 있는 아래쪽을 물들이면 사실이 오염된다.
	float top = 1.0 - smoothstep(0.0, 7.0, p.y);
	float pulse = ui_breathe(TIME, pulse_period);

	vec3 col = fill_color.rgb;
	col += signal_color.rgb * glow * 0.11 * certainty;
	col = mix(col, col * (0.84 + 0.32 * scan), 0.06 + 0.34 * doubt);
	// 잡음을 세게 주면 축소했을 때 타일이 통째로 지직거리는 덩어리가 된다.
	// 낮은 배율은 판의 모양과 색을 읽는 배율이라(design/07 §7.8) 그 순간 판이 안 읽힌다.
	col += vec3(noise) * 0.045 * doubt;
	col += signal_color.rgb * rim * (0.06 + 0.16 * certainty);
	col += heat_color.rgb * top * heat * (0.20 + 0.80 * pulse);

	COLOR = vec4(col, fill_color.a * clamp(d, 0.0, 1.0));
}
