class_name DungeonGenerator
extends RefCounted
## 던전 절차 생성기. 설계는 docs/design/17-dungeon-generation.md 참고.
##
## 이 생성기의 어려움은 판을 만드는 쪽이 아니라 **못 쓸 판을 걸러내는 쪽**에 있다.
## 이 게임에서 던전은 이동 경로가 아니라 추리판이라, 도달만 되면 되는 게 아니라
## **모호함이 실제로 발생하는 판**이어야 한다 (§17.1).
##
## 생성은 시드를 받는다. 같은 시드는 같은 판을 만든다 (§17.7).
## 전역 난수를 쓰면 재현성이 깨지므로 RandomNumberGenerator 를 들고 다닌다.


## 생성 파라미터. 전부 잠정 수치이며 굴려 보고 정한다 (§17.8).
class Params:
	extends RefCounted

	## 고도 층 수. 층이 곧 난이도 계층이 된다.
	var layer_count := 5

	## 층당 방 개수의 하한과 상한.
	var rooms_per_layer_min := 2
	var rooms_per_layer_max := 3

	## 층 사이 고도 상승폭의 하한과 상한.
	var layer_climb_min := 1
	var layer_climb_max := 3

	## 척추 외에 추가로 시도할 간선 수의 배율 (방 개수 대비).
	var extra_edge_ratio := 0.6

	## 막다른 방(차수 1) 비율의 허용 범위.
	var dead_end_ratio_min := 0.1
	var dead_end_ratio_max := 0.45

	## 입구 인접 위험도 상한. 즉사 배치를 막는다.
	var entrance_threat_max := 4

	## 검증 실패 시 재시도 상한. 넘기면 파라미터를 완화한다.
	var max_attempts := 40


const _ROOM_NAMES_BY_KIND := {
	Room.Kind.ENTRANCE: ["입구 광장"],
	Room.Kind.EXIT: ["탈출 승강기", "비상 통로", "화물 리프트"],
	Room.Kind.TREASURE: ["봉인된 금고", "수장고", "유물 안치소", "밀실"],
	Room.Kind.BOSS: ["제단", "옥좌실", "심부"],
	Room.Kind.HAZARD: ["붕괴 구간", "가스 저장고", "함정 회랑"],
	Room.Kind.EMPTY: ["회랑", "저수조", "전시실", "계단참", "창고", "통신실", "중정"],
}

var _rng := RandomNumberGenerator.new()
var _params: Params


func _init(seed_value: int = 0, params: Params = null) -> void:
	_rng.seed = seed_value
	_params = params if params != null else Params.new()


## 검증을 통과한 설계도를 돌려준다.
##
## 상한까지 실패하면 파라미터를 완화해 다시 시도한다.
## 무한 루프는 웹 단일 스레드에서 화면을 얼린다 (§17.5).
func generate() -> DungeonBlueprint:
	for attempt in _params.max_attempts:
		var blueprint := _build_once()
		if _validate(blueprint):
			return blueprint
	# 완화: 연결을 늘려 도달성과 모호함을 모두 쉽게 만든다.
	_params.extra_edge_ratio += 0.4
	_params.dead_end_ratio_max = 1.0
	for attempt in _params.max_attempts:
		var blueprint := _build_once()
		if _validate(blueprint):
			return blueprint
	push_error("던전 생성에 실패했습니다. 파라미터를 확인하세요.")
	return _build_once()


# ---------------------------------------------------------------- 생성


func _build_once() -> DungeonBlueprint:
	var skeleton := DungeonBlueprint.new()
	var layers := _create_layers(skeleton)
	_connect_spine(skeleton, layers)
	_connect_extra(skeleton, layers)
	return _with_kinds(skeleton, layers)


## 층마다 방을 놓는다. 층이 올라갈수록 고도가 오른다.
func _create_layers(blueprint: DungeonBlueprint) -> Array:
	var layers: Array = []
	var elevation := 0
	var next_index := 0
	for layer_index in _params.layer_count:
		var count := _rng.randi_range(_params.rooms_per_layer_min, _params.rooms_per_layer_max)
		var layer: Array[String] = []
		for i in count:
			var id := "r%d" % next_index
			next_index += 1
			blueprint.add_room(id, id, elevation)
			layer.append(id)
		layers.append(layer)
		elevation += _rng.randi_range(_params.layer_climb_min, _params.layer_climb_max)
	return layers


