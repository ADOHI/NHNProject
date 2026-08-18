extends GutTest
## **화면 연출의 눈금이 실제로 눈금인가** — 속도선 · 임팩트 프레임 · 카메라 (§25.28).
##
## 여기서 막는 실패는 하나뿐이고 이름이 있다 — **눈금에 있는데 아무 일도 안 하는 것.**
##
## 「약」 임팩트 프레임이 실제로 그랬다. 켜져 있는 시간이 `0.033` 초였는데 25 fps 는
## 한 프레임이 `0.040` 초라 **표본 사이로 빠져나갔다.** 사람이 GIF 를 봐도 「약」과
## 「없음」이 같은 그림이었다. §25.19.2 에서 히트스톱이 반 프레임도 안 되어 아무 일도
## 안 했던 것과 **같은 실패**이고, 그때는 눈으로 잡았지만 이번에는 자로 잡는다.

## 화면이 실제로 표본되는 빠르기. GIF 캡처도 게임도 이 언저리다.
const FPS := 25.0
const FRAME := 1.0 / FPS

## 닿는 시각을 프레임 격자에 대해 몇 가지 위상으로 밀어 보나.
##
## **한 위상만 보면 통과한다.** 짧은 번쩍임은 위상에 따라 걸리기도 하고 빠지기도 해서,
## 운 좋은 위상 하나로는 아무것도 증명하지 못한다.
const PHASES := 16

const SCAN_FRAMES := 60


func _levels() -> Array:
	return [CharScreenFx.Level.WEAK, CharScreenFx.Level.STRONG, CharScreenFx.Level.OVER]


## 닿는 시각을 위상 `i` 만큼 민다. 프레임 격자와 어긋난 자리를 일부러 만든다.
func _impact_at(phase: int) -> float:
	return 0.5 + FRAME * float(phase) / float(PHASES)


func test_every_impact_notch_lands_on_at_least_one_frame() -> void:
	# **이것이 이 파일의 이유다.** 어느 위상에서 맞아도 꽉 찬 한 프레임이 나와야 한다.
	for level: CharScreenFx.Level in _levels():
		var fx := CharScreenFx.new()
		fx.impact = level
		for phase in PHASES:
			var impact_at := _impact_at(phase)
			var brightest := 0.0
			for i in SCAN_FRAMES:
				brightest = maxf(brightest, fx.flash_alpha(FRAME * float(i), impact_at))
			assert_almost_eq(
				brightest,
				CharScreenFx.FLASH_INK[level],
				0.0001,
				"눈금 %s 가 위상 %d 에서 표본 사이로 빠져나간다" % [CharScreenFx.LEVEL_NAMES[level], phase]
			)


func test_the_flash_is_a_held_frame_not_a_fade() -> void:
	# **번쩍임은 「몇 프레임 켜져 있는 것」이지 「밝기가 줄어드는 것」이 아니다.**
	# 줄어들게 두면 표본이 늦게 걸릴 때 0 에 가깝게 잡힌다 — 그것이 위의 실패의 원인이었다.
	var fx := CharScreenFx.new()
	fx.impact = CharScreenFx.Level.OVER
	var hold := CharScreenFx.FLASH_HOLD[CharScreenFx.Level.OVER]
	var early := fx.flash_alpha(1.0 + hold * 0.05, 1.0)
	var late := fx.flash_alpha(1.0 + hold * 0.95, 1.0)
	assert_almost_eq(early, late, 0.0001, "켜져 있는 동안 짙기가 변하면 안 된다")
	assert_eq(fx.flash_alpha(1.0 + hold * 1.05, 1.0), 0.0, "지나면 꺼져야 한다")
	assert_eq(fx.flash_alpha(0.99, 1.0), 0.0, "닿기 전에는 안 켜진다")


func test_the_inversion_also_survives_the_frame_grid() -> void:
	# 반전은 백색 다음에 온다. **같은 함정이 그대로 있다** — 한 프레임보다 짧으면 못 본다.
	for level: CharScreenFx.Level in [CharScreenFx.Level.STRONG, CharScreenFx.Level.OVER]:
		var fx := CharScreenFx.new()
		fx.impact = level
		for phase in PHASES:
			var impact_at := _impact_at(phase)
			var seen := false
			for i in SCAN_FRAMES:
				seen = seen or fx.is_inverted(FRAME * float(i), impact_at)
			assert_true(
				seen, "반전이 눈금 %s · 위상 %d 에서 안 보인다" % [CharScreenFx.LEVEL_NAMES[level], phase]
			)


