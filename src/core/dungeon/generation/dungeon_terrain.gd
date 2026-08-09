class_name DungeonTerrain
extends RefCounted
## 방마다 고도를 매긴다. **고도는 지형이지 그래프가 아니다.**
##
## 예전 생성기는 고도를 "층"으로 매겼다. 층을 나누고 층마다 방을 놓는 방식이라
## 고도가 그래프 구조와 한 몸이었고, 간선을 하나 더 이으면 지형이 통째로 흔들렸다.
##
## 지금은 좌표에서 바로 만든다. 순서가 **지형 먼저, 길은 그 위에** 가 되어
## 간선 선택이 고도차를 비용으로 볼 수 있다
## (docs/design/17-dungeon-generation.md §17.3 4단계).
##
## 규칙은 두 가지가 겹친 것이다.
##
## | 항 | 하는 일 |
## | --- | --- |
## | **구역 등급에 비례하는 단차** | 깊이 들어갈수록 돌아 나오기 어렵다 ([`07`] §7.2.6.2) |
## | 저주파 노이즈 | 층이 칼같이 평평해지지 않게. 구역 안에 잔 기복이 생긴다 |
##
## 입구는 언제나 판에서 가장 낮다. "내려가는 것은 자유"라는 규칙이
## 입구를 향한 방향과 같은 뜻이 되어야 지도가 읽힌다.
##
## ## 거리 원뿔에서 구역 등급으로 바꿨다 (§17.12.4-D)
##
## 예전에는 `입구에서의 거리 x 0.85` 였다. 어디를 봐도 기울기가 같은 **매끈한 원뿔**이라
## 「여기부터 위쪽」이라는 경계가 생기지 않았다. 실측에서 상승이 있는 간선이 62% 인데도
## 민첩 2 로 판의 87% 가 열렸다 — **절벽이 없고 경사만 있었다** (§17.11.7-5).
##
## 등급으로 만들면 **구역 안은 평탄하고 구역 경계에서만 층이 진다.** 관문이 눈에 보이는
## 지형이 되고, 메트로배니아식 관문([`07`] §7.2.6.1)이 실제로 작동한다.
##
## ## 고도로 판 전체를 막지 않는다
##
## 프로토타입에서 두 번 틀렸다. 단차를 3 으로 두면 관문마다 벽이 서서 기본 민첩으로
## 갈 수 있는 방이 20% 까지 떨어졌고, 고도 폭을 고정해 구역 수로 나누니 이번엔
## 구역이 적은 작은 판만 가팔라졌다.
##
## **지형은 걸어 다닐 수 있게 두고 벽은 보상 봉우리와 지름길에만 세운다.**
## 그래서 기본 단차가 2 다 — 스쿼드 기본 민첩으로 넘을 수 있는 크기다.
## 벽을 세우는 것은 덩어리 4 의 경로 시공이 한다 (§17.17).
##
## ## 고도를 건드리는 순서
##
## 프로토타입에서 `_sharpen` 뒤에 `carve_route` 가 와서 방금 세운 경사로를 탈출 통로가
## 도로 0 으로 깎았다. 두 경로의 상승폭 차가 0.13 까지 무너진 원인이다.
## **순서는 이렇게 고정한다.**
##
##     assign -> carve_route -> (덩어리 4) 경로 시공
##
## 깎는 것이 먼저이고, 깎인 자리는 뒤 단계에 **건드리지 말 자리로 넘긴다.**

## 보상 봉우리가 주변보다 얼마나 높은가. 보스 방의 필요 민첩이 곧 이 값이다.
##
## 3 인 것은 스쿼드 기본 민첩(2)보다 하나 크기 때문이다 — **능력이 올라야 손이 닿는다.**
const PEAK_RISE := 3

## 급경사 지름길의 마지막 한 칸 상승폭.
##
## **3 에서 4 로 올렸다.** 두 경로의 최대 상승폭 차가 1.06 에 머물러 목표(1.5)에 못 미쳤는데,
## 우회로는 이미 `GENTLE_SLOPE` 로 2 에 묶여 있어 **벌릴 수 있는 쪽이 지름길뿐**이었다.
## 4 로 올리니 차가 2.35 가 됐다 (실측, 방 50개).
##
## 대가는 지름길을 여는 민첩이 3 에서 4 로 오르는 것이다 — 스쿼드 기본 민첩(2)보다
## **둘** 위다. 그만큼 지름길이 진행 뒤로 밀리지만, **두 길의 성격이 갈리지 않으면
## 험난 등급이 화면에서 안 보인다.** 그쪽이 더 크다.
const SHORTCUT_CLIMB := 4

