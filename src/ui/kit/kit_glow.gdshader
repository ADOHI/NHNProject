shader_type canvas_item;
render_mode blend_add;

// 겹 0 — 잔광.
//
// 판 아래로 새어 나오는 자개색 번짐이다. 그림자가 아니다 — 나전은 빛을 먹지 않고
// 되쏘는 재료라, 판 둘레가 어두워지는 것이 아니라 **밝아진다.**
// 호버에서 이 번짐이 벌어지는 것이 "판이 떠올랐다"의 실체다.

uniform vec2 field_size = vec2(200.0, 84.0); // 이 노드의 크기
uniform vec2 plate_size = vec2(160.0, 44.0); // 판의 크기
uniform float margin = 20.0;                 // 판 둘레로 남긴 여백
uniform float spread = 0.0;                  // 0 평상 ~ 1 호버
uniform float dead = 0.0;
uniform vec3 tint : source_color = vec3(0.42, 0.72, 0.76);

void fragment() {
	vec2 p = UV * field_size - vec2(margin);

	// 판 사각형까지의 거리. 안쪽은 0 이지만 판이 덮으므로 보이지 않는다.
	vec2 q = max(-p, p - plate_size);
	float d = length(max(q, vec2(0.0)));

	float falloff = 3.0 + 7.0 * spread;
	float g = exp(-d / falloff);

	vec3 col = tint * g * (0.06 + 0.20 * spread);
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))) * 0.5, dead);
	COLOR = vec4(col, 1.0);
}
