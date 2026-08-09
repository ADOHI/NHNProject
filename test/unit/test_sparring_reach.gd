extends GutTest
## **닿는가**, 그리고 **적도 때리는가.**
##
## `docs/design/28-combat.md` §28.20.27 · §28.20.30 · §28.20.31.
##
## `test_sparring_bout.gd` 에서 갈라져 나왔다 — 한 파일에 스무 개가 넘어가서이기도 하고,
## 여기 있는 것은 전부 **거리가 걸린 이야기**라 한곳에 모이는 편이 낫다.
##
## 「닿지 않는다」는 **체이닝 조건이 아니다** (§28.20.27).
## 조건은 아이템끼리의 문제라 백팩을 볼 때 이미 정해지고,
## 이것은 **필드에서 그 순간에만** 정해진다.

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const Fixtures := preload("res://test/support/sparring_fixtures.gd")


func _tuning(decay: float = 20.0) -> BreakTuning:
	return TuningScript.new(decay)


# ---------------------------------------------------------------- 닿지 않는다


func test_a_chain_stops_when_the_weapon_cannot_reach() -> void:
	# **백팩에서는 이어지는데 필드에서 못 나간다.** 격자 이유와 다른 층이다.
	var bout := BoutScript.new(Fixtures.items(5), _tuning(), Fixtures.field_at(400.0))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.landed(), 0, "한 대도 못 닿는다")
	assert_eq(bout.stop_reason(), SparringBout.Stop.OUT_OF_REACH)


func test_a_chain_completes_when_in_range() -> void:
	var bout := BoutScript.new(Fixtures.items(5), _tuning(), Fixtures.field_at(60.0))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.landed(), 5)
	assert_eq(bout.stop_reason(), SparringBout.Stop.COMPLETED)


func test_without_a_field_there_is_no_distance_judgement() -> void:
	# 눈금만 보던 옛 사용처가 그대로 돌아야 한다.
	var bout := BoutScript.new(Fixtures.items(4), _tuning())
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.landed(), 4)
	assert_eq(bout.stop_reason(), SparringBout.Stop.COMPLETED)


