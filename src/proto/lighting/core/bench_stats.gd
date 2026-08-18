class_name ProtoLightBenchStats
extends RefCounted
## **분위수로 재는 통계.** 노드에 의존하지 않으므로 테스트가 쉽다.
##
## 최악값 하나로 판정하면 남의 딸꾹질에 결론이 뒤집힌다 —
## 이동 레인이 같은 자리에서 한 번 헛돌았고 (`unit_move/README.md` §21),
## 그 판정 방식을 그대로 쓴다. **95 분위가 판정선이다.**

## 웹 프레임 예산 (초당 60 프레임)
const BUDGET_MS := 16.7

## **16.7 은 32 비트 실수로 정확히 적히지 않는다.** 표본을 `PackedFloat32Array` 에
## 담으므로 16.7 을 넣으면 16.7000008 로 되살아나고, 그대로 비교하면 **예산에 딱 맞는
## 프레임이 「넘쳤다」로 세어진다.** 테스트가 이걸 잡았다 (3 을 기대값 2 와 비교하며 떨어짐).
##
## 값을 64 비트로 올리지 않고 여유를 두는 쪽을 골랐다 — 표본이 수천 개라 저장 폭이
## 두 배가 되는 것보다, **「1 마이크로초 차이는 넘친 것이 아니다」** 가 뜻으로도 맞다.
const _BUDGET_EPSILON_MS := 0.001

var _frame_ms := PackedFloat32Array()
var _render_ms := PackedFloat32Array()


func reset() -> void:
	_frame_ms = PackedFloat32Array()
	_render_ms = PackedFloat32Array()


## 한 프레임을 기록한다. `render_ms` 는 엔진이 잰 뷰포트 렌더 시간이고,
## 재지 못하는 환경(브라우저의 GPU 타이머)에서는 0 이 들어온다.
func add(frame_ms: float, render_ms: float) -> void:
	_frame_ms.append(frame_ms)
	_render_ms.append(render_ms)


func count() -> int:
	return _frame_ms.size()


func frame_at(ratio: float) -> float:
	return _percentile(_frame_ms, ratio)


func render_at(ratio: float) -> float:
	return _percentile(_render_ms, ratio)


## 예산을 넘긴 프레임 수
func over_budget() -> int:
	var n := 0
	for ms in _frame_ms:
		if _is_over(ms):
			n += 1
	return n


## 넘긴 프레임 중 **렌더가 예산의 절반을 넘게 쓴 것.** 이동 레인의 「우리 탓」과 같은
## 자다 — 프레임이 26 밀리초인데 렌더가 3 밀리초면 남은 23 은 우리가 만든 것이 아니다.
## 렌더 시간을 못 재는 환경에서는 늘 0 이 되므로 **0 을 「우리 탓 아님」으로 읽지 마라.**
func over_and_render_heavy() -> int:
	var n := 0
	for i in _frame_ms.size():
		if _is_over(_frame_ms[i]) and _render_ms[i] > BUDGET_MS * 0.5:
			n += 1
	return n


func _is_over(ms: float) -> bool:
	return ms > BUDGET_MS + _BUDGET_EPSILON_MS


func _percentile(values: PackedFloat32Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := int(round(ratio * float(sorted.size() - 1)))
	return sorted[clampi(index, 0, sorted.size() - 1)]
