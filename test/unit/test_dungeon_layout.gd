extends GutTest
## **판이 실제로 어떻게 생겼는지**를 검증한다. 이 파일이 새 생성 파이프라인의 근거다.
##
## 규칙(도달 가능한가, 탈출구가 있는가)은 test_dungeon_generator.gd 가 본다.
## 여기서 보는 것은 화면에 그려질 모양이다 —
## 간선이 엉키지 않는가, 방이 고르게 퍼져 있는가.
##
## 두 성질 모두 **생성 순서를 뒤집어서** 얻은 것이다
## (docs/design/17-dungeon-generation.md §17.3).
## 그래서 여기가 깨지면 그 순서가 무너진 것이다.

const Crossing := preload("res://test/support/segment_crossing.gd")

## 화면이 쓰는 간격. **베껴 적지 않고 읽어 온다.**
##
## 예전에는 `280.0` 을 적어 뒀는데 화면이 240 으로 내려가도 그대로 남아 있었다.
## 좌표가 간격에 정비례하고 임계값도 같은 값을 곱하므로 **테스트는 척도 무관이라
## 통과/실패가 한 판도 안 바뀌었다** — 깨진 것은 판정이 아니라 보장이었다.
## `tools/check_board_capacity.gd` 는 이미 읽어 오고 있었고 CI 관문인 여기만 낡아 있었다.
const _SPACING := DungeonBoard._SPACING

## 방 위젯. 통로가 얼마나 떨어져야 하는지를 **여기서 재기 위해** 들고 온다.
const RoomNodeScene := preload("res://src/ui/dungeon_board/room_node.tscn")

## 크기마다 검사할 시드 수. 무작위 생성이라 한 판만 봐서는 아무것도 증명되지 않는다.
const _SEEDS := 12

## 눈으로 확인한 판들. [시드, 맵 크기].
const _CAPTURED := [[1, 3], [7, 3], [42, 5], [99, 5], [314, 1], [2718, 4], [12345, 5]]

## 빈 구멍의 허용 크기 (간격 대비).
##
## 판 안 어느 지점에서든 이 거리 안에 방이 하나는 있어야 한다.
## 푸아송 디스크 샘플링이 최대 집합을 만들므로 이론상 간격 1 이면 충분하지만,
## 후보를 유한 번만 던져 보고 포기하기 때문에 실측으로 여유를 뒀다.
const _MAX_HOLE_RATIO := 1.6

## 구멍을 찾을 때 격자를 얼마나 잘게 훑을지 (간격 대비).
const _PROBE_STEP := 0.35

## 통로가 방 위젯을 파고들지 않으려면 방 중심에서 이만큼은 떨어져야 한다 (픽셀).
##
## **위젯 크기에서 직접 잰다.** 예전에는 `간격 x 0.30` 이라는 비율을 적어 뒀는데,
## 간격 240 에서 그 값이 72 px 이라 **위젯 가로 반너비 73 px 도 못 덮었다** —
## 통로가 방 이름을 파고들어도 초록불이었다.
##
## 진짜 기준은 위젯의 대각 반지름이다. 146x76 이면 82.3 px 이고, 그보다 멀면
## 어떤 방향에서 와도 위젯에 닿지 않는다. 위젯이 커지면 이 값도 따라 커진다.
var _room_clearance := 0.0


func before_all() -> void:
	var node: Control = RoomNodeScene.instantiate()
	_room_clearance = node.custom_minimum_size.length() * 0.5
	node.free()


func _positions(seed_value: int, size: int) -> Dictionary:
	var blueprint := SampleDungeons.create_run(seed_value, size).blueprint
	return blueprint.layout(seed_value, _SPACING)


func _sizes() -> Array[int]:
	var result: Array[int] = []
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		result.append(size)
	return result


# ---------------------------------------------------------------- 1. 교차 없음


func test_no_two_corridors_ever_cross() -> void:
	# 후보 간선이 전부 들로네 삼각분할에서 나오므로 **교차할 수 없다.**
	# 그 논증을 믿지 않고, 화면에 그려질 선분끼리 직접 비교해 확인한다.
	for size in _sizes():
		for seed_value in _SEEDS:
			_assert_no_crossing(seed_value + 1, size)


