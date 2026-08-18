extends SceneTree
## **「빠르고 조금 나간다」 vs 「느리고 많이 나간다」가 새 저울인가.**
##
##     godot --headless --path . -s res://tools/survey_weapon_motion.gd
##
## `docs/design/28-combat.md` §28.20.30.
##
## ## 무엇을 묻는가
##
## §28.20.29 에서 큰 무기는 **내주는 것 셋에 받는 것 하나**였다
## (칸을 먹고 · 느리고 · 감쇠에 약한데 · 적은 타로 문턱을 넘는다).
##
## 전진과 리치가 들어오면 **받는 것이 둘이 될 수도** 있다.
## 그러면 부피 축이 다시 평평해진다. **재봐야 안다.**

const _SHAPES := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(2, 2)]


func _initialize() -> void:
	print("캐릭터 애니 레인 실측표를 그대로 쓴다. **여기 수치는 우리가 정한 것이 아니다.**")
	print("")
	_report_per_swing()
	_report_opening()
	_report_closing()
	_report_verdict()
	quit()


func _shaped(box: Vector2i) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for x in box.x:
		for y in box.y:
			shape.append(Vector2i(x, y))
	return BackpackItem.new(
		"w",
		"%dx%d" % [box.x, box.y],
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


func _swing_seconds(tuning: BreakTuning, item: BackpackItem) -> float:
	return tuning.strike_seconds_for(item) + tuning.hitstop_seconds_for(item)


# ---------------------------------------------------------------- 한 타에


func _report_per_swing() -> void:
	var tuning := BreakTuning.new()
	print("== 한 타에 얼마나 나가고 얼마나 걸리나 ==")
	print("  %-8s %-6s %-10s %-10s %-12s %s" % ["모양", "칸", "전진/타", "한 타 시간", "**전진 속도**", "리치"])
	for box: Vector2i in _SHAPES:
		var item := _shaped(box)
		var seconds := _swing_seconds(tuning, item)
		print(
			(
				"  %-8s %-6d %-10s %-10s %-12s %s"
				% [
					"%dx%d" % [box.x, box.y],
					item.shape.size(),
					"%.1f" % WeaponMotion.advance_px(item),
					"%.2f초" % seconds,
					"%.1f px/초" % (WeaponMotion.advance_px(item) / seconds),
					"%.0f" % WeaponMotion.reach_px(item),
				]
			)
		)
	print("")
	print("  **전진 속도로 보면 큰 무기가 받는 것이 없다.** 한 타에도 덜 나가고 초당은 더 심하다.")
	print("  「느리고 많이 나간다」가 아니라 **「느리고 조금 나간다」**다.")
	print("")


# ---------------------------------------------------------------- 개전 거리


## **큰 무기가 실제로 받는 값은 이것이다** — 멀리서 시작할 수 있다.
func _report_opening() -> void:
	print("== 얼마나 먼 데서 첫 타를 낼 수 있나 ==")
	print("  %-8s %-10s %s" % ["모양", "리치", "이 거리에서 못 여는 무기"])
	var reaches := {}
	for box: Vector2i in _SHAPES:
		reaches[box] = WeaponMotion.reach_px(_shaped(box))
	for box: Vector2i in _SHAPES:
		var blocked := PackedStringArray()
		for other: Vector2i in _SHAPES:
			if float(reaches[other]) < float(reaches[box]):
				blocked.append("%dx%d" % [other.x, other.y])
		print(
			(
				"  %-8s %-10s %s"
				% [
					"%dx%d" % [box.x, box.y],
					"%.0f" % float(reaches[box]),
					"없음" if blocked.is_empty() else ", ".join(blocked),
				]
			)
		)
	print("")
	print("  **못 닿으면 영영 못 붙는다** — 전진은 때려야 생기기 때문이다.")
	print("  붙는 것은 이 대련장 밖(§28.4 의 RTS 자동 이동)의 일이고,")
	print("  그래서 리치는 「먼저 때릴 수 있나」가 아니라 **「교전을 열 수 있나」**다.")
	print("")


# ---------------------------------------------------------------- 붙는 데 걸리는 시간


func _report_closing() -> void:
	var tuning := BreakTuning.new()
	print("== 전진이 남을 때, 닿는 거리에서 시작해 몸이 붙기까지 (STAY) ==")
	print("  %-8s %-12s %-12s %s" % ["모양", "시작 간격", "붙는 데 타", "걸린 시간"])
	for box: Vector2i in _SHAPES:
		var item := _shaped(box)
		var start := WeaponMotion.reach_px(item)
		var field := SparringField.new(0.0, start)
		field.advance_mode = SparringField.AdvanceMode.STAY
		var swings := 0
		while field.gap() > 1.0 and swings < 200:
			field.swing_advance(WeaponMotion.advance_px(item))
			swings += 1
		print(
			(
				"  %-8s %-12s %-12s %s"
				% [
					"%dx%d" % [box.x, box.y],
					"%.0f" % start,
					"%d타" % swings,
					"%.2f초" % (float(swings) * _swing_seconds(tuning, item)),
				]
			)
		)
	print("")
	print("  **전진이 돌아오는(RETURN) 규칙이면 이 표가 통째로 없어진다** — 영영 안 붙는다.")
	print("  그래서 「남나 돌아오나」가 연출이 아니라 규칙이다. 아직 미정이다.")
	print("")


# ---------------------------------------------------------------- 결론


func _report_verdict() -> void:
	var tuning := BreakTuning.new()
	var small := _shaped(Vector2i(1, 1))
	var large := _shaped(Vector2i(4, 1))
	print("== 부피 축이 평평해졌나 ==")
	print("  %-22s %-12s %-12s %s" % ["항목", "1x1 단검", "4x1 대검", "누가 낫나"])
	_verdict_row("칸 (적을수록 좋다)", small.shape.size(), large.shape.size(), false)
	_verdict_row("한 방 무게", tuning.poise_for(small), tuning.poise_for(large), true)
	_verdict_row(
		"한 타 시간 (짧을수록)", _swing_seconds(tuning, small), _swing_seconds(tuning, large), false
	)
	_verdict_row(
		"한계 빠짐 속도",
		tuning.poise_for(small) / tuning.strike_seconds_for(small),
		tuning.poise_for(large) / tuning.strike_seconds_for(large),
		true
	)
	_verdict_row(
		"전진 속도",
		WeaponMotion.advance_px(small) / _swing_seconds(tuning, small),
		WeaponMotion.advance_px(large) / _swing_seconds(tuning, large),
		true
	)
	_verdict_row("리치 (개전 거리)", WeaponMotion.reach_px(small), WeaponMotion.reach_px(large), true)
	print("")
	print("  **평평해지지 않았다.** 큰 무기가 이기는 칸은 여전히 둘뿐이다 —")
	print("  「한 방 무게」와 「리치」. 전진은 큰 무기 편이 아니었다.")


func _verdict_row(label: String, small: float, large: float, higher_is_better: bool) -> void:
	var winner := "="
	if not is_equal_approx(small, large):
		var large_wins := large > small if higher_is_better else large < small
		winner = "4x1" if large_wins else "1x1"
	print("  %-22s %-12s %-12s %s" % [label, "%.1f" % small, "%.1f" % large, winner])