## 완경사 우회가 한 칸에 오를 수 있는 최대 상승폭.
##
## **1 이 아니라 2 인 것이 판단이다.** 1 로 묶었더니 봉우리 높이가 우회로 길이에 갇혀
## 낮아졌고, 그러면 **보상 방이 평범한 깊은 방보다 싸게 닿는다** (V3 정신이 깨진다).
##
## 2 는 스쿼드 기본 민첩과 같다 — **여전히 걸어서 올라갈 수 있다.**
## 지름길은 3 이므로 성격은 그대로 갈린다.
const GENTLE_SLOPE := 2


## 방마다 고도를 매긴다. 결과의 최솟값은 0 이고 입구가 그 최솟값이다.
##
## `ranks` 는 구역 번호 -> 입구 구역에서의 관문 수 거리다 (`DungeonZones.ranks`).
static func assign(
	points: PackedVector2Array,
	zones: PackedInt32Array,
	ranks: PackedInt32Array,
	entrance: int,
	noise_seed: int,
	step: float,
	amplitude: float,
	frequency: float
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if points.is_empty():
		return result

	# FastNoiseLite 는 Resource 라 노드 트리에 의존하지 않는다 (conventions.md §3.1).
	# 시드를 넣으면 같은 좌표에서 언제나 같은 값이 나온다 (§17.7).
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency

	var lowest := 0
	for index in points.size():
		var rank := _rank_of(zones, ranks, index)
		var height := (
			float(rank) * step + noise.get_noise_2d(points[index].x, points[index].y) * amplitude
		)
		var value := int(round(height))
		lowest = mini(lowest, value)
		result.append(value)

	for index in result.size():
		result[index] -= lowest
	# 노이즈가 입구보다 낮은 방을 만들 수 있다. 입구는 반드시 바닥이어야 한다.
	if entrance >= 0 and entrance < result.size():
		result[entrance] = 0
	return result


## 그 방이 속한 구역의 등급. 배정이 비어 있으면 0 으로 본다(아주 작은 판의 계약).
static func _rank_of(zones: PackedInt32Array, ranks: PackedInt32Array, index: int) -> int:
	if index >= zones.size():
		return 0
	var zone := zones[index]
	if zone < 0 or zone >= ranks.size():
		return 0
	return ranks[zone]


## 주어진 방들의 고도를 바닥(0)까지 깎는다.
##
## 민첩 0 으로 닿는 탈출구가 최소 하나 있어야 한다 (§17.5 V2).
## 이걸 검증으로 걸러 내면 재시도가 폭증하므로, 입구에서 탈출구까지의 경로를
## 한 줄 깎아 **구조적으로 보장한다.** 이제 V2 는 검사할 필요가 없는 규칙이 된다.
##
## 부수 효과가 오히려 이득이다 — 판을 가로지르는 낮은 길이 하나 생겨서
## "돌아 나올 수 있는 길"이 지도에서 눈에 띈다 ([`07`] §7.6 배치 원칙).
##
## PackedInt32Array 는 값 타입이라 인자를 고쳐도 부르는 쪽에 반영되지 않는다.
## 그래서 새 배열을 돌려준다.
static func carve_route(elevations: PackedInt32Array, route: PackedInt32Array) -> PackedInt32Array:
	var result := elevations.duplicate()
	for index in route:
		result[index] = 0
	return result


## 두 경로의 성격을 **일부러 벌린다.** 고도를 건드리는 마지막 단계다.
##
## 대안이 있기만 해서는 선택이 아니다. 실측에서 대안 경로는 더 길고 더 위험한데 기울기는
## 같았다 — 그러면 아무도 고르지 않는다 (§17.11.7-1).
##
## ## 프로토타입에서 세 번 틀렸다. 순서를 뒤집는 것이 답이었다
##
## | # | 무엇을 했나 | 왜 틀렸나 |
## | --- | --- | --- |
## | 1 | 목표 방의 고도를 올렸다 | 두 길이 **같은 방으로 들어온다.** 양쪽이 똑같이 가팔라진다 |
## | 2 | 우회로를 "한 칸에 1 씩" 깎았다 | 경사로가 **시작하는 지점**이 그대로 절벽이 됐다 |
## | 3 | 봉우리를 세운 뒤 계단을 맞췄다 | 경로가 짧거나 탈출 통로와 겹치면 **마지막 한 칸이 절벽**이 됐다 |
##
## 지금은 **계단이 1 씩 올라 닿을 수 있는 높이를 먼저 재고 봉우리를 거기에 맞춘다.**
## 그러면 우회로의 최대 상승폭이 1 임이 계산이 아니라 **구성으로 보장된다** (§17.5).
##
## `protected` 는 건드리면 안 되는 방들이다 — 보통 탈출 경로다.
## 민첩 0 으로 닿는 탈출구가 하나는 있어야 하므로(V2) 계단보다 그쪽이 우선한다.
static func sharpen(
	elevations: PackedInt32Array,
	fast: PackedInt32Array,
	slow: PackedInt32Array,
	edges: Array[Vector2i],
	entrance: int,
	protected: PackedInt32Array
) -> PackedInt32Array:
	var result := elevations.duplicate()
	if fast.size() < 2:
		return result
	var goal := fast[fast.size() - 1]
	if _holds(protected, goal):
		return result

	# 우회로를 못 낸 판에서도 **봉우리는 세운다.** 그러지 않으면 보상 방이 평지에 놓여
	# 필요 민첩이 0 이 되고 V3 가 깨진다. 경사로가 없으니 그 판은 그냥 어렵다.
	if slow.size() < 2:
		result[goal] = _around(result, edges, goal) + PEAK_RISE
		return result

	# 1) 우회로가 1 씩 올라 닿을 수 있는 높이를 잰다.
	var base: int = result[slow[0]]
	var last := slow.size() - 1
	var reach := PackedInt32Array()
	reach.resize(slow.size())
	reach[0] = base
	for index in range(1, slow.size()):
		if _holds(protected, slow[index]):
			reach[index] = result[slow[index]]
		else:
			reach[index] = reach[index - 1] + GENTLE_SLOPE

	# 2) 보상 방을 봉우리로 세운다 (P1). 계단이 닿는 높이를 넘지 않는다.
	# **경사로 보장이 봉우리 높이보다 앞선다.**
	#
	# 처음에는 `maxi(around + 1, ...)` 로 "이웃보다 최소 1 은 높게" 를 함께 요구했다.
	# 그게 경사로를 깼다 — 이웃이 높고 우회로가 짧으면 계단이 닿을 수 있는 높이를 넘어서
	# **마지막 한 칸이 절벽**이 됐다. 시드 넷 중 둘에서 우회로 최대 상승폭이 5 로 나왔다
	# (빠른 길은 3 이었으니 성격이 거꾸로 뒤집힌 것이다).
	#
	# 그래서 봉우리는 **계단이 닿는 높이까지만** 올린다. 그 판에서 보상 방이 이웃보다
	# 낮을 수는 있지만, 「빨리 가는 길과 돌아가는 길」이 사용자가 요구한 것이다.
	# V3 는 그대로다 — 계단이 최소 1 은 올라오므로 필요 민첩이 0 이 되지 않는다.
	var around := _around(result, edges, goal)
	result[goal] = maxi(1, mini(around + PEAK_RISE, reach[last - 1] + GENTLE_SLOPE))

	# 3) 계단을 목표에서 거꾸로 놓는다. 닿을 수 있는 높이 안에서만 올린다.
	for index in range(1, last):
		if _holds(protected, slow[index]):
			continue
		result[slow[index]] = clampi(
			result[goal] - (last - index) * GENTLE_SLOPE, base, reach[index]
		)

	# 4) 급경사 지름길. 마지막 한 칸을 떨어뜨린다 — 짧은 쪽은 기어올라야 한다.
	var steep := fast[fast.size() - 2]
	if steep != entrance and not _holds(slow, steep) and not _holds(protected, steep):
		result[steep] = maxi(0, result[goal] - SHORTCUT_CLIMB)
	return result


## 그 방에 붙은 이웃들 중 가장 높은 고도.
static func _around(elevations: PackedInt32Array, edges: Array[Vector2i], node: int) -> int:
	var highest := 0
	for edge in edges:
		if edge.x == node:
			highest = maxi(highest, elevations[edge.y])
		elif edge.y == node:
			highest = maxi(highest, elevations[edge.x])
	return highest


static func _holds(route: PackedInt32Array, node: int) -> bool:
	for index in route:
		if index == node:
			return true
	return false


## 판에 오르막이 하나도 없으면 하나 만든다.
##
## 고가치 방은 필요 민첩이 0 보다 커야 한다 (§17.5 V3).
## 모든 방이 같은 높이면 그런 방을 고를 수 없다. 판이 아주 작을 때만 걸리는
## 경우지만, 걸렸을 때 재생성하는 대신 **정해진 한 곳을 올려** 끝낸다.
static func ensure_a_climb_exists(
	elevations: PackedInt32Array, target: int, climb: int
) -> PackedInt32Array:
	for value in elevations:
		if value > 0:
			return elevations
	var result := elevations.duplicate()
	if target >= 0 and target < result.size():
		result[target] = maxi(climb, 1)
	return result
