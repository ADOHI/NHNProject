class_name DungeonZones
extends RefCounted
## 방들을 **구역**으로 나누고 구역끼리 어떻게 이을지 정한다.
##
## 지금 판이 「유기적이지 않다」고 읽히는 이유는 축척이 하나뿐이기 때문이다.
## 어느 방에 서도 서너 갈래고 어느 갈래로 가도 비슷한 곳이 나온다 — 균질한 그물망이다
## (docs/design/17-dungeon-generation.md §17.11.7).
##
## 구역은 **성김과 촘촘함을 다른 축척에 둔다.**
##
## | 축척 | 규칙 | 결과 |
## | --- | --- | --- |
## | 구역 **안** | 촘촘하게 잇는다 (RNG∪MST + 가브리엘 곁가지) | 갈림길이 유지된다 |
## | 구역 **사이** | 가장 짧은 들로네 간선 **하나씩만** | 거시 구조가 성기다 — 관문이 된다 |
##
## ## 왜 나무가 아니라 고리인가
##
## 구역을 나무로 이으면 어느 목적지든 통로가 하나뿐이라 **「돌아가는 길」이 원리적으로 없다.**
## 프로토타입을 나무로 먼저 만들었더니 보스 방에 대안 경로가 있는 판이 8~42% 였고,
## 보상 구역에만 고리를 덧대도 마찬가지였다 — **입구 구역이 그 고리 위에 없으면**
## 두 경로가 앞부분을 공유해 결국 한 길이기 때문이다 (§17.12.4-B).
##
## 고리로 만들면 입구가 반드시 고리 위에 있고 어느 구역으로 가든 좌우 두 방향이 생긴다.
## **거시 순환 계수가 정확히 1 이다** — 간선 몇 개로 대안 경로를 얻는 가장 싼 방법이다.
##
## ## 이 파일은 좌표만 안다
##
## 방 종류도 고도도 모른다. 자리와 들로네 간선만 받아 구역 번호를 돌려준다.
## 그래서 순서상 어디에 끼워도 되고, 테스트가 다른 단계에 의존하지 않는다.

## 구역 하나가 담을 방의 대략적인 수.
##
## 작을수록 관문이 늘어 판이 길어진다. 6 은 프로토타입 실측에서 방 50개짜리 판의
## 지름이 11.5 -> 14.4 로 늘어난 값이다 (§17.12.7).
const ROOMS_PER_ZONE := 6.0

## 구역 개수의 범위.
##
## 셋 아래로는 고리가 만들어지지 않는다(두 구역을 고리로 이으면 같은 관문을 두 번 쓴다).
## 여덟 위로는 구역이 너무 작아져 구역 안에 갈림길이 남지 않는다.
const ZONE_MIN := 3
const ZONE_MAX := 8

## 통로가 상관없는 방에서 떨어져 있어야 하는 최소 거리 (방 사이 최소 간격 1 기준).
##
## **관문 때문에 이 값이 필요해졌다.** 관문은 구역 경계를 넘는 간선 하나인데, 후보 중
## 가장 짧은 것을 골랐더니 그 선이 제3의 방을 24 px 앞까지 스쳤다(기준 84 px).
## 짧은 것이 곧 깨끗한 것은 아니다 — 짧아도 옆에 방이 붙어 있으면 선이 그 방을 지난다.
##
## **기준은 방 위젯의 대각 반지름이다.** 146x76 위젯이면 82.3 px 이고, 화면 간격 240 에서
## 0.343 이다. 그보다 멀어야 어느 방향에서 와도 통로가 위젯에 닿지 않는다.
##
## 예전에는 "테스트 기준 0.3 에 여유를 둔 0.35" 라고 적어 뒀는데, 그 0.3 은
## **간격 280 시절의 낡은 자**였다. 간격이 240 으로 내려가면서 0.3 은 72 px 이 되어
## 위젯 가로 반너비 73 px 도 못 덮었고, 0.35 가 남기는 여유는 1.7 px 이었다.
##
## 0.38 이면 여유가 8.9 px 이다. 실측에서 판의 모양은 거의 안 변하고
## (순환 11.8, 지름 10.6 그대로) 보스 방 차수만 3.98 -> 4.05 로 올랐다.
## 더 올리면(0.42) 후보가 줄어 기본 민첩으로 닿는 방이 87.5% -> 84.7% 로 준다.
const CLEARANCE_MIN := 0.38


