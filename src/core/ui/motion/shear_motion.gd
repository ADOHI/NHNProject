class_name ShearMotion
extends RefCounted
## 컨셉 2 — **베여서 어긋난다.**
##
## > 판은 성한 물건이 아니다. **이미 베여 있다.**
## > 커서가 닿으면 조각들이 벤 자리를 따라 **서로 반대로 미끄러지고**, 벌어진 틈에서
## > 청록이 드러난다. 누르면 한 번 더 베여 세 조각이 된다.
##
## **SLAM 과 정반대로 움직인다.** SLAM 이 「들이받고 되튄다」(탄성 · 오버슛 · 연속)라면
## 여기는 **덜컥덜컥 끊긴다** — 이 파일에는 보간이 한 줄도 없다.
## 모든 값이 `KitEase.hold()` 로 시간을 칸칸이 끊어 계단으로만 바뀐다.
## 부드러운 것은 어느 엔진에나 있고, 끊기는 것은 손으로 자른 것이다.
##
## 모션 서명 셋:
##   **하드 컷** — 사이값이 없다. 조각은 한 칸에서 다음 칸으로 순간이동한다
##   **어긋남** — 조각은 벤 선을 **따라** 미끄러진다. 가로지르지 않는다
##   **틈에서 드러나는 색** — 벌어진 자리는 비어 있지 않고 청록이 차 있다

const BODY := Color(0.929, 0.914, 0.878)
const ACCENT := Color(0.0, 0.898, 0.816)
const INK := Color(0.039, 0.039, 0.043)

## 벤 선의 법선. 살짝 기울어야 「가로로 자른 것」이 아니라 「벤 것」이 된다.
const CUT_NORMAL := Vector2(0.46, -0.89)

## idle 에서 이음매가 다시 붙는 박자. 초당 세 번 덜컥인다.
const IDLE_STEPS: float = 3.0

## 호버 · 눌림에서 시간을 끊는 칸. 이 값이 「부드럽지 않음」의 전부다.
const SNAP_STEPS: float = 18.0


static func evaluate(
	time: float, hover_time: float, hovering: bool, press_time: float, pressing: bool, seed: int
) -> PlateState:
	var state := PlateState.new()
	state.body = BODY
	state.accent = ACCENT
	state.ink = INK
	state.cut_normal = CUT_NORMAL.normalized()

	var slide_axis := Vector2(-state.cut_normal.y, state.cut_normal.x)

	# 벌어진 정도. 세 상태가 같은 값 하나를 서로 다른 크기로 밀 뿐이다.
	var apart := _idle_apart(time, seed)
	var cut_count := 1

	if hovering:
		var step := KitEase.hold(hover_time, SNAP_STEPS)
		# 0.06초면 다 벌어진다. 두 칸 만에 끝나므로 도중이 거의 안 보인다.
		apart = maxf(apart, minf(step / 0.06, 1.0) * 36.0)
	else:
		# 되붙는 것도 계단이다. 스르륵 붙으면 벤 자국이 아니라 고무가 된다.
		var back := KitEase.hold(hover_time, 14.0)
		apart = maxf(apart, maxf(0.0, 1.0 - back / 0.16) * 36.0)

	if pressing:
		var step := KitEase.hold(press_time, SNAP_STEPS)
		apart = maxf(apart, 54.0)
		cut_count = 2
		state.ink_offset = slide_axis * (6.0 if step > 0.02 else 0.0)
	elif press_time < 0.20:
		# 손을 뗀 직후 한 칸만 더 벌어져 있다가 붙는다.
		cut_count = 2 if KitEase.hold(press_time, 12.0) < 0.09 else 1
		apart = maxf(apart, 40.0)

	_fill_cuts(state, cut_count, apart, slide_axis, time, seed)
	_open_gap(state, apart)
	state.bar = 0.30 + minf(apart / 36.0, 1.0) * 0.42
	return state


## idle — 이음매가 가만있지 않는다. 초당 세 번, 몇 픽셀씩 어긋났다 붙는다.
##
## 상시 사인파로 흔들면 「숨쉬는 UI」가 되는데 그건 어느 앱에나 있다.
## 계단으로 끊으면 필름이 잘못 이어 붙은 것처럼 보이고, 그게 이 컨셉의 성격이다.
static func _idle_apart(time: float, seed: int) -> float:
	var step := int(KitEase.hold(time, IDLE_STEPS) * IDLE_STEPS)
	return KitEase.hash01(seed * 31 + step) * 7.0


## 조각을 벤 선에 **수직으로도** 조금 벌린다.
##
## 벤 선을 따라서만 미끄러뜨리면 벌어지는 자리가 판의 양 끝뿐이라, 강세색이
## 얇은 쐐기로만 새어 나와 **긁힌 자국처럼** 보인다. 수직으로 몇 픽셀만 벌리면
## 벤 자리 전체가 띠로 열려 「잘렸다」가 한눈에 읽힌다.
static func _open_gap(state: PlateState, apart: float) -> void:
	var push := state.cut_normal * clampf(apart * 0.18, 0.0, 9.0)
	var count := state.piece_slide.size()
	for i in range(count):
		# 위쪽 조각은 위로, 아래쪽 조각은 아래로. 가운데 조각은 거의 제자리다.
		var side := 1.0 - 2.0 * (float(i) / maxf(1.0, float(count - 1)))
		state.piece_slide[i] += push * side


## 벤 자리와 조각별 어긋남을 채운다.
static func _fill_cuts(
	state: PlateState, cut_count: int, apart: float, slide_axis: Vector2, time: float, seed: int
) -> void:
	var wobble := KitEase.hash01(seed * 7 + int(KitEase.hold(time, IDLE_STEPS) * IDLE_STEPS)) - 0.5
	if cut_count <= 1:
		state.cuts = [Vector2(0.0, wobble * 7.0)]
		state.piece_slide = [slide_axis * apart * 0.5, slide_axis * -apart * 0.5]
		state.piece_spin = [0.0, 0.0]
		return
	# 두 번 베이면 가운데 조각이 생기고, 그 조각만 반대로 크게 밀린다.
	state.cuts = [Vector2(0.0, -9.0 + wobble * 5.0), Vector2(0.0, 11.0 + wobble * 5.0)]
	state.piece_slide = [
		slide_axis * apart * 0.55,
		slide_axis * -apart * 0.75,
		slide_axis * apart * 0.35,
	]
	state.piece_spin = [0.0, 0.045, -0.028]
