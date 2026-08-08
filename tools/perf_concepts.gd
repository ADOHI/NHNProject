extends SceneTree
## 컨셉 다섯의 프레임 시간을 잰다.
##
##     godot --path . --resolution 1280x720 -s res://tools/perf_concepts.gd
##
## **기준선을 함께 잰다.** 이 기계는 레인 여럿이 Godot 를 돌려 오염되어 있어서,
## 절대값만 보면 우리 그리기가 무거운 것인지 외부 간섭인지 구별할 수 없다.
## 아무것도 안 그리는 화면을 **같은 실행 안에서** 재고 그 차이를 우리 비용으로 읽는다.
##
## 최악값 하나만 보지 않는다. 최악은 외부 간섭 한 번에 통째로 흔들리므로
## **95분위**를 함께 낸다 — 그게 사람이 체감하는 값이다.

const _CONCEPTS: Array[String] = ["slam", "shear", "hold", "squash", "afterimage"]

## 컨셉을 갈아 끼운 뒤 자리를 잡을 시간.
const _WARMUP := 50

const _SAMPLES := 320

var _stage: Node
var _phase := -1
var _frames := 0
var _deltas: Array[float] = []
var _process_times: Array[float] = []
var _draw_calls: Array[float] = []
var _rows: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.086, 0.086, 0.094)
	root.add_child(back)
	_stage = load("res://src/ui/kit/concept_stage.tscn").instantiate()
	root.add_child(_stage)


func _process(delta: float) -> bool:
	# `_initialize()` 안의 `add_child()` 는 `_ready()` 를 그 자리에서 부르지 않는다.
	# 첫 프레임에는 아무것도 건드리지 않는다 (20-ui-kit.md §20.4).
	if _phase < 0:
		_phase = 0
		_begin()
		return false

	_frames += 1
	if _frames <= _WARMUP:
		return false

	_deltas.append(delta)
	_process_times.append(Performance.get_monitor(Performance.TIME_PROCESS))
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _deltas.size() < _SAMPLES:
		return false

	_report()
	_phase += 1
	if _phase > _CONCEPTS.size():
		_print_table()
		return true
	_begin()
	return false


## 지금 재는 것을 화면에 세운다. 0 은 기준선(아무것도 안 그린다).
func _begin() -> void:
	_frames = 0
	_deltas.clear()
	_process_times.clear()
	_draw_calls.clear()
	if _phase == 0:
		_stage.set("visible", false)
		return
	_stage.set("visible", true)
	_stage.call("set_concept", _CONCEPTS[_phase - 1])


func _report() -> void:
	var name: String = "기준선(빈 화면)" if _phase == 0 else _CONCEPTS[_phase - 1].to_upper()
	(
		_rows
		. append(
			(
				"%-16s %s  |  process %s  |  draw calls %s"
				% [
					name,
					_stats_ms(_deltas),
					_stats_ms(_process_times),
					"%.0f" % _mean(_draw_calls),
				]
			)
		)
	)


func _stats_ms(values: Array[float]) -> String:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var count := sorted_values.size()
	var p95: float = sorted_values[mini(count - 1, int(float(count) * 0.95))]
	return (
		"avg %6.3fms  p95 %6.3fms  worst %6.3fms"
		% [_mean(values) * 1000.0, p95 * 1000.0, sorted_values[count - 1] * 1000.0]
	)


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(1.0, float(values.size()))


func _print_table() -> void:
	print("\n=== 컨셉 프레임 시간 (vsync 끔, %d표본, 1280x720) ===" % _SAMPLES)
	for row in _rows:
		print(row)
	print("\n=== 모션 계산 자체의 비용 (순수 함수 100k회) ===")
	_bench_motion()


## 모션 계산은 순수 함수라 따로 잴 수 있다. 그리기와 섞이지 않은 값이다.
func _bench_motion() -> void:
	var count := 100000
	for name in _CONCEPTS:
		var start := Time.get_ticks_usec()
		for i in range(count):
			var t := float(i) * 0.001
			match name:
				"shear":
					ShearMotion.evaluate(t, 0.3, true, 9.0, false, 3)
				"hold":
					HoldMotion.evaluate(t, 0.3, true, 9.0, false, 3)
				"squash":
					SquashMotion.evaluate(t, 0.3, true, 9.0, false, 3)
				"afterimage":
					AfterimageMotion.evaluate(t, 0.3, true, 9.0, false, 3)
				_:
					SlamMotion.evaluate(t, 0.3, true, 9.0, false, 3)
		var spent := float(Time.get_ticks_usec() - start) / 1000.0
		print(
			(
				"%-11s %8.1fms / %d회  =  %.4fms 1회  (판 셋이면 프레임당 %.4fms)"
				% [name.to_upper(), spent, count, spent / float(count), spent / float(count) * 3.0]
			)
		)