## 방 개수에 맞는 구역 수.
static func count_for(rooms: int) -> int:
	return clampi(int(round(float(rooms) / ROOMS_PER_ZONE)), ZONE_MIN, ZONE_MAX)


## 방마다 구역 번호를 매긴다. 결과의 크기는 방 개수와 같다.
##
## **입구를 첫 씨앗으로 하는 최원점 샘플링**으로 씨앗을 고르고, 각 방을 가장 가까운
## 씨앗에 붙인다. 무작위 씨앗을 쓰면 구역 크기가 들쭉날쭉해지는데, 최원점 샘플링은
## 씨앗끼리 최대한 떨어뜨리므로 구역이 고르게 나뉜다.
##
## 입구가 첫 씨앗인 것이 중요하다 — 입구 구역이 언제나 존재하고 등급 0 이 된다.
static func assign(points: PackedVector2Array, entrance: int, wanted: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if points.is_empty():
		return result
	var total := clampi(wanted, 1, points.size())
	var seeds := _seeds(points, entrance, total)

	result.resize(points.size())
	for index in points.size():
		var best := 0
		var best_distance := INF
		for slot in seeds.size():
			var distance := points[seeds[slot]].distance_squared_to(points[index])
			if distance < best_distance:
				best_distance = distance
				best = slot
		result[index] = best
	return result


## 씨앗 방들. 첫 씨앗은 입구이고, 그다음부터는 이미 고른 씨앗들에서 가장 먼 방이다.
static func _seeds(points: PackedVector2Array, entrance: int, wanted: int) -> Array[int]:
	var result: Array[int] = [clampi(entrance, 0, points.size() - 1)]
	while result.size() < wanted:
		var best := -1
		var best_distance := -1.0
		for index in points.size():
			if result.has(index):
				continue
			var nearest := INF
			for seed_index in result:
				nearest = minf(nearest, points[seed_index].distance_squared_to(points[index]))
			if nearest > best_distance:
				best_distance = nearest
				best = index
		if best < 0:
			break
		result.append(best)
	return result


## 서로 다른 구역을 잇는 들로네 간선들. 키는 구역 쌍 Vector2i(작은 번호, 큰 번호).
##
## 같은 구역 안의 간선은 담지 않는다. 여기 담긴 것만이 관문 후보다.
static func boundaries(delaunay: Array[Vector2i], zones: PackedInt32Array) -> Dictionary:
	var result := {}
	for edge in delaunay:
		if edge.x < 0 or edge.y < 0 or edge.x >= zones.size() or edge.y >= zones.size():
			push_error("구역 배정 밖의 간선입니다: %s (방 %d개)" % [edge, zones.size()])
			continue
		var a := zones[edge.x]
		var b := zones[edge.y]
		if a == b:
			continue
		var key := Vector2i(mini(a, b), maxi(a, b))
		if not result.has(key):
			result[key] = [] as Array[Vector2i]
		(result[key] as Array[Vector2i]).append(edge)
	return result


## 그릴 수 있는 경계만 남긴 것. **고리와 관문은 이걸 써야 한다.**
##
## 관문을 「후보 중 여유가 가장 큰 것」으로 물러나게 했더니 여전히 방을 스쳤다.
## 이유는 그 구역 쌍의 **모든** 경계 간선이 방을 스치기 때문이었다(최대 여유 0.11, 기준 0.35).
## 고를 수 있는 것 중 최선을 골라도 최선이 나쁘면 결과가 나쁘다.
##
## 그래서 **고를 때 물러나는 대신 애초에 후보에서 뺀다.** 그리기 어려운 경계를 가진 구역 쌍은
## 이어질 수 없는 쌍이 되고, 고리는 그 쌍을 우회해 다른 쪽으로 돈다.
##
## 이렇게 해서 구역 그래프가 갈라지면 어떻게 되는가 — **방 단위 연결은 그대로 보장된다.**
## `DungeonEdgeSelector` 의 수선이 방 단위로 도달성을 마감하기 때문이다 (V1).
## 잃는 것은 「입구가 순환 위에 있다」가 약해지는 것뿐이고, 그건 덩어리 4 의 경로 시공이
## 구역 안에서 메운다.
static func readable_boundaries(
	points: PackedVector2Array, delaunay: Array[Vector2i], zones: PackedInt32Array
) -> Dictionary:
	var result := {}
	var raw := boundaries(delaunay, zones)
	for key in raw:
		var kept: Array[Vector2i] = []
		for edge in raw[key] as Array[Vector2i]:
			if clearance(points, edge) >= CLEARANCE_MIN:
				kept.append(edge)
		if not kept.is_empty():
			result[key] = kept
	return result


## 구역을 잇는 방식. **고리다.** 돌려주는 것은 구역 쌍의 목록이다.
##
## 구역 중심을 판의 무게중심 기준 각도 순으로 세워 이웃끼리 잇는다.
## 각도 순이라 고리가 판을 한 바퀴 돌고, 관문이 판을 가로지르지 않는다.
##
## 각도 순으로 이웃이 된 두 구역이 실제로 맞닿아 있지 않을 수 있다(들로네에 그 쌍이 없다).
## 그때는 그 연결을 건너뛰므로 **고리가 저절로 닫히지 않는다.**
##
## **테스트가 이걸 잡았다** — 구역 8개에서 연결이 7개, 즉 나무가 나왔다.
## 각도 고리만으로는 순환이 보장되지 않는다. 그래서 세 단계로 만든다.
##
## | 단계 | 하는 일 |
## | --- | --- |
## | 1 | 각도 순 이웃끼리 잇는다 (맞닿아 있는 쌍만) |
## | 2 | 남은 쌍으로 **연결성**을 채운다 (V1 — 갈라진 판이 나오지 않는다) |
## | 3 | **입구 구역이 순환 위에 없으면** 순환을 만드는 쌍을 하나 더 잇는다 |
##
## 3단계가 핵심이다. 순환이 어딘가 있는 것으로는 모자라고 **입구가 그 위에 있어야** 한다 —
## 입구가 순환 밖이면 두 경로가 앞부분을 공유해 결국 한 길이 된다 (§17.12.4-B).
##
## 입구 구역이 맞닿은 구역이 하나뿐이면 순환을 만들 수 없다. 그때는 연결만 보장하고
## 물러난다 — 두 경로는 덩어리 4 의 경로 시공이 구역 **안**에서 만든다.
static func ring(
	points: PackedVector2Array,
	zones: PackedInt32Array,
	zone_boundaries: Dictionary,
	count: int,
	entrance_zone: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count < 2:
		return result
	var order := _angular_order(centers(points, zones, count), count)

	for slot in count:
		var a: int = order[slot]
		var b: int = order[(slot + 1) % count]
		if a == b:
			continue
		var key := Vector2i(mini(a, b), maxi(a, b))
		if zone_boundaries.has(key) and not result.has(key):
			result.append(key)

	# 각도 순서가 맞닿지 않는 쌍을 만들었으면 남은 쌍으로 연결만 채운다.
	var parent: Array[int] = []
	for index in count:
		parent.append(index)
	for key in result:
		_union(parent, key.x, key.y)
	var pending: Array[Vector2i] = []
	for key in zone_boundaries:
		pending.append(key)
	pending.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a.x, a.y).length_squared() < Vector2(b.x, b.y).length_squared()
	)
	for key in pending:
		if _union(parent, key.x, key.y):
			result.append(key)

	return _close_cycle(points, zone_boundaries, result, pending, count, entrance_zone)


