class_name RoomKindPlanner
extends RefCounted
## 방마다 종류와 이름을 정한다. 기준은 **필요 민첩과 입구로부터의 거리** 둘뿐이다
## (docs/design/07-level-design.md §7.2.8, §7.2.9).
##
## ## 값을 치러야 닿는다는 것의 두 가지 뜻
##
## | 종류 | 치르는 값 | 왜 |
## | --- | --- | --- |
## | 보스 · 귀중품 | **필요 민첩** | 능력이 올라야 손이 닿는다. 메트로배니아식 관문 (§7.2.6.1) |
## | 탈출구 | **거리** | 민첩 0 으로 닿아야 하지만(V2) 코앞에 있으면 안 된다 |
##
## 탈출구를 민첩으로 막을 수 없다는 것이 이 배치의 제약이다.
## 민첩 0 인 탈출구가 최소 하나 없으면 시작하자마자 진 판이 되기 때문이다.
## 그래서 탈출구의 대가는 거리로 받는다 — 판을 가로질러 걸어가야 한다.

## 종류별 방 이름 후보.
##
## 이름은 렉카 기사에 장소로 등장하므로 사실이어야 한다
## (docs/design/13-information-design.md §13.3.1). 종류와 어긋나면 기사가 판과
## 연결되지 않아 정보로서 무가치해진다.
const _NAMES_BY_KIND := {
	Room.Kind.ENTRANCE: ["입구 광장"],
	Room.Kind.EXIT: ["탈출 승강기", "비상 통로", "화물 리프트"],
	Room.Kind.TREASURE: ["봉인된 금고", "수장고", "유물 안치소", "밀실"],
	Room.Kind.BOSS: ["제단", "옥좌실", "심부"],
	Room.Kind.HAZARD: ["붕괴 구간", "가스 저장고", "함정 회랑"],
	Room.Kind.EMPTY: ["회랑", "저수조", "전시실", "계단참", "창고", "통신실", "중정"],
}


## 방 id -> Room.Kind.
static func plan(
	graph: DungeonGraph,
	entrance: String,
	exit_id: String,
	rng: RandomNumberGenerator,
	treasure_ratio: float,
	hazard_ratio: float
) -> Dictionary:
	var costs := graph.required_agility_from(entrance)
	var assignments := {entrance: Room.Kind.ENTRANCE}
	if not exit_id.is_empty() and exit_id != entrance:
		assignments[exit_id] = Room.Kind.EXIT

	var ranked := _by_cost_descending(graph, entrance, costs, assignments)
	_place_valuables(assignments, ranked, costs, treasure_ratio)
	_place_hazards(assignments, ranked, rng, hazard_ratio)
	return assignments


## 종류에 맞는 이름 하나. 같은 이름이 두 번 나오면 번호를 붙인다.
##
## 번호가 붙는 것을 감수하는 이유는, 이름이 겹치면 렉카 기사가 어느 방을 말하는지
## 알 수 없게 되기 때문이다.
static func pick_name(kind: Room.Kind, used: Dictionary, rng: RandomNumberGenerator) -> String:
	var pool: Array = _NAMES_BY_KIND[kind]
	var base: String = pool[rng.randi() % pool.size()]
	if not used.has(base):
		used[base] = 1
		return base
	used[base] = int(used[base]) + 1
	return "%s %d" % [base, int(used[base])]


## 아직 종류가 없는 방들을 필요 민첩 내림차순으로 세운다.
## 같은 값이면 입구에서 먼 쪽이 앞선다.
static func _by_cost_descending(
	graph: DungeonGraph, entrance: String, costs: Dictionary, assignments: Dictionary
) -> Array[String]:
	var hops := hops_from(graph, entrance)
	# 정렬 기준을 하나의 수로 미리 접어 둔다. 비교 함수 안에서 바깥 사전을 들여다보지
	# 않는 편이 안전하고, 같은 입력이면 언제나 같은 순서가 나온다 (§17.7).
	# 거리는 필요 민첩의 동점을 가르는 용도라 1000 으로 나눠 아래 자리에 넣는다.
	var entries: Array = []
	for id in graph.room_ids():
		if assignments.has(id):
			continue
		var cost := float(int(costs.get(id, 0)))
		var distance := float(int(hops.get(id, 0))) / 1000.0
		entries.append({"id": id, "key": cost + distance})
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) > float(b["key"])
	)
	var result: Array[String] = []
	for entry in entries:
		result.append(entry["id"])
	return result


## V3 — 보스와 귀중품은 **필요 민첩이 0 보다 큰 방에만** 놓는다.
##
## 0 인 방에 놓으면 기본 탈출구와 같은 값으로 닿게 되어 보상이 대가를 요구하지 않는다.
## 자격이 되는 방이 모자라면 그만큼만 놓는다. 억지로 채우면 규칙이 깨진다.
static func _place_valuables(
	assignments: Dictionary, ranked: Array[String], costs: Dictionary, treasure_ratio: float
) -> void:
	var budget := maxi(1, int(round(float(ranked.size()) * treasure_ratio)))
	var boss_placed := false
	for id in ranked:
		if int(costs.get(id, 0)) <= 0:
			break
		if not boss_placed:
			assignments[id] = Room.Kind.BOSS
			boss_placed = true
			continue
		if budget <= 0:
			break
		assignments[id] = Room.Kind.TREASURE
		budget -= 1


## 위험방은 남은 방에 흩뿌린다.
##
## 귀중품 옆에 몰아 두지 않는 이유는, 위험방의 존재 구성(작은 여럿)이
## 보스방(큰 하나)과 같은 합을 만들어야 인접 합이 모호해지기 때문이다 (§17.5 V6).
## 판 곳곳에 섞여 있어야 그 대조가 실제로 일어난다.
static func _place_hazards(
	assignments: Dictionary, ranked: Array[String], rng: RandomNumberGenerator, hazard_ratio: float
) -> void:
	for id in ranked:
		if assignments.has(id):
			continue
		if rng.randf() < hazard_ratio:
			assignments[id] = Room.Kind.HAZARD


## 시작 방에서 각 방까지의 **간선 수** 거리. 필요 민첩과는 다른 축의 값이다.
##
## 필요 민첩은 "능력이 되는가", 거리는 "몇 턴 걸리는가"를 말한다.
## 탈출구의 대가가 거리인 이유가 여기 있다 — 능력으로는 못 막고 시간으로 막는다.
static func hops_from(graph: DungeonGraph, start: String) -> Dictionary:
	if start.is_empty() or not graph.has_room(start):
		return {}
	var hops := {start: 0}
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		for neighbor in graph.neighbors_of(current):
			if hops.has(neighbor):
				continue
			hops[neighbor] = int(hops[current]) + 1
			frontier.append(neighbor)
	return hops
