extends GutTest
## RekkaSlots 테스트 — 자리표시를 판의 이름으로 채운다.
##
## 여기서 지키는 것은 둘이다 (docs/design/32-rekka-feed.md §32.3.3).
##
##   1. **조사가 받침을 따른다.** 틀리면 모델도 사람도 이름을 이름으로 안 읽는다
##   2. **못 채우는 줄은 버린다.** 지우면 주어가 사라지고, 메우면 없는 인물을 지어낸다

const SlotsScript := preload("res://src/core/rekka/rekka_slots.gd")


# ---------------------------------------------------------------- 조사


func test_particles_follow_the_final_consonant() -> void:
	var values := {"주체": "요한", "방": "회랑"}

	assert_eq(SlotsScript.fill_line("{주체이}", values), "요한이")
	assert_eq(SlotsScript.fill_line("{방이}", values), "회랑이")
	assert_eq(SlotsScript.fill_line("{주체은}", values), "요한은")
	assert_eq(SlotsScript.fill_line("{주체을}", values), "요한을")
	assert_eq(SlotsScript.fill_line("{주체와}", values), "요한과")


func test_particles_follow_a_name_that_ends_in_a_vowel() -> void:
	var values := {"주체": "미나", "방": "밀실"}

	assert_eq(SlotsScript.fill_line("{주체이}", values), "미나가")
	assert_eq(SlotsScript.fill_line("{주체은}", values), "미나는")
	assert_eq(SlotsScript.fill_line("{주체을}", values), "미나를")
	assert_eq(SlotsScript.fill_line("{주체와}", values), "미나와")


func test_room_numbers_are_read_as_sino_korean() -> void:
	# 생성기가 같은 이름을 두 번 쓰면 번호를 붙인다. `중정 3` 은 "중정 삼" 이라 받침이 있다.
	assert_eq(SlotsScript.fill_line("{방은}", {"방": "중정 3"}), "중정 3은")
	assert_eq(SlotsScript.fill_line("{방은}", {"방": "중정 2"}), "중정 2는")


func test_invariant_particles_pass_straight_through() -> void:
	# 받침과 무관한 조사까지 목록으로 막으면 멀쩡한 문장이 통째로 사라진다.
	var values := {"방": "회랑"}

	assert_eq(SlotsScript.fill_line("{방에서}", values), "회랑에서")
	assert_eq(SlotsScript.fill_line("{방까지}", values), "회랑까지")


func test_direction_particle_treats_rieul_as_no_final() -> void:
	assert_eq(SlotsScript.fill_line("{방으로}", {"방": "밀실"}), "밀실로")
	assert_eq(SlotsScript.fill_line("{방으로}", {"방": "회랑"}), "회랑으로")


# ---------------------------------------------------------------- 못 채우면 버린다


func test_a_line_with_no_partner_is_dropped_whole() -> void:
	# 지우면 주어가 사라지고 `누군가` 로 메우면 없는 인물을 지어낸 것이 된다.
	var line := "{주체이} {상대을} 어떻게 했다는데"

	assert_eq(SlotsScript.fill_line(line, {"주체": "요한"}), "")


func test_an_empty_value_counts_as_missing() -> void:
	assert_eq(SlotsScript.fill_line("{등급} 실화냐", {"등급": ""}), "")


func test_fill_keeps_the_lines_it_can_and_drops_the_rest() -> void:
	var text := "{주체이} 뭔가 했다\n{상대은} 어디 갔냐\n다들 구경만 함"

	var kept := SlotsScript.fill(text, {"주체": "미나"})

	assert_eq(kept.size(), 2, str(kept))
	assert_eq(kept[0], "미나가 뭔가 했다")
	assert_eq(kept[1], "다들 구경만 함")


func test_text_without_any_slot_is_untouched() -> void:
	assert_eq(SlotsScript.fill_line("아무도 안 움직이는 중", {}), "아무도 안 움직이는 중")


# ---------------------------------------------------------------- 검사용


func test_keys_in_lists_every_slot_it_finds() -> void:
	var found := SlotsScript.keys_in("{주체은} {방에서} {주체은} 또 뭔가")

	assert_eq(found.size(), 2, str(found))
	assert_has(found, "주체은")
	assert_has(found, "방에서")


func test_an_unclosed_slot_does_not_hang() -> void:
	assert_eq(SlotsScript.fill_line("{주체 이름이 안 닫혔다", {"주체": "요한"}), "{주체 이름이 안 닫혔다")
	assert_eq(SlotsScript.keys_in("{주체 안 닫힘"), [] as Array[String])
