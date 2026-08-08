class_name RekkaPrompt
extends RefCounted
## 사건 로그를 렉카 게시글 생성 프롬프트의 **입력**으로 옮긴다.
##
## 게시글 문안 자체는 여기서 만들지 않는다. 문안은 언어 모델이 쓰고,
## 이 클래스는 모델에게 넘길 사실만 정리한다
## (docs/design/19-rekka-voice.md §19.A).
##
## **과장되는 것은 어투뿐이고 사실은 그대로 나간다** (13-information-design.md §13.3.0).
## 렉카는 스쳐 지나간 일을 놓고도 호들갑을 떨지만 "싸웠다" 라고 쓰지는 않는다.
##
## 경계는 이렇다.
##
##     이 클래스     -> 무엇이 사실인가
##     RekkaContext  -> 판이 그 사실 주위에 대해 이미 아는 것 (§19.A.3)
##     언어 모델     -> 그걸 어떻게 지껄이는가
##     RekkaPost     -> 지껄인 것에서 규칙 위반을 걷어낸다 (§19.A.6)
##
## ## 입력을 칸이 아니라 문장으로 넘긴다
##
## 5차까지는 `누가=... | 어디서=...` 꼴이었다. 15차에서 문장으로 바뀐 이유는
## 시스템 프롬프트가 짧아졌기 때문이다. 칸 형식은 "이 칸은 이런 뜻이다" 를
## 설명하는 줄을 프롬프트에 요구하는데, **프롬프트에 줄을 더하면 산출이 나빠진다**
## (§19.A.2 발견 1 — 188자에서 합니다체 8회, 330자에서 26회).
## 문장은 설명이 필요 없다.

## `magnitude` 가 무엇을 세는 값인지. 종류마다 다르므로 등급 축도 갈린다.
##
## magnitude 가 뜻하는 것은 **값어치 아니면 사람 수** 둘 중 하나이고,
## 이동에는 둘 다 없다. 그래서 축도 둘뿐이다.
enum Axis {
	NONE,  ## 셀 것이 없다
	HAUL,  ## 값어치 — 전리품 · 오간 물건
	CROWD,  ## 사람 수 — 마주친 · 붙은 · 쫓은 · 쓰러진 인원
}

## 시스템 프롬프트 전문. **의뢰인이 직접 작성했고 실제 호출로 검증됐다** (§19.A.4).
##
## **줄을 더하지 마라.** 길어질수록 문어체로 도망가고 빈칸을 상상으로 메운다.
## 고칠 것이 있으면 더하지 말고 바꿔라.
const SYSTEM := """너는 던전에서 벌어진 일을 SNS에 공개하는 사이코패스 악질 분탕충이야.

디시 펨코같은 커뮤니티 말투로 작성해.

제목은 한 줄로 어그로 끌듯이 작성하고 본문은 대여섯 줄, 그 밑에 댓글 몇 개.

댓글은 너보다 막 나가고 헛소리도 해.

준 사건 밖의 일을 네 입으로 확정하지 마. 댓글이 지어내는 건 놔둬.

댓글은 줄 앞에 대괄호로 닉네임을 적어"""

## 수확 등급 이름. 낮은 쪽이 앞이다.
##
## 네 단계인 이유는 플레이어가 이 값으로 내리는 결정이 하나이기 때문이다 —
## "저 방에 가 볼 값어치가 있나". 그 결정은 네 갈래로 갈린다.
## 갈 이유 없음 / 굳이 / 갈 만함 / 만사 제쳐놓고.
const HAUL_GRADES: Array[String] = ["빈손", "푼돈", "한몫", "대박"]

## 수확 등급의 경계값. `magnitude` 가 이 값 이상이면 다음 등급이다.
##
## **잠정 수치다.** 전리품 가치의 실제 분포가 정해지면 다시 본다 (§19.9.2).
const HAUL_CUTS: Array[int] = [1, 4, 10]

## 규모 등급 이름. 낮은 쪽이 앞이다.
##
## 세 단계인 이유도 결정이 하나이기 때문이다 — "내가 저기 끼어들 수 있나".
## 혼자 감당 / 애매 / 불가능 세 갈래면 충분하다.
const CROWD_GRADES: Array[String] = ["맞대면", "한줌", "떼거리"]

## 규모 등급의 경계값. 스쿼드 상한 인원이 정해지면 다시 본다 (§19.9.2).
const CROWD_CUTS: Array[int] = [2, 4]

