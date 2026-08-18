shader_type canvas_item;
// **금속판.** 결이 한 방향으로 지나가고 비스듬한 반사 띠가 스친다.
//
// 결은 가로로만 간다 — 두 방향으로 그으면 격자가 되고, 육각이든 사각이든 격자는
// 이 킷이 배제한 것이다.
#include "res://assets/shaders/holo_common.gdshaderinc"

uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float aspect = 2.4;
uniform float clock = 0.0;
uniform vec4 plate : source_color = vec4(0.72, 0.77, 0.83, 1.0);
uniform vec4 shine : source_color = vec4(0.95, 0.96, 0.98, 1.0);

void fragment() {
	// 결은 **가로로** 지나간다. x 를 잘게 나누면 세로 줄이 되어 비 오는 화면이 된다 —
	// 잘게 나눌 축은 결과 **직각**인 축이다.
	float brushed = smooth_grain(vec2(UV.x * 3.0, UV.y * 240.0)) * 0.10 * strength;
	// 비스듬한 반사 띠. 지나가는 것이라 시간이 든다.
	float band = fract(UV.x * 0.7 - UV.y * 0.45 - clock * 0.11);
	float gleam = smoothstep(0.86, 0.995, band) * strength;
	float near = edge_near(UV, aspect);
	// 깎인 면처럼 가장자리 한 줄만 밝다.
	float facet = (1.0 - smoothstep(0.0, 0.10, near)) * 0.5 * strength;
	vec3 tone = plate.rgb + brushed - 0.05;
	tone = mix(tone, shine.rgb, gleam * 0.55 + facet);
	COLOR = vec4(tone, (0.52 + 0.26 * strength) * COLOR.a);
}
