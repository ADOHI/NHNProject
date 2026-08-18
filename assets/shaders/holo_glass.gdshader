shader_type canvas_item;
// **유리.** 뒤가 비치고 가장자리에서 빛이 모인다.
//
// 굴절을 화면 텍스처로 하지 않는다 — 채움률을 두 배로 먹고, 창이 여섯이면 여섯 배다.
// 대신 **가장자리에서 밝아지는 것**만 남긴다. 유리로 읽히는 데 필요한 건 그것뿐이다.
#include "res://assets/shaders/holo_common.gdshaderinc"

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float aspect = 2.4;
uniform vec4 body : source_color = vec4(0.776, 0.824, 0.875, 1.0);
uniform vec4 lit : source_color = vec4(0.92, 0.95, 0.98, 1.0);

void fragment() {
	float near = edge_near(UV, aspect);
	float rim = 1.0 - smoothstep(0.0, 0.34, near);
	vec3 tone = mix(body.rgb, lit.rgb, rim * 0.85 * strength);
	// 위에서 아래로 아주 얕게. 균일하면 유리가 아니라 색종이다.
	tone += (0.5 - UV.y) * 0.035 * strength;
	COLOR = vec4(tone, (0.34 + 0.30 * strength + rim * 0.18) * COLOR.a);
}
