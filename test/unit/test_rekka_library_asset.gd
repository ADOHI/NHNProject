extends GutTest
## **실려 있는 문안 자산 자체**를 지킨다.
##
## 자산은 `tools/build_rekka_library.gd` 가 굽고, 그 도구가 이미 검사를 한다.
## 그런데 자산은 **구운 결과가 저장소에 들어가는 것**이라 도구를 안 돌리고 손으로
## 고칠 수도 있고, 원본을 고치고 굽는 것을 잊을 수도 있다.
## **저장소에 들어간 것이 실제로 화면에 나가는 것**이므로 그것을 직접 본다.
##
## docs/design/32-rekka-feed.md §32.3.

const LibraryScript := preload("res://src/core/rekka/rekka_library.gd")
const SlotsScript := preload("res://src/core/rekka/rekka_slots.gd")
const PromptScript := preload("res://src/core/rekka/rekka_prompt.gd")

## 자산이 쓸 수 있는 자리표시. 여기 없는 것을 쓰면 그 줄이 런타임에 조용히 사라진다.
const ALLOWED_SLOTS: Array[String] = ["주체", "상대", "방", "등급"]

var _library: RekkaLibrary


func before_all() -> void:
	_library = LibraryScript.shared()


func _titles() -> Array[String]:
	var found: Array[String] = []
	for post in _library.posts:
		for line in post.split("\n"):
			var trimmed := (line as String).strip_edges()
			if not trimmed.is_empty():
				found.append(trimmed)
				break
	return found


# ---------------------------------------------------------------- 열쇠


func test_every_key_is_one_the_game_can_actually_make() -> void:
	# 만들어지지 않는 열쇠에 실린 문안은 영영 안 나온다. 있는 줄 알고 안 채우게 된다.
	for key in _library.keys:
		if key == LibraryScript.QUIET_KEY:
			continue
		var parts := (key as String).split(":")
		assert_eq(parts.size(), 2, "열쇠 꼴이 아니다: %s" % key)
		var known := false
		for kind in LibraryScript.KIND_NAMES:
			if LibraryScript.KIND_NAMES[kind] == parts[0]:
				known = true
				break
		assert_true(known, "모르는 사건 종류: %s" % key)


func test_every_grade_belongs_to_that_kinds_axis() -> void:
	# 이동에 `대박` 을 달아 두면 그 문안은 영영 안 나온다.
	for key in _library.keys:
		var parts := (key as String).split(":")
		if key == LibraryScript.QUIET_KEY or parts[1].is_empty():
			continue
		var grades: Array[String] = []
		for kind in LibraryScript.KIND_NAMES:
			if LibraryScript.KIND_NAMES[kind] != parts[0]:
				continue
			match PromptScript.axis_of(kind):
				PromptScript.Axis.HAUL:
					grades = PromptScript.HAUL_GRADES
				PromptScript.Axis.CROWD:
					grades = PromptScript.CROWD_GRADES
		assert_has(grades, parts[1], "축에 없는 등급: %s" % key)


func test_the_quiet_turn_has_something_to_say() -> void:
	# 사건이 없는 턴이 제일 문맥이 필요한 턴이다 (19-rekka-voice.md §19.B.1).
	assert_gt(_library.posts_for(LibraryScript.QUIET_KEY).size(), 1)


# ---------------------------------------------------------------- 문안


func test_no_post_uses_a_slot_the_game_cannot_fill() -> void:
	for i in _library.count():
		for token in SlotsScript.keys_in(_library.posts[i]):
			var known := false
			for slot in ALLOWED_SLOTS:
				if token.begins_with(slot):
					known = true
					break
			assert_true(known, "%s — 모르는 자리표시 {%s}" % [_library.keys[i], token])


func test_a_quiet_post_never_calls_a_name() -> void:
	# 조용한 턴에는 부를 이름이 없다. 자리표시가 있으면 그 줄이 통째로 사라진다.
	for post in _library.posts_for(LibraryScript.QUIET_KEY):
		assert_eq(SlotsScript.keys_in(post), [] as Array[String], post)


func test_no_title_is_a_comment() -> void:
	# 첫 줄은 언제나 제목이다. 대괄호로 시작하면 후처리가 접두어로 알고 떼어 낸다.
	for title in _titles():
		assert_false(title.begins_with("["), "제목이 댓글이다: %s" % title)


func test_comment_placeholders_do_not_repeat_inside_a_post() -> void:
	# 같으면 후처리가 한 사람으로 보고 댓글 넷에 닉 하나를 준다.
	for i in _library.count():
		var seen: Dictionary = {}
		var first := true
		for line in _library.posts[i].split("\n"):
			var trimmed := (line as String).strip_edges()
			if trimmed.is_empty():
				continue
			if first:
				first = false
				continue
			if not trimmed.begins_with("["):
				continue
			var mark := trimmed.substr(0, trimmed.find("]") + 1)
			assert_false(seen.has(mark), "%s — 자리표시가 겹친다: %s" % [_library.keys[i], mark])
			seen[mark] = true


func test_no_post_counts_people_or_money() -> void:
	# 인원과 값어치는 등급이 말한다. 자산에 숫자가 박히면 후처리가 그 자리를 고쳐 버린다.
	for i in _library.count():
		var blocked := RekkaPost.blocked_numbers(_library.posts[i])
		assert_eq(blocked, [] as Array[String], "%s — %s" % [_library.keys[i], str(blocked)])


func test_titles_do_not_all_end_the_same_way() -> void:
	# 실측에서 제목 28편이 전부 `ㅋㅋ` 로 끝났다 (§19.B.8). 자산은 그 함정을 피해야 한다.
	var laughing := 0
	var titles := _titles()
	for title in titles:
		if title.ends_with("ㅋㅋ") or title.ends_with("ㅋ"):
			laughing += 1
	assert_lt(laughing * 2, titles.size(), "제목의 절반 넘게 같은 말로 끝난다")
