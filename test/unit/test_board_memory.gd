extends GutTest
## 플레이어가 기억하는 것. **docs/design/13-information-design.md §13.5 · §13.7.**
##
## > 숫자의 절대값은 위험을 알려 주고, **숫자의 변화량은 사람을 알려 준다.**
##
## 절대값은 판을 보면 나온다. **변화량은 기억이 있어야 나온다.**
## §13.7 이 이것을 「구현 시 주의」의 첫 줄로 적었다 —
## *"매 턴 암산을 강요하면 재미가 아니라 노동이 된다."*

const Fixtures := preload("res://test/support/turn_fixtures.gd")


func test_an_unseen_room_is_not_a_zero() -> void:
	# 위험도 합은 0 일 수 있다. 0 을 "모른다"로 쓰면 두 정보가 섞인다.
	var memory := BoardMemory.new()

	assert_eq(memory.last_threat("hall"), BoardMemory.UNSEEN)
	assert_false(memory.has_visited("hall"))


func test_standing_somewhere_makes_it_remembered() -> void:
	var memory := BoardMemory.new()
	memory.note("hall", 5)

	assert_true(memory.has_visited("hall"))
	assert_eq(memory.last_threat("hall"), 5)
	assert_eq(memory.visited_count(), 1)


func test_coming_back_shows_what_changed() -> void:
	# 3이던 방이 7이 됐다 -> 몬스터는 안 움직인다. **누가 들어갔다** (§13.5.1).
	var memory := BoardMemory.new()
	memory.note("hall", 3)

	assert_eq(memory.delta("hall", 7), 4)
	assert_eq(memory.delta_text("hall", 7), "오름 4")


func test_a_number_that_dropped_reads_as_a_drop() -> void:
	# 7이던 방이 3이 됐다 -> 나갔거나, 죽었다.
	var memory := BoardMemory.new()
	memory.note("hall", 7)

	assert_eq(memory.delta_text("hall", 3), "내림 4")


func test_no_change_says_nothing() -> void:
	# 변화가 없는 것도 정보이지만, 화면에 표를 남기면 판이 표로 뒤덮인다.
	var memory := BoardMemory.new()
	memory.note("hall", 5)

	assert_eq(memory.delta_text("hall", 5), "")


func test_the_first_look_is_not_a_change() -> void:
	var memory := BoardMemory.new()

	assert_eq(memory.delta("어디", 9), 0)
	assert_eq(memory.delta_text("어디", 9), "")


func test_it_never_uses_a_glyph_the_font_lacks() -> void:
	# `▲ ▼` 는 테마 폰트에 없다. 데스크톱은 OS 가 대신 그려 줘서 보이지 않고
	# 웹에서만 두부가 된다 (docs/conventions.md §5.1).
	var memory := BoardMemory.new()
	memory.note("hall", 1)

	var text := memory.delta_text("hall", 9) + memory.delta_text("hall", 0)
	assert_false(text.contains("▲"))
	assert_false(text.contains("▼"))


func test_visiting_order_is_kept() -> void:
	var memory := BoardMemory.new()
	memory.note("hall", 1)
	memory.note("vault", 2)
	memory.note("hall", 3)

	assert_eq(memory.visited_room_ids(), ["hall", "vault"] as Array[String])


# ---------------------------------------------------------------- 판에 붙어 있다


func test_the_run_measures_the_change_for_you() -> void:
	# **화면이 기억하면 화면을 닫을 때 지워진다.** 기억은 판의 것이다.
	var run := Fixtures.run("hall")
	Fixtures.monster(run, "gate", "watcher", 4)
	# 한 번 서서 읽는다. 기억은 **본 것**이지 판의 현재값이 아니다.
	run.resolve_turn()

	run.move_player("vault")
	run.move_player("hall")

	assert_eq(run.threat_change, 0, "판이 안 바뀌었는데 변화가 잡혔다")
	assert_eq(run.threat_change_text, "")


func test_someone_moving_in_shows_up_as_a_change() -> void:
	# NPC 가 움직이는 것만으로 숫자가 달라진다. 이것이 §13.5 의 전부다.
	var run := Fixtures.run("hall")
	Fixtures.rival(run, "deep")

	run.submit_intent(TurnIntent.stay("squad"))
	run.submit_intent(TurnIntent.stay("rival"))
	run.resolve_turn()
	run.submit_intent(TurnIntent.stay("squad"))
	run.submit_intent(TurnIntent.move("rival", "vault"))
	run.resolve_turn()

	assert_eq(run.threat_change, 4, "옆방에 사람이 들어왔는데 숫자가 그대로다")
	assert_eq(run.threat_change_text, "오름 4")