## 한 게시글에 실을 사건 수의 상한.
##
## 시스템 프롬프트가 본문을 "대여섯 줄" 로 잡았다. 사건이 그보다 많으면
## 모델이 골라야 하고, 고르는 일을 모델에게 맡기면 매번 같은 것을 고른다.
## **고르는 것은 규칙이 맡는다** (§19.6.2 의 교훈).
const MAX_EVENTS := 4

## 사건 종류의 한국어 표기. 게시글에서 **사실로** 전달되는 값이다.
const _KIND_LABELS := {
	GameEvent.Kind.MOVED: "이동",
	GameEvent.Kind.SEARCHED: "탐색",
	GameEvent.Kind.ACQUIRED: "획득",
	GameEvent.Kind.ENCOUNTERED: "조우",
	GameEvent.Kind.FOUGHT: "전투",
	GameEvent.Kind.NEGOTIATED: "협상",
	GameEvent.Kind.FLED: "도주",
	GameEvent.Kind.DOWNED: "쓰러짐",
	GameEvent.Kind.ESCAPED: "탈출",
}

## 종류마다 `magnitude` 가 무엇을 세는가.
##
## 이 표가 비어 있으면 모델이 값어치를 사람 수로 읽는다.
## 앞선 차수에서 "8 가치" 를 "8명" 으로 적은 사고가 그것이다 (§19.5.3).
const _KIND_AXES := {
	GameEvent.Kind.MOVED: Axis.NONE,
	GameEvent.Kind.SEARCHED: Axis.HAUL,
	GameEvent.Kind.ACQUIRED: Axis.HAUL,
	GameEvent.Kind.ENCOUNTERED: Axis.CROWD,
	GameEvent.Kind.FOUGHT: Axis.CROWD,
	GameEvent.Kind.NEGOTIATED: Axis.HAUL,
	GameEvent.Kind.FLED: Axis.CROWD,
	GameEvent.Kind.DOWNED: Axis.CROWD,
	GameEvent.Kind.ESCAPED: Axis.HAUL,
}

## 사건을 게시글 소재로 고를 때의 순위. 큰 쪽이 먼저 실린다.
##
## 이 순서는 "플레이어가 다음 턴 결정을 내리는 데 얼마나 쓸모 있는가" 다.
## 누가 어디서 빠져나갔는지는 판이 끝나가는 신호이고, 누가 어디로 옮겼는지는
## 다음 턴이면 또 바뀐다.
const _PRIORITY := {
	GameEvent.Kind.ESCAPED: 9,
	GameEvent.Kind.DOWNED: 8,
	GameEvent.Kind.FOUGHT: 7,
	GameEvent.Kind.ACQUIRED: 6,
	GameEvent.Kind.NEGOTIATED: 5,
	GameEvent.Kind.FLED: 4,
	GameEvent.Kind.ENCOUNTERED: 3,
	GameEvent.Kind.SEARCHED: 2,
	GameEvent.Kind.MOVED: 1,
}


## 사건 종류의 한국어 표기.
static func kind_label(kind: GameEvent.Kind) -> String:
	return _KIND_LABELS.get(kind, "")


## 이 종류의 `magnitude` 가 무엇을 세는 값인가.
static func axis_of(kind: GameEvent.Kind) -> Axis:
	return _KIND_AXES.get(kind, Axis.NONE)


## 값어치를 수확 등급으로 옮긴다. **0 은 등급이 아니라 빈손이다.**
##
## 빈손은 지어낸 것이 아니라 실제로 허탕을 쳤다는 정보이므로 등급으로 남긴다.
## "저 방은 이미 누가 털었다" 는 위험도 추론의 재료다.
static func haul_grade(magnitude: int) -> String:
	return HAUL_GRADES[_bucket(magnitude, HAUL_CUTS)]


## 사람 수를 규모 등급으로 옮긴다. 인원이 기록되지 않았으면 빈 문자열이다.
##
## 여기서 0 을 등급으로 만들면 "아무도 없는 전투" 가 게시글에 실린다.
static func crowd_grade(magnitude: int) -> String:
	if magnitude <= 0:
		return ""
	return CROWD_GRADES[_bucket(magnitude, CROWD_CUTS)]


## 사건의 등급. 등급이 없는 사건은 빈 문자열이다.
static func grade_of(event: GameEvent) -> String:
	match axis_of(event.kind):
		Axis.HAUL:
			return haul_grade(event.magnitude)
		Axis.CROWD:
			return crowd_grade(event.magnitude)
		_:
			return ""


