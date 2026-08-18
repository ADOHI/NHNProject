class_name RekkaStock
extends RefCounted
## **예비 문안.** 자산에 없는 조합이 나와도 피드가 비지 않게 하는 층.
##
## ## 왜 이것이 있어야 하는가
##
## 문장은 미리 만들어 자산으로 싣는다 (docs/design/32-rekka-feed.md §32.1).
## 그런데 자산은 사건 종류 x 등급으로 키를 잡으므로 **빈칸이 반드시 생긴다.**
## 빈칸에서 아무것도 안 나오면 그 턴 피드가 통째로 빈다.
##
## **피드가 비는 것보다 밋밋한 게 낫다** (19-rekka-voice.md §19.10).
## 빈 피드는 정보 손실이고 밋밋한 글은 톤 손실일 뿐이다.
##
## ## 지어내지 않는 유일한 방법은 이미 사실인 문장을 쓰는 것이다
##
## 그래서 사실 줄은 **새로 쓰지 않는다.** `RekkaPrompt.serialize_event()` 와
## `RekkaContext.for_turn()` 이 만든 바로 그 줄을 쓰고, 끝에 말투만 얹는다.
## 그 줄들은 이미 판에서 읽어 만든 것이고 중의어도 걸러져 있다 (§19.B.5).
##
##     사실 줄   <칼날의 요한>이 <회랑>을 수색했다. 수확은 푼돈이다.
##     예비 문안 칼날의 요한이 회랑을 수색했다. 수확은 푼돈이다 ㅋㅋ
##
## **본문은 억측하지 않는다.** 억측은 댓글이 떠맡는다 (13-information-design.md §13.3.0).
## 그래서 밋밋해도 틀리지 않는다.
##
## ## 고르는 규칙이 규칙적이면 그것이 새로운 틀이다
##
## 어미도 논평도 댓글도 목록에서 고른다. 순서대로 소비하면 그 순서가 곧 반복이 된다 —
## `RekkaHandles` 가 이미 두 차수 연속으로 밟은 함정이라 여기도 `RekkaRing` 을 쓴다.

## 사실 줄 끝에 얹는 말투. **절반이 빈 칸이다.**
##
## 매 줄에 붙으면 그게 곧 틀이다. 접두어를 절반만 붙이는 것과 같은 이유다 (§19.B.4).
## 문장을 고쳐 쓰지 않고 뒤에 붙이기만 하는 이유는, 한국어 종결어미를 기계가 갈아
## 끼우면 `헤어진 사이다` 가 `헤어진 사임` 이 되기 때문이다. **못 잡은 것은 어색할
## 뿐이지만 잘못 잡은 것은 문장을 부순다** (§19.B.3 이 같은 결론을 이미 냈다).
## **말줄임표는 뺐다.** 사실 줄 끝에 붙으니 말투가 아니라 **글이 잘린 것**으로 읽혔다 —
## `칼날의 요한이 가스 저장고 2로 옮겼다...` 는 뒤가 더 있는 문장처럼 보인다.
const TAILS: Array[String] = ["", " ㅋㅋ", "", " ㄷㄷ", "", " ㅋ", "", " ㄹㅇ", "", " ㅇㅇ"]

## 본문 줄 수의 폭. **편마다 달라야 한다.**
##
## 실측에서 28편의 본문이 **전부 정확히 여섯 줄**이었다 (19-rekka-voice.md 19.B.8).
## 길이 분산이 0 이면 목록을 훑을 때 글이 아니라 표로 보인다.
##
## 상한을 두는 이유는 따로 있다. 사건 넷에 문맥 넷을 그대로 다 실으면 아홉 줄이 되고,
## 그 아홉 줄은 **읽는 글이 아니라 로그 뷰어**다. 규칙 문안은 편집을 못 하므로
## 편집 대신 자른다.
const BODY_MIN := 4
const BODY_MAX := 7

