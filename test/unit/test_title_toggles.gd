extends GutTest
## 연출 토글 검증. **순수 데이터라 씬 없이 검사된다.**
##
## 이 토글은 임시 디버그 스위치가 아니라 **판정 도구**다(docs/design/21-title.md §21.14.2).
## 그림이 갈린 뒤에도 하나씩 꺼 보면서 그 장치가 아직 값을 하는지 다시 잰다.
## 그래서 검사한다 — 판정 도구가 조용히 틀리면 판정 전체가 틀린다.


func _fresh() -> TitleToggles:
	return TitleToggles.new()


func test_everything_starts_on() -> void:
	# 기본이 꺼짐이면 사용자가 아무것도 안 만졌을 때 화면이 죽은 것으로 보인다.
	var toggles := _fresh()
	for device: TitleToggles.Device in TitleToggles.Device.values():
		assert_true(toggles.is_on(device), "처음에는 다 켜져 있어야 한다: %d" % device)
	assert_false(toggles.any_off(), "처음에는 꺼진 것이 없다")


func test_toggle_flips_and_reports_the_new_state() -> void:
	var toggles := _fresh()
	assert_false(toggles.toggle(TitleToggles.Device.PARALLAX), "켜진 것을 뒤집으면 꺼진다")
	assert_false(toggles.is_on(TitleToggles.Device.PARALLAX), "꺼진 채로 남아 있어야 한다")
	assert_true(toggles.toggle(TitleToggles.Device.PARALLAX), "다시 뒤집으면 켜진다")


func test_toggling_one_device_leaves_the_others_alone() -> void:
	# **이것이 이 도구의 존재 이유다.** 하나만 꺼야 그 하나가 무엇을 했는지 갈린다.
	var toggles := _fresh()
	toggles.set_on(TitleToggles.Device.VFX, false)
	assert_true(toggles.is_on(TitleToggles.Device.PARALLAX), "시차는 그대로 켜져 있어야 한다")
	assert_true(toggles.is_on(TitleToggles.Device.SHADER), "셰이더도 그대로여야 한다")
	assert_false(toggles.is_on(TitleToggles.Device.VFX), "끈 것만 꺼져 있어야 한다")


func test_number_keys_map_to_devices_in_order() -> void:
	# 화면에 "1 시차 · 2 VFX · 3 셰이더" 라고 적어 두므로 그 대응이 실제와 같아야 한다.
	var toggles := _fresh()
	assert_eq(toggles.toggle_by_key(KEY_1), TitleToggles.Device.PARALLAX, "1 은 시차다")
	assert_eq(toggles.toggle_by_key(KEY_2), TitleToggles.Device.VFX, "2 는 VFX 다")
	assert_eq(toggles.toggle_by_key(KEY_3), TitleToggles.Device.SHADER, "3 은 셰이더다")


func test_an_unmapped_key_changes_nothing() -> void:
	# 호출한 쪽이 그 키를 자기 것으로 쓸 수 있어야 한다(0 은 안내 접기다).
	var toggles := _fresh()
	assert_eq(toggles.toggle_by_key(KEY_9), -1, "대응이 없으면 -1 이다")
	assert_false(toggles.any_off(), "아무것도 안 뒤집혀야 한다")


func test_unknown_device_reads_as_on() -> void:
	# 장치를 새로 만들다가 등록을 잊었을 때, 화면이 조용히 죽는 것보다 켜진 편이 낫다.
	assert_true(_fresh().is_on(9999 as TitleToggles.Device), "모르는 장치는 켜진 것으로 답한다")


func test_the_hint_names_every_device_and_its_key() -> void:
	var text := _fresh().hint()
	for device: TitleToggles.Device in TitleToggles.Device.values():
		assert_string_contains(text, TitleToggles.NAMES[device], "안내에 이름이 있어야 한다")
	for keycode: int in TitleToggles.KEYS.keys():
		assert_string_contains(text, str(keycode - KEY_0), "안내에 누를 숫자가 있어야 한다")


func test_the_hint_marks_what_is_off() -> void:
	# 대개 다 켜져 있으므로 **꺼진 것에만** 표가 붙어야 줄이 조용하다.
	var toggles := _fresh()
	assert_false(toggles.hint().contains("끔"), "다 켜져 있으면 표가 없다")
	toggles.set_on(TitleToggles.Device.VFX, false)
	assert_true(toggles.hint().contains("끔"), "꺼진 것이 있으면 표가 붙는다")


func test_off_tags_name_only_what_is_off() -> void:
	# 필름 이름에 붙는다. **무엇을 끈 상태였는지 모르는 필름은 증거가 아니다.**
	var toggles := _fresh()
	assert_eq(toggles.off_tags().size(), 0, "다 켜져 있으면 표가 비어 있다")
	toggles.set_on(TitleToggles.Device.PARALLAX, false)
	var tags := toggles.off_tags()
	assert_eq(tags.size(), 1, "끈 것 하나만 나와야 한다")
	assert_eq(tags[0], "parallax", "파일 이름에 넣기 좋게 영문 소문자다")
