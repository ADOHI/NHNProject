shader_type canvas_item;
render_mode blend_mix, unshaded;

// 스케치용 **망점**. 인쇄된 사진 한 칸이다.
//
// 여기서 하나만 확인하면 된다 — 망점의 굵기로 "이 방을 얼마나 아는가"를 말할 수 있는가.
// 좋은 원판이 있으면 가는 선수로 곱게 찍고, 없으면 굵은 선수로 뭉개 찍는다.
// 그리고 붉은 판은 검은 판과 각도도 다르고 자리도 어긋난다.

uniform vec2 cell_size = vec2(190.0, 84.0);
uniform vec4 paper_color : source_color = vec4(0.910, 0.878, 0.804, 1.0);
uniform vec4 ink_color : source_color = vec4(0.086, 0.071, 0.055, 1.0);
uniform vec4 spot_color : source_color = vec4(0.827, 0.141, 0.165, 1.0);

// 망점 하나의 간격(px). **클수록 거칠고, 거칠수록 모르는 것이다.**
uniform float screen_pitch = 6.0;

// 검은 판의 농도 0~1.
uniform float density : hint_range(0.0, 1.0) = 0.45;

// 붉은 판의 농도와 어긋난 정도(px).
uniform float spot_density : hint_range(0.0, 1.0) = 0.0;
uniform vec2 spot_offset = vec2(3.0, -2.0);

vec2 turn(vec2 p, float radians_angle) {
	float s = sin(radians_angle);
	float c = cos(radians_angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// 한 판의 망점. 각도와 간격이 주어지면 점이 얼마나 덮는지 돌려준다.
float plate(vec2 p, float radians_angle, float pitch, float amount) {
	if (amount <= 0.001) {
		return 0.0;
	}
	vec2 q = turn(p, radians_angle) / pitch;
	vec2 near = (fract(q) - vec2(0.5)) * pitch;
	// 면적이 농도를 따라야 하므로 반지름은 제곱근으로 자란다.
	float radius = pitch * 0.62 * sqrt(clamp(amount, 0.0, 1.0));
	return 1.0 - smoothstep(radius - 0.9, radius + 0.9, length(near));
}

void fragment() {
	vec2 p = UV * cell_size;
	float pitch = max(screen_pitch, 1.2);

	// 인쇄 선수는 각도를 어긋나게 건다. 겹쳐도 무늬가 지지 않게 하는 실무 규칙이다.
	float black = plate(p, 0.2618, pitch, density);
	float spot = plate(p + spot_offset, 0.7854, pitch, spot_density);

	vec3 col = paper_color.rgb;
	col = mix(col, spot_color.rgb, spot * 0.86);
	col = mix(col, ink_color.rgb, black);

	COLOR = vec4(col, 1.0);
}
