shader_type canvas_item;
render_mode blend_mix, unshaded;

// 패널의 면. HUD·조작반·개발 패널이 앉는 판때기다.
//
// 회색 사각형에 얇은 흰 테두리를 두르는 대신, 면 자체가 **송출 장비의 표면**으로 보이게 한다.
// 모서리는 잘리고, 위쪽에 계측 색이 얇게 맺히고, 아주 느린 간섭 띠가 한 줄 지나간다.
//
// interference 는 그 패널이 어느 레이어의 것인지를 정한다.
//   0 — 계측 패널. 잡티가 없다. 여기 적힌 숫자는 사실이다
//   1 — 송출 패널. 신호가 흔들린다. 여기 적힌 말은 못 믿는다
//
// 비용: 패널 몇 장, 합쳐도 화면의 1/4 이 안 된다. 산술만 쓴다.

#include "res://src/ui/style/shaders/facility.gdshaderinc"

uniform vec2 panel_size = vec2(320.0, 160.0);
uniform vec4 cuts = vec4(0.0, 0.0, 20.0, 0.0);

uniform vec4 fill_color : source_color = vec4(0.078, 0.102, 0.094, 0.94);
uniform vec4 accent_color : source_color = vec4(0.310, 0.863, 0.659, 1.0);

uniform float interference : hint_range(0.0, 1.0) = 0.0;
uniform float grain = 0.009;
uniform float band_period = 6.5;

void fragment() {
	vec2 p = UV * panel_size;
	float d = ui_chamfer_distance(p, panel_size, cuts);

	// 아래로 갈수록 어둡다. 조명이 위에 있는 시설이다.
	float fall = smoothstep(0.0, 1.0, UV.y) * 0.10;

	// 위 가장자리에 맺히는 계측 선. 테두리를 사방에 두르지 않기 위한 대체물이다.
	float crest = 1.0 - smoothstep(0.0, 2.0, p.y);

	// 간섭 띠. 송출 패널에서만 보인다.
	float band_y = fract(UV.y + TIME / max(band_period, 0.1));
	float band = pow(max(0.0, 1.0 - abs(band_y - 0.5) * 22.0), 4.0);

	float noise = ui_hash(floor(p) + floor(TIME * 8.0) * interference) - 0.5;

	vec3 col = fill_color.rgb * (1.0 - fall);
	col += accent_color.rgb * crest * 0.55;
	col += accent_color.rgb * band * interference * 0.10;
	col += vec3(noise) * (grain + 0.03 * interference);

	COLOR = vec4(col, fill_color.a * clamp(d, 0.0, 1.0));
}
