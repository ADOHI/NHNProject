class_name UiMotion
extends RefCounted
## 움직임을 만드는 곳. 길이와 곡선이 여기서만 나온다.
##
## **이 게임에서 움직이는 것은 변한 것이다.**
## 판 위의 숫자는 절대값이 위험을 알려 주고 변화량이 사람을 알려 준다
## (docs/design/13-information-design.md §13.5.1). 그래서 값이 바뀌는 순간은
## 이 게임에서 가장 중요한 사건이고, 화면은 그것만 움직여야 한다.
##
## 늘 흔들리는 화면에서는 진짜 변화가 묻힌다. 상시 움직임으로 허용한 것은 두 가지뿐이고
## 둘 다 정보다 — **모르는 방의 신호 잡음**과 **송출 중 표시의 맥동**.


## 값이 바뀐 순간의 섬광. 밝게 튀었다가 제 색으로 가라앉는다.
##
## 켜지는 것보다 꺼지는 것이 느려야 잔상으로 읽힌다. 인광이 그렇게 꺼진다.
static func flash_color(target: CanvasItem, hot: Color, rest: Color) -> Tween:
	var tween := target.create_tween()
	tween.tween_property(target, "modulate", hot, UiTokens.TIME_FLASH)
	tween.tween_property(target, "modulate", rest, UiTokens.TIME_SETTLE * 2.0)
	return tween


## 변화량 표시가 떠올랐다 사라진다.
##
## 플레이어가 이전 값을 암산으로 기억하게 두면 재미가 아니라 노동이 된다
## (docs/design/13-information-design.md §13.7). 이 움직임이 그 기억을 대신한다.
static func rise_and_fade(target: Control, distance: float) -> Tween:
	var start := target.position
	target.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "position", start - Vector2(0.0, distance), UiTokens.TIME_GHOST)
	(
		tween
		. tween_property(target, "modulate:a", 0.0, UiTokens.TIME_GHOST)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_CUBIC)
	)
	return tween


## 상태가 바뀐 위젯이 자리를 잡는다. 크기가 아니라 밝기만 움직인다 —
## 판 위에서 크기가 흔들리면 배치를 다시 읽어야 한다.
static func settle(target: CanvasItem, from: float = 0.0) -> Tween:
	target.modulate.a = from
	var tween := target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, UiTokens.TIME_SETTLE)
	return tween


## 0 에서 1 사이를 오가는 맥동. 송출 표시처럼 늘 움직여야 하는 것에 쓴다.
##
## 정현파를 그대로 쓰지 않고 한 번 더 눌러 준다. 밝은 구간이 짧아야
## "깜빡인다"로 읽히고, 고르게 오가면 그냥 밝기가 변하는 것으로 보인다.
static func breathe(period: float = UiTokens.TIME_PULSE) -> float:
	var phase := fmod(Time.get_ticks_msec() / 1000.0, period) / period
	var wave := 0.5 - 0.5 * cos(phase * TAU)
	return wave * wave


## 화면에 공통으로 흐르는 시간. 셰이더의 TIME 과 같은 축을 쓰기 위한 값이다.
static func clock() -> float:
	return Time.get_ticks_msec() / 1000.0
