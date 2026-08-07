// 지면을 만드는 셰이더들이 함께 쓰는 조각.
//
// 같은 망점 계산을 셰이더마다 베껴 두면 인쇄 규칙이 여러 곳에 흩어진다.
// 선수 각도 하나를 바꾸려고 파일 세 개를 고치게 되는 순간 규칙은 무너진다.
//
// gl_compatibility(WebGL 2) 에서만 돌아가면 된다.
// 그래서 텍스처 조회도, 미분(dFdx/fwidth)도 쓰지 않는다. 산술뿐이다.

// 값 잡음. 종이 섬유를 만들기 위한 최소 해시다.
float press_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 부드러운 값 잡음. 잉크가 고르게 먹지 않아 생기는 큰 얼룩이다.
float press_blob(vec2 p) {
	vec2 cell = floor(p);
	vec2 frac = fract(p);
	frac = frac * frac * (3.0 - 2.0 * frac);
	float a = press_hash(cell);
	float b = press_hash(cell + vec2(1.0, 0.0));
	float c = press_hash(cell + vec2(0.0, 1.0));
	float d = press_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, frac.x), mix(c, d, frac.x), frac.y);
}

vec2 press_turn(vec2 p, float radians_angle) {
	float s = sin(radians_angle);
	float c = cos(radians_angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// **망점 한 판.** 각도와 간격이 주어지면 그 자리를 점이 얼마나 덮는지 돌려준다.
//
// 인쇄에서 판마다 선수 각도를 어긋나게 거는 것은 실무 규칙이다.
// 같은 각도로 겹치면 무늬(모아레)가 져서 그림이 안 보인다.
// 여기서는 먹판 15도, 별색판 45도를 쓴다.
//
// 반지름이 농도의 제곱근으로 자라는 이유는 점의 **면적**이 농도를 따라야 하기 때문이다.
float press_plate(vec2 p, float radians_angle, float pitch, float amount) {
	if (amount <= 0.001) {
		return 0.0;
	}
	vec2 q = press_turn(p, radians_angle) / max(pitch, 1.0);
	vec2 near = (fract(q) - vec2(0.5)) * max(pitch, 1.0);
	float radius = max(pitch, 1.0) * 0.62 * sqrt(clamp(amount, 0.0, 1.0));
	return 1.0 - smoothstep(radius - 0.9, radius + 0.9, length(near));
}

// 0 에서 1 사이를 오가되 밝은 구간이 짧은 맥동. ui_motion.gd 의 press_beat() 와 같은 식이다.
float press_beat(float seconds, float period) {
	float wave = 0.5 - 0.5 * cos(seconds / max(period, 0.001) * 6.28318530718);
	return wave * wave;
}

// 사각형 안쪽까지의 거리(px). 밖이면 음수다.
// 모서리를 굴리지도 자르지도 않으므로 판정이 이보다 단순할 수 없다.
float press_inside(vec2 p, vec2 size) {
	return min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
}