func test_staying_forward_closes_the_gap_while_it_lands() -> void:
	# 닿는 거리 안에서 시작하면 때릴 때마다 파고든다.
	var field := Fixtures.field_at(100.0)
	field.advance_mode = SparringField.AdvanceMode.STAY
	var bout := BoutScript.new(Fixtures.items(6), _tuning(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.landed(), 6, "닿는 데서 시작하면 계속 닿는다")
	assert_true(field.gap() < 100.0, "간격이 줄어 있어야 한다")


func test_out_of_reach_can_never_close_by_itself() -> void:
	# **전진은 때려야 생긴다.** 그래서 못 닿으면 영영 못 붙는다 —
	# 붙는 것은 이 대련장 밖(§28.4 의 RTS 자동 이동)의 일이다.
	var field := Fixtures.field_at(140.0)
	field.advance_mode = SparringField.AdvanceMode.STAY
	var bout := BoutScript.new(Fixtures.items(12), _tuning(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.landed(), 0)
	assert_eq(field.gap(), 140.0, "한 발짝도 못 나간다")
	assert_eq(bout.stop_reason(), SparringBout.Stop.OUT_OF_REACH)


func test_a_long_weapon_opens_where_a_short_one_cannot() -> void:
	# **큰 무기가 받는 값은 「멀리서 시작할 수 있다」다** — 리치는 개전 능력이다.
	var gap := 112.0
	var dagger := BoutScript.new(Fixtures.items(3), _tuning(), Fixtures.field_at(gap))
	var reaching := BoutScript.new(Fixtures.items(3, 4), _tuning(), Fixtures.field_at(gap))
	dagger.start()
	reaching.start()
	Fixtures.run_to_end(dagger)
	Fixtures.run_to_end(reaching)
	assert_eq(dagger.landed(), 0, "단검은 이 거리에서 못 연다")
	assert_true(reaching.landed() > 0, "대검은 같은 거리에서 연다")


# ---------------------------------------------------------------- 적도 때린다


func test_without_an_enemy_weapon_nothing_hits_us() -> void:
	# 눈금만 보던 옛 사용처가 그대로 돌아야 한다.
	var bout := BoutScript.new(Fixtures.items(6), _tuning(), Fixtures.field_at(60.0))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_false(bout.has_enemy())
	assert_eq(bout.own_gauge().value(), 0.0, "반격이 없으면 우리 눈금은 안 오른다")
	assert_eq(bout.enemy_landed(), 0)


func test_the_enemy_hits_back() -> void:
	# **이게 없으면 대련장이 샌드백이다.**
	var bout := BoutScript.new(
		Fixtures.items(12), _tuning(), Fixtures.field_at(60.0), Fixtures.sized(1)
	)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.has_enemy())
	assert_true(bout.enemy_landed() > 0, "적이 한 대도 못 때리면 반격이 아니다")
	assert_true(bout.own_gauge().peak() > 0.0, "우리 눈금이 올라야 한다")


func test_our_gauge_can_reach_a_break_state() -> void:
	var bout := BoutScript.new(
		Fixtures.items(30), _tuning(0.0), Fixtures.field_at(60.0), Fixtures.sized(1)
	)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(
		BreakState.is_worse(bout.own_gauge().peak_state(), BreakState.Kind.NONE), "오래 맞으면 우리도 무너진다"
	)


func test_being_hit_does_not_cut_our_chain() -> void:
	# **§28.8 이 「우리에게도 걸리나」를 미정으로 뒀다.**
	# 애니 레인의 반응 층도 「때리다 맞아도 스윙이 안 끊긴다」이므로 지금은 안 끊는다.
	var bout := BoutScript.new(
		Fixtures.items(10), _tuning(0.0), Fixtures.field_at(60.0), Fixtures.sized(4)
	)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.landed(), 10, "맞아도 우리 체인은 끝까지 나간다")
	assert_eq(bout.stop_reason(), SparringBout.Stop.COMPLETED)


func test_a_heavier_enemy_weapon_breaks_us_faster() -> void:
	var light := BoutScript.new(
		Fixtures.items(20), _tuning(0.0), Fixtures.field_at(60.0), Fixtures.sized(1)
	)
	var heavy := BoutScript.new(
		Fixtures.items(20), _tuning(0.0), Fixtures.field_at(60.0), Fixtures.sized(4)
	)
	light.start()
	heavy.start()
	Fixtures.run_to_end(light)
	Fixtures.run_to_end(heavy)
	assert_true(heavy.own_gauge().peak() > 0.0 and light.own_gauge().peak() > 0.0)
	assert_true(
		(
			heavy.own_gauge().peak() / maxf(1.0, float(heavy.enemy_landed()))
			> light.own_gauge().peak() / maxf(1.0, float(light.enemy_landed()))
		),
		"무거운 무기가 한 방에 더 올린다"
	)


func test_the_enemy_cannot_hit_from_out_of_reach() -> void:
	# 적도 닿아야 때린다. 다만 못 닿아도 판을 끝내지는 않는다 — 헛칠 뿐이다.
	var bout := BoutScript.new(
		Fixtures.items(5), _tuning(), Fixtures.field_at(400.0), Fixtures.sized(1)
	)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.enemy_landed(), 0, "멀면 적도 못 때린다")
	assert_eq(bout.own_gauge().value(), 0.0)


func test_both_gauges_drain_together() -> void:
	var bout := BoutScript.new(
		Fixtures.items(8), _tuning(20.0), Fixtures.field_at(60.0), Fixtures.sized(1)
	)
	bout.start()
	Fixtures.run_to_end(bout)
	# 마무리 관찰이 끝나면 둘 다 빠져 있어야 한다.
	assert_true(bout.enemy_gauge(0).value() < bout.enemy_gauge(0).peak(), "적 눈금이 빠졌다")
	assert_true(bout.own_gauge().value() < bout.own_gauge().peak(), "우리 눈금도 빠졌다")