## 입구 구역이 순환 위에 오도록 연결 하나를 더 잇는다. 이미 순환 위면 그대로 둔다.
##
## 어떤 쌍 (a, b) 를 이으면 입구를 지나는 순환이 생기는가 —
## **입구를 지웠을 때 a 와 b 가 서로 끊어지는 쌍**이다. 그 둘을 이으면 원래 입구를
## 거쳐 가던 길에 우회로가 생기므로 입구가 순환 위에 놓인다.
##
## 후보가 여럿이면 관문이 가장 짧은 것을 고른다. 긴 관문은 판을 가로질러 읽히지 않는다.
static func _close_cycle(
	points: PackedVector2Array,
	zone_boundaries: Dictionary,
	links: Array[Vector2i],
	candidates: Array[Vector2i],
	count: int,
	entrance_zone: int
) -> Array[Vector2i]:
	if entrance_zone < 0 or entrance_zone >= count:
		return links
	if _on_cycle(links, count, entrance_zone):
		return links

	var best := Vector2i(-1, -1)
	var best_length := INF
	for key in candidates:
		if links.has(key) or key.x == entrance_zone or key.y == entrance_zone:
			continue
		if _joined_without(links, count, entrance_zone, key.x, key.y):
			continue
		var found := gate(points, zone_boundaries, key)
		if found == Vector2i(-1, -1):
			continue
		var length := points[found.x].distance_squared_to(points[found.y])
		if length < best_length:
			best_length = length
			best = key
	if best == Vector2i(-1, -1):
		return links

	var result := links.duplicate()
	result.append(best)
	return result


