extends Node2D
## **웹에서 프레임 예산을 재는 장면.** `bench_frame_budget.gd` 와 같은 것을 재지만
## `SceneTree` 스크립트가 아니라 **장면**이다.
##
## 내보낸 웹 빌드는 `run/main_scene` 하나만 띄우고 `-s` 로 스크립트를 돌릴 수 없다.
## 그래서 같은 측정을 장면으로 옮겼다. 결과는 화면과 콘솔에 함께 낸다 -
## 브라우저에서는 콘솔이 확실하고, 화면은 사람이 바로 볼 수 있다.
##
## **네이티브에서도 같은 장면을 돌려야 배수가 뜻을 가진다.** 같은 코드로 두 곳을 재야
## 렌더 경로와 스레드 차이만 남는다.

const _PROTO := "res://src/proto/unit_move/unit_move_proto.tscn"
const _FRAMES := 600
const _WARMUP := 60
const _BUDGET := 16.7
const _COUNTS: Array[int] = [40, 100, 200]

var _proto: Node2D
var _label: Label
var _index := -1
var _warmup := 0
var _turn := 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _step_ms: PackedFloat32Array = PackedFloat32Array()
var _lines := PackedStringArray()


func _ready() -> void:
	_proto = load(_PROTO).instantiate()
	add_child(_proto)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 15)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(_label)
	add_child(layer)
	_lines.append("| 인원 | 계산 중앙 | 계산 95 | 계산 최악 | 프레임 중앙 | 프레임 95 | 프레임 99 | 넘침 | 우리탓 |")
	_next()


func _process(delta: float) -> void:
	if _index >= _COUNTS.size():
		return
	if _warmup > 0:
		_warmup -= 1
		return
	_frame_ms.append(delta * 1000.0)
	var field: Object = _proto.get("field")
	_step_ms.append(0.0 if field == null else float(field.get("last_step_usec")) / 1000.0)
	_turn += 1
	if _turn % 90 == 0:
		var target := Vector2(1500.0, 550.0) if _turn % 180 == 0 else Vector2(260.0, 550.0)
		_proto.call("select_all")
		_proto.call("order_move_at", target)
	if _frame_ms.size() >= _FRAMES:
		_record()
		_next()
	else:
		_show()


func _next() -> void:
	_index += 1
	_show()
	if _index >= _COUNTS.size():
		for line in _lines:
			print(line)
		return
	_frame_ms = PackedFloat32Array()
	_step_ms = PackedFloat32Array()
	_warmup = _WARMUP
	_turn = 0
	_proto.call("set_unit_count", _COUNTS[_index])
	_proto.call("set_debug_visible", false)
	_proto.call("select_all")
	_proto.call("order_move_at", Vector2(1500.0, 550.0))


## 넘친 프레임 중 **우리 계산이 예산의 절반을 넘게 쓴 것**만 우리 탓으로 센다.
##
## 우리 계산이 4 밀리초인데 프레임이 26 밀리초면 남은 22 는 우리가 만든 것이 아니다.
## 브라우저는 네이티브보다 간섭이 더 심할 수 있어 웹에서 이 구분이 더 중요하다.
func _record() -> void:
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
	(
		_lines
		. append(
			(
				"| %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %d / %d | %d |"
				% [
					_COUNTS[_index],
					_at(steps, 0.50),
					_at(steps, 0.95),
					_at(steps, 1.0),
					_at(frames, 0.50),
					_at(frames, 0.95),
					_at(frames, 0.99),
					over,
					_frame_ms.size(),
					ours,
				]
			)
		)
	)


func _show() -> void:
	var text := "프레임 예산 측정\n"
	if _index < _COUNTS.size():
		text += "지금 %d 명 재는 중 (%d / %d)\n" % [_COUNTS[_index], _frame_ms.size(), _FRAMES]
	else:
		text += "끝났다\n"
	for line in _lines:
		text += line + "\n"
	_label.text = text


func _at(sorted: PackedFloat32Array, ratio: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(round(ratio * float(sorted.size() - 1))), 0, sorted.size() - 1)]