## 제목. 자리표시는 `RekkaSlots` 가 채우고, 못 채우면 다음 것으로 넘어간다.
##
## 종류마다 여러 벌인 이유는 5차의 실패가 분량이 아니라 **같은 틀**이었기 때문이다 —
## 22편의 본문 형태가 한 가지였다 (§19.A.1).
const TITLES := {
	GameEvent.Kind.MOVED: ["{주체} 또 자리 옮겼다", "{방} 쪽으로 붙는 놈 있음"],
	GameEvent.Kind.SEARCHED: ["{방} 긁은 결과 {등급}", "{주체이} {방} 뒤적인 값 나왔다"],
	GameEvent.Kind.ACQUIRED: ["{주체} 오늘 {등급} 찍었네", "{방}에서 {등급} 나왔다는 소문"],
	GameEvent.Kind.ENCOUNTERED: ["{방}에서 {주체와} {상대} 마주침", "{방} 지금 분위기 이상함"],
	GameEvent.Kind.FOUGHT: ["{방} 붙었다 {등급}", "{주체} 결국 손 나갔다"],
	GameEvent.Kind.NEGOTIATED: ["{주체} 거래 텄다 {등급}", "{방}에서 뭔가 오갔다는데"],
	GameEvent.Kind.FLED: ["{주체} 튐 ㅋㅋ", "{방}에서 발 뺀 놈 나옴"],
	GameEvent.Kind.DOWNED: ["{주체} 뻗음", "{방} 하나 정리됐다"],
	GameEvent.Kind.ESCAPED: ["{주체} 밖으로 나감 {등급}", "{방} 통해서 빠진 놈 있다"],
}

## 사건이 하나도 없는 턴의 제목. 자리표시가 없어야 한다 — 부를 이름이 없는 턴이다.
##
## **조용한 턴에도 기사는 나간다.** 아무 일도 없었다는 것 자체가 판을 읽는 재료다.
const QUIET_TITLES: Array[String] = [
	"오늘 던전 왜 이렇게 조용하냐",
	"아무도 안 움직이는 중",
	"지금 다들 눈치만 보는 각",
	"소식 없음. 그래서 더 수상함",
]

## 논평. **사실을 하나도 담지 않는다.** 담는 순간 지어낸 것이 된다.
const REMARKS: Array[String] = [
	"다음 턴에 누가 먼저 움직이나 보자",
	"이거 판 돌아가는 꼴 보면 답 나온다",
	"구경값은 하네",
	"나는 그냥 보고만 있겠음",
	"이 판 끝나고 정산이나 봐야지",
	"뭐 어차피 다들 자기 몫 챙기러 온 거 아니냐",
]

## 댓글. 억측을 떠맡는 자리라 **틀려도 된다** (§13.3.0).
##
## 닉네임은 여기 적지 않는다. `RekkaPost.apply_handles()` 가 갈아 끼우므로
## 자리만 한 글자로 표시해 두면 된다 — 숫자를 쓰면 후처리의 숫자 규칙과 엮인다.
const COMMENTS: Array[String] = [
	"내가 볼 땐 이미 짜고 치는 거임",
	"저럴 줄 알았다니까",
	"저기 아직 뭐 남았을 텐데",
	"저 판에 나 아는 사람 있음",
	"솔직히 부럽다",
	"저래놓고 나중에 또 아쉬운 소리 함",
	"다음 턴에 바로 뒤집힌다에 건다",
	"굳이 저기를 들어간 이유가 있을 거임",
	"관전자한테는 최고의 전개",
	"저 동선 나는 못 따라감",
	"어차피 나갈 때 다 뺏긴다",
	"이게 왜 화제인지 모르겠는데",
]

## 댓글 자리표시. 편마다 서로 다른 것을 써야 후처리가 서로 다른 닉을 배정한다.
##
## `RekkaPost.apply_handles()` 는 **원래 닉이 같으면 같은 사람**으로 본다.
## 전부 빈 대괄호로 두면 한 편의 댓글 넷이 전부 한 사람이 된다.
const _COMMENT_MARKS: Array[String] = ["가", "나", "다", "라", "마"]

## 한 편에 붙는 댓글 수의 폭. 편마다 달라야 목록이 기계처럼 안 읽힌다.
const COMMENT_MIN := 2
const COMMENT_MAX := 4


