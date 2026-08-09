extends Node2D
## **웹에서 던전 생성이 프레임을 먹는지 재는 장면.**
##
## 내보낸 웹 빌드는 `run/main_scene` 하나만 띄우고 `-s` 로 스크립트를 못 돌린다.
## 그래서 측정을 **장면**으로 옮겼다. 이동 레인이 같은 벽에 부딪혀 찾은 방법이다
## (`src/proto/unit_move/README.md` §22).
##
## **네이티브에서도 같은 장면을 돌려야 배수가 뜻을 가진다.** 같은 코드로 두 곳을 재야
## 렌더 경로와 스레드 차이만 남는다.
##
## ## 왜 던전 생성이 웹에서 위험한가
##
## 웹은 느린 것이 아니라 **꼬리가 나쁘다.** 이동 레인 실측에서 네이티브 대비 배수가
## 부하와 백분위를 따라 1.00 -> 1.38 -> 2.21 -> 3.76 으로 올랐다.
## **중앙값은 멀쩡한데 최악값이 무너진다.**
##
## 던전 생성은 **한 프레임에 몰아서 계산하는 일**이라 정확히 그 꼬리에 걸린다.
## 슬라이더를 움직일 때마다 한 판을 통째로 만들기 때문이다.
##
## ## 가장 무거운 조합으로 잰다
##
## 규모 5 • 복잡 3 • 험난 3. 곁가지를 늘리면 간선이 늘고, 단차를 올리면 고도 계산과
## 경로 시공이 무거워진다. 평균이 아니라 **최악을 알아야** 예산 판정이 된다.

## 몇 판을 만들어 볼지. 이동 레인이 웹에서 표본을 늘렸다가 wasm 메모리로 죽은 적이 있어
## 넉넉히 잡지 않는다.
const _SAMPLES := 120

## 처음 몇 판은 버린다. 첫 판은 스크립트 캐시와 셰이더 준비가 섞인다.
const _WARMUP := 20

## 한 프레임 예산 (60fps).
const _BUDGET := 16.7

## 잴 조합. [이름, 크기, 곁가지, 단차]
const _CASES := [
	["규모3 • 복잡2 • 험난2 (기본)", 3, 0.24, 2.0],
	["규모5 • 복잡3 • 험난3 (최악)", 5, 0.46, 5.0],
]

var _label: Label
var _case := 0
var _seen := 0
var _step_ms := PackedFloat32Array()
var _frame_ms := PackedFloat32Array()
var _last_frame_start := 0
var _lines := PackedStringArray()


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 15)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(_label)
	add_child(layer)
	_say("던전 생성 프레임 측정 — 표본 %d, 예열 %d" % [_SAMPLES, _WARMUP])
	_last_frame_start = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if _case >= _CASES.size():
		return

	var now := Time.get_ticks_usec()
	var frame := float(now - _last_frame_start) / 1000.0
	_last_frame_start = now

	var entry: Array = _CASES[_case]
	var params := DungeonGenerator.Params.new()
	params.room_count = 7 + int(entry[1]) * 5
	params.extra_edge_ratio = float(entry[2])
	params.elevation_gain = float(entry[3])

	var started := Time.get_ticks_usec()
	var blueprint := DungeonGenerator.new(_seen * 7919 + _case, params).generate()
	var step := float(Time.get_ticks_usec() - started) / 1000.0

	# 결과를 쓰지 않으면 최적화로 사라질 수 있다. 방 개수를 한 번 읽어 둔다.
	var rooms := blueprint.room_ids().size()
	_seen += 1
	if _seen > _WARMUP:
		_step_ms.append(step)
		_frame_ms.append(frame)
	if _seen % 20 == 0:
		_say("%s — %d/%d 판, 방 %d" % [entry[0], _seen, _SAMPLES + _WARMUP, rooms])
	if _seen >= _SAMPLES + _WARMUP:
		_report(String(entry[0]))
		_case += 1
		_seen = 0
		_step_ms = PackedFloat32Array()
		_frame_ms = PackedFloat32Array()
		if _case >= _CASES.size():
			_say("끝. 위 표를 읽으면 된다.")


## **행마다 즉시 낸다.** 마지막에 몰아서 내면 웹에서 안 끝났을 때 앞의 결과도 못 본다.
func _report(label: String) -> void:
	var steps := _sorted(_step_ms)
	var frames := _sorted(_frame_ms)
	var over := 0
	var ours := 0
	for index in _frame_ms.size():
		if _frame_ms[index] > _BUDGET:
			over += 1
			# 그 프레임에서 우리 계산이 예산의 절반을 넘었으면 우리 탓으로 센다.
			if _step_ms[index] > _BUDGET * 0.5:
				ours += 1

	_say(
		(
			"%s | 생성 중앙 %.2f 95 %.2f 최악 %.2f | 프레임 중앙 %.2f 95 %.2f | 넘침 %d/%d 그중 우리 %d"
			% [
				label,
				_at(steps, 0.50),
				_at(steps, 0.95),
				_at(steps, 1.0),
				_at(frames, 0.50),
				_at(frames, 0.95),
				over,
				_frame_ms.size(),
				ours,
			]
		)
	)


func _say(line: String) -> void:
	print(line)
	_lines.append(line)
	if _lines.size() > 14:
		_lines.remove_at(0)
	if _label != null:
		_label.text = "\n".join(_lines)


func _sorted(values: PackedFloat32Array) -> PackedFloat32Array:
	var copy := values.duplicate()
	copy.sort()
	return copy


func _at(sorted_values: PackedFloat32Array, ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		int(round(ratio * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1
	)
	return sorted_values[index]