## 이름을 홑화살괄호로 감싼다.
##
## **감싸지 않으면 모델이 이름을 서술로 읽는다.** `웃는 베른` 을 그대로 주면
## "베른이 웃고 있었습니다" 가 나온다 (§19.A.5 의 실측).
## 괄호는 입력 전용이고 출력에서는 `RekkaPost` 가 지운다.
static func wrap_name(name: String) -> String:
	return "<%s>" % name


## 사건 하나를 입력 한 줄로 옮긴다.
##
## **수치는 한 자도 나가지 않는다.** 이 게임의 전투는 피해가 오가는 방식이 아니라
## 상황이 갈리는 방식이고(docs/design/05-rules.md §5.8),
## 게시글에 "12 피해" 가 뜨면 있지도 않은 계량 감각이 생긴다.
##
## **중의어를 쓰지 않는다.** `뒤졌다` 를 모델이 "죽었다" 로 읽은 적이 있다.
## 걸러 낸 말의 목록은 §19.B.5 에 있다.
static func serialize_event(event: GameEvent, names: Dictionary = {}) -> String:
	var others := _resolve_names(event.related_actor_ids, names)
	var other := others[0] if not others.is_empty() else ""
	return "%s%s" % [_action_of(event, other), _grade_tail(event)]


## 이번 턴 사건 중 게시글에 실을 것들. 순위가 높은 쪽부터 최대 `limit` 건이다.
##
## **고르는 일을 모델에게 맡기지 않는다.** 5차 실측에서 모델은 사건이 하나도 없는
## 턴에 기사 세 편을 썼다 (§19.6.2). 편집은 문체가 아니라 규칙이다.
## **고르는 것과 늘어놓는 것은 다른 일이다.** 무엇을 실을지는 순위가 정하지만
## 실린 것들의 순서는 **일어난 순서**여야 한다. 순위대로 늘어놓았더니
## `거래를 맺었다` 다음에 `그 방으로 옮겼다` 가 와서, 모델이 없는 이동을 지어냈다 —
## "거래 끝나자마자 둘 다 계단참으로 이동함" 같은 문장이 그것이다.
static func pick_events(events: Array[GameEvent], limit: int = MAX_EVENTS) -> Array[GameEvent]:
	var order: Dictionary = {}
	for index in events.size():
		order[events[index]] = index
	var ranked := events.duplicate()
	ranked.sort_custom(func(a: GameEvent, b: GameEvent) -> bool: return _rank_of(a) > _rank_of(b))
	var chosen := ranked.slice(0, maxi(0, limit))
	chosen.sort_custom(func(a: GameEvent, b: GameEvent) -> bool: return order[a] < order[b])
	var picked: Array[GameEvent] = []
	for event in chosen:
		picked.append(event)
	return picked


## 한 턴을 통째로 옮긴다. 이 문자열이 그대로 모델의 사용자 메시지가 된다.
##
## **두 칸으로 나눈다** (§19.A.5). 이번 턴에 벌어진 것과, 판이 이미 들고 있는 상태.
## 후자가 없으면 모델은 할 말이 없어서 짧게 쓰거나, 늘리라면 되풀이하거나,
## 놓아주면 지어낸다. **판 문맥을 함께 넘기면 셋 다 사라진다** (§19.A.3).
##
## `spent` 는 최근 게시글에서 이미 써먹은 말이다. 모델은 턴마다 새로 불려서
## 자기가 방금 무슨 밈을 썼는지 모른다.
static func serialize_turn(
	events: Array[GameEvent],
	context: Array[String] = [] as Array[String],
	names: Dictionary = {},
	spent: Array[String] = [] as Array[String]
) -> String:
	var lines: Array[String] = ["이번 턴 사건"]
	if events.is_empty():
		lines.append("- 아무 일도 없었다.")
	else:
		for event in events:
			lines.append("- %s" % serialize_event(event, names))
	if not context.is_empty():
		lines.append("판이 이미 아는 것")
		for fact in context:
			lines.append("- %s" % fact)
	if not spent.is_empty():
		lines.append("이미 써먹은 말 (다시 쓰지 마)")
		lines.append("- %s" % ", ".join(spent))
	return "\n".join(lines)


## 값이 경계값 몇 개를 넘었는가. 그대로 등급 배열의 첨자가 된다.
static func _bucket(value: int, cuts: Array[int]) -> int:
	var index := 0
	for cut in cuts:
		if value >= cut:
			index += 1
	return index


