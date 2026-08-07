extends GutTest
## TurnIntent · TurnPhase 의 단위 테스트.
##
## 이 둘은 2단계의 **공유 어휘**다. 해결기 · NPC 행동 결정 · 화면이 모두 이것을 통해
## 대화하므로, 모양이 흔들리면 세 곳이 동시에 어긋난다. 계약을 여기서 못 박는다.

const IntentScript := preload("res://src/core/turn/turn_intent.gd")
const PhaseScript := preload("res://src/core/turn/turn_phase.gd")

# ---------------------------------------------------------------- TurnIntent


func test_move_carries_destination() -> void:
	var intent: TurnIntent = IntentScript.move("squad", "west_hall")
	assert_eq(intent.actor_id, "squad")
	assert_eq(intent.kind, TurnIntent.Kind.MOVE)
	assert_eq(intent.target_room_id, "west_hall")
	assert_true(intent.is_move())


func test_stay_is_explicit_not_empty() -> void:
	# 의도를 내지 않은 주체도 STAY 를 받는다. 해결기가 모두를 같은 방식으로 훑기 위해서다.
	var intent: TurnIntent = IntentScript.stay("guard")
	assert_eq(intent.kind, TurnIntent.Kind.STAY)
	assert_false(intent.is_move())
	assert_false(intent.changes_board(), "제자리는 아무 사건도 남기지 않는다")


func test_search_changes_board() -> void:
	var intent: TurnIntent = IntentScript.search("squad")
	assert_eq(intent.kind, TurnIntent.Kind.SEARCH)
	assert_true(intent.changes_board(), "탐색은 사건으로 남는다")


func test_non_move_intent_never_holds_destination() -> void:
	# 목적지가 남아 있으면 해결기가 STAY 를 이동으로 오해할 여지가 생긴다.
	var intent: TurnIntent = IntentScript.new("squad", TurnIntent.Kind.STAY, "west_hall")
	assert_eq(intent.target_room_id, "", "MOVE 가 아니면 목적지는 비워진다")


# ---------------------------------------------------------------- TurnPhase


func test_only_planning_accepts_input() -> void:
	# 행동 페이즈에 조작이 들어오면 동시성이 깨진다 (docs/design/03-core-loop.md §3.6).
	assert_true(PhaseScript.accepts_input(TurnPhase.Kind.PLANNING))
	assert_false(PhaseScript.accepts_input(TurnPhase.Kind.ACTION))


func test_phase_labels_exist() -> void:
	assert_eq(PhaseScript.label(TurnPhase.Kind.PLANNING), "계획")
	assert_eq(PhaseScript.label(TurnPhase.Kind.ACTION), "행동")
