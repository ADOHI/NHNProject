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


func test_title_is_returned_without_its_tag() -> void:
	# 이 제목을 다음 턴 입력에 되돌려 주면 밈 반복이 준다 (§19.B.4).
	assert_eq(PostScript.title_of("[속보] 요한 근황\n\n본문"), "요한 근황")
	assert_eq(PostScript.title_of("\n\n요한 근황\n본문"), "요한 근황")
