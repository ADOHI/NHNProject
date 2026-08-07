shader_type canvas_item;
render_mode blend_mix, unshaded;

// 판이 놓인 **지면.** 신문 용지 그 자체다.
//
// 여기서 하지 않는 것을 먼저 적는다 — 격자도, 비네트도, 필름 그레인도,
// 화면을 훑는 조명 띠도 없다. 그것들은 어느 게임에나 있는 기성품이고,
// 그것만 겹쳐서는 이 게임의 얼굴이 나오지 않는다.
//
// 종이의 성격은 딱 하나로 만든다 — **잉크가 고르게 먹지 않는다.**
// 큰 얼룩이 지고, 결을 따라 짙은 줄이 간다. 그 위의 모든 것은 인쇄판
// (src/ui/style/shaders/ink_plate.gdshader)이 점으로 다시 찍으므로,
// 여기서 질감을 더 얹을 이유가 없다.
//
// 비용: 화면 전체 1패스, 텍스처 조회 0, 분기 0.

#include "res://src/ui/style/shaders/press.gdshaderinc"

uniform vec4 paper_color : source_color = vec4(0.910, 0.878, 0.804, 1.0);
uniform vec4 shade_color : source_color = vec4(0.824, 0.780, 0.678, 1.0);

// 판의 이동과 배율. 얼룩이 지도와 함께 흘러야 **종이를 미는 것**이 된다.
uniform vec2 view_pan = vec2(0.0);
uniform float view_zoom = 1.0;

void fragment() {
	float zoom = max(view_zoom, 0.05);
	vec2 sheet = (FRAGCOORD.xy - view_pan) / zoom;

	// 잉크 얼룩. 큰 것 하나와 결 하나뿐이다.
	float blot = press_blob(sheet * 0.0035);
	float grain_line = press_blob(vec2(sheet.x * 0.0012, sheet.y * 0.03));

	vec3 col = mix(paper_color.rgb, shade_color.rgb, blot * 0.5 + grain_line * 0.18);

	COLOR = vec4(col, 1.0);
}
