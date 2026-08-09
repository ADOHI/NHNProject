shader_type canvas_item;
// **빛 자체.** 안쪽에서 나오고 가장자리로 갈수록 스며 사라진다.
//
// 청록 발광선은 안 쓴다. **같은 파스텔 청회색에서 밝은 쪽을 고른다** —
// 미래지향은 조형을 버리는 게 아니라 소속을 바꾸는 것이다.
#include "res://assets/shaders/holo_common.gdshaderinc"

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float aspect = 2.4;
uniform float clock = 0.0;
uniform vec4 core : source_color = vec4(0.87, 0.91, 0.96, 1.0);
uniform vec4 falls : source_color = vec4(0.63, 0.70, 0.79, 1.0);

void fragment() {
	float near = edge_near(UV, aspect);
	// 안쪽이 밝고 가장자리가 옅다. 반대로 하면 테두리 장식이 된다.
	float core_lit = smoothstep(0.0, 0.55, near);
	// 아주 느린 숨. 멈춰 있으면 빛이 아니라 칠이다.
	float breath = 1.0 + sin(clock * 1.1) * 0.05 * strength;
	vec3 tone = mix(falls.rgb, core.rgb, core_lit * breath);
	COLOR = vec4(tone, (0.22 + 0.34 * strength) * (0.35 + 0.65 * core_lit) * COLOR.a);
}
