shader_type canvas_item;
render_mode blend_add;

// 겹 7 — 광택. **가장 빠른 겹이다.**
//
// 겹 2(속반사)가 왼쪽으로 흐르는 동안 이것이 오른쪽으로 지나가면, 정지 화면에서도
// 판에 두께가 있다고 읽힌다. 그 속도 차이가 이 키트의 깊이다.
//
// 광택은 **각도의 함수**다. 그래서 판이 눌리면 밝아지는 것이 아니라 **꺼진다** —
// 웹 버튼이 눌렸을 때 어두워지는 것과 이유가 다르다.

uniform vec2 rect_size = vec2(160.0, 44.0);
uniform float chamfer = 12.0;

uniform float travel = 0.0;    // 판을 훑는 자리
uniform float strength = 1.0;
uniform float width = 0.10;
uniform vec3 tone : source_color = vec3(0.62, 0.70, 0.76);

void fragment() {
	vec2 px = UV * rect_size;
	if (px.x - px.y > rect_size.x - chamfer) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// 비스듬한 띠. 수직으로 두면 유리판이 아니라 스캔라인이 된다.
		float d = abs((UV.x * 0.72 + UV.y * 0.28) - travel);
		float band = 1.0 - smoothstep(0.0, width, d);
		band = pow(band, 3.4);
		COLOR = vec4(tone * band * strength * 0.26, 1.0);
	}
}
