extends GutTest
## **적이 두 켜로 선다.** 자리를 좌표가 아니라 켜 번호로만 준 판.
##
## `docs/design/28-combat.md` §28.20.38.
##
## ## 왜 켜인가
##
## §28.20.37 이 뒤집은 손잡이 둘(걸침 · 표적 고르기)이 **전부 기하다.**
## 그런데 그 표는 **전원이 같은 자리**에 서 있는 판에서 잰 것이었다.
##
## 좌표를 넣으면 이동 · 충돌 · 자리 다툼이 딸려 온다 (§28.4 의 몫이다).
## **켜 번호만으로도** 뒷줄에 닿나 · 걸침이 앞뒤로 걸리나 · 못 닿는 놈을 고르면
## 어떻게 되나를 다 물을 수 있다.

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const FieldScript := preload("res://src/core/combat/sparring_field.gd")
const Fixtures := preload("res://test/support/sparring_fixtures.gd")

## 앞 켜가 서는 거리. 1칸 리치(104)보다 안쪽이라 누구든 앞 켜는 친다.
const FRONT := 96.0


func _tuning(decay: float = 10.0) -> BreakTuning:
	return TuningScript.new(decay)


func _ranked(counts: Array[int]) -> SparringField:
	return Fixtures.ranks(FRONT, counts)


# ---------------------------------------------------------------- 켜가 자리를 정한다


func test_the_same_rank_stands_at_the_same_distance() -> void:
	# **가로 축이 아예 없다.** 같은 켜에 선 적은 구분할 자리가 없다.
	var field := _ranked([3])
	assert_eq(field.enemy_count(), 3)
	for index in 3:
		assert_eq(field.gap_to(index), FRONT, "%d번이 앞 켜에 안 섰다" % index)
		assert_eq(field.enemy_at(index).rank, 0)


func test_the_back_rank_stands_one_depth_further() -> void:
	var field := _ranked([2, 2])
	assert_eq(field.gap_to(0), FRONT)
	assert_eq(field.gap_to(2), FRONT + field.rank_depth)
	assert_eq(field.enemy_at(2).rank, 1)


func test_ranks_fill_front_first() -> void:
	var field := _ranked([3, 1])
	assert_eq(field.enemy_count(), 4)
	assert_eq(field.enemy_at(3).rank, 1, "넘친 하나만 뒤 켜다")


# ---------------------------------------------------------------- 뒷줄에 닿나


func test_a_small_weapon_cannot_reach_the_back_rank() -> void:
	# **이 한 줄이 나머지 전부를 설명한다** — 1칸 리치 104 인데 뒤 켜는 112 다.
	var field := _ranked([1, 1])
	var short_reach := WeaponMotion.reach_px(Fixtures.sized(1))
	assert_eq(field.targets_within(short_reach, 9), PackedInt32Array([0]), "앞 켜만 든다")


func test_a_long_weapon_reaches_both_ranks() -> void:
	var field := _ranked([1, 1])
	var long_reach := WeaponMotion.reach_px(Fixtures.sized(4))
	assert_eq(field.targets_within(long_reach, 9).size(), 2, "4칸은 뒤 켜까지 든다")


func test_the_order_of_a_rank_does_not_wobble() -> void:
	# 같은 켜는 거리가 같다. 그때 순서가 판마다 달라지면 같은 배치가 다른 결과를 낸다.
	var field := _ranked([3, 1])
	var reach := WeaponMotion.reach_px(Fixtures.sized(4))
	var first := field.targets_within(reach, 9)
	for _again in 5:
		assert_eq(field.targets_within(reach, 9), first, "같은 판이 매번 같아야 한다")


# ---------------------------------------------------------------- 걸침이 켜를 넘나


func test_by_default_a_sweep_crosses_ranks() -> void:
	# 켜가 없던 때의 동작 그대로가 기본값이다.
	assert_true(_tuning().splash_spans_ranks)


func test_a_sweep_can_be_held_to_one_rank() -> void:
	var tuning := _tuning()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL
	tuning.splash_spans_ranks = false

	var bout := BoutScript.new(Fixtures.items(6, 4), tuning, _ranked([1, 1]))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0, "앞 켜는 맞는다")
	assert_eq(bout.enemy_gauge(1).peak(), 0.0, "같은 켜만 걸리면 뒤 켜는 안 맞는다")


func test_crossing_ranks_catches_the_one_behind() -> void:
	var tuning := _tuning()
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var bout := BoutScript.new(Fixtures.items(6, 4), tuning, _ranked([1, 1]))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(1).peak() > 0.0, "켜를 넘으면 뒤도 함께 맞는다")


# ---------------------------------------------------------------- 못 닿는 놈을 고르면


func test_finish_off_cannot_pick_someone_out_of_reach() -> void:
	# **못 닿는 적은 고르는 단계에 아예 안 올라온다** (§28.20.38).
	# 그래서 FINISH_OFF 는 「제일 상한 놈」이 아니라 「닿는 것 중 제일 상한 놈」이다.
	#
	# 앞 켜를 눕힐 만큼 큰 무기로 열고 나면 다음 표적은 뒤 켜다.
	# **그때 손에 든 것이 짧으면 갈 데가 없다** — 앞 켜를 계속 친다.
	var reaching := _bout_with(_opening_then(4))
	var stubby := _bout_with(_opening_then(1))
	Fixtures.run_to_end(reaching)
	Fixtures.run_to_end(stubby)

	assert_eq(reaching.enemy_gauge(0).peak_state(), BreakState.Kind.KNOCKDOWN, "전제 확인 — 앞 켜를 눕혔다")
	assert_true(reaching.enemy_gauge(1).peak() > 0.0, "닿는 무기는 뒤 켜로 넘어간다")
	assert_eq(stubby.enemy_gauge(1).peak(), 0.0, "짧은 무기는 뒤 켜를 못 고른다")


## 앞 켜를 눕힐 만큼 큰 무기 다섯 타 + 그 뒤로 `cells` 칸 다섯 타.
func _opening_then(cells: int) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for _index in 5:
		items.append(Fixtures.sized(4))
	for _index in 5:
		items.append(Fixtures.sized(cells))
	return items


## 빠짐 없는 판. 눕힌 것이 도로 일어나면 「넘어갔나」를 못 가른다.
func _bout_with(items: Array[BackpackItem]) -> SparringBout:
	var field := _ranked([1, 1])
	field.target_choice = SparringField.TargetChoice.FINISH_OFF
	var bout := BoutScript.new(items, _tuning(0.0), field)
	bout.start()
	return bout
