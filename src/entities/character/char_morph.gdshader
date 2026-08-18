shader_type canvas_item;
// 파츠 그림의 UV 를 앵커 둘레에서 **방사형으로 휜다.**
//
// docs/design/31-soft-body.md §31.2.2.
//
// ## 왜 프래그먼트인가
//
// 파츠 그림은 `draw_texture_rect` 로 그리는 **사각형 하나**다. 버텍스 셰이더로는
// 네 모서리밖에 못 움직여서 국소 부풀림이 원천적으로 안 나온다. 격자를 잘게 나눈
// `MeshInstance2D` 로 바꾸면 되지만 파츠 수와 드로우 비용표(§25.32)를 다시 재야 한다.
//
// UV 를 여기서 휘면 **노드가 안 늘고** `gl_compatibility`(WebGL2)에서 그대로 돈다.
//
// ## 여백(pad)이 필요한 이유
//
// 파츠 그림은 알파 경계상자로 **딱 잘려 있다**(§25.41.2). 그 사각형 그대로 그리면
// 밀려난 살이 변에서 **잘린다.** 그래서 그리는 쪽이 사각형을 `pad` 만큼 넓히고,
// 여기서 UV 를 **되돌려 매핑**해 그림이 원래 크기로 남게 한다.
//
// 되돌린 좌표가 `0 … 1` 밖이면 알파를 0 으로 죽인다 — 안 그러면 가장자리 화소가
// 여백으로 늘어나 **번진다.**

const int MAX_ANCHORS = 2;

// 실제로 쓰는 앵커 수. `0` 이면 그냥 그린다.
uniform int anchor_count : hint_range(0, 2) = 0;

// 그리는 사각형을 원래 크기의 몇 배로 넓혔나(한쪽 변당 비율).
uniform float pad = 0.0;

// 앵커 중심 (텍스처 UV).
uniform vec2 anchor_uv[MAX_ANCHORS];

// 타원 감쇠의 반경 (UV).
uniform vec2 anchor_radius[MAX_ANCHORS];

// 살이 밀려난 양 (UV). **UV 를 반대로 읽어야 그림이 그쪽으로 간다.**
uniform vec2 anchor_shift[MAX_ANCHORS];

// 부풀림. 양수면 중심 둘레를 확대한다.
uniform float anchor_bulge[MAX_ANCHORS];

// 반평면 게이트. `xy` 단위법선 · `z` 자리 · `w` 무뎌지는 폭 (전부 UV).
// `xy` 가 0 이면 게이트가 없다.
uniform vec4 anchor_mask[MAX_ANCHORS];


// 그 점이 얼마나 휘나 (0 … 1). 타원 감쇠와 반평면 게이트의 곱이다.
float anchor_weight(int i, vec2 at) {
	vec2 radius = max(anchor_radius[i], vec2(0.0001));
	float distance = length((at - anchor_uv[i]) / radius);
	float weight = 1.0 - smoothstep(0.0, 1.0, distance);
	vec4 mask = anchor_mask[i];
	if (dot(mask.xy, mask.xy) > 0.000001) {
		weight *= smoothstep(mask.z - mask.w, mask.z + mask.w, dot(at, mask.xy));
	}
	return weight;
}

void fragment() {
	// 넓힌 사각형의 UV 를 **원래 텍스처 좌표로 되돌린다.**
	vec2 base = UV * (1.0 + 2.0 * pad) - vec2(pad);
	vec2 warped = base;
	for (int i = 0; i < MAX_ANCHORS; i++) {
		if (i >= anchor_count) {
			break;
		}
		// **가중치는 원래 자리에서 잰다.** 이미 휜 좌표로 재면 사상이 자기를 물어
		// 접히는 자리가 생긴다.
		float weight = anchor_weight(i, base);
		if (weight <= 0.0) {
			continue;
		}
		vec2 centre = anchor_uv[i];
		float grow = 1.0 - anchor_bulge[i] * weight;
		warped = centre + (warped - centre) * grow;
		warped -= anchor_shift[i] * weight;
	}
	vec4 texel = texture(TEXTURE, warped);
	// 여백 밖에서 끌어온 것은 없는 것이다. 안 죽이면 가장자리가 번진다.
	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		texel.a = 0.0;
	}
	// **`COLOR` 는 들어올 때 버텍스 색(= 그리는 쪽이 준 modulate)이다.**
	// `MODULATE` 를 쓰려다 이 판에서 「모르는 이름」으로 컴파일이 통째로 실패했다.
	// 곱한 값이 맞는지는 `tools/check_morph_pixels.gd` 가 화면에서 재서 확인한다.
	COLOR = texel * COLOR;
}
