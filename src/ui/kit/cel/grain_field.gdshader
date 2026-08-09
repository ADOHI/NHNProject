shader_type canvas_item;
// **축의 끝 — 아무도 안 보는 것은 순수 노이즈다.**
//
// docs/design/20-ui-kit.md §20.44.
//
// 바탕은 부품이 아니라 **주의를 하나도 안 받는 자리**다. 그래서 알갱이만 있다.
// 지금까지 여기 있던 것들(무아레 · 주사선 · 비네트 · 훑는 띠 · 잔광 · 먼지)은
// 전부 「브라운관이라는 물질」을 말하지 **무엇을 보고 있나**를 안 말해서 뺐다.
//
// ## 초점 둘레가 걷힌다
//
// 「보는 순간 또렷해진다」가 부품에서만 일어나면 부품과 바탕이 다른 말을 한다.
// 초점에서 가까운 데서는 알갱이가 잦아든다 — **또렷함이 자리를 가진다.**
// 선택이 옮겨가면 걷힌 자리가 따라간다. §20.43 의 파면이 하던 일을 이것이 대신한다.
//
// 화면 텍스처도 앞 편도 안 읽는다. **자리와 시각만으로** 나온다 — 웹 빌드 그대로 돈다.

uniform vec2 card = vec2(660.0, 760.0);
uniform float clock = 0.0;

// 바탕색과 알갱이색. 팔레트가 갈릴 때 같이 갈린다 — 색은 `HoloPalette` 한 곳에서 온다.
uniform vec3 deep : source_color = vec3(0.07, 0.06, 0.05);
uniform vec3 ink : source_color = vec3(0.92, 0.88, 0.81);

// 지금 또렷한 것이 어디 있나. 그 둘레에서 알갱이가 잦아든다.
uniform vec2 focus = vec2(-2000.0, -2000.0);
uniform float clear_reach = 300.0;

// 초당 몇 편이 갈리나. `Grain.CHURN` 과 같은 값이어야 **바탕과 부품이 같이 떤다.**
uniform float churn = 11.0;

// 알갱이 하나의 크기(px)와 가장 시끄러운 데서의 세기.
uniform float grit = 2.0;
uniform float force = 0.17;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 at = UV * card;
	float edge = floor(clock * churn);
	float speck = hash1(floor(at / grit) + vec2(edge * 13.0, edge * 7.0));
	// 초점에서 멀수록 알갱이가 산다. 안쪽 절반은 완전히 걷힌다.
	float far = smoothstep(clear_reach * 0.45, clear_reach, distance(at, focus));
	COLOR = vec4(mix(deep, ink, speck * force * far), 1.0);
}
