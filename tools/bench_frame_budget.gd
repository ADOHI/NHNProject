extends SceneTree
## **프레임 예산을 분포로 재고, 우리 탓과 남 탓을 가른다.**
##
##     godot --path . -s res://tools/bench_frame_budget.gd
##     godot --path . -s res://tools/bench_frame_budget.gd -- 40 100 200
##
## 지금까지 **최악 프레임 하나로 판정해 왔고 그것이 틀렸다.** 최악값은 외부 간섭에 가장
## 취약한 통계다. 다른 프로세스가 한 번 튀면 그 값이 우리 코드의 값이 되어 버린다.
## 실제로 같은 코드에서 최악값이 18.5~20.7 밀리초를 오갔다.
##
## 그래서 둘을 바꿨다.
##
## | 무엇 | 왜 |
## | --- | --- |
## | **분위수로 잰다** (중앙값 · 95 · 99 · 최악) | 한 번의 딸꾹질이 판정을 뒤집지 못한다 |
## | **우리 계산과 프레임을 따로 잰다** | 우리 계산이 3 ms 인데 프레임이 20 ms 면 우리 탓이 아니다 |
##
## `field.last_step_usec` 이 **우리가 이동에 쓴 시간**이고, `_process` 의 delta 가
## **프레임 전체 시간**이다. 둘을 프레임마다 짝지어 모으면, 넘친 프레임에서 우리 몫이
## 얼마였는지 바로 나온다.
##
## **판정 기준은 95 분위로 삼는다.** 중앙값은 스파이크를 통째로 놓치고, 최악값은 남의 딸꾹질
## 하나에 뒤집힌다. 스무 프레임에 한 번 넘치는 것은 사람이 알아채므로 95 분위면 충분히 엄하다.

const _SCENE := "res://src/proto/unit_move/unit_move_proto.tscn"

## 인원마다 모으는 프레임 수. 분위수가 안정되려면 표본이 넉넉해야 한다.
const _FRAMES := 600

## 인원을 바꾼 뒤 버리는 프레임. 첫 프레임은 자원 할당이 섞여 값이 튄다.
const _WARMUP := 60

## 웹 프레임 예산(밀리초). 60 프레임 기준이다.
const _BUDGET := 16.7

var _proto: Node2D
var _counts: PackedInt32Array = PackedInt32Array()
var _index := -1
var _warmup := 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _step_ms: PackedFloat32Array = PackedFloat32Array()
var _turn := 0


func _initialize() -> void:
	_proto = load(_SCENE).instantiate()
	root.add_child(_proto)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		_counts.append(int(arg))
	if _counts.is_empty():
		_counts = PackedInt32Array([40, 100, 200])
	print("| 인원 | 이동 계산 중앙 | 95 | 99 | 최악 | 프레임 중앙 | 95 | 99 | 최악 | 넘친 프레임 | 그중 우리 탓 |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	_advance()


func _process(delta: float) -> bool:
	if _index >= _counts.size():
		return true
	if _warmup > 0:
		_warmup -= 1
		return false
	_frame_ms.append(delta * 1000.0)
	# 이동 계산에 실제로 쓴 시간. `unit_field` 가 프레임마다 갱신한다.
	var field: Object = _proto.get("field")
	_step_ms.append(0.0 if field == null else float(field.get("last_step_usec")) / 1000.0)
	# 계속 움직여야 가장 무거운 구간이 잡힌다. 가만히 선 유닛은 부하를 만들지 않는다.
	_turn += 1
	if _turn % 90 == 0:
		var target := Vector2(1500.0, 550.0) if _turn % 180 == 0 else Vector2(260.0, 550.0)
		_proto.call("select_all")
		_proto.call("order_move_at", target)
	if _frame_ms.size() >= _FRAMES:
		_report()
		_advance()
	return false


func _advance() -> void:
	_index += 1
	if _index >= _counts.size():
		return
	_frame_ms = PackedFloat32Array()
	_step_ms = PackedFloat32Array()
	_warmup = _WARMUP
	_turn = 0
	_proto.call("set_unit_count", _counts[_index])
	_proto.call("set_debug_visible", false)
	_proto.call("select_all")
	_proto.call("order_move_at", Vector2(1500.0, 550.0))


## 넘친 프레임 중 **우리 계산이 예산의 절반을 넘게 쓴 것**만 우리 탓으로 센다.
##
## 우리 계산이 3 밀리초인데 프레임이 20 밀리초면 남은 17 은 우리가 만든 것이 아니다.
## 이 구분이 없으면 다른 레인이 Godot 를 하나 더 띄우는 것만으로 우리 판정이 뒤집힌다.
func _report() -> void:
	var frames := _frame_ms.duplicate()
	var steps := _step_ms.duplicate()
	frames.sort()
	steps.sort()
	var over := 0
	var ours := 0
	for i in _frame_ms.size():
		if _frame_ms[i] <= _BUDGET:
			continue
		over += 1
		if _step_ms[i] > _BUDGET * 0.5:
			ours += 1
	print(
		(
			"| %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %d / %d | %d |"
			% [
				_counts[_index],
				_at(steps, 0.50),
				_at(steps, 0.95),
				_at(steps, 0.99),
				_at(steps, 1.0),
				_at(frames, 0.50),
				_at(frames, 0.95),
				_at(frames, 0.99),
				_at(frames, 1.0),
				over,
				_frame_ms.size(),
				ours,
			]
		)
	)


func _at(sorted: PackedFloat32Array, ratio: float) -> float:
	if sorted.is_empty():
		return 0.0
	var slot := int(round(ratio * float(sorted.size() - 1)))
	return sorted[clampi(slot, 0, sorted.size() - 1)]
