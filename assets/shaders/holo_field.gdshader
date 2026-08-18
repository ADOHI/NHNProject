shader_type canvas_item;
// **에너지 장.** 무늬가 흐르고 경계가 떨린다.
//
// 주사선은 안 쓴다 — 가로줄이 규칙적으로 지나가는 그것이 진부함의 표본이다.
// 여기서는 **잡음이 비스듬히 흘러가고** 규칙이 안 잡힌다.
#include "res://assets/shaders/holo_common.gdshaderinc"

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float aspect = 2.4;
uniform float clock = 0.0;
uniform vec4 body : source_color = vec4(0.74, 0.80, 0.87, 1.0);
uniform vec4 hot : source_color = vec4(0.75, 0.44, 0.37, 1.0);

void fragment() {
	vec2 flow = vec2(UV.x * 7.0 - clock * 0.35, UV.y * 4.0 + clock * 0.12);
	float wave = smooth_grain(flow);
	float veins = smoothstep(0.55, 0.86, wave) * strength;
	float near = edge_near(UV, aspect);
	// 경계가 떨린다 — 가장자리 가까이에서만 잡음이 세진다.
	float shiver = (1.0 - smoothstep(0.0, 0.22, near)) * smooth_grain(flow * 3.0);
	vec3 tone = mix(body.rgb, hot.rgb, veins * 0.22 + shiver * 0.30 * strength);
	COLOR = vec4(tone, (0.30 + 0.28 * strength + shiver * 0.24) * COLOR.a);
}