func test_the_captured_maps_have_no_crossing() -> void:
	# tools/capture_dungeon_maps.gd 가 PNG 로 뽑는 판들이다.
	# 눈으로 본 판이 테스트로도 덮여 있어야 "그 그림이 근거다"라고 말할 수 있다.
	for shot in _CAPTURED:
		_assert_no_crossing(shot[0], shot[1])


func _assert_no_crossing(seed_value: int, size: int) -> void:
	var run := SampleDungeons.create_run(seed_value, size)
	var positions := run.blueprint.layout(seed_value, _SPACING)
	var pairs := run.blueprint.connections()
	for i in pairs.size():
		for j in range(i + 1, pairs.size()):
			var a: Array = pairs[i]
			var b: Array = pairs[j]
			if Crossing.crosses(positions[a[0]], positions[a[1]], positions[b[0]], positions[b[1]]):
				fail_test(
					(
						"시드 %d 크기 %d 에서 통로가 교차한다: %s-%s 와 %s-%s"
						% [seed_value, size, a[0], a[1], b[0], b[1]]
					)
				)
				return
	assert_gt(pairs.size(), 0, "간선이 하나도 없다")


func test_the_crossing_check_itself_catches_a_crossing() -> void:
	# 검사기가 아무것도 못 잡는 물건이면 위 테스트는 늘 통과한다.
	assert_true(
		Crossing.crosses(Vector2(0, 0), Vector2(10, 10), Vector2(0, 10), Vector2(10, 0)),
		"X 자로 만나는 선분을 못 잡았다"
	)
	assert_true(
		Crossing.crosses(Vector2(0, 0), Vector2(10, 0), Vector2(5, 0), Vector2(5, 9)),
		"T 자로 닿는 선분을 못 잡았다"
	)
	assert_false(
		Crossing.crosses(Vector2(0, 0), Vector2(10, 0), Vector2(0, 0), Vector2(0, 10)),
		"끝점을 공유하는 것은 교차가 아니다"
	)
	assert_false(
		Crossing.crosses(Vector2(0, 0), Vector2(10, 0), Vector2(0, 5), Vector2(10, 5)),
		"평행한 선분을 교차로 봤다"
	)


func test_no_corridor_runs_through_a_room() -> void:
	# 교차가 없어도 선이 엉뚱한 방을 관통하면 이름도 숫자도 못 읽는다 (§17.6).
	#
	# 곁가지 후보를 가브리엘 간선으로 제한한 근거가 이것이다.
	# 가브리엘 간선은 두 방을 지름으로 하는 원 안에 다른 방이 없다.
	for size in _sizes():
		for seed_value in _SEEDS:
			var run := SampleDungeons.create_run(seed_value + 1, size)
			var positions := run.blueprint.layout(seed_value, _SPACING)
			var closest := _closest_room_to_a_corridor(run.blueprint, positions)
			assert_gt(
				closest,
				_room_clearance,
				"시드 %d 크기 %d 에서 통로가 방을 %.1f 까지 스친다" % [seed_value + 1, size, closest]
			)


func _closest_room_to_a_corridor(blueprint: DungeonBlueprint, positions: Dictionary) -> float:
	var closest := INF
	for pair in blueprint.connections():
		var from_pos: Vector2 = positions[pair[0]]
		var to_pos: Vector2 = positions[pair[1]]
		for id in positions:
			if id == pair[0] or id == pair[1]:
				continue
			var point := Geometry2D.get_closest_point_to_segment(positions[id], from_pos, to_pos)
			closest = minf(closest, point.distance_to(positions[id]))
	return closest


# ---------------------------------------------------------------- 2. 고른 밀도


func test_rooms_never_come_closer_than_the_spacing() -> void:
	# 뭉치지 않는다. 푸아송 디스크 샘플링의 첫 번째 성질이다.
	for size in _sizes():
		for seed_value in _SEEDS:
			var positions := _positions(seed_value * 17 + size, size)
			var gap := _closest_gap(positions)
			assert_gte(
				gap,
				_SPACING * 0.999,
				"시드 %d 크기 %d 에서 두 방이 %.1f 만큼밖에 안 떨어져 있다" % [seed_value, size, gap]
			)


