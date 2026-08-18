class_name RekkaFeedEntry
extends RefCounted
## 게시글 한 편. **화면이 읽는 모양**으로 나눠 둔 것이다.
##
## 후처리를 마친 글은 줄바꿈으로만 나뉜 한 덩어리 문자열이다. 화면은 그것을
## 제목 · 본문 · 댓글로 나눠 서로 다른 판(먹판 · 별색판)으로 찍어야 하므로
## (docs/design/32-rekka-feed.md §32.5.2), 나누는 규칙을 화면이 아니라 여기에 둔다.
## 화면에 두면 인게임 피드와 주둔지 피드가 각자 나누게 되고 (08-ui-ux.md §8.3.4.1),
## 둘이 어긋나는 순간 같은 글이 두 화면에서 다르게 보인다.
##
## ## 방 이름은 글이 아니라 판에서 찾는다
##
## §13.7 이 **필수**로 못 박았다 — *"기사에 나온 방 이름을 클릭하면 판 위에서
## 강조되는 정도의 연결은 필수다. 안 그러면 기사는 장식이 된다."*
##
## 그런데 **글에만 있고 판에는 없는 이름을 누를 수 있으면 안 된다.** 모델도
## 예비 문안도 방 이름을 지어낼 수 있고, 없는 방으로 이어지는 링크는 그 자체가
## 거짓 정보다. 그래서 링크가 되는 것은 판이 실제로 들고 있는 표시명뿐이다.

## 몇 번째 턴의 글인가.
var turn: int = 0

## 후처리를 마친 글 전체. 화면에 나가는 것과 한 글자도 다르지 않다.
var text: String = ""

## 제목 줄. 배정된 접두어가 붙어 있다.
var title: String = ""

## 본문 줄들. 사실 줄과 논평이 섞여 있다.
var body: Array[String] = []

## 댓글 줄들. 각 줄이 `[닉] 말` 꼴이다.
var comments: Array[String] = []

## 이 글에 나온 방들. 표시명 -> 방 id.
var rooms: Dictionary = {}


func _init(entry_turn: int = 0, entry_text: String = "", entry_rooms: Dictionary = {}) -> void:
	turn = entry_turn
	text = entry_text
	rooms = entry_rooms.duplicate()
	_split()


## 이 글이 가리키는 방 id 들. 판을 강조할 때 쓴다.
func room_ids() -> Array[String]:
	var found: Array[String] = []
	for name in rooms:
		var id := str(rooms[name])
		if not id.is_empty() and not found.has(id):
			found.append(id)
	return found


## 한 줄을 **방 이름 토막과 그냥 글자 토막**으로 자른다.
##
## 화면은 이 토막들을 받아 방 이름만 누를 수 있게 만든다. 자르는 규칙이 여기 있는
## 이유는 그것이 화면 배치가 아니라 판정이기 때문이다 — 어디까지가 방 이름인가.
##
## **긴 이름부터 맞춘다.** 생성기는 같은 이름이 두 번 나오면 번호를 붙이므로
## (`room_kind_planner.pick_name`) `중정` 과 `중정 3` 이 함께 있다.
## 짧은 쪽을 먼저 맞추면 `중정 3` 이 `중정` + `3` 으로 쪼개져 엉뚱한 방으로 이어진다.
static func spans(line: String, rooms_by_name: Dictionary) -> Array[Dictionary]:
	var names := _by_length(rooms_by_name)
	var found: Array[Dictionary] = []
	var plain := ""
	var cursor := 0
	while cursor < line.length():
		var hit := ""
		for name in names:
			if line.substr(cursor, name.length()) == name:
				hit = name
				break
		if hit.is_empty():
			plain += line[cursor]
			cursor += 1
			continue
		if not plain.is_empty():
			found.append({"text": plain, "room_id": ""})
			plain = ""
		found.append({"text": hit, "room_id": str(rooms_by_name[hit])})
		cursor += hit.length()
	if not plain.is_empty():
		found.append({"text": plain, "room_id": ""})
	return found


## 판이 들고 있는 이름 중 이 글에 실제로 남아 있는 것들.
##
## 후처리를 **마친** 글에서 찾아야 한다. `RekkaPost.normalize_names()` 가
## 띄어쓰기를 판의 표기로 되돌리기 전에 찾으면 `중정3` 을 못 잡는다.
static func rooms_in(post_text: String, rooms_by_name: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for name in _by_length(rooms_by_name):
		if post_text.contains(name):
			found[name] = rooms_by_name[name]
	return found


static func _by_length(rooms_by_name: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for name in rooms_by_name:
		names.append(str(name))
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return names


## 제목 · 본문 · 댓글로 나눈다.
##
## **첫 줄은 언제나 제목이다.** 배정된 접두어 때문에 제목도 대괄호로 시작할 수 있어서
## "대괄호로 시작하면 댓글" 규칙을 첫 줄에 적용하면 제목이 댓글이 된다
## (`RekkaPost.apply_handles` 도 같은 이유로 첫 줄을 건너뛴다).
func _split() -> void:
	body = []
	comments = []
	var seen_title := false
	for line in text.split("\n"):
		var trimmed := (line as String).strip_edges()
		if trimmed.is_empty():
			continue
		if not seen_title:
			seen_title = true
			title = trimmed
			continue
		if trimmed.begins_with("["):
			comments.append(trimmed)
		else:
			body.append(trimmed)