## 입구 층에서 최상층까지 이어지는 경로를 먼저 보장한다.
##
## 무작위로 잇고 나서 도달성을 검사하면 대부분 실패해 재시도가 폭증한다.
## 성립하는 뼈대를 먼저 놓고 살을 붙이면 검증은 거의 통과한다 (§17.3).
func _connect_spine(blueprint: DungeonBlueprint, layers: Array) -> void:
	for i in range(layers.size() - 1):
		var lower: Array[String] = layers[i]
		var upper: Array[String] = layers[i + 1]
		# 층마다 최소 하나는 위층과 이어져야 위로 가는 길이 끊기지 않는다.
		blueprint.connect_rooms(
			lower[_rng.randi() % lower.size()], upper[_rng.randi() % upper.size()]
		)
		# 같은 층 안도 이어 둔다. 층이 조각나면 옆방으로 못 간다.
		for j in range(lower.size() - 1):
			blueprint.connect_rooms(lower[j], lower[j + 1])
	var top: Array[String] = layers[layers.size() - 1]
	for j in range(top.size() - 1):
		blueprint.connect_rooms(top[j], top[j + 1])


## 곁가지를 붙인다. 차수가 올라갈수록 인접 합이 뭉쳐 추리가 어려워진다 (§17.2).
func _connect_extra(blueprint: DungeonBlueprint, layers: Array) -> void:
	var ids := blueprint.room_ids()
	var target := int(float(ids.size()) * _params.extra_edge_ratio)
	for i in target:
		var layer_index := _rng.randi() % layers.size()
		var lower: Array[String] = layers[layer_index]
		var upper: Array[String] = layers[mini(layer_index + 1, layers.size() - 1)]
		var a: String = lower[_rng.randi() % lower.size()]
		var b: String = upper[_rng.randi() % upper.size()]
		if a != b:
			blueprint.connect_rooms(a, b)


## 뼈대에 방 종류와 이름을 입힌 **새 설계도**를 만든다.
##
## 기존 설계도를 고치지 않고 새로 만드는 이유는, DungeonBlueprint 에
## "나중에 방을 수정하는" 경로를 열지 않기 위해서다.
## 그 경로가 생기면 어떤 값이 언제 확정되는지가 흐려진다.
func _with_kinds(skeleton: DungeonBlueprint, layers: Array) -> DungeonBlueprint:
	var entrance: String = (layers[0] as Array[String])[0]
	var assignments := _assign_kinds(skeleton, entrance)

	var result := DungeonBlueprint.new()
	var used_names := {}
	for id in skeleton.room_ids():
		var kind: Room.Kind = assignments.get(id, Room.Kind.EMPTY)
		result.add_room(id, _pick_name(kind, used_names), skeleton.elevation_of(id), kind)
	for pair in skeleton.connections():
		result.connect_rooms(pair[0], pair[1])
	return result


## 필요 민첩 등급에 따라 방 종류를 정한다. 방 id -> Room.Kind.
##
## 고가치일수록 접근이 어려워야 하므로 등급이 높은 방부터 보스·귀중품을 놓고,
## **가장 싸게 닿는 방을 기본 탈출구로** 삼아 V2 를 구조적으로 보장한다 (§17.5).
func _assign_kinds(skeleton: DungeonBlueprint, entrance: String) -> Dictionary:
	var graph := skeleton.build()
	var costs := graph.required_agility_from(entrance)

	var ranked := skeleton.room_ids()
	ranked.erase(entrance)
	ranked.sort_custom(
		func(a: String, b: String) -> bool: return costs.get(a, 999) < costs.get(b, 999)
	)

	var assignments := {entrance: Room.Kind.ENTRANCE}
	if ranked.is_empty():
		return assignments
	assignments[ranked[0]] = Room.Kind.EXIT

	var expensive := ranked.duplicate()
	expensive.reverse()
	var boss_placed := false
	var treasure_budget := maxi(1, ranked.size() / 4)
	for id in expensive:
		if assignments.has(id):
			continue
		if not boss_placed:
			assignments[id] = Room.Kind.BOSS
			boss_placed = true
		elif treasure_budget > 0:
			assignments[id] = Room.Kind.TREASURE
			treasure_budget -= 1
		else:
			break

	for id in ranked:
		if not assignments.has(id) and _rng.randf() < 0.2:
			assignments[id] = Room.Kind.HAZARD
	return assignments


