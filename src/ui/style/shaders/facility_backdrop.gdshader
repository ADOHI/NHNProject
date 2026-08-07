shader_type canvas_item;
render_mode blend_mix, unshaded;

// 판이 놓인 **바닥**. 시설의 격자 바닥과 그 위를 훑는 카메라 조명이다.
//
// 배경을 단색으로 두면 판을 끌어도 화면이 가만히 있어서 "지도를 움직인다"는 감각이 없다.
// 격자를 지도와 같은 좌표로 깔고 배율까지 따라가게 하면, 끌 때 바닥이 함께 흘러
// 판이 **장소**로 읽힌다. 그래서 이건 장식이 아니라 공간 표현이다.
//
// 비용: 화면 전체 1패스, 텍스처 조회 0, 분기 0. 산술만 40 줄 남짓이다.

#include "res://src/ui/style/shaders/facility.gdshaderinc"

uniform vec4 floor_color : source_color = vec4(0.047, 0.063, 0.059, 1.0);
uniform vec4 seam_color : source_color = vec4(0.165, 0.208, 0.196, 1.0);
uniform vec4 glow_color : source_color = vec4(0.310, 0.863, 0.659, 1.0);

// 판의 이동과 배율. DungeonBoard 가 그릴 때마다 넘겨 준다.
uniform vec2 view_pan = vec2(0.0);
uniform float view_zoom = 1.0;

uniform float grid_pitch = 92.0;
uniform float grain = 0.020;

// 조명이 화면을 한 번 훑는 데 걸리는 시간(초).
uniform float sweep_period = 6.5;

void fragment() {
	float zoom = max(view_zoom, 0.05);
	vec2 world = (FRAGCOORD.xy - view_pan) / zoom;
	vec2 cell = world / grid_pitch;

	// 화면 위에서 늘 같은 굵기로 보이도록 배율을 되돌려 준다.
	float width = 1.1 / (grid_pitch * zoom);
	vec2 minor = min(fract(cell), 1.0 - fract(cell));
	float minor_line = 1.0 - smoothstep(0.0, width, min(minor.x, minor.y));

	vec2 major_cell = cell * 0.25;
	vec2 major = min(fract(major_cell), 1.0 - fract(major_cell));
	float major_line = 1.0 - smoothstep(0.0, width * 0.25, min(major.x, major.y));

	// 카메라 조명 한 줄이 위에서 아래로 흐른다. 판의 상태와 무관하므로 아주 약하게 둔다.
	float sweep = fract(UV.y - TIME / max(sweep_period, 0.1));
	float band = pow(max(0.0, 1.0 - abs(sweep - 0.5) * 30.0), 3.0);

	float vignette = 1.0 - smoothstep(0.30, 0.98, length((UV - vec2(0.5)) * vec2(1.15, 1.0)));

	vec3 col = floor_color.rgb;
	col = mix(col, seam_color.rgb, minor_line * 0.32);
	col = mix(col, seam_color.rgb * 1.25, major_line * 0.50);
	col += glow_color.rgb * band * 0.018;
	col *= mix(0.66, 1.05, vignette);

	// 입자는 시간에 흔들리지 않는다. 늘 떨리는 화면에서는 진짜 변화가 묻힌다.
	col += vec3(ui_hash(floor(FRAGCOORD.xy)) - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
