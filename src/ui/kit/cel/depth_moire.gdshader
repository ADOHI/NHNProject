shader_type canvas_item;
// **가장 깊은 단.** 무늬를 얹는 것이 아니라 **화면이 스스로 계산하는 무늬**다.
//
// docs/design/20-ui-kit.md §20.43.
//
// ## 왜 무아레인가
//
// 지금까지의 셰이더(줄무늬 · 망점 · 주사선)는 전부 **종이 위에서도 되는 것**이었다.
// 무아레는 아니다 — 두 줄무늬 가족의 각도 차이가 0.05 라디안일 때 생기는 굵은 간섭 띠는
// **그 두 가족을 실제로 겹쳐 놔야만** 나온다. 손으로 그리려면 간섭 띠를 눈으로 계산해
// 한 줄씩 옮겨 그려야 하고, 각도를 조금만 바꾸면 처음부터 다시다.
//
// ## 그리고 파면이 지나가면 **무늬가 재편된다**
//
// `front` 는 사건이 난 자리에서 퍼져 나가는 반지름이다. 파면이 **지나간 자리에서는
// 두 번째 가족의 각도 부호가 뒤집힌다** — 간섭 띠가 반대로 눕는다.
// 밝기가 잠깐 튀는 게 아니라 **바탕이 사건을 기억한다.**
//
// 화면 텍스처를 안 읽는다. 앞 프레임도 안 읽는다 — 전부 자리와 시각으로만 계산한다.

uniform vec2 card = vec2(660.0, 760.0);
uniform float clock = 0.0;

// 바탕색과 무늬색. 팔레트가 갈릴 때 같이 갈린다 — 색은 여전히 `HoloPalette` 한 곳에서 온다.
uniform vec3 deep : source_color = vec3(0.07, 0.06, 0.05);
uniform vec3 ink : source_color = vec3(0.92, 0.88, 0.81);

// 사건이 난 자리와 지금 파면의 반지름. 반지름이 음수면 사건이 없다.
uniform vec2 hit = vec2(-1000.0, -1000.0);
uniform float front = -1.0;

// 파면 **앞쪽**이 지금 어느 상태인가(0 또는 1). 파면 뒤는 그 반대다.
// 사건이 날 때마다 이 값이 뒤집히므로 **바탕이 지난 사건을 기억한다** —
// 한 번 쓸고 지나간 뒤에도 원래대로 안 돌아온다.
uniform float ahead = 0.0;

// 줄무늬 간격(px)과 두 가족의 각도 차이(라디안).
uniform float gap = 15.0;
uniform float skew = 0.052;

float family(vec2 p, float ang, float phase) {
	vec2 way = vec2(cos(ang), sin(ang));
	return fract((dot(p, way) + phase) / gap);
}

void fragment() {
	vec2 at = UV * card;
	float reach = length(at - hit);

	// 파면이 지나갔나. 지나간 자리는 **두 번째 가족이 반대로 눕는다.**
	float passed = step(reach, front) * step(0.0, front);
	float state = mix(ahead, 1.0 - ahead, passed);

	float base = -0.88;
	float other = base + mix(skew, -skew, state);
	// 두 가족의 차이. 각도가 거의 같아서 **굵은 간섭 띠**가 생긴다.
	float beat = abs(family(at, base, clock * 7.0) - family(at, other, 0.0));
	// 띠의 가장자리만 남긴다 — 채우면 줄무늬고, 가장자리만 남기면 등고선이다.
	float ridge = smoothstep(0.42, 0.5, beat) * 0.10 + beat * 0.035;

	// 파면 자체. 얇은 밝은 테 하나가 화면을 건너간다.
	float edge = smoothstep(1.0, 0.0, abs(reach - front) / 26.0) * step(0.0, front);

	vec3 lit = mix(deep, ink, ridge + edge * 0.30);
	COLOR = vec4(lit, 1.0);
}
