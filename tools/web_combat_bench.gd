extends Node2D
## **전투 모양의 부하를 잰다.** 지금까지 잰 것은 "같은 편 여럿이 한 방향으로 간다"였다.
## 전투는 다르다 - **한 점으로 수렴하고, 목표를 스스로 고른다.**
##
## `web_frame_bench.gd` 와 같은 계기를 쓰되 판을 전투 모양으로 만든다.
## 판정선도 그대로 - **계산 95 분위가 예산의 절반(8.35 ms) 이하**, 그리고 넘친 프레임에서
## **우리 탓과 남의 탓을 가른다.**
##
## | 판 | 무엇을 재는가 |
## | --- | --- |
## | 수렴 | 두 편이 서로에게 몰려든다. 맞교차와 달리 **스쳐 지나가지 않고 한 점에 쌓인다** |
## | 큰 것 하나 | 넷이 큰 것 하나를 둘러싼다. 목표가 한 점이라 자리 다툼이 가장 심하다 |
## | **자동 타겟** | **유닛마다 제 목표를 고른다. 명령이 쪼개져 흐름장이 여러 벌 만들어진다** |
##
## **셋째가 진짜 위험이다.** 지금 구조는 명령 하나에 흐름장 하나이고 그것이 네이티브 8 ms,
## 웹에서 두세 배다. 자동 타겟팅으로 유닛마다 목표가 달라지면 **흐름장이 인원수만큼** 생긴다.
## RTS 기본 행동을 얹기 전에 그 값을 알아야 한다.

## 수렴 · 큰것하나 · 자동타겟
enum Shape { CONVERGE, GIANT, AUTO }

const _PROTO := "res://src/proto/unit_move/unit_move_proto.tscn"
const _FRAMES := 300
const _WARMUP := 60
const _BUDGET := 16.7
const _CEILING_RATIO := 0.5

## 편을 가르는 기준. 앞의 이만큼이 아군(스쿼드)이고 나머지가 몬스터다.
const _SQUAD := 4

## 목표를 다시 정하는 주기(프레임). 자동 이동이 목표를 갱신하는 것을 흉내 낸다.
const _RETARGET := 30

## 재는 판들. **작은 인원부터 올려 데운다** - 웹은 데워진 정도가 두 배를 만든다.
const _CASES: Array[Dictionary] = [
	{"name": "수렴 4 대 20", "shape": Shape.CONVERGE, "count": 24},
	{"name": "수렴 4 대 56", "shape": Shape.CONVERGE, "count": 60},
	{"name": "큰 것 하나 4 대 1", "shape": Shape.GIANT, "count": 5},
	{"name": "자동타겟 4 대 20", "shape": Shape.AUTO, "count": 24},
	{"name": "자동타겟 4 대 56", "shape": Shape.AUTO, "count": 60},
	{"name": "자동타겟 4 대 100", "shape": Shape.AUTO, "count": 104},
]

var _proto: Node2D
var _label: Label
var _index := -1
var _warmup := 0
var _turn := 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _step_ms: PackedFloat32Array = PackedFloat32Array()
var _lines := PackedStringArray()
var _orders := 0


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
	_emit("| 판 | 계산 중앙 | 계산 95 | 계산 최악 | 프레임 중앙 | 프레임 95 | 넘침 | 우리탓 | 명령 | 판정 |")
	_next()


func _process(delta: float) -> void:
	if _index >= _CASES.size():
		return
	if _warmup > 0:
		_warmup -= 1
		return
	_frame_ms.append(delta * 1000.0)
	var field: Object = _proto.get("field")
	_step_ms.append(0.0 if field == null else float(field.get("last_step_usec")) / 1000.0)
	_turn += 1
	_drive(field)
	if _frame_ms.size() >= _FRAMES:
		_record()
		_next()
	else:
		_show()


