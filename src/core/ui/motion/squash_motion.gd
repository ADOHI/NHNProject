class_name SquashMotion
extends RefCounted
## 컨셉 4 — **부피가 보존된다.**
##
## > 판은 굳은 물건이 아니라 **덩어리**다.
## > 누르면 납작해지면서 **그만큼 옆으로 넓어진다.** 밀려난 부피가 어디로도 사라지지 않는다.
## > 손을 떼면 세로로 길쭉해졌다가 여러 번 출렁이며 잦아든다.
##
## **여기서 조심할 것 하나.** 젤리 되튐은 어느 UI 에나 있는 가장 흔한 모션이고,
## SLAM 이 이미 오버슛과 되튐을 가져갔다. 그래서 이 컨셉이 「SLAM 을 부드럽게 한 판」이
## 되면 넷 중 하나를 버리는 셈이 된다. 그걸 막는 규칙 셋:
##
##   **자리를 옮기지 않는다** — 날아 들어오지 않는다. 판은 제자리에 붙박여 있고
##     오직 **모양**만 바뀐다. SLAM 은 자리가 움직이고 여기는 비율이 움직인다
##   **색을 뒤집지 않는다** — SLAM · HOLD 의 수단이다. 여기서는 색이 사건에 관여하지 않는다
##   **부피가 언제나 1** — 세로로 눌린 만큼 가로로 정확히 넓어진다.
##     되튐 타이밍이 아니라 **모양이 변하는 것**이 이 컨셉을 만든다
##
## 배색도 갈랐다 (검정/주황 · 뼈색/청록 · 노랑/마젠타 다음) — 짙은 남색에 라임이다.

const BODY := Color(0.090, 0.075, 0.251)
const ACCENT := Color(0.784, 1.0, 0.196)
const INK := Color(0.949, 1.0, 0.878)

## 눌렸을 때의 세로 비율. 0.55 면 가로가 1.82 배가 된다 — 옆 판까지 닿는다.
const PRESS_SQUASH: float = 0.55

## 아래 모서리를 고정한다. 복판을 고정하면 판이 위아래로 동시에 줄어 **공중에 뜬다.**
const PIVOT := Vector2(0.0, 0.5)


static func evaluate(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool, seed: int
) -> PlateState:
	var state := PlateState.new()
	state.body = BODY
	state.accent = ACCENT
	state.ink = INK
	state.pivot = PIVOT

	# 세로 비율 하나가 모든 것을 정한다. 가로는 그 역수라 따로 정할 수 없다.
	var tall := _idle_tall(time, seed)

	if hovering:
		tall += _hover_tall(hover_time)
	if pressing:
		tall = PRESS_SQUASH + _press_wobble(press_time)
	elif press_time < 1.10:
		tall += _release_tall(press_time)

	tall = clampf(tall, 0.42, 1.62)
	_apply_volume(state, tall)

	state.bar = 0.26 + (1.0 if hovering else 0.0) * 0.52
	return state


## **부피 보존.** 가로는 세로의 역수다. 이 한 줄이 컨셉의 전부라 예외를 두지 않는다.
static func _apply_volume(state: PlateState, tall: float) -> void:
	state.scale = Vector2(1.0 / tall, tall)
	# 글자도 같이 찌그러진다. 판만 물렁하면 고무판에 얹은 스티커로 보인다.
	# 다만 판보다 덜 먹인다 — 그대로 먹이면 글자가 읽히지 않는다.
	var ink_tall := 1.0 + (tall - 1.0) * 0.62
	state.ink_squash = Vector2(1.0 / ink_tall, ink_tall)


## idle — 덩어리는 늘 아주 조금 출렁인다. 그리고 3.4초마다 한 번 크게 출렁인다.
##
## 상시 사인파만 두면 「숨쉬는 UI」가 되므로, 가끔 크게 한 번 흔들어 덩어리라는 것을
## 상기시킨다. 그 두 개가 겹쳐야 물렁한 물건으로 읽힌다.
static func _idle_tall(time: float, seed: int) -> float:
	var drift := sin(TAU * time / 2.6 + KitEase.hash01(seed) * TAU) * 0.020
	var period := 3.4
	var since := fposmod(time + KitEase.hash01(seed * 5) * period, period)
	return 1.0 + drift + KitEase.shiver(since, 3.4, 4.2) * 0.075


## 호버 — 세로로 늘어났다가 **여러 번** 출렁이며 잦아든다.
##
## 감쇠를 느슨하게 잡아 되튐이 서너 번 눈에 보인다. 한 번에 서면 그냥 크기 변화이고,
## 덩어리로 보이려면 남은 힘이 계속 오가는 것이 보여야 한다.
static func _hover_tall(hover_time: float) -> float:
	if hover_time < 0.0:
		return 0.0
	return 0.30 * exp(-4.0 * hover_time) * cos(TAU * 4.4 * hover_time)


## 눌림 — 납작한 채로 버틴다. 버티는 동안에도 미세하게 떨린다.
static func _press_wobble(press_time: float) -> float:
	return KitEase.shiver(press_time, 7.0, 9.0) * 0.05


## 뗌 — 눌렸던 만큼 **반대로** 길쭉해졌다가 잦아든다.
static func _release_tall(press_time: float) -> float:
	if press_time < 0.0:
		return 0.0
	return 0.46 * exp(-3.2 * press_time) * cos(TAU * 3.6 * press_time - 0.35)
