extends GutTest
## 조절 가능한 수치의 단위 테스트.
##
## 화면의 슬라이더가 이 정의를 그대로 읽어 만들어진다. 정의가 망가지면 슬라이더가
## 엉뚱한 범위로 생기고, 그 상태로 만진 값은 손맛 판단 자체를 오염시킨다.


func test_every_definition_is_complete() -> void:
	for definition in ProtoMoveTuning.DEFS:
		for key in ["key", "label", "min", "max", "step", "value", "hint"]:
			assert_true(definition.has(key), "%s 항목이 빠졌다: %s" % [definition, key])


func test_default_sits_inside_its_range() -> void:
	for definition in ProtoMoveTuning.DEFS:
		var value := float(definition["value"])
		assert_between(value, float(definition["min"]), float(definition["max"]))


func test_keys_are_unique() -> void:
	var seen := {}
	for definition in ProtoMoveTuning.DEFS:
		var key := String(definition["key"])
		assert_false(seen.has(key), "이름이 겹친다: %s" % key)
		seen[key] = true


func test_new_tuning_starts_at_defaults() -> void:
	var tuning := ProtoMoveTuning.new()
	assert_eq(tuning.changed_count(), 0)
	for definition in ProtoMoveTuning.DEFS:
		assert_almost_eq(
			tuning.get_value(String(definition["key"])), float(definition["value"]), 0.0001
		)


func test_set_value_reports_the_change() -> void:
	var tuning := ProtoMoveTuning.new()
	watch_signals(tuning)
	tuning.set_value("max_speed", 400.0)
	assert_almost_eq(tuning.get_value("max_speed"), 400.0, 0.0001)
	assert_eq(tuning.changed_count(), 1)
	assert_signal_emit_count(tuning, "value_changed", 1)


func test_setting_the_same_value_is_silent() -> void:
	var tuning := ProtoMoveTuning.new()
	watch_signals(tuning)
	tuning.set_value("max_speed", tuning.get_value("max_speed"))
	assert_signal_emit_count(tuning, "value_changed", 0)


func test_unknown_key_is_ignored() -> void:
	var tuning := ProtoMoveTuning.new()
	tuning.set_value("없는값", 1.0)
	assert_almost_eq(tuning.get_value("없는값"), 0.0, 0.0001)


## 밀고 밀리는 값은 전부 없어졌다. 하나라도 되살아나면 물리력이 다시 스며든 것이다.
func test_no_pushing_knob_survives() -> void:
	var banned := [
		"separation_radius",
		"separation_weight",
		"side_bias",
		"yield_strength",
		"push_resolve",
		"push_cap",
	]
	for definition in ProtoMoveTuning.DEFS:
		assert_false(banned.has(String(definition["key"])), "미는 값이 되살아났다: %s" % definition["key"])


func test_reset_restores_every_default() -> void:
	# 만지다 망가뜨렸을 때 돌아올 곳이 없으면 아무도 마음 놓고 만지지 않는다.
	var tuning := ProtoMoveTuning.new()
	tuning.set_value("max_speed", 500.0)
	tuning.set_value("turn_rate", 200.0)
	tuning.reset()
	assert_eq(tuning.changed_count(), 0)
	assert_almost_eq(tuning.get_value("max_speed"), tuning.default_of("max_speed"), 0.0001)
