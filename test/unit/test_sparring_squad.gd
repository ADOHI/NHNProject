extends GutTest
## **대원이 여럿일 때**, 그리고 **무너지면 못 치나.**
##
## `docs/design/28-combat.md` §28.20.36.
##
## ## 여기 있는 것도 값이 아니라 성질이다
##
## 「우리에게도 걸리나」는 §28.8 이 미정으로 뒀다. 그래서 붙드는 것은
## **기본값이 안 끊는다는 것**과 **켜면 못 친다는 것**과
## **켜도 체인이 사라지지는 않는다는 것** 셋뿐이다.

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const Fixtures := preload("res://test/support/sparring_fixtures.gd")

## 전원이 서로 리치 안이라 붙어서 싸우는 판.
const NEAR := 60.0
const TIGHT := 4.0


func _tuning(decay: float = 10.0) -> BreakTuning:
	return TuningScript.new(decay)


func _squad(count: int, hits: int, cells: int = 1) -> Array:
	var chains: Array = []
	for _index in count:
		chains.append(Fixtures.items(hits, cells))
	return chains


# ---------------------------------------------------------------- 대원이 여럿


func test_one_ally_is_still_the_default() -> void:
	# 대원 하나짜리 판이 대부분이라 번호를 안 줘도 0번이 나와야 한다.
	var bout := BoutScript.new(Fixtures.items(4), _tuning())
	assert_eq(bout.ally_count(), 1)
	assert_eq(bout.ally_total_hits(), 4)


func test_a_squad_gets_one_gauge_each() -> void:
	var bout := BoutScript.from_squad(_squad(3, 5), _tuning())
	assert_eq(bout.ally_count(), 3)
	for index in 3:
		assert_eq(bout.ally_total_hits(index), 5, "%d번 대원도 자기 체인을 가진다" % index)


func test_every_ally_swings() -> void:
	var bout := BoutScript.from_squad(_squad(3, 4), _tuning(), Fixtures.field_at(NEAR))
	bout.start()
	Fixtures.run_to_end(bout)
	for index in 3:
		assert_eq(bout.ally_landed(index), 4, "%d번 대원이 다 못 쳤다" % index)


func test_a_bigger_squad_breaks_the_enemy_faster() -> void:
	# **이것이 스쿼드 규모가 무엇을 하는지의 전부다** (§28.20.36).
	var alone := BoutScript.from_squad(_squad(1, 6), _tuning(), Fixtures.field_at(NEAR))
	var three := BoutScript.from_squad(_squad(3, 6), _tuning(), Fixtures.field_at(NEAR))
	alone.start()
	three.start()
	Fixtures.run_to_end(alone)
	Fixtures.run_to_end(three)
	assert_true(three.enemy_gauge(0).peak() > alone.enemy_gauge(0).peak(), "셋이 치면 더 많이 무너뜨린다")


func test_enemies_are_shared_out_among_the_allies() -> void:
	# **적 하나가 대원 하나를 문다** — 측정 가정이다 (§28.20.36).
	# 한 명에게 몰리면 나머지 대원의 눈금이 0 으로 남는다.
	var field := Fixtures.crowd(NEAR, TIGHT, 2)
	var bout := BoutScript.from_squad(_squad(2, 20), _tuning(), field, Fixtures.sized(1))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.ally_gauge(0).peak() > 0.0, "0번이 맞는다")
	assert_true(bout.ally_gauge(1).peak() > 0.0, "1번도 맞는다 — 한 명에게 몰리지 않는다")


func test_only_the_first_ally_drives_the_advance() -> void:
	# 필드에 대원 자리가 하나뿐이라 전원이 밀면 사람 수만큼 빨리 파고든다.
	var one := Fixtures.field_at(100.0)
	var three := Fixtures.field_at(100.0)
	one.advance_mode = SparringField.AdvanceMode.STAY
	three.advance_mode = SparringField.AdvanceMode.STAY
	var solo := BoutScript.from_squad(_squad(1, 3), _tuning(), one)
	var squad := BoutScript.from_squad(_squad(3, 3), _tuning(), three)
	solo.start()
	squad.start()
	Fixtures.run_to_end(solo)
	Fixtures.run_to_end(squad)
	assert_eq(three.gap(), one.gap(), "사람이 늘어도 파고드는 거리는 같다")
	assert_true(one.gap() < 100.0, "전제 확인 — 실제로 파고들었다")


# ---------------------------------------------------------------- 무너지면 못 치나