func test_no_wide_empty_hole_in_the_map() -> void:
	# 비지 않는다. 푸아송 디스크 샘플링의 두 번째 성질이다.
	#
	# 판 범위 안에 격자를 깔고 각 지점에서 가장 가까운 방까지의 거리를 잰다.
	# 이 값이 크다는 것은 그 자리에 아무것도 없다는 뜻이다.
	for size in _sizes():
		for seed_value in _SEEDS:
			var positions := _positions(seed_value * 23 + size, size)
			var hole := _widest_hole(positions)
			assert_lte(
				hole,
				_SPACING * _MAX_HOLE_RATIO,
				"시드 %d 크기 %d 에 지름 %.1f 짜리 빈 구멍이 있다" % [seed_value, size, hole * 2.0]
			)


func test_density_beats_the_force_directed_fallback() -> void:
	# 예전 방식(좌표 없는 설계도의 대체 배치)과 같은 판을 놓고 비교한다.
	# 새 배치가 더 고르다는 것을 숫자로 남겨 두지 않으면
	# "바꿨더니 좋아 보인다"에서 끝난다.
	var run := SampleDungeons.create_run(7, SampleDungeons.SIZE_MAX)
	var placed := run.blueprint.layout(7, _SPACING)
	var relaxed := _without_positions(run.blueprint).layout(7, _SPACING)
	assert_gt(_closest_gap(placed), _closest_gap(relaxed), "새 배치가 예전 배치보다 방 사이가 좁다")
	assert_lt(_widest_hole(placed), _widest_hole(relaxed), "새 배치에 더 넓은 구멍이 있다")


# ---------------------------------------------------------------- 7. 재현성


func test_the_same_seed_draws_the_same_map() -> void:
	# 시드가 고정되지 않으면 이상한 판을 다시 볼 수 없다 (§17.7).
	for size in _sizes():
		var first := _positions(1234, size)
		var second := _positions(1234, size)
		assert_eq(first, second, "크기 %d 에서 같은 시드가 다른 배치를 만들었다" % size)


func test_different_seeds_draw_different_maps() -> void:
	assert_ne(_positions(1, 3), _positions(2, 3))


# ---------------------------------------------------------------- 측정 도구


func _closest_gap(positions: Dictionary) -> float:
	var ids := positions.keys()
	var closest := INF
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			closest = minf(closest, (positions[ids[i]] as Vector2).distance_to(positions[ids[j]]))
	return closest


## 판 범위 안에서 "가장 가까운 방까지의 거리"의 최댓값.
func _widest_hole(positions: Dictionary) -> float:
	var lowest := Vector2.INF
	var highest := -Vector2.INF
	for position in positions.values():
		lowest = lowest.min(position as Vector2)
		highest = highest.max(position as Vector2)

	var step := _SPACING * _PROBE_STEP
	var widest := 0.0
	var y := lowest.y
	while y <= highest.y:
		var x := lowest.x
		while x <= highest.x:
			widest = maxf(widest, _distance_to_nearest(positions, Vector2(x, y)))
			x += step
		y += step
	return widest


func _distance_to_nearest(positions: Dictionary, probe: Vector2) -> float:
	var nearest := INF
	for position in positions.values():
		nearest = minf(nearest, probe.distance_to(position as Vector2))
	return nearest


## 같은 판에서 좌표만 지운 설계도. 예전 배치 방식과 비교하기 위한 것이다.
func _without_positions(blueprint: DungeonBlueprint) -> DungeonBlueprint:
	var copy := DungeonBlueprint.new()
	for id in blueprint.room_ids():
		copy.add_room(
			id, blueprint.display_name_of(id), blueprint.elevation_of(id), blueprint.kind_of(id)
		)
	for pair in blueprint.connections():
		copy.connect_rooms(pair[0], pair[1])
	return copy