## 사건 한 줄의 서술부. 상대가 없으면 상대를 지어내지 않고 문장을 줄인다.
static func _action_of(event: GameEvent, other_name: String) -> String:
	var who := wrap_name(event.actor_name)
	var room := wrap_name(event.room_name)
	var other := wrap_name(other_name)
	var subject := KoreanParticle.subject(event.actor_name)
	var with_other := KoreanParticle.conjunction(other_name)
	var has_other := not other_name.is_empty()
	match event.kind:
		GameEvent.Kind.MOVED:
			return (
				"%s%s %s%s 옮겼다." % [who, subject, room, KoreanParticle.direction(event.room_name)]
			)
		GameEvent.Kind.SEARCHED:
			# `뒤졌다` 는 쓰지 않는다. 모델이 "죽었다" 로 읽는다 (§19.B.5).
			return (
				"%s%s %s%s 수색했다." % [who, subject, room, KoreanParticle.object_of(event.room_name)]
			)
		GameEvent.Kind.ACQUIRED:
			return "%s%s %s에서 물건을 챙겼다." % [who, subject, room]
		GameEvent.Kind.ENCOUNTERED:
			if has_other:
				return "%s에서 %s%s %s%s 마주쳤다." % [room, who, subject, other, with_other]
			return "%s에서 %s%s 누군가와 마주쳤다." % [room, who, subject]
		GameEvent.Kind.FOUGHT:
			if has_other:
				return "%s에서 %s%s %s%s 맞붙었다." % [room, who, subject, other, with_other]
			return "%s에서 %s%s 싸웠다." % [room, who, subject]
		GameEvent.Kind.NEGOTIATED:
			if has_other:
				return "%s에서 %s%s %s%s 거래를 맺었다." % [room, who, subject, other, with_other]
			return "%s에서 %s%s 거래를 맺었다." % [room, who, subject]
		GameEvent.Kind.FLED:
			if has_other:
				return (
					"%s%s %s에서 %s%s 피해 달아났다."
					% [who, subject, room, other, KoreanParticle.object_of(other_name)]
				)
			return "%s%s %s에서 달아났다." % [who, subject, room]
		GameEvent.Kind.DOWNED:
			# 쓰러짐은 영구 사망이 아니다 (docs/design/14-squad.md §14.6).
			# 그래서 `눕혔다` `접었다` 같은 말을 쓰지 않는다.
			if has_other:
				return (
					"%s에서 %s%s 쓰러졌다. 제압한 쪽은 %s%s."
					% [room, who, subject, other, KoreanParticle.copula(other_name)]
				)
			return "%s에서 %s%s 쓰러졌다." % [room, who, subject]
		GameEvent.Kind.ESCAPED:
			return (
				"%s%s %s%s 던전을 빠져나갔다."
				% [who, subject, room, KoreanParticle.direction(event.room_name)]
			)
		_:
			return "%s에서 %s%s 뭔가 했다." % [room, who, subject]


## 등급을 덧붙이는 뒷문장. 등급이 없으면 빈 문자열이다.
static func _grade_tail(event: GameEvent) -> String:
	var grade := grade_of(event)
	if grade.is_empty():
		return ""
	var copula := KoreanParticle.copula(grade)
	if axis_of(event.kind) == Axis.CROWD:
		return " 규모는 %s%s." % [grade, copula]
	match event.kind:
		GameEvent.Kind.SEARCHED:
			return " 수확은 %s%s." % [grade, copula]
		GameEvent.Kind.NEGOTIATED:
			return " 오간 값어치는 %s%s." % [grade, copula]
		GameEvent.Kind.ESCAPED:
			return " 들고 나간 값어치는 %s%s." % [grade, copula]
		_:
			return " 값어치는 %s%s." % [grade, copula]


## 소재 순위. 표에 없는 종류는 제일 뒤로 보낸다.
static func _rank_of(event: GameEvent) -> int:
	return _PRIORITY.get(event.kind, 0)


## id 를 표시명으로 바꾼다. 모르는 id 는 그대로 둔다.
##
## GameEvent 는 주인공의 이름만 보존하고 얽힌 상대는 id 로만 남긴다.
## 게시글에 "누구와" 를 실으려면 여기서 이름을 되찾아야 한다 (§19.9.3).
static func _resolve_names(ids: Array[String], names: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		result.append(str(names.get(id, id)))
	return result
