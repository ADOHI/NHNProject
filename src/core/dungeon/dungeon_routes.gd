class_name DungeonRoutes
extends RefCounted
## 입구에서 **보스까지 가는 두 길** — 지름길과 우회로.
##
## 이 판이 "짧고 가파른 길과 길고 완만한 길로 갈리는가"를 재는 자다.
## 그 갈림이 **험난 축이 화면에서 판정되는 유일한 자리**다
## (docs/design/17-dungeon-generation.md §17.27.1).
##
## | 이름 | 정의 |
## | --- | --- |
## | 지름길 | 입구에서 보스까지 **칸 수가 가장 적은 길** (너비 우선) |
## | 우회로 | 지름길이 쓴 간선을 **전부 뺀 판**에서 다시 구한 최단 길 |
## | 최대 오름 | 그 길 위에서 **한 걸음에 오르는 상승폭의 최댓값** |
##
## **최대 오름은 합이 아니다.** 막는 것은 총량이 아니라 가장 높은 한 단이라서,
## 이 값이 곧 그 길에 필요한 민첩이다 (docs/design/07-level-design.md §7.2.8).
##
## ## 계측기와 같은 정의를 두 번 구현했다
##
## `tools/dungeon_metrics.gd` 가 같은 계산을 색인 기반으로 갖고 있다. 그쪽은 설계안
## 프로토타입 판도 재야 해서 `DungeonBlueprint` 를 요구할 수 없고, 화면은 반대로
## 설계도밖에 없다. 그리고 그 파일은 `class_name` 을 일부러 안 붙였다 —
## **게임은 `tools/` 를 몰라야 한다**(docs/conventions.md §3.1).
##
## **그래서 둘로 두되 테스트가 묶는다** — `test/unit/test_dungeon_routes.gd` 가 같은 판을
## 두 자로 재서 길이와 최대 오름이 같은지 본다. 한쪽만 고치면 그 테스트가 깨진다.


## 설계도를 재서 두 길과 그 성질을 돌려준다.
##
## 돌려주는 사전의 키는 **언제나 같다.** 호출하는 쪽이 `has()` 를 흩뿌리지 않도록
## 없는 것은 빈 배열과 0 으로 나타낸다.
##
## | 키 | 뜻 |
## | --- | --- |
## | `entrance` • `boss` | 두 끝. 보스가 없으면 `boss` 가 빈 문자열이다 |
## | `shortcut` • `detour` | 방 id 를 입구부터 보스까지 늘어놓은 배열 |
## | `shortcut_length` • `detour_length` | **칸 수**(간선 수). 방 개수보다 하나 적다 |
## | `shortcut_climb` • `detour_climb` | 그 길의 최대 오름 |
##
## 보스가 없으면 두 길 다 비어 있고, 지름길 간선을 빼면 보스가 끊기는 외길 판에서는
## `detour` 만 비어 있다. **둘을 구분해야 화면이 다르게 말할 수 있다** (§17.27.6).
static func to_boss(blueprint: DungeonBlueprint) -> Dictionary:
	var result := {
		"entrance": entrance_of(blueprint),
		"boss": boss_of(blueprint),
		"shortcut": [] as Array[String],
		"detour": [] as Array[String],
		"shortcut_length": 0,
		"detour_length": 0,
		"shortcut_climb": 0,
		"detour_climb": 0,
	}
	var entrance: String = result["entrance"]
	var boss: String = result["boss"]
	if entrance.is_empty() or boss.is_empty() or entrance == boss:
		return result

	var edges := blueprint.connections()
	var shortcut := shortest_route(edges, entrance, boss)
	if shortcut.size() < 2:
		return result
	result["shortcut"] = shortcut
	result["shortcut_length"] = shortcut.size() - 1
	result["shortcut_climb"] = climb_of(blueprint, shortcut)

	var detour := shortest_route(_without(edges, shortcut), entrance, boss)
	if detour.size() < 2:
		return result
	result["detour"] = detour
	result["detour_length"] = detour.size() - 1
	result["detour_climb"] = climb_of(blueprint, detour)
	return result