## 그 구역이 순환 위에 있는가.
##
## 이웃 둘 이상이 **그 구역을 지우고도** 서로 이어져 있으면 순환 위다.
static func _on_cycle(links: Array[Vector2i], count: int, zone: int) -> bool:
	var neighbours: Array[int] = []
	for link in links:
		if link.x == zone:
			neighbours.append(link.y)
		elif link.y == zone:
			neighbours.append(link.x)
	for slot in neighbours.size():
		for other in range(slot + 1, neighbours.size()):
			if _joined_without(links, count, zone, neighbours[slot], neighbours[other]):
				return true
	return false


## zone 을 지운 그래프에서 a 와 b 가 이어져 있는가.
static func _joined_without(links: Array[Vector2i], count: int, zone: int, a: int, b: int) -> bool:
	if a == zone or b == zone:
		return false
	if a == b:
		return true
	var seen := {a: true}
	var frontier: Array[int] = [a]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for link in links:
			var other := -1
			if link.x == current:
				other = link.y
			elif link.y == current:
				other = link.x
			if other < 0 or other == zone or other >= count or seen.has(other):
				continue
			if other == b:
				return true
			seen[other] = true
			frontier.append(other)
	return false


## 구역마다 방들의 무게중심.
static func centers(
	points: PackedVector2Array, zones: PackedInt32Array, count: int
) -> Array[Vector2]:
	var totals: Array[Vector2] = []
	var seen: Array[float] = []
	for index in count:
		totals.append(Vector2.ZERO)
		seen.append(0.0)
	for index in points.size():
		var zone := zones[index]
		if zone < 0 or zone >= count:
			continue
		totals[zone] += points[index]
		seen[zone] += 1.0
	for index in count:
		totals[index] /= maxf(seen[index], 1.0)
	return totals


