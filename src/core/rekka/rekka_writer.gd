class_name RekkaWriter
extends RefCounted
## 게시글 한 편을 조립한다. **두 문장 공급원이 만나는 자리다.**
##
##     자산(RekkaLibrary)  제목 · 논평 · 댓글      — 없으면 예비 문안이 대신한다
##     규칙(RekkaStock)    사실 줄                — 언제나 나온다
##     후처리(RekkaPost)   둘 다 지나는 하나의 문
##
## ## 후처리는 하나의 문이다
##
## 자산에서 온 글이든 규칙이 조립한 글이든 `RekkaPost.clean()` 을 **같은 인자로**
## 지난다. 두 경로가 갈리면 한쪽만 접두어 배정을 받거나 한쪽만 숫자 규칙을 어기는데,
## 그런 결함은 한 편만 보면 안 보이고 스무 편째에 보인다
## (docs/design/19-rekka-voice.md §19.B.4).
##
## ## 열쇠는 머리 사건 하나로 정한다
##
## 사건 넷을 전부 열쇠에 넣으면 조합이 다시 터진다 (§19.10.1). 머리 사건은
## `RekkaPrompt.pick_events()` 가 순위로 골라 준 첫 건이고, 그 순위는
## **플레이어가 다음 턴 결정을 내리는 데 얼마나 쓸모 있는가**다.

## 자산의 줄 중 댓글인 것. 후처리가 닉을 갈아 끼울 표시이기도 하다.
const _COMMENT_PREFIX := "["


## 게시글 한 편. 돌려주는 것은 **후처리를 마친** 글이다.
##
## `handle_start` 는 판이 시작한 뒤로 쓴 댓글 수의 누계다. 이어서 세지 않으면
## 편끼리 닉이 겹친다 — 실측에서 닉 139개 중 서로 다른 것이 113개였다 (§19.B.4).
static func write(
	events: Array[GameEvent],
	facts: Array[String],
	names: Dictionary,
	room_names: Array[String],
	index: int,
	handle_start: int,
	salt: int,
	library: RekkaLibrary = null
) -> String:
	var raw := compose(events, facts, names, index, salt, library)
	return RekkaPost.clean(raw, index, handle_start, room_names, salt)


## 후처리 전의 글. 검사와 테스트가 "무엇이 어디서 왔는가" 를 보려고 쓴다.
static func compose(
	events: Array[GameEvent],
	facts: Array[String],
	names: Dictionary,
	index: int,
	salt: int,
	library: RekkaLibrary = null
) -> String:
	var picked := RekkaPrompt.pick_events(events)
	var head := head_of(picked)
	var book := library if library != null else RekkaLibrary.shared()
	var stock := book.pick(RekkaLibrary.key_for(head), index, salt)
	var values := RekkaStock.values_of(head, names) if head != null else {}

	var lines: Array[String] = []
	lines.append(_title(stock, head, names, values, index, salt))
	lines.append_array(RekkaStock.fact_lines(picked, facts, names, index, salt))
	lines.append_array(_remarks(stock, values, index, salt))
	lines.append_array(_comments(stock, values, index, salt))
	return "\n".join(lines)


## 이번 턴의 머리 사건. 없으면 `null` 이고 그 턴은 조용한 턴이다.
##
## 순위를 다시 매기지 않고 `pick_events` 에 하나만 달라고 한다. 순위 표가 두 곳에
## 있으면 언젠가 어긋나고, 그러면 자산 열쇠와 제목이 서로 다른 사건을 가리킨다.
static func head_of(events: Array[GameEvent]) -> GameEvent:
	var top := RekkaPrompt.pick_events(events, 1)
	return top[0] if not top.is_empty() else null


## 제목. 자산에 있으면 그것을 채워 쓰고, 못 채우면 예비 문안으로 간다.
static func _title(
	stock: String, head: GameEvent, names: Dictionary, values: Dictionary, index: int, salt: int
) -> String:
	var body := _section(stock, false)
	if not body.is_empty():
		var filled := RekkaSlots.fill_line(body[0], values)
		if not filled.is_empty():
			return filled
	return RekkaStock.title_for(head, names, index, salt)


## 논평. 자산의 둘째 줄부터가 논평이고, 없으면 예비 문안에서 한 줄 가져온다.
static func _remarks(stock: String, values: Dictionary, index: int, salt: int) -> Array[String]:
	var found: Array[String] = []
	var body := _section(stock, false)
	for i in range(1, body.size()):
		var filled := RekkaSlots.fill_line(body[i], values)
		if not filled.is_empty():
			found.append(filled)
	if found.is_empty():
		found.append(RekkaStock.remark_line(index, salt))
	return found


## 댓글. 자산에 있으면 그것을, 없으면 예비 문안을 쓴다.
##
## 자산의 댓글이 자리표시를 못 채워 전부 버려질 수 있다. 그때도 댓글은 나가야 한다 —
## 댓글이 억측을 떠맡으므로 본문이 깨끗하게 유지된다 (13-information-design.md §13.3.0).
static func _comments(stock: String, values: Dictionary, index: int, salt: int) -> Array[String]:
	var found: Array[String] = []
	for line in _section(stock, true):
		var filled := RekkaSlots.fill_line(line, values)
		if not filled.is_empty():
			found.append(filled)
	if found.is_empty():
		return RekkaStock.comment_lines(index, salt)
	return found


## 자산 한 편을 댓글과 그 밖으로 가른다. 대괄호로 시작하는 줄이 댓글이다.
static func _section(stock: String, comments: bool) -> Array[String]:
	var found: Array[String] = []
	for line in stock.split("\n"):
		var trimmed := (line as String).strip_edges()
		if trimmed.is_empty():
			continue
		if trimmed.begins_with(_COMMENT_PREFIX) == comments:
			found.append(trimmed)
	return found
