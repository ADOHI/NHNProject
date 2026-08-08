shader_type canvas_item;
// 판 위를 흐르는 **넓고 부드러운 사선 띠.** 명도만 ±5% 흔든다.
//
// 채도를 건드리지 않는 이유: 파스텔에서 색을 흔들면 곧바로 홀로그램이 된다.
// 명도만 흔들면 종이에 비친 빛이 되고, 그건 이 배색이 하려던 것이다.
//
// 띠가 **넓어야** 한다. 좁으면 줄무늬(스캔라인)가 되고 그건 배제 목록에 있다.

uniform float clock = 0.0;
uniform float energy = 0.0;
uniform vec2 plate_origin = vec2(0.0);
uniform vec2 plate_size = vec2(200.0, 56.0);

void fragment() {
	vec2 at = FRAGCOORD.xy - plate_origin;
	// 사선. 세로 성분을 크게 줘서 띠가 눕는다.
	float along = (at.x * 0.55 + at.y * 1.35) / max(plate_size.x, 1.0);

	float slow = sin(along * 5.1 - clock * 0.85);
	float fast = sin(along * 11.3 + clock * 1.60);
	float band = slow * 0.65 + fast * 0.35;

	float depth = 0.075 + 0.060 * energy;
	COLOR.rgb *= 1.0 + band * depth;
}