## 이 판의 입구. 없으면 첫 방을 쓴다.
##
## 첫 방으로 물러나는 것은 `SampleDungeons` 와 `tools/dungeon_metrics.gd` 가 이미 하는
## 처리라 여기서도 같게 둔다. **셋이 다른 방을 입구로 치면 같은 판이 다르게 재진다.**
static func entrance_of(blueprint: DungeonBlueprint) -> String:
	var entrances := blueprint.rooms_of_kind(Room.Kind.ENTRANCE)
	if not entrances.is_empty():
		return entrances[0]
	var ids := blueprint.room_ids()
	return "" if ids.is_empty() else ids[0]


## 이 판의 보스 방. 없으면 빈 문자열.
##
## 생성기는 보스를 하나만 놓는다(`RoomKindPlanner`). 둘 이상이면 첫 번째를 쓴다 —
## 계측기가 첫 번째부터 도는 것과 같은 순서다.
static func boss_of(blueprint: DungeonBlueprint) -> String:
	var bosses := blueprint.rooms_of_kind(Room.Kind.BOSS)
	return "" if bosses.is_empty() else bosses[0]


## 두 방을 잇는 **칸 수 최단 경로**. 못 가면 빈 배열.
##
## 고도를 보지 않는다. 여기서 구하는 것은 "몇 칸인가"이고, "오를 수 있는가"는
## `climb_of` 가 따로 잰다. **둘을 한 번에 구하면 두 길이 갈리는 이유가 사라진다** —
## 지름길은 못 오를 수 있어야 우회로가 뜻을 갖는다.
static func shortest_route(edges: Array[Array], from_id: String, to_id: String) -> Array[String]:
	var route: Array[String] = []
	if from_id.is_empty() or to_id.is_empty():
		return route

	var neighbors := _adjacency(edges)
	var parent := {from_id: ""}
	var frontier: Array[String] = [from_id]
	while not frontier.is_empty():
		var current: String = frontier.pop_front()
		if current == to_id:
			break
		if not neighbors.has(current):
			continue
		for neighbor in neighbors[current] as Array[String]:
			if parent.has(neighbor):
				continue
			parent[neighbor] = current
			frontier.append(neighbor)

	if not parent.has(to_id):
		return route
	var walk: String = to_id
	while not walk.is_empty():
		route.append(walk)
		walk = parent[walk]
	route.reverse()
	return route


## 그 길에서 **한 걸음에 오르는 상승폭의 최댓값.**
##
## 내려가는 것은 언제나 자유이므로 음수는 0 으로 자른다
## (docs/design/07-level-design.md §7.2.6).
static func climb_of(blueprint: DungeonBlueprint, route: Array[String]) -> int:
	var climb := 0
	for index in range(1, route.size()):
		var step := blueprint.elevation_of(route[index]) - blueprint.elevation_of(route[index - 1])
		climb = maxi(climb, step)
	return climb


## 그 간선이 길 위에 놓여 있는가. 방향은 보지 않는다.
static func route_uses(route: Array[String], a_id: String, b_id: String) -> bool:
	for index in range(1, route.size()):
		var previous: String = route[index - 1]
		var current: String = route[index]
		if (a_id == previous and b_id == current) or (a_id == current and b_id == previous):
			return true
	return false


## 길이 쓴 간선을 뺀 나머지.
static func _without(edges: Array[Array], route: Array[String]) -> Array[Array]:
	var rest: Array[Array] = []
	for pair in edges:
		if not route_uses(route, pair[0], pair[1]):
			rest.append(pair)
	return rest


## 인접 목록. **간선이 적힌 순서를 그대로 따른다.**
##
## 너비 우선은 같은 길이의 경로가 여럿일 때 먼저 만난 것을 고른다. 그래서 이웃의
## 순서가 결과를 가른다. `tools/dungeon_metrics.gd` 도 간선 순서대로 쌓으므로
## **두 자가 같은 길을 고른다** — 이것이 어긋나면 두 계측이 조용히 갈린다.
static func _adjacency(edges: Array[Array]) -> Dictionary:
	var result := {}
	for pair in edges:
		var a: String = pair[0]
		var b: String = pair[1]
		if not result.has(a):
			result[a] = [] as Array[String]
		if not result.has(b):
			result[b] = [] as Array[String]
		(result[a] as Array[String]).append(b)
		(result[b] as Array[String]).append(a)
	return result
