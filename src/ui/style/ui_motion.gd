class_name UiMotion
extends RefCounted
## 움직임을 만드는 곳. 길이와 곡선이 여기서만 나온다.
##
## **이 화면의 움직임은 전부 한 몸짓의 변주다 — 두 판이 어긋났다 맞물리는 것.**
##
##   먹판이 먼저 때린다   비뚤게 들어와 튕기며 자리를 잡는다
##   별색판이 늦게 온다   지나쳤다가 되튀어 앉는다
##
## 등장도, 전환도, 강조도 전부 이 두 박자다. 진폭과 시차만 다르다.
## 그래서 화면 어디를 봐도 같은 리듬이 보이고, 그 반복이 이 게임의 서명이 된다
## (docs/design/18-visual-identity.md §18.6).
##
## **여기서 쓰지 않는 것을 먼저 적는다.**
## 밝기를 올렸다 내리는 것(페이드), 크기를 살짝 키웠다 줄이는 것(scale pop),
## 옆에서 미끄러져 들어오는 것 — 전부 어느 UI 에나 있는 기본값이라 이 게임의 것이 아니다.
## 이 화면에서 무엇이 일어났는지는 **형태가 바뀌어서** 보여야 한다 —
## 각도가 틀어졌다 잡히고, 두 판이 벌어졌다 맞물리고, 망점이 굵었다 고와진다.


## **활자가 조판대에 떨어진다.** 비뚤게 들어와 자리를 잡을 때까지 튕긴다.
##
## 크기를 살짝 키웠다 줄이는 것(scale pop)을 쓰지 않는다. 그건 어느 UI 에나 있는 기본값이고,
## 무엇보다 이 화면에서는 배율이 카메라의 것이라 손댈 수 없다.
## 대신 **각도**를 쓴다 — 납활자를 손으로 집어 판에 앉히면 반듯하게 들어가지 않는다.
static func slam(target: Control, degrees: float) -> Tween:
	target.pivot_offset = target.size * 0.5
	target.rotation = deg_to_rad(degrees)
	var tween := target.create_tween()
	(
		tween
		. tween_property(target, "rotation", 0.0, UiTokens.TIME_CHASE * 1.9)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_ELASTIC)
	)
	return tween


## 별색판이 뒤늦게 따라붙는다. **이 화면의 서명이 움직임이 되는 자리다.**
##
## 지나쳤다가 되튀는 곡선을 쓰는 이유는, 인쇄기의 두 번째 판이 관성으로 밀려
## 제자리를 한 번 넘긴 뒤에 앉기 때문이다. 선형으로 오면 그냥 미끄러지는 사각형이다.
static func chase(target: Control, home: Vector2, amount: float) -> Tween:
	target.position = home + UiTokens.slip(amount)
	var tween := target.create_tween()
	(
		tween
		. tween_property(target, "position", home, UiTokens.TIME_CHASE)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	return tween


## 값이 바뀐 순간의 **오정합**. 별색판이 크게 튀어 나갔다가 제자리로 돌아온다.
##
## 이 게임에서 가장 중요한 사건은 "숫자가 바뀌었다"다 —
## 절대값은 위험을 알려 주고 변화량은 사람을 알려 준다
## (docs/design/13-information-design.md §13.5.1).
## 그러니 변화는 서명이 가장 크게 드러나는 자리여야 한다.
static func misprint(target: Control, home: Vector2, amount: float) -> Tween:
	target.position = home + UiTokens.slip(amount * 3.4)
	var tween := target.create_tween()
	(
		tween
		. tween_property(target, "position", home, UiTokens.TIME_CHASE * 1.6)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_ELASTIC)
	)
	return tween


## 잉크가 번졌다 마른다. 밝기만 움직인다 — 판 위에서 크기가 흔들리면 배치를 다시 읽어야 한다.
static func bleed(target: CanvasItem, hot: Color, rest: Color) -> Tween:
	var tween := target.create_tween()
	tween.tween_property(target, "modulate", hot, UiTokens.TIME_STRIKE)
	tween.tween_property(target, "modulate", rest, UiTokens.TIME_BLEED)
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
	(
		tween
		. tween_property(target, "position", start - Vector2(0.0, distance), UiTokens.TIME_GHOST)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_QUINT)
	)
	(
		tween
		. tween_property(target, "modulate:a", 0.0, UiTokens.TIME_GHOST)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_CUBIC)
	)
	return tween


## 윤전기 한 바퀴. 0 에서 1 사이를 오가되 **밝은 구간이 짧다.**
##
## 정현파를 그대로 쓰면 그냥 밝기가 오가는 것으로 보인다.
## 한 번 더 눌러야 "찍히는 순간"이 짧게 지나가는 박자가 된다.
static func press_beat(period: float = UiTokens.TIME_PRESS) -> float:
	var phase := fmod(clock(), period) / period
	var wave := 0.5 - 0.5 * cos(phase * TAU)
	return wave * wave


## 정합이 완전히 맞는 인쇄기는 없다. 별색판이 늘 미세하게 떠다닌다.
##
## 상시 움직임이지만 장식이 아니다 — **이 지면이 지금 인쇄되고 있다**는 표시이고,
## 떨림의 크기는 곧 그 요소가 얼마나 이야기에 가까운가다.
static func register_drift(amount: float) -> Vector2:
	var seconds := clock()
	return Vector2(sin(seconds * 1.7) * 0.9, cos(seconds * 2.3) * 0.7) * amount


## 화면에 공통으로 흐르는 시간. 셰이더의 TIME 과 같은 축을 쓰기 위한 값이다.
static func clock() -> float:
	return Time.get_ticks_msec() / 1000.0
