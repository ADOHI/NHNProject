extends GutTest
## RekkaPost 의 **후처리** 테스트.
##
## 여기서 지키는 것은 프롬프트에서 뺀 제약들이다. 프롬프트에 적으면 산출이 나빠지므로
## (docs/design/19-rekka-voice.md §19.A.2 발견 1) 코드가 대신 보장한다.
##
## 접두어 · 닉네임 배정은 test_rekka_handles.gd 에 있다.

const PostScript := preload("res://src/core/rekka/rekka_post.gd")
const HandlesScript := preload("res://src/core/rekka/rekka_handles.gd")

# ---------------------------------------------------------------- 표시 지우기


func test_input_brackets_never_reach_the_screen() -> void:
	# 이름을 감싸는 것은 입력에서만 필요하다. 새어 나가면 화면에 꺾쇠가 뜬다.
	var cleaned := PostScript.clean("<칼날의 요한> 근황\n\n[닉] ㅋㅋ")

	assert_false(cleaned.contains("<"), cleaned)
	assert_false(cleaned.contains(">"), cleaned)
	assert_string_contains(cleaned, "칼날의 요한")


func test_label_prefix_is_stripped() -> void:
	# 실측 결함이다. 5편 중 1편이 "제목: ..." 으로 시작했다.
	var cleaned := PostScript.clean("제목: 요한 또 털림\n본문: 그냥 털렸음\n\n[닉] ㅇㅇ")

	assert_false(cleaned.contains("제목:"), cleaned)
	assert_false(cleaned.contains("본문:"), cleaned)
	assert_string_contains(cleaned, "요한 또 털림")


func test_forbidden_glyphs_are_removed() -> void:
	# 웹 빌드에는 빌려 올 시스템 폰트가 없어서 전부 두부가 된다 (conventions.md §5.1).
	var cleaned := PostScript.clean("요한 근황 ★ગુ\n\n[닉] 별표 없음")

	assert_false(cleaned.contains("★"), cleaned)
	assert_false(cleaned.contains("ગ"), cleaned)


func test_curly_marks_are_moved_not_dropped() -> void:
	# 그냥 지우면 인용부호가 통째로 사라져 문장이 달라진다.
	var cleaned := PostScript.clean("그놈이 “가보자고” 했다더라...\n\n[닉] ㅋㅋ")

	assert_string_contains(cleaned, '"가보자고"')


func test_community_jamo_survives() -> void:
	# ㅋㅋ ㄹㅇ 은 커뮤니티 말투의 절반이다. 지우면 문체가 통째로 날아간다.
	var cleaned := PostScript.clean("요한 나락 ㄹㅇ\n\n[닉] ㅋㅋㅋ ㅠㅠ")

	assert_string_contains(cleaned, "ㄹㅇ")
	assert_string_contains(cleaned, "ㅋㅋㅋ")


# ---------------------------------------------------------------- 숫자


func test_counts_and_ranks_survive() -> void:
	# 앞선 필터가 이것들의 숫자까지 지웠다. 허탕도 등수도 정보다 (§19.A.6).
	var text := "전투 기록 0회, 수확량 0, 수확 1등, 세 번째 방, 전리품 0개, 확률 50%"

	assert_eq(PostScript.scrub_magnitudes(text), text)
	assert_true(PostScript.blocked_numbers(text).is_empty(), str(PostScript.blocked_numbers(text)))


func test_headcount_is_folded_not_counted() -> void:
	# 인원은 등급이 대신한다. 숫자만 지우면 "명 죽었다" 같은 부스러기가 남는다.
	assert_eq(PostScript.scrub_magnitudes("3명 눕음"), "여럿 눕음")
	assert_eq(PostScript.scrub_magnitudes("1명 눕음"), "하나 눕음")
	assert_eq(PostScript.scrub_magnitudes("사냥개 2마리"), "사냥개 여럿")


func test_a_bare_zero_before_a_particle_is_not_a_headcount() -> void:
	# 실측 결함이다. `인` 을 인원 단위로 잡았더니 `수확 0인데` 가 `수확 하나데` 가 됐다.
	# 지키려던 바로 그 숫자를 지우는 규칙이면 규칙이 틀린 것이다.
	assert_eq(PostScript.scrub_magnitudes("베른 이번 판 수확 0인데"), "베른 이번 판 수확 0인데")


func test_damage_and_loot_values_are_blocked() -> void:
	# 이 게임의 전투는 피해가 오가는 방식이 아니다 (05-rules.md §5.8).
	assert_eq(PostScript.scrub_magnitudes("12 피해 박음"), "얼마어치 박음")
	assert_eq(PostScript.scrub_magnitudes("500골드 챙김"), "얼마어치 챙김")
	assert_false(PostScript.blocked_numbers("8 값어치").is_empty())


func test_korean_numerals_are_left_alone() -> void:
	# `셋이 마주칠 각` 은 세는 말이 아니라 말투다. 검증된 표본에서 제일 좋았다.
	var text := "이러다 셋이 마주칠 각 ㅋㅋ"

	assert_eq(PostScript.scrub_magnitudes(text), text)


func test_numbered_room_names_survive() -> void:
	# 생성기가 같은 이름을 두 번 쓰면 번호를 붙인다. 지우면 어느 방인지 모른다.
	var text := "중정 3에서 또 터짐"

	assert_eq(PostScript.scrub_magnitudes(text), text)


# ---------------------------------------------------------------- 정리


func test_blank_lines_are_collapsed() -> void:
	var cleaned := PostScript.clean("제목이다\n\n\n\n본문이다\n\n[닉] ㅇㅇ")

	assert_false(cleaned.contains("\n\n\n"), cleaned)


func test_comments_are_spaced_the_same_way_every_post() -> void:
	# 모델은 같은 프롬프트에서도 댓글을 붙여 쓰기도 하고 띄워 쓰기도 한다.
	# 실측 24편 중 여섯 편만 붙어 나왔고, 그러면 같은 피드에서 여섯 편만 다르게 보인다.
	var packed := PostScript.clean("제목이다\n본문이다\n[가] 하나\n[나] 둘")
	var spaced := PostScript.clean("제목이다\n\n본문이다\n\n[가] 하나\n\n[나] 둘")

	assert_eq(packed, spaced)
	assert_string_contains(packed, "하나\n\n[")


func test_a_clean_post_survives_untouched_except_for_the_tag() -> void:
	var raw := "요한 또 빈손\n\n회랑에서 그냥 지나감\n\n[돌] 실화냐"
	var cleaned := PostScript.clean(raw, 0)

	assert_string_contains(cleaned, "회랑에서 그냥 지나감")
	assert_string_contains(cleaned, "실화냐")
	assert_string_contains(cleaned, HandlesScript.handle_for(0))
