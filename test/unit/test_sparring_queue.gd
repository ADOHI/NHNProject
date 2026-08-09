extends GutTest
## **줄이 메워지는 판이 기본값이다.** 다가옴과 빠짐을 지킨다.
##
## `docs/design/28-combat.md` §28.20.55.
##
## ## 왜 이 파일이 따로 있나
##
## 다른 대련 테스트는 `Fixtures.still()` 로 **일부러 게임 기본값이 아닌 판**을 쓴다 —
## 자리가 움직이면 리치와 표적 규칙을 못 가르기 때문이다.
## 그러면 **기본값을 아무도 안 지키게 된다.** 그것을 여기서 지킨다.
##
## ## 붙드는 것은 값이 아니라 **관계**다
##
## 다가오는 속력은 이동 레인의 `max_speed` 에서 온다. 그 수가 옮겨지면 여기도 같이
## 옮겨져야 하므로 **수를 적지 않고 관계를 적는다** (§28.20.50).

const BoutScript := preload("res://src/core/combat/sparring_bout.gd")
const TuningScript := preload("res://src/core/combat/break_tuning.gd")
const FieldScript := preload("res://src/core/combat/sparring_field.gd")
const Fixtures := preload("res://test/support/sparring_fixtures.gd")

## 앞 켜가 서는 거리 (§28.20.50 이 리치에서 뽑는다).
const FRONT := 96.0


func _tuning(decay: float = 10.0) -> BreakTuning:
	return TuningScript.new(decay)


# ---------------------------------------------------------------- 기본값


func test_enemies_walk_in_by_default() -> void:
	# 사용자가 정했다 — *"전투 물량은 적이 다가오는 거"* (§28.20.55).
	assert_true(FieldScript.new().approach_speed > 0.0, "적은 기본으로 다가온다")


func test_the_walking_speed_comes_from_the_movement_lane() -> void:
	# **수를 지어내지 않는다.** 계단의 평평한 쪽이라 아무 수나 되는데,
	# 그러면 **고를 이유가 있는 수**를 고른다 (§28.20.50).
	var moving := ProtoMoveTuning.new()
	assert_eq(FieldScript.new().approach_speed, moving.default_of("max_speed"))


func test_the_downed_leave_by_default() -> void:
	# §28.10 이 확정한 것이 이제 대련장에도 들어왔다 (§28.20.55).
	assert_true(FieldScript.new().downed_leave, "쓰러진 적은 판에서 빠진다")


# ---------------------------------------------------------------- 다가옴


func test_walking_closes_a_gap_that_swinging_never_could() -> void:
	# §28.20.27 이 **전진은 때려야 생긴다**로 잡아 뒀다. 그래서 못 닿으면 영영 못 붙었다.
	# 다가옴은 그 매듭을 **적 쪽에서** 푼다.
	var field := FieldScript.new(0.0, 400.0)
	field.close_in(1.0)
	assert_true(field.gap() < 400.0, "걸어온다")


func test_walking_stops_at_the_opening_gap_not_on_top_of_us() -> void:
	# 겹쳐 서면 자리가 뜻을 잃는다. **개전 거리까지만** 온다.
	var field := FieldScript.new(0.0, 400.0)
	for _step in 100:
		field.close_in(1.0)
	assert_almost_eq(field.gap(), WeaponMotion.opening_gap_px(), 0.01)


func test_a_vacated_slot_does_not_block_the_line() -> void:
	# **빠진 적은 자리를 비운다** — 시체가 길을 막으면 줄이 안 메워진다.
	var field := Fixtures.ranks(FRONT, [1, 1])
	field.approach_speed = FieldScript.new().approach_speed
	var behind := field.gap_to(1)
	for _step in 100:
		field.close_in(1.0, PackedInt32Array([0]))
	assert_true(field.gap_to(1) < behind, "앞이 빠지면 뒤가 그 자리로 들어온다")
	assert_almost_eq(field.gap_to(1), WeaponMotion.opening_gap_px(), 0.01)


# ---------------------------------------------------------------- 둘 다 있어야 한다


func test_one_knob_alone_leaves_the_back_rank_untouched() -> void:
	# **§28.20.55 의 요점이다.** 앞줄이 안 비면 뒤가 들어올 자리가 없고,
	# 자리가 비어도 아무도 안 걸어오면 그 자리는 계속 빈 채다.
	assert_eq(_back_rank_peak(true, false), 0.0, "다가와도 앞줄이 안 빠지면 뒤는 못 온다")
	assert_eq(_back_rank_peak(false, true), 0.0, "빠져도 아무도 안 걸어오면 자리가 빈 채다")


func test_both_knobs_together_bring_the_back_rank_into_reach() -> void:
	assert_true(_back_rank_peak(true, true) > 0.0, "둘 다 켜야 뒷줄이 맞기 시작한다")


## 뒤 켜에 선 적이 받은 눈금. **1칸 무기는 뒤 켜에 절대 안 닿는다** (§28.20.40) —
## 그러니 0 이 아니게 되는 길은 **그 적이 앞으로 걸어오는 것**뿐이다.
func _back_rank_peak(walks: bool, leaves: bool) -> float:
	var field := Fixtures.ranks(FRONT, [1, 1])
	field.target_choice = FieldScript.TargetChoice.FINISH_OFF
	field.downed_leave = leaves
	if walks:
		field.approach_speed = FieldScript.new().approach_speed
	var bout := BoutScript.new(Fixtures.items(200), _tuning(), field)
	bout.start()
	Fixtures.run_to_end(bout)
	return bout.enemy_gauge(1).peak()
