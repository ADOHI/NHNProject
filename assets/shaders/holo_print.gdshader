shader_type canvas_item;
// **종이와 판화.** 결이 있고 가장자리에서 잉크가 번진다.
//
// **이 킷의 계보와 곧장 이어진다** — 겹인쇄도 밀도 대비도 인쇄에서 나왔다.
// 미래지향을 「소속을 바꾸는 것」으로 읽으면 종이가 제일 멀리 있는 재료가 아니다.
#include "res://assets/shaders/holo_common.gdshaderinc"

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float aspect = 2.4;
uniform vec4 stock : source_color = vec4(0.82, 0.85, 0.89, 1.0);
uniform vec4 ink : source_color = vec4(0.42, 0.48, 0.57, 1.0);

void fragment() {
	// 종이 결. 아주 잘아야 종이고, 굵으면 벽지다.
	float fibre = smooth_grain(UV * vec2(420.0, 260.0)) * 0.12 * strength;
	float near = edge_near(UV, aspect);
	// 가장자리에서 잉크가 번진다. 번짐이 고르면 테두리라 잡음을 섞는다.
	float bleed = (1.0 - smoothstep(0.0, 0.19, near));
	bleed *= 0.55 + 0.45 * smooth_grain(UV * vec2(70.0, 44.0));
	vec3 tone = stock.rgb - fibre * 0.5;
	tone = mix(tone, ink.rgb, bleed * 0.42 * strength);
	COLOR = vec4(tone, (0.55 + 0.24 * strength) * COLOR.a);
}
