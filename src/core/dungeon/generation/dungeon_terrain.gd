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
