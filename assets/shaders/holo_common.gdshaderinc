// 창의 재료가 함께 쓰는 것들.
//
// **가장자리까지의 거리는 셰이더가 모른다** — 프래그먼트는 자기 좌표만 안다.
// 그래서 실루엣(모따기)은 **꼭짓점**이 만들고, 셰이더는 그 안쪽만 칠한다.
// 사각 UV 안에서의 거리로 충분한 이유가 그것이다: 깎인 모서리는 이미 도형이 잘랐다.

// 사각형 안에서 가장자리까지의 거리 0..1. 가로세로 비를 맞춰 준다.
float edge_near(vec2 uv, float aspect) {
	vec2 d = min(uv, vec2(1.0) - uv);
	return min(d.x * aspect, d.y) * 2.0;
}

// 값싼 잡음. 결·번짐·흐름이 다 이걸 쓴다.
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 within = fract(p);
	within = within * within * (3.0 - 2.0 * within);
	float a = grain(cell);
	float b = grain(cell + vec2(1.0, 0.0));
	float c = grain(cell + vec2(0.0, 1.0));
	float d = grain(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, within.x), mix(c, d, within.x), within.y);
}
