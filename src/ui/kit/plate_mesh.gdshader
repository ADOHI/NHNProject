shader_type canvas_item;
// 판 위의 점망(halftone). **한쪽으로 몰려 있다.**
//
// 1 판(등고선 · 파편 · 알갱이)이 「무슨 수학 같음」으로 폐기된 이유는 도형과 셰이더를
// 쓴 것이 아니라 **무늬를 골고루 뿌린 것**이었다. 골고루 뿌린 노이즈는 재질이 아니라
// 계산으로 보인다. 그래서 여기서는 점이 **오른쪽 아래로 갈수록 촘촘해지고 왼쪽 위는
// 완전히 비어 있다.** 밀도 자체가 형태를 만든다.
//
// 시간은 `TIME` 이 아니라 밖에서 넣는다. `TIME` 을 쓰면 캡처를 두 번 뽑아 비교할 수 없다.

uniform float clock = 0.0;
// 커서가 올라온 정도. 평상에서는 점이 거의 안 보이고 커서에서 또렷해진다.
uniform float energy = 0.0;
uniform vec2 plate_origin = vec2(0.0);
uniform vec2 plate_size = vec2(200.0, 56.0);

void fragment() {
	vec2 at = FRAGCOORD.xy - plate_origin;
	vec2 unit = clamp(at / max(plate_size, vec2(1.0)), vec2(0.0), vec2(1.0));

	// 왼쪽 위 0, 오른쪽 아래 1. 글자가 앉는 왼쪽 절반이 비어 있게 기울여 둔다.
	float ramp = clamp(unit.x * 0.75 + unit.y * 0.55 - 0.34, 0.0, 1.0);

	float pitch = 6.5;
	vec2 cell = fract(at / pitch + vec2(0.0, clock * 0.04)) - 0.5;
	float far = length(cell);
	float radius = ramp * (0.16 + 0.20 * energy);
	float ink = smoothstep(radius, radius - 0.10, far);

	COLOR.rgb *= 1.0 - ink * (0.12 + 0.10 * energy);
}
