extends GutTest
## RekkaHandles 테스트 — 제목 접두어와 댓글 닉네임을 코드가 배정한다.
##
## 이 파일이 지키는 것은 **반복이 안 생긴다** 하나다.
## 실측에서 `[속보]` 가 5편 중 4편에 붙었고 `돌멩이수집가` 가 두 편에 나왔다
## (docs/design/19-rekka-voice.md §19.B.4).
## 한 편만 보면 안 보이고 스무 편째에 보이는 결함이라 모델은 스스로 못 고친다.

const HandlesScript := preload("res://src/core/rekka/rekka_handles.gd")
const PostScript := preload("res://src/core/rekka/rekka_post.gd")

# ---------------------------------------------------------------- 접두어


func test_half_the_posts_get_no_tag_at_all() -> void:
	# 매번 붙으면 그게 곧 틀이다. 실측 80%를 50%로 내린다.
	var blank := 0
	for index in HandlesScript.TAGS.size():
		if HandlesScript.tag_for(index).is_empty():
			blank += 1
	assert_eq(blank * 2, HandlesScript.TAGS.size(), str(HandlesScript.TAGS))


func test_no_tag_repeats_back_to_back() -> void:
	for index in 40:
		var current := HandlesScript.tag_for(index)
		if current.is_empty():
			continue
		assert_ne(current, HandlesScript.tag_for(index + 1), "연달아 같은 접두어: %d" % index)


func test_tag_assignment_wraps_without_crashing() -> void:
	assert_eq(HandlesScript.tag_for(0), HandlesScript.tag_for(HandlesScript.TAGS.size()))
	assert_ne(HandlesScript.tag_for(-1), "￿")


func test_every_tag_appears_once_per_cycle() -> void:
	# 걸음이 목록 길이와 서로소여야 한 바퀴가 온전히 돈다.
	# 아니면 어떤 접두어는 영영 안 나오고 어떤 것은 두 배로 나온다.
	var seen: Dictionary = {}
	for index in HandlesScript.TAGS.size():
		seen[HandlesScript.tag_for(index)] = int(seen.get(HandlesScript.tag_for(index), 0)) + 1
	assert_eq(int(seen.get("", 0)) * 2, HandlesScript.TAGS.size())
	for tag in HandlesScript.TAGS:
		assert_true(seen.has(tag), tag)


func test_tags_do_not_land_on_alternating_posts() -> void:
	# 실측 결함이다. 심사자 둘이 "짝수 편에만 붙는다" 는 같은 표를 그렸다.
	# 규칙이 눈에 보이는 순간 접두어는 문체가 아니라 인덱스 표시가 된다.
	var odd_tagged := 0
	for index in 24:
		if index % 2 == 1 and not HandlesScript.tag_for(index).is_empty():
			odd_tagged += 1
	assert_gt(odd_tagged, 0, "홀수 편에는 접두어가 하나도 안 붙는다")


func test_the_model_tag_is_thrown_away() -> void:
	# 모델이 붙인 `[속보]` 는 버리고 배정된 것으로 갈아 끼운다.
	var tagged := PostScript.apply_tag("[속보] 요한 근황\n\n[닉] ㅇㅇ", 0)

	assert_false(tagged.begins_with("[속보]"), tagged)
	assert_string_contains(tagged, "요한 근황")


func test_comment_brackets_are_not_mistaken_for_a_tag() -> void:
	# 첫 줄만 제목이다. 댓글의 대괄호까지 건드리면 닉이 통째로 날아간다.
	var tagged := PostScript.apply_tag("요한 근황\n\n[돌멩이] ㅇㅇ", 1)

	assert_string_contains(tagged, "[돌멩이] ㅇㅇ")


# ---------------------------------------------------------------- 닉네임


func test_handles_never_repeat_within_one_cycle() -> void:
	var seen: Dictionary = {}
	for index in HandlesScript.HANDLES.size():
		var handle := HandlesScript.handle_for(index)
		assert_false(seen.has(handle), "닉이 겹쳤다: %d -> %s" % [index, handle])
		seen[handle] = true


func test_handles_carry_no_digits() -> void:
	# 후처리의 숫자 규칙과 엮이면 닉이 깨진다.
	for handle in HandlesScript.HANDLES:
		for digit in "0123456789":
			assert_false(handle.contains(digit), handle)


func test_a_different_run_reorders_the_pool_not_just_its_start() -> void:
	# 시작점만 옮기면 순서가 그대로라 판이 바뀌어도 같은 셋이 늘 붙어 다닌다.
	# 심사자가 서른여섯 개짜리 고리를 통째로 복원해 냈다.
	var first: Array[String] = []
	var second: Array[String] = []
	for index in 6:
		first.append(HandlesScript.handle_for(index, 20260808))
		second.append(HandlesScript.handle_for(index, 771))
	# 두 배열이 서로의 회전이기만 하면 안 된다. 이어지는 짝이 달라야 한다.
	var pairs: Dictionary = {}
	for index in 5:
		pairs["%s>%s" % [first[index], first[index + 1]]] = true
	var shared := 0
	for index in 5:
		if pairs.has("%s>%s" % [second[index], second[index + 1]]):
			shared += 1
	assert_eq(shared, 0, "판이 바뀌어도 같은 닉이 같은 닉을 따라온다: %s / %s" % [first, second])


