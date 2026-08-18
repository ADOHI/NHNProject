extends GutTest
## 스크롤 벤치의 **손**과, 그 손을 부리는 **캡처 대본**을 덮는다.
##
## docs/design/20-ui-kit.md §20.22.5 · §20.24.
##
## ## 대본을 검사가 읽는다
##
## 캡처 대본은 지금까지 **창을 띄워 눈으로 봐야만** 확인됐다. 그래서 「휠을 아홉 번
## 굴리는데 글 절반까지밖에 안 간다」 같은 것이 GIF 를 뽑아 보기 전에는 안 보였다.
##
## `wheel()` 이 공개 함수라서 **창 없이 대본을 그대로 돌려 볼 수 있다.**
## 손을 붙인 것의 값이 그림에만 있는 게 아니다.

const _BENCH := preload("res://src/ui/kit/scroll_bench.tscn")

## 캡처 도구를 **상수째로 읽는다.** 대본을 여기에 베껴 두면 한쪽만 고쳐진다.
const _CAPTURE := preload("res://tools/capture_scroll.gd")

## 캡처가 쓰는 판 크기. 카드 자리와 글 분량이 여기서 정해진다.
const _SHEET := Vector2(1280.0, 1600.0)

var _bench: ScrollBench


## 캡처 대본. `preload` 가 낸 것을 `GDScript` 로 받아야 상수 표를 물어볼 수 있다 —
## 스크립트 자료형 그대로 두면 「정적 함수가 아니다」로 파싱이 막힌다.
func _script_at() -> Array:
	var capture: GDScript = _CAPTURE
	return capture.get_script_constant_map()["SCRIPT_AT"]


func before_each() -> void:
	_bench = _BENCH.instantiate()
	# 캡처와 같은 조건이다 — 시계를 밖에서 잡고 판 크기를 직접 준다.
	_bench.drive_externally()
	_bench.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(_bench)
	_bench.size = _SHEET
	_bench.set_clock(0.0)


func test_the_clock_rolls_until_a_hand_arrives() -> void:
	# 닿기 전에는 시계가 굴린다. 그래야 예전 캡처가 보던 것이 그대로다.
	assert_false(_bench.by_hand(), "만지지도 않았는데 손이 잡고 있다")
	_bench.wheel(-1)
	assert_true(_bench.by_hand(), "휠을 굴렸는데 손이 안 잡았다")


func test_a_notch_moves_something() -> void:
	var before := _bench.rolled()
	_bench.wheel(-1)
	assert_true(_bench.rolled() > before, "휠 한 칸이 아무것도 안 굴렸다")


func test_rolling_never_leaves_the_text() -> void:
	# 위아래 끝을 넘으면 글이 화면 밖으로 사라지고 형태만 남는다.
	for _i in 40:
		_bench.wheel(-1)
	assert_almost_eq(_bench.rolled(), 1.0, 0.001, "끝까지 굴려도 1 을 안 넘어야 한다")
	for _i in 80:
		_bench.wheel(1)
	assert_almost_eq(_bench.rolled(), 0.0, 0.001, "되돌려도 0 아래로 안 가야 한다")


func test_the_capture_script_reaches_the_bottom() -> void:
	# **대본이 글 끝까지 닿나.** 안 닿으면 GIF 가 열전 아랫부분을 한 번도 안 보여 준다 —
	# 그런데 이 벤치가 재려는 것이 바로 그 아랫부분에서의 흔들림이다.
	var script := _script_at()
	for _step in script:
		_bench.wheel(-1)
	assert_almost_eq(_bench.rolled(), 1.0, 0.001, "휠 %d 칸으로는 끝까지 못 간다" % script.size())


func test_the_capture_script_does_not_waste_notches() -> void:
	# 한 칸을 빼도 끝에 닿으면 **남는 칸은 아무것도 안 보여 준다.**
	var script := _script_at()
	for _i in script.size() - 1:
		_bench.wheel(-1)
	assert_true(_bench.rolled() < 1.0, "대본에 쓸데없는 칸이 있다 — %d 칸이면 충분하다" % (script.size() - 1))


func test_the_script_is_in_order_and_inside_the_loop() -> void:
	# 시각이 뒤섞이면 캡처가 그 칸을 영영 안 부른다 (`_did` 가 앞으로만 간다).
	var script := _script_at()
	var last := -1.0
	for step in script:
		var at := float(step)
		assert_true(at > last, "대본 시각이 뒤로 갔다")
		assert_true(at < ScrollBench.LOOP, "대본 시각이 한 바퀴 밖이다 — 그 칸은 안 불린다")
		last = at
