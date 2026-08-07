// 세 셰이더가 함께 쓰는 조각들.
//
// 같은 챔퍼 판정을 셰이더마다 베껴 두면 형태 규칙이 세 곳에 흩어진다.
// 모서리 크기를 바꿀 때 한 곳만 고치면 되도록 여기로 모았다.
//
// gl_compatibility(WebGL 2) 에서만 돌아가면 된다.
// 그래서 텍스처 조회도, 미분(dFdx/fwidth)도 쓰지 않는다.

// 값 잡음. 텍스처 파일 없이 입자를 만들기 위한 최소 해시다.
float ui_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 모서리를 잘라 낸 사각형의 **안쪽 거리**(픽셀 단위). 밖이면 음수가 된다.
//
// cuts 는 [좌상, 우상, 우하, 좌하] 순서로, design_tokens.gd 의 배열과 같다.
// 잘린 변은 45도 직선이므로 반평면까지의 거리에 1/sqrt(2) 를 곱하면 된다.
float ui_chamfer_distance(vec2 p, vec2 size, vec4 cuts) {
	float k = 0.70710678;
	float d = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	d = min(d, (p.x + p.y - cuts.x) * k);
	d = min(d, ((size.x - p.x) + p.y - cuts.y) * k);
	d = min(d, ((size.x - p.x) + (size.y - p.y) - cuts.z) * k);
	d = min(d, (p.x + (size.y - p.y) - cuts.w) * k);
	return d;
}

// 0 에서 1 사이를 오가되 밝은 구간이 짧은 맥동. ui_motion.gd 의 breathe() 와 같은 식이다.
float ui_breathe(float seconds, float period) {
	float wave = 0.5 - 0.5 * cos(seconds / max(period, 0.001) * 6.28318530718);
	return wave * wave;
}