func _pick_name(kind: Room.Kind, used_names: Dictionary) -> String:
	var pool: Array = _ROOM_NAMES_BY_KIND[kind]
	var base: String = pool[_rng.randi() % pool.size()]
	if not used_names.has(base):
		used_names[base] = 1
		return base
	used_names[base] += 1
	return "%s %d" % [base, used_names[base]]


# ---------------------------------------------------------------- 검증


## 검증 규칙을 전부 통과해야 채택한다 (§17.5).
##
## 규칙을 함수로 나눈 이유는, 실패한 규칙을 특정할 수 있어야 하고
## 규칙이 늘어날 때 이 함수가 계속 길어지지 않게 하기 위해서다.
func _validate(blueprint: DungeonBlueprint) -> bool:
	var entrances := blueprint.rooms_of_kind(Room.Kind.ENTRANCE)
	if entrances.size() != 1:
		return false
	var entrance: String = entrances[0]
	var graph := blueprint.build()
	var costs := graph.required_agility_from(entrance)
	return (
		_check_all_reachable(blueprint, costs)
		and _check_free_exit(blueprint, costs)
		and _check_valuables_cost(blueprint, costs)
		and _check_entrance_has_choice(graph, entrance)
		and _check_dead_end_ratio(blueprint, graph)
	)


## V1 — 고립된 방은 존재하지 않는 것과 같다.
func _check_all_reachable(blueprint: DungeonBlueprint, costs: Dictionary) -> bool:
	return costs.size() == blueprint.room_ids().size()


## V2 — 민첩 0 으로 닿는 탈출구가 최소 하나. 없으면 시작하자마자 진 판이다.
func _check_free_exit(blueprint: DungeonBlueprint, costs: Dictionary) -> bool:
	for id in blueprint.rooms_of_kind(Room.Kind.EXIT):
		if costs.get(id, 999) == 0:
			return true
	return false


## V3 — 보상은 대가를 요구해야 한다.
func _check_valuables_cost(blueprint: DungeonBlueprint, costs: Dictionary) -> bool:
	var valuables := (
		blueprint.rooms_of_kind(Room.Kind.TREASURE) + blueprint.rooms_of_kind(Room.Kind.BOSS)
	)
	for id in valuables:
		if costs.get(id, 0) <= 0:
			return false
	return true


## V7 — 입구에는 갈림길이 있어야 한다.
##
## 차수가 1 이면 첫 턴에 선택이 없다. 규칙상으로는 멀쩡한 판이지만
## 플레이어에게는 "누를 수 있는 버튼이 하나뿐인 화면"이라 게임이 시작되지 않는다.
func _check_entrance_has_choice(graph: DungeonGraph, entrance: String) -> bool:
	return graph.neighbors_of(entrance).size() >= 2


## V5 — 막다른 방 비율.
##
## 너무 많으면 정보가 다 새고, 없으면 인접 합이 전부 뭉쳐 못 읽는다 (§17.2).
func _check_dead_end_ratio(blueprint: DungeonBlueprint, graph: DungeonGraph) -> bool:
	var dead_ends := 0
	for id in blueprint.room_ids():
		if graph.neighbors_of(id).size() <= 1:
			dead_ends += 1
	var ratio := float(dead_ends) / float(blueprint.room_ids().size())
	return ratio >= _params.dead_end_ratio_min and ratio <= _params.dead_end_ratio_max