## 사실 줄. **사건 줄이 먼저고 문맥 줄이 뒤다.**
##
## 순서를 바꾸면 이번 턴에 벌어진 일보다 배경이 앞에 서서, 읽는 사람이
## 무엇이 새 소식인지 못 가린다.
##
## **자르는 것은 언제나 문맥 쪽이다.** 사건은 이번 턴의 새 소식이고 문맥은 배경이다.
## 다만 문맥이 있는데 **한 줄도 안 나가는 일은 없다** — 사건만 나열된 편은
## 판을 읽을 재료가 없어서 정보원이 아니라 로그가 된다 (19-rekka-voice.md 19.B.9 1차).
static func fact_lines(
	events: Array[GameEvent], facts: Array[String], names: Dictionary, index: int, salt: int
) -> Array[String]:
	var lines: Array[String] = []
	for event in events:
		lines.append(RekkaPrompt.serialize_event(event, names))
	lines.append_array(facts.slice(0, maxi(1, body_limit(index, salt) - lines.size())))
	var dressed: Array[String] = []
	for i in lines.size():
		dressed.append(_dress(lines[i], index + i, salt))
	return dressed


## 이 편의 본문 줄 수 상한. 편마다 다르다.
static func body_limit(index: int, salt: int) -> int:
	return BODY_MIN + RekkaRing.slot(index, salt, BODY_MAX - BODY_MIN + 1)


## 제목. 채울 수 있는 첫 후보를 쓴다.
##
## 후보를 순서대로 보지 않고 걸음으로 건너뛴다 — 순서대로 보면 같은 종류의 사건이
## 언제나 같은 제목을 받고, 그 규칙이 두어 판이면 읽힌다.
static func title_for(event: GameEvent, names: Dictionary, index: int, salt: int) -> String:
	if event == null:
		return _pick(QUIET_TITLES, index, salt)
	var shapes: Array = TITLES.get(event.kind, [])
	var values := values_of(event, names)
	for offset in shapes.size():
		var shape: String = shapes[RekkaRing.slot(index + offset, salt, shapes.size())]
		var filled := RekkaSlots.fill_line(shape, values)
		if not filled.is_empty():
			return filled
	# 방 이름만 있으면 언제나 채워진다. 사건이 있는데 제목이 비는 일은 없어야 한다.
	var room := RekkaSlots.fill_line("{방} 쪽에서 뭔가 났다", values)
	return room if not room.is_empty() else _pick(QUIET_TITLES, index, salt)


## 논평 한 줄. 사실을 담지 않으므로 어떤 사건에나 붙는다.
static func remark_line(index: int, salt: int) -> String:
	return _pick(REMARKS, index, salt)


## 댓글들. 앞에 붙는 대괄호는 자리표시이고 후처리가 닉으로 갈아 끼운다.
static func comment_lines(index: int, salt: int) -> Array[String]:
	var span := COMMENT_MAX - COMMENT_MIN + 1
	var count := COMMENT_MIN + RekkaRing.slot(index, salt, span)
	var lines: Array[String] = []
	for i in count:
		var mark: String = _COMMENT_MARKS[i % _COMMENT_MARKS.size()]
		lines.append("[%s] %s" % [mark, _pick(COMMENTS, index * COMMENT_MAX + i, salt)])
	return lines


## 사건 하나에서 자리표시에 넣을 값들.
##
## **상대가 없으면 그 열쇠를 아예 두지 않는다.** 빈 문자열로 두면 `RekkaSlots` 가
## 그 줄을 버리는 것은 같지만, 열쇠가 있는데 값이 없는 상태를 만들지 않는 편이
## 읽는 사람에게 덜 헷갈린다.
static func values_of(event: GameEvent, names: Dictionary) -> Dictionary:
	var values := {"주체": event.actor_name, "방": event.room_name}
	var grade := RekkaPrompt.grade_of(event)
	if not grade.is_empty():
		values["등급"] = grade
	for id in event.related_actor_ids:
		var other := str(names.get(id, id))
		if not other.is_empty():
			values["상대"] = other
			break
	return values


## 사실 줄에 말투를 얹는다. **문장은 고치지 않는다.**
static func _dress(line: String, index: int, salt: int) -> String:
	var body := line.strip_edges()
	if body.ends_with("."):
		body = body.substr(0, body.length() - 1)
	return body + _pick(TAILS, index, salt)


static func _pick(options: Array, index: int, salt: int) -> String:
	if options.is_empty():
		return ""
	return str(options[RekkaRing.slot(index, salt, options.size())])
