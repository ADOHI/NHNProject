class_name RekkaPrompt
extends RefCounted
## 사건 로그를 렉카 기사 생성 프롬프트의 **입력 블록**으로 옮긴다.
##
## 기사 문안 자체는 여기서 만들지 않는다. 문안은 언어 모델이 쓰고,
## 이 클래스는 모델에게 넘길 사실만 정리한다
## (docs/design/19-rekka-voice.md §19.4).
##
## **부풀리기를 모델에 맡기지 않고 여기서 계산해 넘긴다.**
## 표본을 돌려 보니 모델은 규칙보다 문맥상 자연스러운 표현을 골랐고,
## 실제 3 을 "두어 개" 로 적어 값을 줄였다 (§19.5.2).
## 축소가 한 번이라도 일어나면 "기사는 하한선" 이라는 규칙이 깨지고,
## 그 순간 플레이어의 역보정이 성립하지 않는다
## (docs/design/13-information-design.md §13.3).
##
## 그래서 경계를 이렇게 긋는다.
##
##     이 클래스 -> 무엇이 사실이고 보도값이 얼마인가 (규칙)
##     언어 모델 -> 그걸 어떻게 지껄이는가 (문체)

## 보도값 배율의 범위. 하한이 1 이라 **절대 축소되지 않는다.**
##
## 고정 배율로 두면 몇 판 만에 간파되어 긴장이 사라지고,
## 범위를 두면 하한만 확실해진다 (docs/design/13-information-design.md §13.3.2).
const INFLATE_MIN := 1
const INFLATE_MAX := 3

## 사건 종류의 한국어 표기. 기사에서 **사실로** 전달되는 값이다.
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

## 보도값의 단위 이름.
##
## 단위를 함께 넘기지 않으면 모델이 "8 가치" 를 "8명" 으로 적는다 (§19.5.3).
## 같은 magnitude 라도 종류마다 뜻이 다르기 때문에 생기는 사고다.
const _KIND_UNITS := {
	GameEvent.Kind.MOVED: "",
	GameEvent.Kind.SEARCHED: "건",
	GameEvent.Kind.ACQUIRED: "가치",
	GameEvent.Kind.ENCOUNTERED: "인원",
	GameEvent.Kind.FOUGHT: "피해",
	GameEvent.Kind.NEGOTIATED: "가치",
	GameEvent.Kind.FLED: "추격 인원",
	GameEvent.Kind.DOWNED: "인원",
	GameEvent.Kind.ESCAPED: "가치",
}


## 사건 종류의 한국어 표기.
static func kind_label(kind: GameEvent.Kind) -> String:
	return _KIND_LABELS.get(kind, "")


## 보도값의 단위 이름. 수치가 뜻을 갖지 않는 종류는 빈 문자열이다.
static func magnitude_unit(kind: GameEvent.Kind) -> String:
	return _KIND_UNITS.get(kind, "")


## 실제 수치를 보도값으로 부풀린다. **줄어드는 경우는 없다.**
##
## 0 은 그대로 0 이다. 없는 일에 숫자를 붙이면 사건을 지어내는 것과 같다.
static func inflate(magnitude: int, rng: RandomNumberGenerator) -> int:
	if magnitude <= 0:
		return 0
	return magnitude * rng.randi_range(INFLATE_MIN, INFLATE_MAX)


## 사건 하나를 프롬프트 한 줄로 옮긴다.
##
## 실제 magnitude 는 넘기지 않는다. 넘기면 모델이 둘 사이에서 타협해
## 보도값보다 작은 수를 적을 여지가 생긴다.
static func serialize_event(
	event: GameEvent, reported: int, player_actor_id: String = "", names: Dictionary = {}
) -> String:
	var side := "플레이어" if event.actor_id == player_actor_id else "타인"
	var parts: Array[String] = [
		"- 누가=%s" % event.actor_name,
		"소속=%s" % side,
		"어디서=%s" % event.room_name,
		"무엇을=%s" % kind_label(event.kind),
	]
	var unit := magnitude_unit(event.kind)
	if reported > 0 and not unit.is_empty():
		parts.append("보도값=%d" % reported)
		parts.append("단위=%s" % unit)
	var together := _resolve_names(event.related_actor_ids, names)
	if not together.is_empty():
		parts.append("함께=%s" % ", ".join(together))
	return " | ".join(parts)


## 한 턴을 통째로 옮긴다. 이 문자열이 그대로 모델의 사용자 메시지가 된다.
##
## 사건이 없어도 블록을 만든다. **조용한 턴에도 기사는 나가야 한다** —
## 아무도 안 움직였다는 것 자체가 위험도 숫자에 대한 정보이기 때문이다 (§19.6.3).
static func serialize_turn(
	turn: int,
	events: Array[GameEvent],
	viewpoint: String,
	rng: RandomNumberGenerator,
	player_actor_id: String = "",
	names: Dictionary = {}
) -> String:
	var lines: Array[String] = ["턴: %d" % turn, "시점: %s" % viewpoint]
	if events.is_empty():
		lines.append("사건: 없음")
		return "\n".join(lines)

	lines.append("사건:")
	for event in events:
		var reported := inflate(event.magnitude, rng)
		lines.append(serialize_event(event, reported, player_actor_id, names))
	return "\n".join(lines)


## id 를 표시명으로 바꾼다. 모르는 id 는 그대로 둔다.
##
## GameEvent 는 주인공의 이름만 보존하고 얽힌 상대는 id 로만 남긴다.
## 기사에 "누구와" 를 실으려면 여기서 이름을 되찾아야 한다 (§19.9).
static func _resolve_names(ids: Array[String], names: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		result.append(str(names.get(id, id)))
	return result
