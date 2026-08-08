shader_type canvas_item;

// 흑칠(黑漆) — 바닥과 속반사.
//
// 겹 1(바닥)과 겹 2(속반사)를 한 패스로 만든다. **같은 사진을 두 배율로 겹치고
// 서로 다른 속도로 미끄러뜨린다.** 옻은 여러 번 칠해 쌓는 재료라 표면과 속이
// 따로 비치고, 그 속도 차이가 곧 판의 두께다.
//
// 그라디언트를 그리지 않는다. 위쪽이 밝은 것은 유리질 표면이 위에서 오는 빛을
// 더 받기 때문이지 장식이 아니다.

uniform sampler2D ground : source_color, filter_linear_mipmap, repeat_enable;

uniform vec2 rect_size = vec2(160.0, 44.0);
uniform float chamfer = 12.0;

// GDScript 가 누적한다. 호버에서 속도가 바뀌므로 TIME 을 직접 쓰면 튄다.
uniform float phase = 0.0;

uniform float lift = 0.0;
uniform float press = 0.0;
uniform float dead = 0.0;

uniform vec3 ink : source_color = vec3(0.078, 0.070, 0.059);
uniform vec3 depth_tint : source_color = vec3(0.42, 0.62, 0.72);
uniform float dust = 0.12;
uniform float depth_gain = 0.20;
uniform float sheen = 0.135;

void fragment() {
	vec2 px = UV * rect_size;

	// 오른쪽 위 모서리를 비스듬히 자른다. 자개는 실톱과 줄로 다루는 재료라
	// 부드러운 라운드 코너가 나오지 않는다. 모서리는 각지거나 잘려 있다.
	if (px.x - px.y > rect_size.x - chamfer) {
		COLOR = vec4(0.0);
	} else {
		// 겹 1 — 바닥. 거의 움직이지 않는다.
		float a = texture(ground, UV + vec2(phase * 0.006, 0.0)).r;
		// 겹 2 — 속반사. 배율이 크고 방향이 반대라 바닥 위를 미끄러진다.
		float b = texture(ground, UV * 0.55 + vec2(-phase * 0.011, phase * 0.004)).r;

		vec3 col = ink;
		col += a * dust;                    // 옻 속에 갇힌 먼지
		col += b * depth_gain * depth_tint; // 속에서 비쳐 나오는 반사
		// 위에서 오는 빛. 선형으로 두면 회색 그라디언트가 되고 그건 플라스틱이다.
		// 거듭제곱으로 위쪽에 몰아야 **광택 있는 검정**으로 읽힌다.
		col += pow(1.0 - UV.y, 2.4) * sheen;

		col *= 1.0 + lift * 0.30;
		col *= 1.0 - press * 0.28;
		col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))) * 0.85, dead);

		COLOR = vec4(col, 1.0);
	}
}
