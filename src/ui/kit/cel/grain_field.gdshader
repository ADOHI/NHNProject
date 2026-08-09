shader_type canvas_item;
// **축의 끝 — 아무도 안 보는 것은 순수 노이즈다.**
//
// docs/design/20-ui-kit.md §20.44 · §20.47.
//
// 바탕은 부품이 아니라 **주의를 하나도 안 받는 자리**다. 그래서 알갱이만 있다.
// 지금까지 여기 있던 것들(무아레 · 주사선 · 비네트 · 훑는 띠 · 잔광 · 먼지)은
// 전부 「브라운관이라는 물질」을 말하지 **무엇을 보고 있나**를 안 말해서 뺐다.
//
// ## 맑은 것의 **둘레까지** 맑다 (§20.47.3)
//
// 「보는 순간 또렷해진다」가 부품에서만 일어나면 부품과 바탕이 다른 말을 한다.
// 걷힌 자리가 **원**이면 부품은 가로로 긴데 걷힘은 동그래서, 긴 부품의 양 끝이
// 알갱이 한복판에 박힌다 — 부품 자신은 또렷한데 **자리가 안 맑다.**
//
// 그래서 걷힘이 부품의 **네모를 따라간다**: `focus` 한가운데에 `span` 만큼의 네모가
// 통째로 걷히고, 거기서 `halo` px 에 걸쳐 알갱이가 살아난다. 맑은 것은 이제
// **잡음에 뚫린 구멍 안에** 서 있다. 선택이 옮겨가면 구멍이 따라간다.
//
// 화면 텍스처도 앞 편도 안 읽는다. **자리와 시각만으로** 나온다 — 웹 빌드 그대로 돈다.

uniform vec2 card = vec2(660.0, 760.0);
uniform float clock = 0.0;

// 바탕색과 알갱이색. 팔레트가 갈릴 때 같이 갈린다 — 색은 `HoloPalette` 한 곳에서 온다.
uniform vec3 deep : source_color = vec3(0.07, 0.06, 0.05);
uniform vec3 ink : source_color = vec3(0.92, 0.88, 0.81);

// 지금 또렷한 것이 어디에 얼마만큼 있나. 그 네모 안은 알갱이가 **하나도 없다.**
uniform vec2 focus = vec2(-4000.0, -4000.0);
uniform vec2 span = vec2(90.0, 40.0);

// 네모 밖에서 알갱이가 다 살아나기까지의 거리(px).
uniform float halo = 170.0;

// 초당 몇 편이 갈리나. `Grain.CHURN` 과 같은 값이어야 **바탕과 부품이 같이 떤다.**
uniform float churn = 11.0;

// 알갱이 하나의 크기(px)와 가장 시끄러운 데서의 세기.
//
// 세기를 0.17 에서 올렸다. **맑음이 눈에 들려면 흐림이 세야 한다** — 맑은 자리가
// 이제 진짜 0 이라, 바탕이 세질수록 둘의 차가 커지지 맑은 쪽이 더러워지지 않는다.
uniform float grit = 2.0;
uniform float force = 0.34;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 at = UV * card;
	float edge = floor(clock * churn);
	float speck = hash1(floor(at / grit) + vec2(edge * 13.0, edge * 7.0));
	// 네모 밖으로 얼마나 나갔나. 안쪽은 0 이라 **완전히 걷힌다.**
	vec2 out_by = max(abs(at - focus) - span, vec2(0.0));
	float far = smoothstep(0.0, halo, length(out_by));
	COLOR = vec4(mix(deep, ink, speck * force * far), 1.0);
}
