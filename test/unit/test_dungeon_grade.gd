extends GutTest
## 던전 선택 수치의 단위 테스트.
##
## 이 수치는 **플레이어가 들어가기 전에 보고 고르는 것**이다. 화면이 「복잡 3」이라고
## 했는데 판이 안 복잡하면 그 수치는 거짓말이 되고, 거짓말하는 수치는 없는 것만 못하다
## (docs/design/17-dungeon-generation.md §17.20).
##
## | 성질 | 왜 |
## | --- | --- |
## | 등급이 범위 안에 있다 | 화면이 「복잡 7/3」 을 그리면 안 된다 |
## | 입력이 아니라 결과를 잰다 | 파라미터가 5 인데 판이 3 이면 화면이 거짓말한다 |
## | 단조롭다 | 곁가지를 늘렸는데 복잡이 내려가면 수치가 뜻을 잃는다 |
## | 축끼리 섞이지 않는다 | 험난을 올렸는데 복잡이 따라 오르면 축이 하나다 |
## | 같은 판 -> 같은 등급 | 볼 때마다 달라지면 고를 수 없다 |

const GradeScript := preload("res://src/core/dungeon/dungeon_grade.gd")
const GeneratorScript := preload("res://src/core/dungeon/dungeon_generator.gd")

const _SEEDS := 8


func _blueprint(seed_value: int, rooms: int, extra: float, gain: float) -> DungeonBlueprint:
	var params := DungeonGenerator.Params.new()
	params.room_count = rooms
	params.extra_edge_ratio = extra
	params.elevation_gain = gain
	return GeneratorScript.new(seed_value, params).generate()


func test_every_grade_stays_inside_its_range() -> void:
	for seed_value in _SEEDS:
		for rooms in [12, 22, 32]:
			var grade := GradeScript.of(_blueprint(seed_value, rooms, 0.24, 2.0))
			assert_between(int(grade["scale"]), 1, GradeScript.SCALE_MAX, "규모가 범위 밖이다")
			assert_between(int(grade["complexity"]), 1, GradeScript.COMPLEXITY_MAX, "복잡이 범위 밖이다")
			assert_between(int(grade["hardship"]), 1, GradeScript.HARDSHIP_MAX, "험난이 범위 밖이다")


func test_the_scale_follows_the_room_count() -> void:
	for seed_value in _SEEDS:
		var small := GradeScript.of(_blueprint(seed_value, 12, 0.24, 2.0))
		var large := GradeScript.of(_blueprint(seed_value, 32, 0.24, 2.0))
		assert_lt(int(small["scale"]), int(large["scale"]), "큰 판의 규모가 더 높지 않다")


func test_more_side_branches_never_lower_the_complexity() -> void:
	# 단조롭지 않으면 플레이어가 수치를 믿을 수 없다.
	for seed_value in _SEEDS:
		var sparse := GradeScript.of(_blueprint(seed_value, 24, 0.06, 2.0))
		var dense := GradeScript.of(_blueprint(seed_value, 24, 0.60, 2.0))
		assert_lte(int(sparse["complexity"]), int(dense["complexity"]), "곁가지를 늘렸는데 복잡이 내려갔다")
		assert_lt(
			float(sparse["average_degree"]),
			float(dense["average_degree"]),
			"곁가지를 늘렸는데 평균 차수가 안 올랐다"
		)


func test_a_steeper_board_never_lowers_the_hardship() -> void:
	for seed_value in _SEEDS:
		var flat := GradeScript.of(_blueprint(seed_value, 24, 0.24, 0.5))
		var steep := GradeScript.of(_blueprint(seed_value, 24, 0.24, 6.0))
		assert_lte(int(flat["hardship"]), int(steep["hardship"]), "단차를 올렸는데 험난이 내려갔다")


func test_hardship_does_not_drag_complexity_with_it() -> void:
	# 험난을 열 배로 올려도 갈림길은 그대로여야 한다. 아니면 축이 하나다 (§17.20.3).
	for seed_value in _SEEDS:
		var flat := GradeScript.of(_blueprint(seed_value, 30, 0.24, 0.5))
		var steep := GradeScript.of(_blueprint(seed_value, 30, 0.24, 5.0))
		assert_almost_eq(
			float(flat["average_degree"]),
			float(steep["average_degree"]),
			0.35,
			"험난을 올렸더니 평균 차수가 따라 움직였다"
		)


func test_the_same_board_always_grades_the_same() -> void:
	for seed_value in _SEEDS:
		var first := GradeScript.of(_blueprint(seed_value, 22, 0.24, 2.0))
		var second := GradeScript.of(_blueprint(seed_value, 22, 0.24, 2.0))
		assert_eq(first, second, "같은 판이 다른 등급을 받았다")


func test_the_grade_reads_the_board_not_the_parameters() -> void:
	# 손으로 짠 설계도에도 등급이 매겨져야 한다. 파라미터를 보고 있으면 여기서 죽는다.
	var plan := DungeonBlueprint.new()
	for index in 4:
		plan.add_room("r%d" % index, "방 %d" % index, index, Room.Kind.EMPTY)
	plan.connect_rooms("r0", "r1")
	plan.connect_rooms("r1", "r2")
	plan.connect_rooms("r2", "r3")

	var grade := GradeScript.of(plan)
	assert_eq(int(grade["rooms"]), 4, "방 개수를 못 읽었다")
	assert_eq(int(grade["scale"]), 1, "네 칸짜리 판의 규모가 1 이 아니다")
	assert_almost_eq(float(grade["average_climb"]), 1.0, 0.001, "한 칸에 1 씩 오르는 판이다")


func test_an_empty_board_does_not_crash() -> void:
	var grade := GradeScript.of(DungeonBlueprint.new())
	assert_eq(int(grade["rooms"]), 0, "빈 판의 방 개수가 0 이 아니다")
	assert_between(int(grade["complexity"]), 1, GradeScript.COMPLEXITY_MAX, "빈 판의 복잡이 범위 밖")


## **사다리와 등급 경계는 같이 움직여야 한다.**
##
## 크기 N 의 판은 규모 N 으로 읽혀야 한다. 안 그러면 슬라이더를 끝까지 밀어도 화면이
## 안 바뀌고, 그 순간 수치가 뜻을 잃는다.
##
## **한 번 어긋난 적이 있다.** §17.25 가 사다리를 12/22/32/42/52 로 올렸는데 경계는
## 옛 사다리에 맞춰 잘린 채로 남아 크기 3 • 4 • 5 가 전부 「규모 5/5」였다
## (docs/design/17-dungeon-generation.md §17.29). **이 테스트가 그것을 다시 못 잡게 한다.**
func test_each_size_step_reads_as_its_own_scale_grade() -> void:
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		var hits := 0
		var boards := 0
		for character in DungeonCatalog.count():
			for seed_value in _SEEDS:
				var params := SampleDungeons.params_for_size(size, character)
				var plan := GeneratorScript.new(seed_value * 977 + character, params).generate()
				boards += 1
				if int(GradeScript.of(plan)["scale"]) == size:
					hits += 1
		# 시드 편차로 이웃 등급이 몇 판 섞이는 것은 정상이다. 붙어 버린 것만 잡는다.
		assert_gt(
			float(hits) / float(boards),
			0.85,
			"크기 %d 가 규모 %d 로 안 읽힌다 (%d/%d)" % [size, size, hits, boards]
		)
