extends GutTest
## **적이 여럿일 때.** 걸치는가 · 누구를 때리는가 · 시계가 안 어긋나는가.
##
## `docs/design/28-combat.md` §28.20.34.
##
## ## 여기 있는 것은 전부 「자리」지 결정이 아니다
##
## 걸침 인원(`splash_*`)도 고르는 규칙(`TargetChoice`)도 **미정**이다.
## 그래서 테스트가 붙드는 것은 **값이 아니라 성질**이다 —
## 기본값이 하나를 때린다는 것, 늘리면 둘을 때린다는 것, 그리고 그 규칙이
## 리치 안에서만 돈다는 것.

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const FieldScript := preload("res://src/core/combat/sparring_field.gd")
const Fixtures := preload("res://test/support/sparring_fixtures.gd")

## 1칸 리치 104 · 4칸 리치 118. 이 사이에 둘째 적을 세우면
## **작은 무기는 못 닿고 큰 무기는 닿는다.**
const NEAR := 96.0
const SPACING := 16.0


func _tuning(decay: float = 20.0) -> BreakTuning:
	return TuningScript.new(decay)


func _volume_splash(decay: float = 20.0) -> BreakTuning:
	var tuning := TuningScript.new(decay)
	tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
	tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL
	return tuning


# ---------------------------------------------------------------- 줄 세우기


func test_a_field_holds_a_list_even_with_one_enemy() -> void:
	# 하나를 특별 취급해 두면 여럿이 될 때 판정하는 쪽이 두 갈래로 갈린다.
	var field := FieldScript.new(0.0, 240.0)
	assert_eq(field.enemy_count(), 1)
	assert_eq(field.gap(), 240.0)


func test_the_gap_is_to_the_nearest_enemy() -> void:
	var field := Fixtures.crowd(NEAR, SPACING, 3)
	assert_eq(field.enemy_count(), 3)
	assert_eq(field.gap(), NEAR, "간격은 가장 가까운 적까지다")
	assert_eq(field.target_index(), 0)


func test_the_chosen_one_is_the_nearest_even_when_it_is_last_in_the_list() -> void:
	# **고르는 규칙은 목록 순서가 아니라 거리다** (§28.20.34 물음 ②).
	var field := FieldScript.new()
	field.reset_with(0.0, PackedFloat32Array([200.0, 60.0, 130.0]))
	assert_eq(field.target_index(), 1)
	assert_eq(field.gap(), 60.0)


func test_advancing_stops_at_the_nearest_not_the_farthest() -> void:
	var field := Fixtures.crowd(NEAR, SPACING, 3)
	field.advance(999.0)
	assert_eq(field.attacker_x, NEAR, "고른 적을 지나치지 않는다")
	assert_eq(field.facing(), 1.0, "방향이 뒤집히면 안 된다")


# ---------------------------------------------------------------- 닿는 범위가 걸치는 범위다


func test_reach_decides_who_is_even_a_candidate() -> void:
	var field := Fixtures.crowd(NEAR, SPACING, 3)
	assert_eq(field.targets_within(104.0, 9).size(), 1, "1칸 리치로는 앞의 하나뿐이다")
	assert_eq(field.targets_within(118.0, 9).size(), 2, "4칸 리치면 둘째까지 든다")


func test_targets_come_back_nearest_first() -> void:
	var field := FieldScript.new()
	field.reset_with(0.0, PackedFloat32Array([90.0, 30.0, 60.0]))
	var found := field.targets_within(100.0, 9)
	assert_eq(found, PackedInt32Array([1, 2, 0]), "가까운 것부터다")


func test_nobody_behind_us_is_hit() -> void:
	# 지나쳐 온 적이 계속 맞으면 전진이 곧 후방 공격이 된다.
	var field := FieldScript.new()
	field.reset_with(50.0, PackedFloat32Array([120.0]))
	field.attacker_x = 80.0
	field.add_enemy(20.0)
	assert_eq(field.targets_within(200.0, 9), PackedInt32Array([0]), "등 뒤는 안 맞는다")


func test_the_limit_caps_how_many_are_swept() -> void:
	var field := Fixtures.crowd(NEAR, SPACING, 3)
	assert_eq(field.targets_within(200.0, 1).size(), 1)
	assert_eq(field.targets_within(200.0, 2).size(), 2)


# ---------------------------------------------------------------- 걸침 인원


func test_by_default_a_hit_lands_on_one_enemy_only() -> void:
	# **기본값이 한 명인 것은 「하나만 때린다」를 고른 것이 아니라 아무것도 안 고른 것이다.**
	var tuning := _tuning()
	for cells: int in [1, 2, 3, 4]:
		assert_eq(tuning.splash_targets_for(Fixtures.sized(cells)), 1, "%d칸도 한 명이다" % cells)


func test_the_volume_dial_makes_big_weapons_sweep() -> void:
	var tuning := _volume_splash()
	assert_eq(tuning.splash_targets_for(Fixtures.sized(1)), 1)
	assert_eq(tuning.splash_targets_for(Fixtures.sized(4)), 2)


