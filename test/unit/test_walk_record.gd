extends GutTest
## 걸음 기록의 단위 테스트.
##
## **이 값들은 판을 채점하지 않는다** (docs/design/17-dungeon-generation.md §17.28.1).
## 사람이 걸은 뒤에 자기가 어떻게 걸었는지 되짚을 근거일 뿐이다.
## 그래서 여기서 지키는 것은 "좋은 값이 나오는가"가 아니라 **"세는 것이 맞는가"** 하나다.
##
## | 성질 | 왜 |
## | --- | --- |
## | 안 걸었으면 안 걸린다 | 켜자마자 숫자가 붙어 있으면 걸은 것으로 읽힌다 |
## | 되돌아섬은 **직전 방**으로 돌아간 것 | 아무 데나 다시 간 것까지 세면 뜻이 사라진다 |
## | 왕복 통로는 **서로 다른** 통로 | 같은 자리를 오간 횟수는 되돌아섬이 이미 센다 |
## | 둘이 어느 쪽으로도 벌어진다 | 두 값이 늘 같이 움직이면 하나만 두면 된다 |
## | 새 판이면 0 | 판이 바뀌었는데 앞 판의 걸음이 남으면 기록이 거짓말한다 |

const RecordScript := preload("res://src/core/dungeon/walk_record.gd")


func test_a_walk_that_never_started_counts_nothing() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	assert_false(walk.has_walked(), "안 걸었는데 걸은 것으로 나온다")
	assert_eq(walk.steps(), 0, "걸음이 0 이 아니다")
	assert_eq(walk.seen_room_count(), 1, "선 방 하나는 본 방에 들어가야 한다")
	assert_eq(walk.backtracks(), 0, "되돌아섬이 0 이 아니다")
	assert_eq(walk.retraced_corridors(), 0, "왕복 통로가 0 이 아니다")


func test_walking_straight_never_looks_like_getting_lost() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	walk.note_move("a", "b")
	walk.note_move("b", "c")
	walk.note_move("c", "d")
	assert_eq(walk.steps(), 3, "걸음이 틀렸다")
	assert_eq(walk.seen_room_count(), 4, "본 방이 틀렸다")
	assert_eq(walk.backtracks(), 0, "곧장 걸었는데 되돌아섰다고 센다")
	assert_eq(walk.retraced_corridors(), 0, "곧장 걸었는데 왕복했다고 센다")


func test_turning_around_counts_once_for_each_turn() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	walk.note_move("a", "b")
	walk.note_move("b", "a")
	assert_eq(walk.backtracks(), 1, "돌아섰는데 안 셌다")
	assert_eq(walk.retraced_corridors(), 1, "같은 통로를 양쪽으로 걸었는데 안 셌다")
	assert_eq(walk.seen_room_count(), 2, "다시 간 방을 새 방으로 셌다")


## **한 자리에서 망설인 것.** 되돌아섬은 늘어나지만 통로는 하나뿐이다.
func test_pacing_the_same_corridor_grows_only_the_turn_count() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	walk.note_move("a", "b")
	walk.note_move("b", "a")
	walk.note_move("a", "b")
	assert_eq(walk.backtracks(), 2, "오간 횟수가 틀렸다")
	assert_eq(walk.retraced_corridors(), 1, "통로 하나를 여러 번 세고 있다")


## **한 번도 안 돌아섰는데 들어온 길로 나온 것.**
##
##   a - b, 그리고 b • c • d 가 고리
##
## 되돌아섬 0 에 왕복 통로 1 이 나와야 둘이 다른 것을 센다는 것이 증명된다.
func test_looping_back_out_is_not_a_turn_around() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	walk.note_move("a", "b")
	walk.note_move("b", "c")
	walk.note_move("c", "d")
	walk.note_move("d", "b")
	walk.note_move("b", "a")
	assert_eq(walk.backtracks(), 0, "한 번도 안 돌아섰는데 돌아섰다고 센다")
	assert_eq(walk.retraced_corridors(), 1, "들어온 길로 나왔는데 왕복을 안 셌다")
	assert_eq(walk.seen_room_count(), 4, "본 방이 틀렸다")


func test_a_new_board_starts_from_zero() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	walk.note_move("a", "b")
	walk.note_move("b", "a")
	walk.begin_at("x")
	assert_false(walk.has_walked(), "새 판인데 걸은 것으로 남아 있다")
	assert_eq(walk.steps(), 0, "새 판인데 걸음이 남아 있다")
	assert_eq(walk.seen_room_count(), 1, "새 판인데 앞 판의 방이 남아 있다")
	assert_eq(walk.backtracks(), 0, "새 판인데 되돌아섬이 남아 있다")
	assert_eq(walk.retraced_corridors(), 0, "새 판인데 왕복 통로가 남아 있다")


## 성사되지 않은 이동은 넘어오지 않는다. 그래도 들어오면 조용히 무시한다 —
## 제자리 이동을 되돌아섬으로 세면 손가락 실수가 헤맴으로 기록된다.
func test_a_move_that_goes_nowhere_is_ignored() -> void:
	var walk: WalkRecord = RecordScript.new()
	walk.begin_at("a")
	walk.note_move("a", "a")
	walk.note_move("", "b")
	walk.note_move("b", "")
	assert_eq(walk.steps(), 0, "제자리 이동을 걸음으로 셌다")
	assert_false(walk.has_walked(), "제자리 이동으로 걸은 것이 됐다")