func test_no_notch_does_anything_when_it_is_none() -> void:
	# **「없음」이 정말 아무것도 안 해야** 나란히 놓은 첫 칸이 비교의 바닥이 된다.
	var fx := CharScreenFx.new()
	assert_true(fx.is_idle(), "아무것도 안 켠 것은 쉬는 상태여야 한다")
	assert_eq(fx.flash_alpha(1.0, 1.0), 0.0, "없음인데 번쩍인다")
	assert_false(fx.is_inverted(1.0, 1.0), "없음인데 반전된다")
	assert_eq(fx.line_strength(1.0, 1.0), 0.0, "없음인데 속도선이 선다")
	assert_eq(
		fx.camera_transform(1.01, 1.0, Vector2(100.0, 100.0)),
		Transform2D.IDENTITY,
		"없음인데 카메라가 움직인다"
	)


func test_each_axis_grows_with_the_notch() -> void:
	# 눈금이 **순서대로** 세져야 「약 / 세 / 과」가 뜻을 갖는다.
	var focus := Vector2(240.0, 260.0)
	var previous_lines := -1.0
	var previous_zoom := -1.0
	var previous_hold := -1.0
	for level: CharScreenFx.Level in _levels():
		var fx := CharScreenFx.all_at(level)
		var lines: Array = fx.line_field(Vector2(480.0, 520.0), focus, Vector2.LEFT, 1.0)
		var ink := fx.line_alpha(1.0)
		assert_gt(lines.size(), 0, "눈금 %s 인데 선이 한 줄도 없다" % CharScreenFx.LEVEL_NAMES[level])
		assert_gt(float(lines.size()) * ink, previous_lines, "속도선이 눈금을 따라 세져야 한다")
		previous_lines = float(lines.size()) * ink
		var zoom := fx.camera_transform(1.0, 1.0, focus).get_scale().x
		assert_gt(zoom, previous_zoom, "카메라가 눈금을 따라 더 밀고 들어가야 한다")
		previous_zoom = zoom
		assert_gt(CharScreenFx.FLASH_HOLD[level], previous_hold, "임팩트가 눈금을 따라 길어져야 한다")
		previous_hold = CharScreenFx.FLASH_HOLD[level]


func test_the_speed_lines_point_where_the_blade_went() -> void:
	# **방향을 박아 두지 않았다** — 검끝이 지나간 쪽에서 온다 (§25.28.1).
	# 진행 방향을 뒤집으면 선도 뒤집혀야 한다.
	var fx := CharScreenFx.all_at(CharScreenFx.Level.STRONG)
	var size := Vector2(480.0, 520.0)
	var focus := Vector2(240.0, 260.0)
	var left: Array = fx.line_field(size, focus, Vector2.LEFT, 1.0)
	var right: Array = fx.line_field(size, focus, Vector2.RIGHT, 1.0)
	assert_gt(left.size(), 0, "선이 있어야 방향을 잰다")
	assert_eq(left.size(), right.size(), "방향만 바꿨는데 줄 수가 달라졌다")
	var left_run: Vector2 = left[0][1] - left[0][0]
	var right_run: Vector2 = right[0][1] - right[0][0]
	assert_lt(left_run.dot(right_run), 0.0, "검이 반대로 지나갔는데 선이 같은 쪽으로 흐른다")


func test_the_lines_clear_a_hole_around_the_character() -> void:
	# **얼굴 앞이 지저분하면 자세를 못 본다.** 연출이 자세를 덮으면 안 된다 (§25.26.3).
	for level: CharScreenFx.Level in _levels():
		var fx := CharScreenFx.all_at(level)
		var focus := Vector2(240.0, 260.0)
		var clear := CharScreenFx.LINE_CLEAR[level]
		for pair: Array in fx.line_field(Vector2(480.0, 520.0), focus, Vector2.LEFT, 1.0):
			var middle: Vector2 = (pair[0] + pair[1]) * 0.5
			assert_gte(middle.distance_to(focus), clear, "선이 캐릭터 위를 지나간다")