func test_only_the_chosen_one_takes_the_hit_by_default() -> void:
	var field := Fixtures.crowd(NEAR, SPACING, 2)
	var bout := BoutScript.new(Fixtures.items(4, 4), _tuning(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0, "앞의 적은 맞는다")
	assert_eq(bout.enemy_gauge(1).peak(), 0.0, "걸침이 꺼져 있으면 뒤의 적은 안 맞는다")
	assert_eq(bout.spread_at(0), 1)


func test_with_the_dial_on_a_big_weapon_hits_two() -> void:
	# **리치가 곧 걸치는 범위다** — 4칸은 118 까지 닿아서 112 에 선 둘째가 든다.
	var field := Fixtures.crowd(NEAR, SPACING, 2)
	var bout := BoutScript.new(Fixtures.items(4, 4), _volume_splash(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(1).peak() > 0.0, "뒤의 적도 맞는다")
	assert_eq(bout.spread_at(0), 2)


func test_the_dial_cannot_reach_past_the_weapon() -> void:
	# 걸침을 켜도 **안 닿는 것은 안 맞는다.** 인원이 범위를 늘리지 않는다.
	var field := Fixtures.crowd(NEAR, 60.0, 2)
	var bout := BoutScript.new(Fixtures.items(4, 4), _volume_splash(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0)
	assert_eq(bout.enemy_gauge(1).peak(), 0.0, "리치 밖은 걸침으로도 못 때린다")


func test_a_small_weapon_still_hits_only_one_with_the_dial_on() -> void:
	var field := Fixtures.crowd(NEAR, SPACING, 2)
	var bout := BoutScript.new(Fixtures.items(6, 1), _volume_splash(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.spread_at(0), 1, "1칸은 인원도 하나고 리치도 짧다")


# ---------------------------------------------------------------- 여럿이 반격한다


func test_every_armed_enemy_hits_us() -> void:
	# **빠짐을 켜 둔 채로 잰다.** 안 켜면 둘 다 눈금 상한(100)에 붙어서
	# "셋이 더 무섭다" 가 안 보인다 — 오래 돌리면 하나짜리도 결국 다 채운다.
	var field := Fixtures.crowd(60.0, 8.0, 3)
	var bout := BoutScript.new(Fixtures.items(12), _tuning(20.0), field, Fixtures.sized(1))
	bout.start()
	Fixtures.run_to_end(bout)
	var alone := BoutScript.new(
		Fixtures.items(12), _tuning(20.0), Fixtures.field_at(60.0), Fixtures.sized(1)
	)
	alone.start()
	Fixtures.run_to_end(alone)
	assert_true(bout.enemy_landed() > alone.enemy_landed(), "셋이 때리면 더 많이 맞는다")
	assert_true(bout.ally_gauge().peak() > alone.ally_gauge().peak(), "우리가 더 빨리 무너진다")


func test_a_far_enemy_swings_but_misses() -> void:
	# 적은 못 닿으면 그냥 헛친다 — 우리처럼 판을 끝내지 않는다.
	var field := Fixtures.crowd(60.0, 400.0, 2)
	var bout := BoutScript.new(Fixtures.items(10), _tuning(0.0), field, Fixtures.sized(1))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_landed() > 0, "가까운 적은 때린다")
	assert_eq(bout.ally_stop(), SparringBout.Stop.COMPLETED, "먼 적이 헛쳐도 판은 끝까지 간다")


# ---------------------------------------------------------------- 시계가 어긋나면 안 된다


func test_a_crowd_still_matches_across_lumpy_frames() -> void:
	# **적이 셋이면 사건이 셋으로 는다.** 몰아 처리하면 눈금이 잘못된 시점에 빠져
	# 프레임 길이에 따라 결과가 달라진다.
	var tuning := _tuning()
	var fine := BoutScript.new(
		Fixtures.items(9), tuning, Fixtures.crowd(60.0, 8.0, 3), Fixtures.sized(1)
	)
	var lumpy := BoutScript.new(
		Fixtures.items(9), tuning, Fixtures.crowd(60.0, 8.0, 3), Fixtures.sized(1)
	)
	fine.start()
	lumpy.start()
	Fixtures.run_to_end(fine, 1.0 / 480.0)
	for _frame in 300:
		if not lumpy.is_running():
			break
		lumpy.tick(Fixtures.strike(tuning) * 2.7)

	assert_eq(lumpy.ally_landed(), fine.ally_landed(), "타가 사라지면 안 된다")
	assert_almost_eq(
		lumpy.ally_gauge().peak(), fine.ally_gauge().peak(), 0.5, "프레임이 튀어도 우리 눈금이 같아야 한다"
	)
	assert_almost_eq(lumpy.enemy_gauge(0).peak(), fine.enemy_gauge(0).peak(), 0.5, "적 눈금도 같아야 한다")


func test_one_enemy_still_matches_the_simulator() -> void:
	# **여럿을 넣었다고 하나짜리가 달라지면 안 된다.** 계산기와의 일치가 이 판의 기준선이다.
	var tuning := _tuning()
	var expected := ChainBreakSim.run_items(Fixtures.items(6), tuning)
	var bout := BoutScript.new(Fixtures.items(6), tuning, Fixtures.field_at(60.0))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_almost_eq(bout.enemy_gauge(0).peak(), expected.peak, 0.5)
