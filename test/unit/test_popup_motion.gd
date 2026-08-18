extends GutTest
## `PopupMotion` — 팝업의 열림과 닫힘.
##
## 여기서 잠그는 것은 **「닫힘이 열림의 역재생이 아닌가」**다. 되감기로 만들면
## 싸구려로 읽히고, 그건 규칙 위반이기도 하다 — **사건이 둘이면 같은 축의 양끝을
## 써야 구분이 산다.** 역재생은 같은 축을 되짚는 것이라 두 사건이 한 몸이 된다.

const PIECES: int = 5


func _opened(at: float) -> PopupMotion:
	var motion := PopupMotion.new()
	motion.phase = PopupMotion.Phase.OPENING
	motion.open()
	motion.advance(at)
	return motion


func test_nothing_shows_before_it_opens() -> void:
	var motion := PopupMotion.new()
	motion.advance(2.0)
	assert_eq(motion.presence(), 0.0, "안 연 팝업은 화면에 없다")
	assert_eq(motion.veil(), 0.0, "뒤도 안 어두워진다")
	assert_eq(motion.content(), 0.0, "내용도 없다")


## 조각이 한꺼번에 오면 판 하나가 커지는 것이고, 차례로 와야 **조립되는 것**이다.
func test_pieces_arrive_one_after_another() -> void:
	var motion := _opened(0.05)
	var arrived := 0
	for i in PIECES:
		if motion.piece(i, PIECES) > 0.01:
			arrived += 1
	assert_lt(arrived, PIECES, "열림 초반에는 아직 안 온 조각이 있어야 한다")
	assert_gt(arrived, 0, "그래도 몇은 이미 와 있어야 한다")


func test_middle_piece_arrives_before_the_edges() -> void:
	var motion := _opened(0.06)
	assert_gt(motion.piece(2, PIECES), motion.piece(0, PIECES), "가운데부터 와야 글이 옆에서 밀려드는 것으로 안 보인다")


func test_pieces_overshoot_their_place() -> void:
	var peak := 0.0
	var motion := PopupMotion.new()
	motion.phase = PopupMotion.Phase.OPENING
	motion.open()
	for i in 60:
		motion.advance(0.01)
		peak = maxf(peak, motion.piece(2, PIECES))
	assert_gt(peak, 1.02, "조각이 제자리를 지나쳤다 되돌아와야 맞물린 것으로 읽힌다")


## 뒤는 판보다 **먼저** 자리잡는다. 같이 오면 판이 어디에서 왔는지 안 보인다.
func test_the_backdrop_settles_before_the_panel() -> void:
	var motion := _opened(0.10)
	assert_gt(motion.veil(), motion.piece(0, PIECES), "뒤가 판보다 앞서야 한다")


## 내용은 판이 다 온 **뒤에** 든다. 같이 오면 글자가 날아다녀 읽기를 방해한다.
func test_content_arrives_after_the_panel() -> void:
	var motion := _opened(0.12)
	assert_lt(motion.content(), motion.piece(2, PIECES), "글자가 판보다 늦게 들어야 한다")


func test_closing_is_faster_than_opening() -> void:
	assert_lt(PopupMotion.CLOSE_TIME, PopupMotion.PIECE_TIME, "닫힘이 열림만큼 길면 굼떠 보인다")


## **역재생이 아니라는 것.** 닫힘에서는 조각이 제자리로 돌아가는 것이 아니라 접힌다.
func test_closing_folds_instead_of_rewinding() -> void:
	var motion := _opened(1.0)
	motion.close()
	motion.advance(0.10)
	assert_gt(motion.fold(), 0.0, "닫힘은 접는 것이다")
	assert_eq(motion.piece(0, PIECES), 1.0, "조각은 제자리에 그대로 있다 — 되짚지 않는다")


func test_closing_folds_from_the_outside_in() -> void:
	var motion := _opened(1.0)
	motion.close()
	motion.advance(0.06)
	assert_gt(
		motion.fold_of(0, PIECES),
		motion.fold_of(2, PIECES),
		"열림은 가운데부터, 닫힘은 바깥부터 — 순서가 반대라야 두 사건이 갈린다"
	)


## 뒤는 판이 다 접힌 뒤에 걷힌다. 같이 사라지면 판이 어디로 갔는지 안 보인다.
func test_the_backdrop_lingers_after_the_panel_is_gone() -> void:
	var motion := _opened(1.0)
	motion.close()
	motion.advance(PopupMotion.CLOSE_TIME)
	assert_almost_eq(motion.presence(), 0.0, 0.02, "판은 이미 갔다")
	assert_gt(motion.veil(), 0.05, "뒤는 아직 남아 있어야 한다")


func test_content_leaves_before_the_panel() -> void:
	var motion := _opened(1.0)
	motion.close()
	motion.advance(PopupMotion.CLOSE_TIME * 0.6)
	assert_eq(motion.content(), 0.0, "빈 판이 접히는 것이 읽기 좋다")
	assert_gt(motion.presence(), 0.0, "판은 아직 남아 있다")


func test_settled_reports_when_the_last_piece_landed() -> void:
	var motion := _opened(0.10)
	assert_false(motion.settled(PIECES), "아직 오는 중이다")
	motion.advance(PopupMotion.PIECE_TIME + PopupMotion.STAGGER * float(PIECES))
	assert_true(motion.settled(PIECES), "다 오면 열린 것이다")


func test_pose_reproduces_the_same_frame() -> void:
	var first := _opened(0.13)
	var second := PopupMotion.new()
	second.phase = PopupMotion.Phase.OPENING
	second.pose(0.13, 0.13, -1.0)
	assert_almost_eq(second.piece(1, PIECES), first.piece(1, PIECES), 0.0001)
	assert_almost_eq(second.veil(), first.veil(), 0.0001)