## 입구 구역에서 관문 몇 개를 지나야 닿는가. 그대로 고도의 기본값이 된다 (덩어리 3).
##
## 이어지지 않은 구역은 0 으로 둔다. `ring()` 이 연결을 보장하므로 정상 경로에서는
## 나오지 않지만, 방이 아주 적어 구역이 비는 경우를 위해 남긴다.
static func ranks(links: Array[Vector2i], start: int, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(count)
	result.fill(-1)
	if start < 0 or start >= count:
		return result
	result[start] = 0

	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		var current: int = frontier.pop_front()
		for link in links:
			var other := -1
			if link.x == current:
				other = link.y
			elif link.y == current:
				other = link.x
			if other >= 0 and other < count and result[other] < 0:
				result[other] = result[current] + 1
				frontier.append(other)
	for index in count:
		if result[index] < 0:
			result[index] = 0
	return result


## 두 구역을 잇는 **관문 간선 하나.**
##
## 짧은 것을 고르는 이유는 관문이 판을 가로지르지 않아야 하기 때문이다.
## 긴 간선을 관문으로 쓰면 통로가 판을 건너질러 다른 구역을 스치고 지나간다 (§17.6).
##
## **다만 짧은 것만으로는 모자랐다.** 최단 간선을 관문으로 잡았더니
## 「통로가 방을 관통하지 않는다」 테스트가 깨졌다 — 통로가 방 20 px 앞까지 다가왔다(기준 84).
## 짧아도 옆에 방이 붙어 있으면 선이 그 방을 지난다.
##
## 그래서 두 기준을 순서대로 쓴다.
##
## | 순서 | 기준 |
## | --- | --- |
## | 1 | 여유(`CLEARANCE_MIN`)를 지키는 후보 중 **가장 짧은 것** |
## | 2 | 하나도 못 지키면 **여유가 가장 큰 것** |
##
## 여유를 1순위로 두지 않는 이유는, 긴 간선이 여유는 크지만 판을 가로지르기 때문이다.
## **여유는 통과 조건이고 길이가 고르는 기준이다.**
##
## 후보가 없으면 Vector2i(-1, -1) 을 돌려준다. 부르는 쪽이 그 경우를 처리해야 한다.
static func gate(
	points: PackedVector2Array, zone_boundaries: Dictionary, link: Vector2i
) -> Vector2i:
	if not zone_boundaries.has(link):
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_length := INF
	var roomy := Vector2i(-1, -1)
	var roomy_clearance := -1.0
	for edge in zone_boundaries[link] as Array[Vector2i]:
		var gap := clearance(points, edge)
		if gap > roomy_clearance:
			roomy_clearance = gap
			roomy = edge
		if gap < CLEARANCE_MIN:
			continue
		var length := points[edge.x].distance_squared_to(points[edge.y])
		if length < best_length:
			best_length = length
			best = edge
	return best if best != Vector2i(-1, -1) else roomy


## 그 간선이 **상관없는 방들에서 얼마나 떨어져 있는가.** 작을수록 선이 방을 스친다.
##
## 통로가 방을 스치면 이름도 숫자도 못 읽는다 (§17.6). 가브리엘 조건이 이 성질의
## 대리값이지만, 관문은 가브리엘이 아닌 후보만 남는 경우가 있어 직접 잰다.
static func clearance(points: PackedVector2Array, edge: Vector2i) -> float:
	var closest := INF
	for index in points.size():
		if index == edge.x or index == edge.y:
			continue
		var found := Geometry2D.get_closest_point_to_segment(
			points[index], points[edge.x], points[edge.y]
		)
		closest = minf(closest, found.distance_to(points[index]))
	return closest


## 구역 중심을 무게중심 기준 각도 순으로 세운다.
##
## 정렬 기준을 미리 계산해 두는 이유는 §17.7 과 같다 — 비교 함수 안에서 바깥 값을
## 들여다보지 않는 편이 안전하고, 같은 입력이면 언제나 같은 순서가 나온다.
static func _angular_order(zone_centers: Array[Vector2], count: int) -> Array[int]:
	var middle := Vector2.ZERO
	for center in zone_centers:
		middle += center
	middle /= maxf(float(count), 1.0)

	var entries: Array = []
	for index in count:
		entries.append({"zone": index, "key": (zone_centers[index] - middle).angle()})
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) < float(b["key"])
	)
	var result: Array[int] = []
	for entry in entries:
		result.append(int(entry["zone"]))
	return result


static func _find(parent: Array[int], node: int) -> int:
	var root := node
	while parent[root] != root:
		root = parent[root]
	return root


## 두 집합을 합쳤으면 true. 이미 같은 집합이면 그 연결은 고리를 만든다.
static func _union(parent: Array[int], a: int, b: int) -> bool:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a == root_b:
		return false
	parent[root_b] = root_a
	return true
