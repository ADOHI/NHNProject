shader_type canvas_item;
render_mode blend_mix, unshaded;

// 패널의 면. 1면의 박스 기사 · 오려 붙인 조각 · 교정쇄가 앉는 종이다.
//
// 회색 사각형에 얇은 흰 테두리를 두르는 대신, 면 자체가 **인쇄된 종이**로 보이게 한다.
// 위 가장자리에 잉크가 고이고, 섬유가 비치고, 조각은 인쇄기에서 갓 나온 것처럼 젖어 있다.
//
// story 는 그 패널이 어느 판의 것인지를 정한다.
//   0 — 먹판. 시설이 잰 값이다. 얼룩이 없다
//   1 — 별색판. 렉카가 쓴 것이다. 잉크가 번지고 정합이 흔들린다
//
// 비용: 패널 몇 장, 합쳐도 화면의 1/4 이 안 된다. 산술만 쓴다.

#include "res://src/ui/style/shaders/press.gdshaderinc"

uniform vec2 panel_size = vec2(320.0, 160.0);

uniform vec4 paper_color : source_color = vec4(0.957, 0.933, 0.871, 0.97);
uniform vec4 ink_color : source_color = vec4(0.086, 0.071, 0.055, 1.0);
uniform vec4 accent_color : source_color = vec4(0.827, 0.141, 0.165, 1.0);

uniform float story : hint_range(0.0, 1.0) = 0.0;
uniform float fibre = 0.014;
uniform float bleed_period = 5.4;

void fragment() {
	vec2 p = UV * panel_size;

	// 위쪽이 밝다. 조판대의 등이 위에 있다.
	float fall = smoothstep(0.0, 1.0, UV.y) * 0.09;

	// 위 가장자리에 잉크가 고인다. 사방 테두리를 두르지 않기 위한 대체물이다.
	float crest = 1.0 - smoothstep(0.0, 3.0, p.y);

	// 잉크가 마르지 않아 번지는 띠. 별색 조각에서만 보인다.
	float wet = fract(UV.y + TIME / max(bleed_period, 0.1));
	float band = pow(max(0.0, 1.0 - abs(wet - 0.5) * 16.0), 4.0);

	float blot = press_blob(p * 0.03);

	vec3 col = paper_color.rgb * (1.0 - fall);
	col = mix(col, paper_color.rgb * 0.93, blot * (0.10 + 0.24 * story));
	col = mix(col, ink_color.rgb, crest * 0.55 * (1.0 - story));
	col = mix(col, accent_color.rgb, crest * 0.70 * story);
	col = mix(col, accent_color.rgb, band * story * 0.09);

	col += vec3(press_hash(floor(p)) - 0.5) * (fibre + 0.020 * story);

	COLOR = vec4(col, paper_color.a * clamp(press_inside(p, panel_size), 0.0, 1.0));
}