func test_by_default_being_broken_cuts_nothing() -> void:
	# **§28.8 이 미정으로 뒀다.** 기본값은 지금까지의 동작 그대로여야 한다.
	var tuning := _tuning()
	assert_eq(tuning.chain_cut_at, BreakState.Kind.NONE)
	for kind: BreakState.Kind in [
		BreakState.Kind.NONE,
		BreakState.Kind.STAGGER,
		BreakState.Kind.LAUNCH,
		BreakState.Kind.KNOCKDOWN
	]:
		assert_false(tuning.cuts_chain(kind), "꺼져 있으면 어느 단계에서도 안 끊는다")


func test_a_healthy_fighter_is_never_cut() -> void:
	var tuning := _tuning()
	tuning.chain_cut_at = BreakState.Kind.STAGGER
	assert_false(tuning.cuts_chain(BreakState.Kind.NONE), "멀쩡한 사람까지 끊기면 안 된다")
	assert_true(tuning.cuts_chain(BreakState.Kind.STAGGER))
	assert_true(tuning.cuts_chain(BreakState.Kind.KNOCKDOWN), "더 심한 단계도 끊긴다")


func test_turning_it_on_slows_our_chain_down() -> void:
	# 맞아서 무너진 동안에는 못 친다. 같은 시간에 낸 타가 줄어야 한다.
	var field := Fixtures.crowd(NEAR, TIGHT, 3)
	var loose := BoutScript.from_squad(_squad(1, 40), _tuning(), field, Fixtures.sized(4))
	var cutting_tuning := _tuning()
	cutting_tuning.chain_cut_at = BreakState.Kind.STAGGER
	var cut := BoutScript.from_squad(
		_squad(1, 40), cutting_tuning, Fixtures.crowd(NEAR, TIGHT, 3), Fixtures.sized(4)
	)
	loose.start()
	cut.start()
	for _frame in 3000:
		loose.tick(1.0 / 120.0)
		cut.tick(1.0 / 120.0)
	assert_true(cut.ally_landed() < loose.ally_landed(), "무너진 동안 못 치면 타가 줄어야 한다")


func test_the_chain_is_delayed_not_erased() -> void:
	# **지우는 것은 「무너진 뒤에 무엇이 되나」를 정하는 것이다** (§28.5 미정).
	# 눈금이 빠지면 다시 쳐야 한다.
	var tuning := _tuning(40.0)
	tuning.chain_cut_at = BreakState.Kind.STAGGER
	var bout := BoutScript.from_squad(_squad(1, 6), tuning, Fixtures.field_at(NEAR))
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.ally_landed(), 6, "미룬 것이지 지운 것이 아니다")
	assert_eq(bout.ally_stop(), SparringBout.Stop.COMPLETED)


func test_a_broken_enemy_stops_hitting_us() -> void:
	# **한쪽만 걸면 무너뜨리는 것이 한쪽에게만 이득이 된다.**
	#
	# 빠짐을 0 으로 두고 **빠른 무기로 먼저 무너뜨린다** — 그러면 적이 굳은 채로 남아
	# "그 뒤로 한 대도 못 때린다" 가 또렷하게 갈린다. 빠짐을 켜면 굳었다 풀렸다 하고,
	# 그때는 우리 체인도 같이 밀려서 무엇 때문에 줄었는지 못 가른다.
	var loose := BoutScript.from_squad(
		_squad(1, 30), _tuning(0.0), Fixtures.field_at(NEAR), Fixtures.sized(4)
	)
	var cutting_tuning := _tuning(0.0)
	cutting_tuning.chain_cut_at = BreakState.Kind.STAGGER
	var cut := BoutScript.from_squad(
		_squad(1, 30), cutting_tuning, Fixtures.field_at(NEAR), Fixtures.sized(4)
	)
	loose.start()
	cut.start()
	Fixtures.run_to_end(loose)
	Fixtures.run_to_end(cut)
	assert_true(loose.enemy_landed() > 1, "전제 확인 — 안 끊는 판에서는 적이 여러 대 때린다")
	assert_true(cut.enemy_landed() < loose.enemy_landed(), "무너뜨린 적은 그동안 못 때린다")
	assert_eq(cut.ally_landed(), 30, "먼저 무너뜨렸으니 우리 체인은 끝까지 나간다")


# ---------------------------------------------------------------- 누구를 때리나


func test_nearest_is_still_the_default() -> void:
	# **§28.20.37 은 규칙을 넷으로 늘렸을 뿐 고르지 않았다.**
	assert_eq(SparringField.new().target_choice, SparringField.TargetChoice.NEAREST)