func test_every_handle_still_appears_once_per_cycle_under_any_salt() -> void:
	# 걸음이 목록 길이와 서로소가 아니면 어떤 닉은 영영 안 나오고 어떤 닉은 두 배로 나온다.
	for salt in [0, 771, 20260808, 31337, 9042]:
		var seen: Dictionary = {}
		for index in HandlesScript.HANDLES.size():
			seen[HandlesScript.handle_for(index, salt)] = true
		assert_eq(seen.size(), HandlesScript.HANDLES.size(), "소금 %d 에서 닉이 빠진다" % salt)


func test_handles_do_not_march_down_the_list() -> void:
	# 실측 결함이다. 순서대로 소비했더니 `낄낄이` 다음은 언제나 `지하실단골` 이었고,
	# 심사자가 다음 편 댓글자 명단을 미리 적어 보였다.
	var marched := 0
	for index in HandlesScript.HANDLES.size():
		var here := HandlesScript.HANDLES.find(HandlesScript.handle_for(index))
		var next := HandlesScript.HANDLES.find(HandlesScript.handle_for(index + 1))
		if next == here + 1:
			marched += 1
	assert_eq(marched, 0, "닉이 목록 순서대로 행진한다")


func test_model_handles_are_replaced_in_order() -> void:
	var post := "요한 근황\n[가] 첫 댓글\n[나] 둘째 댓글"
	var swapped := PostScript.apply_handles(post, 0)

	assert_string_contains(swapped, "[%s] 첫 댓글" % HandlesScript.handle_for(0))
	assert_string_contains(swapped, "[%s] 둘째 댓글" % HandlesScript.handle_for(1))


func test_the_same_commenter_keeps_one_handle() -> void:
	# 한 사람이 두 번 단 것은 반복이 아니다.
	var post := "요한 근황\n[가] 하나\n[나] 둘\n[가] 셋"
	var swapped := PostScript.apply_handles(post, 0)

	assert_eq(swapped.count(HandlesScript.handle_for(0)), 2, swapped)
	assert_eq(PostScript.distinct_handle_count(post), 2)


func test_consecutive_posts_do_not_share_handles() -> void:
	# 실측 결함이다. `돌멩이수집가` 가 두 편에 나왔다.
	var first := PostScript.apply_handles("제목\n[가] 하나\n[나] 둘", 0)
	var second := PostScript.apply_handles("제목\n[가] 하나\n[나] 둘", 2)

	for index in 2:
		assert_false(second.contains(HandlesScript.handle_for(index)), second)
	assert_true(first.contains(HandlesScript.handle_for(0)), first)


func test_only_phrases_that_already_repeated_are_reported() -> void:
	# 한 번 나온 말까지 금지하면 화자의 어휘가 매 턴 깎인다.
	# 두 번 나왔다는 사실 자체가 고르는 기준이라 목록이 저절로 판을 따라간다.
	var recent: Array[String] = ["이건 학계 정설임", "저것도 학계 정설이지", "혼자만 아는 얘기"]
	var found := PostScript.repeated_phrases(recent)

	assert_true(found.has("학계정설"), str(found))
	for gram in found:
		assert_false(gram.contains("혼자"), str(found))


func test_inflected_endings_do_not_hide_a_habit() -> void:
	# 한국어는 같은 말이 어미로 갈라진다. 낱말로 맞추면 `정설임` 과 `정설이지` 가
	# 서로 다른 말이 되어 버릇이 통째로 안 잡힌다.
	var recent: Array[String] = ["그건 손절각이다", "이것도 손절각이지"]

	assert_false(PostScript.repeated_phrases(recent).is_empty())


func test_words_from_this_turn_are_never_banned() -> void:
	# 이번 턴 입력에 있는 말(인물 · 방 · 등급)을 금지하면 사실을 못 쓰게 막는 꼴이 된다.
	var recent: Array[String] = ["회랑에서 대박 터짐", "회랑에서 또 대박"]
	var barred := PostScript.repeated_phrases(recent, "<회랑>에서 대박을 챙겼다")

	assert_false(barred.has("회랑에서"), str(barred))
	# 같은 글에 소금 없이 걸면 잡힌다는 것도 확인한다. 안 그러면 무엇도 안 잡혀서
	# 통과한 것인지 걸러서 통과한 것인지 구분되지 않는다.
	assert_true(PostScript.repeated_phrases(recent).has("회랑에서"), "아무것도 못 잡는다")


func test_the_ban_list_is_capped() -> void:
	# 금지 목록이 길어지면 그것 자체가 프롬프트를 늘린다 (발견 1).
	var recent: Array[String] = [
		"학계 정설이고 손절각이고 통행세고 국룰이고 나락이다",
		"학계 정설이며 손절각이며 통행세며 국룰이며 나락이다",
	]

	assert_lte(PostScript.repeated_phrases(recent, "", 3).size(), 3)


func test_title_is_returned_without_its_tag() -> void:
	# 이 제목을 다음 턴 입력에 되돌려 주면 밈 반복이 준다 (§19.B.4).
	assert_eq(PostScript.title_of("[속보] 요한 근황\n\n본문"), "요한 근황")
	assert_eq(PostScript.title_of("\n\n요한 근황\n본문"), "요한 근황")
