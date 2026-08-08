class_name KitEase
extends RefCounted
## 도착 곡선 모음. 순수 정적 함수뿐이라 씬 없이 검증된다.
##
## **앞 판이 여기서 죽었다.** 상태를 목표값으로 지수 접근(`current += (target-current)*k`)
## 시켰더니 어느 순간에도 요소가 「도착」하지 않고 계속 스르륵 다가가기만 했다.
## 그래서 타격감이 나올 수 없었다.
##
## 여기서는 전부 **사건이 일어난 뒤 흐른 시간 `u`** 의 함수다. 호버가 붙은 순간부터
## 시계가 0 에서 시작하므로 **오버슛과 되튐이 성립한다.** 지수 접근으로는
## 목표를 지나칠 방법이 아예 없다.

const FULL_TURN: float = 6.283185307


## 목표를 지나쳤다 되튄다. `overshoot` 이 클수록 세게 지나친다.
static func out_back(u: float, overshoot: float = 2.4) -> float:
	var t := clampf(u, 0.0, 1.0) - 1.0
	return 1.0 + (overshoot + 1.0) * t * t * t + overshoot * t * t


## 여러 번 되튀며 잦아든다. 들이받은 뒤의 떨림.
static func out_elastic(u: float, period: float = 0.32, decay: float = 7.0) -> float:
	var t := clampf(u, 0.0, 1.0)
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return 1.0 - exp(-decay * t) * cos(FULL_TURN * t / period)


## 감쇠 진동 그 자체. 0 에서 시작해 0 으로 잦아든다 — 충격의 잔떨림에 쓴다.
static func shiver(u: float, frequency: float, decay: float) -> float:
	if u < 0.0:
		return 0.0
	return exp(-decay * u) * sin(FULL_TURN * frequency * u)


## 순식간에 가고 천천히 선다. 들이받는 도착.
static func out_expo(u: float, sharpness: float = 9.0) -> float:
	var t := clampf(u, 0.0, 1.0)
	return 1.0 - exp(-sharpness * t)


## 처음에 느리고 끝에 빠르다. 떠나는 쪽에 쓴다.
static func in_quad(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return t * t


## 시간을 `fps` 칸으로 끊는다. 사이값이 없어지므로 화면이 **덜컥덜컥** 넘어간다.
##
## 60fps 로 부드럽게 도는 것은 어느 엔진에나 있는 기본값이다. 8fps 로 홀드하면
## 그 순간 손으로 찍은 자막이 된다.
static func hold(time: float, fps: float) -> float:
	if fps <= 0.0:
		return time
	return floorf(time * fps) / fps


## 결정적 난수. 캡처마다 화면이 달라지면 비교가 안 되므로 `randf()` 를 쓰지 않는다.
static func hash01(n: int) -> float:
	var x := float((n * 1103515245 + 12345) & 0x7FFFFFFF)
	return fposmod(x * 0.00000000046566129, 1.0)