## 판 모양대로 명령을 낸다. **이것이 전투의 부하다.**
func _drive(field: Object) -> void:
	if field == null:
		return
	var shape: int = int(_CASES[_index]["shape"])
	if shape == Shape.AUTO:
		_drive_auto(field)
		return
	if _turn % _RETARGET != 0:
		return
	var squad := PackedInt32Array()
	var horde := PackedInt32Array()
	var agents: Array = field.get("agents")
	for i in agents.size():
		if i < _SQUAD:
			squad.append(agents[i].id)
		else:
			horde.append(agents[i].id)
	if squad.is_empty() or horde.is_empty():
		return
	if shape == Shape.GIANT:
		# 넷이 큰 것 하나를 둘러싼다. 큰 것은 안 움직인다.
		field.call("issue_move", squad, agents[agents.size() - 1].position)
		_orders += 1
		return
	# 두 편이 서로의 한가운데로 온다. 스쳐 지나가지 않고 한 점에 쌓인다.
	field.call("issue_move", squad, _center(field, horde))
	field.call("issue_move", horde, _center(field, squad))
	_orders += 2


## **유닛마다 제 목표를 고른다.** 자동 타겟팅과 자동 이동을 흉내 낸다.
##
## 명령이 쪼개지므로 **흐름장이 유닛 수만큼 만들어진다.** 한꺼번에 내면 한 프레임에
## 수십 벌을 굽게 되어 그것만으로 죽으므로, 실제 게임처럼 **유닛마다 시점을 어긋나게** 낸다.
func _drive_auto(field: Object) -> void:
	var agents: Array = field.get("agents")
	for i in agents.size():
		if (i + _turn) % _RETARGET != 0:
			continue
		var mine: Object = agents[i]
		var foe := _nearest_foe(agents, i)
		if foe == null:
			continue
		var one := PackedInt32Array()
		one.append(mine.id)
		field.call("issue_move", one, foe.position)
		_orders += 1


func _nearest_foe(agents: Array, index: int) -> Object:
	var friendly := index < _SQUAD
	var best: Object = null
	var closest := INF
	var mine: Object = agents[index]
	for i in agents.size():
		if (i < _SQUAD) == friendly:
			continue
		var distance: float = mine.position.distance_squared_to(agents[i].position)
		if distance < closest:
			closest = distance
			best = agents[i]
	return best


func _center(field: Object, ids: PackedInt32Array) -> Vector2:
	var total := Vector2.ZERO
	for id in ids:
		var agent: Object = field.call("agent_of", id)
		if agent != null:
			total += agent.position
	return total / maxf(float(ids.size()), 1.0)


func _next() -> void:
	_index += 1
	_show()
	if _index >= _CASES.size():
		_emit("측정 끝")
		return
	_frame_ms = PackedFloat32Array()
	_step_ms = PackedFloat32Array()
	_warmup = _WARMUP
	_turn = 0
	_orders = 0
	_proto.call("set_unit_count", int(_CASES[_index]["count"]))
	_proto.call("set_debug_visible", false)


## 넘친 프레임 중 **우리 계산이 예산의 절반을 넘게 쓴 것**만 우리 탓으로 센다.
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
	_emit(
		(
			"| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %d / %d | %d | %d | %s |"
			% [
				_CASES[_index]["name"],
				_at(steps, 0.50),
				_at(steps, 0.95),
				_at(steps, 1.0),
				_at(frames, 0.50),
				_at(frames, 0.95),
				over,
				_frame_ms.size(),
				ours,
				_orders,
				"통과" if _at(steps, 0.95) <= _BUDGET * _CEILING_RATIO else "초과",
			]
		)
	)


func _emit(line: String) -> void:
	_lines.append(line)
	print(line)


func _show() -> void:
	var text := "전투 부하 측정\n"
	if _index < _CASES.size():
		text += ("지금 %s (%d / %d)\n" % [_CASES[_index]["name"], _frame_ms.size(), _FRAMES])
	else:
		text += "끝났다\n"
	for line in _lines:
		text += line + "\n"
	_label.text = text


func _at(sorted: PackedFloat32Array, ratio: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(round(ratio * float(sorted.size() - 1))), 0, sorted.size() - 1)]
