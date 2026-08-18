extends GutTest
## RekkaFeedEntry 테스트 — 글을 화면이 읽는 모양으로 나눈다.
##
## 핵심은 **방 이름 판정**이다. docs/design/13-information-design.md §13.7 이
## *"기사에 나온 방 이름을 클릭하면 판 위에서 강조되는 정도의 연결은 필수다"* 라고
## 못 박았고, 그 연결이 틀리면 기사가 **엉뚱한 방을 가리키는 정보원**이 된다.
## 그건 장식보다 나쁘다.

const EntryScript := preload("res://src/core/rekka/rekka_feed_entry.gd")


func _entry(text: String, rooms: Dictionary = {}) -> RekkaFeedEntry:
	return EntryScript.new(3, text, rooms)


# ---------------------------------------------------------------- 나누기


func test_the_first_line_is_the_title_even_with_a_prefix() -> void:
	# 배정된 접두어 때문에 제목도 대괄호로 시작할 수 있다.
	var entry := _entry("[속보] 요한 또 움직임\n\n요한이 회랑으로 옮겼다\n\n[낄낄이] ㅋㅋ")

	assert_eq(entry.title, "[속보] 요한 또 움직임")
	assert_eq(entry.body, ["요한이 회랑으로 옮겼다"] as Array[String])
	assert_eq(entry.comments, ["[낄낄이] ㅋㅋ"] as Array[String])


func test_comments_are_told_apart_from_the_body() -> void:
	var entry := _entry("제목\n본문 한 줄\n논평 한 줄\n[가] 댓글 하나\n[나] 댓글 둘")

	assert_eq(entry.body.size(), 2, str(entry.body))
	assert_eq(entry.comments.size(), 2, str(entry.comments))


func test_an_empty_post_does_not_crash() -> void:
	var entry := _entry("")

	assert_eq(entry.title, "")
	assert_true(entry.body.is_empty())
	assert_true(entry.comments.is_empty())


# ---------------------------------------------------------------- 방 이름


func test_only_rooms_the_board_has_become_links() -> void:
	# 글에만 있고 판에 없는 이름을 누를 수 있으면 그 자체가 거짓 정보다.
	var found := EntryScript.rooms_in("요한이 회랑에서 유령의 방으로 갔다", {"회랑": "hall"})

	assert_eq(found.size(), 1, str(found))
	assert_eq(found.get("회랑"), "hall")


func test_the_longer_room_name_wins() -> void:
	# 생성기가 같은 이름을 두 번 쓰면 번호를 붙인다. 짧은 쪽을 먼저 맞추면 쪼개진다.
	var rooms := {"중정": "a", "중정 3": "b"}
	var spans := EntryScript.spans("중정 3에서 붙었다", rooms)

	assert_eq(str(spans[0]["text"]), "중정 3")
	assert_eq(str(spans[0]["room_id"]), "b")


func test_spans_keep_the_whole_line() -> void:
	# 토막을 다시 이으면 원래 줄이어야 한다. 한 글자라도 새면 화면에서 글이 깨진다.
	var line := "요한이 회랑에서 밀실로 갔다"
	var rebuilt := ""
	for span in EntryScript.spans(line, {"회랑": "hall", "밀실": "cell"}):
		rebuilt += str(span["text"])

	assert_eq(rebuilt, line)


func test_spans_mark_every_room_it_finds() -> void:
	var spans := EntryScript.spans("회랑과 밀실", {"회랑": "hall", "밀실": "cell"})
	var marked: Array[String] = []
	for span in spans:
		if not str(span["room_id"]).is_empty():
			marked.append(str(span["room_id"]))

	assert_eq(marked, ["hall", "cell"] as Array[String])


func test_a_line_without_any_room_is_one_plain_span() -> void:
	var spans := EntryScript.spans("다들 눈치만 보는 중", {"회랑": "hall"})

	assert_eq(spans.size(), 1)
	assert_eq(str(spans[0]["room_id"]), "")


func test_room_ids_are_listed_without_duplicates() -> void:
	var entry := _entry("제목\n회랑에서 또", {"회랑": "hall", "회랑 2": "hall"})

	assert_eq(entry.room_ids(), ["hall"] as Array[String])