func test_by_default_everyone_piles_on_the_front_one() -> void:
	# **이것이 §28.20.36 이 잡은 것이다** — 뒷줄이 영영 안 맞는다.
	var bout := _crowd_bout(2, 2, SparringField.TargetChoice.NEAREST)
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0, "앞의 적은 맞는다")
	assert_eq(bout.enemy_gauge(1).peak(), 0.0, "뒷줄은 한 대도 안 맞는다")


func test_by_number_spreads_the_squad_across_the_line() -> void:
	var bout := _crowd_bout(2, 2, SparringField.TargetChoice.BY_NUMBER)
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0)
	assert_true(bout.enemy_gauge(1).peak() > 0.0, "1번 대원이 1번 적에게 간다")


func test_least_targeted_spreads_even_with_one_ally() -> void:
	# 대원 하나여도 번갈아 때린다 — 「퍼뜨린다」가 사람 수와 무관한 규칙이다.
	var bout := _crowd_bout(1, 2, SparringField.TargetChoice.LEAST_TARGETED)
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(1).peak() > 0.0, "안 맞은 놈에게 넘어간다")


func test_finish_off_moves_on_once_one_is_down() -> void:
	# **지금 규칙의 진짜 문제는 「모은다」가 아니라 「안 넘어간다」였다** (§28.20.37).
	var bout := _crowd_bout(1, 2, SparringField.TargetChoice.FINISH_OFF)
	Fixtures.run_to_end(bout)
	assert_eq(bout.enemy_gauge(0).peak_state(), BreakState.Kind.KNOCKDOWN, "먼저 하나를 끝까지 눕힌다")
	assert_true(bout.enemy_gauge(1).peak() > 0.0, "다 눕고 나면 다음으로 넘어간다")


## 적이 붙어 서 있고 우리가 오래 치는 판. 규칙 말고는 아무것도 안 다르다.
func _crowd_bout(squad: int, enemies: int, rule: SparringField.TargetChoice) -> SparringBout:
	var field := Fixtures.crowd(NEAR, TIGHT, enemies)
	field.target_choice = rule
	var bout := BoutScript.from_squad(_squad(squad, 60), _tuning(), field)
	bout.start()
	return bout


# ---------------------------------------------------------------- 우두머리


func test_an_enemy_is_a_monster_until_told_otherwise() -> void:
	# §28.10 이 몬스터와 사람을 갈랐지만 **싸우는 방식은 안 갈린다** — 판정만 갈린다.
	var enemy := SparringEnemy.new()
	assert_eq(enemy.kind, SparringEnemy.Kind.MONSTER)
	assert_false(enemy.is_leader)


func test_leader_first_goes_for_the_one_at_the_back() -> void:
	# **우두머리는 특정한 하나다.** 아무 규칙도 안 노리면 제일 늦게 눕는다 (§28.20.44).
	var field := Fixtures.crowd(NEAR, TIGHT, 3)
	field.enemy_at(2).is_leader = true
	field.target_choice = SparringField.TargetChoice.LEADER_FIRST
	var bout := BoutScript.from_squad(_squad(1, 40), _tuning(0.0), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_eq(bout.enemy_gauge(2).peak_state(), BreakState.Kind.KNOCKDOWN, "맨 뒤 우두머리를 먼저 눕힌다")
	assert_eq(bout.enemy_gauge(0).peak(), 0.0, "가까운 적은 아직 안 맞았다")


func test_a_hidden_leader_cannot_be_targeted() -> void:
	# **모르면 못 노린다** (§28.20.47). 규칙이 있어도 대상을 모르면 거리순으로 떨어진다.
	var field := Fixtures.crowd(NEAR, TIGHT, 3)
	field.enemy_at(2).is_leader = true
	field.target_choice = SparringField.TargetChoice.LEADER_FIRST
	field.leader_knowledge = SparringField.LeaderKnowledge.HIDDEN
	var bout := BoutScript.from_squad(_squad(1, 40), _tuning(0.0), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0, "모르면 가까운 것부터 친다")


func test_a_leader_learned_by_hitting_is_known_only_after_a_hit() -> void:
	# **「때려 봐야 안다」는 그를 한 대라도 맞힌 뒤부터다** — 그 전에는 그냥 적 하나다.
	var field := Fixtures.crowd(NEAR, TIGHT, 2)
	field.enemy_at(1).is_leader = true
	field.target_choice = SparringField.TargetChoice.LEADER_FIRST
	field.leader_knowledge = SparringField.LeaderKnowledge.ON_HIT
	var bout := BoutScript.from_squad(_squad(1, 40), _tuning(0.0), field)
	bout.start()
	Fixtures.run_to_end(bout)
	assert_true(bout.enemy_gauge(0).peak() > 0.0, "처음에는 우두머리를 못 알아본다")
