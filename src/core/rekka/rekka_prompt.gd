class_name RekkaPrompt
extends RefCounted
## 사건 로그를 렉카 기사 생성 프롬프트의 **입력 블록**으로 옮긴다.
##
## 기사 문안 자체는 여기서 만들지 않는다. 문안은 언어 모델이 쓰고,
## 이 클래스는 모델에게 넘길 사실만 정리한다
## (docs/design/19-rekka-voice.md §19.4).
##
## **과장되는 것은 어투뿐이고 사실은 그대로 나간다.**
## 렉카는 스쳐 지나간 일을 놓고도 호들갑을 떨지만 "싸웠다" 라고 쓰지는 않는다.
## 그래서 이 클래스가 넘기는 값은 전부 실제로 일어난 그대로이며,
## 부풀린 값과 실제값을 나누어 들고 다니지 않는다 (§19.3.1).
##
## **수치는 넘기지 않는다.** 이 게임의 전투는 피해가 오가는 방식이 아니라
## 상황이 갈리는 방식이고(docs/design/05-rules.md §5.8),
## 기사에 "12 피해" 가 뜨면 있지도 않은 계량 감각을 만들어 낸다.
## 그래서 magnitude 는 여기서 **등급**으로 옮겨진 뒤에만 프롬프트로 나간다 (§19.3.3).
##
## 그래서 경계를 이렇게 긋는다.
##
##     이 클래스 -> 무엇이 사실인가 (사실)
##     언어 모델 -> 그걸 어떻게 지껄이는가 (어투)

## `magnitude` 가 무엇을 세는 값인지. 종류마다 다르므로 등급 축도 갈린다.
##
## 이 갈래가 등급 축이 둘뿐인 이유다. magnitude 가 뜻하는 것은
## **값어치 아니면 사람 수** 둘 중 하나이고, 이동에는 둘 다 없다.
enum Axis {
	NONE,  ## 셀 것이 없다
	HAUL,  ## 값어치 — 전리품 · 오간 물건
	CROWD,  ## 사람 수 — 마주친 · 붙은 · 쫓은 · 쓰러진 인원
}

## 수확 등급 이름. 낮은 쪽이 앞이다.
##
## 네 단계인 이유는 플레이어가 이 값으로 내리는 결정이 하나이기 때문이다 —
## "저 방에 가 볼 값어치가 있나". 그 결정은 네 갈래로 갈린다.
## 갈 이유 없음 / 굳이 / 갈 만함 / 만사 제쳐놓고.
const HAUL_GRADES: Array[String] = ["빈손", "푼돈", "한몫", "대박"]

## 수확 등급의 경계값. `magnitude` 가 이 값 이상이면 다음 등급이다.
##
## **잠정 수치다.** 전리품 가치의 실제 분포가 정해지면 다시 본다
## (docs/design/19-rekka-voice.md §19.9.1).
const HAUL_CUTS: Array[int] = [1, 4, 10]

## 규모 등급 이름. 낮은 쪽이 앞이다.
##
## 세 단계인 이유도 결정이 하나이기 때문이다 — "내가 저기 끼어들 수 있나".
## 혼자 감당 / 애매 / 불가능 세 갈래면 충분하다.
const CROWD_GRADES: Array[String] = ["맞대면", "한줌", "떼거리"]

## 규모 등급의 경계값. 스쿼드 상한 인원이 정해지면 다시 본다 (§19.9.1).
const CROWD_CUTS: Array[int] = [2, 4]

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

## 등급이 프롬프트에서 쓰는 칸 이름.
const _AXIS_SLOTS := {
	Axis.NONE: "",
	Axis.HAUL: "수확",
	Axis.CROWD: "규모",
}

## 한 턴에 나갈 기사 수의 상한 (docs/design/19-rekka-voice.md §19.4.3).
const MAX_ARTICLES := 3

## 제목의 결. 모델이 고르게 두면 한 가지로 수렴하므로 여기서 배정한다 (§19.6.2).
const TITLE_SHAPES: Array[String] = [
	"이름에 한 단어만 붙인 것",
	"명사로 끊긴 파편",
	"물음",
	"반말 한 마디",
	"누가 내뱉은 말을 옮긴 것 같은 것",
	"완결된 서술문",
]

## 본문의 결.
const BODY_SHAPES: Array[String] = [
	"한 문장으로 끝",
	"파편 두어 개를 이어 붙인 것",
	"물음만",
	"반말만",
	"존댓말만",
	"반말로 사실을 적고 존댓말로 비꼬는 것",
]


## 사건 종류의 한국어 표기.
static func kind_label(kind: GameEvent.Kind) -> String:
	return _KIND_LABELS.get(kind, "")


## 이 종류의 `magnitude` 가 무엇을 세는 값인가.
static func axis_of(kind: GameEvent.Kind) -> Axis:
	return _KIND_AXES.get(kind, Axis.NONE)


## 값어치를 수확 등급으로 옮긴다. **0 은 등급이 아니라 빈손이다.**
##
## 없는 일에 등급을 붙이면 사건을 지어내는 것과 같다. 다만 빈손은 지어낸 것이
## 아니라 실제로 허탕을 쳤다는 정보이므로 등급으로 남긴다.
static func haul_grade(magnitude: int) -> String:
	return HAUL_GRADES[_bucket(magnitude, HAUL_CUTS)]


## 사람 수를 규모 등급으로 옮긴다. 인원이 기록되지 않았으면 빈 문자열이다.
##
## 여기서 0 을 등급으로 만들면 "아무도 없는 전투" 가 기사에 실린다.
static func crowd_grade(magnitude: int) -> String:
	if magnitude <= 0:
		return ""
	return CROWD_GRADES[_bucket(magnitude, CROWD_CUTS)]


## 사건의 등급 칸을 만든다. 등급이 없는 사건은 빈 문자열이다.
static func grade_slot(event: GameEvent) -> String:
	var axis := axis_of(event.kind)
	var grade := ""
	match axis:
		Axis.HAUL:
			grade = haul_grade(event.magnitude)
		Axis.CROWD:
			grade = crowd_grade(event.magnitude)
		_:
			grade = ""
	if grade.is_empty():
		return ""
	return "%s=%s" % [_AXIS_SLOTS[axis], grade]


## 사건 하나를 프롬프트 한 줄로 옮긴다.
##
## 수치는 한 칸도 나가지 않는다. 등급만 나간다.
static func serialize_event(
	event: GameEvent, player_actor_id: String = "", names: Dictionary = {}
) -> String:
	var side := "플레이어" if event.actor_id == player_actor_id else "타인"
	var parts: Array[String] = [
		"- 누가=%s" % event.actor_name,
		"소속=%s" % side,
		"어디서=%s" % event.room_name,
		"무엇을=%s" % kind_label(event.kind),
	]
	var grade := grade_slot(event)
	if not grade.is_empty():
		parts.append(grade)
	var others := _resolve_names(event.related_actor_ids, names)
	if not others.is_empty():
		parts.append("상대=%s" % ", ".join(others))
	return " | ".join(parts)


## 한 턴을 통째로 옮긴다. 이 문자열이 그대로 모델의 사용자 메시지가 된다.
##
## 사건이 없어도 블록을 만든다. **조용한 턴에도 기사는 나가야 한다** —
## 아무도 안 움직였다는 것 자체가 위험도 숫자에 대한 정보이기 때문이다 (§19.6.3).
##
## `recent_titles` 는 직전 턴들의 제목이다. 모델은 턴마다 새로 불리므로
## 자기가 방금 무슨 결로 썼는지 모르고, 그래서 매번 같은 틀로 돌아간다.
## 최근 제목을 함께 넘기는 것이 그 반복을 깨는 유일한 장치다 (§19.4.2).
static func serialize_turn(
	turn: int,
	events: Array[GameEvent],
	viewpoint: String,
	player_actor_id: String = "",
	names: Dictionary = {},
	recent_titles: Array[String] = [] as Array[String]
) -> String:
	var lines: Array[String] = ["턴: %d" % turn, "시점: %s" % viewpoint]
	if not recent_titles.is_empty():
		lines.append("최근: %s" % " / ".join(recent_titles))
	if events.is_empty():
		lines.append("사건: 없음")
		return "\n".join(lines)

	lines.append("사건:")
	for event in events:
		lines.append(serialize_event(event, player_actor_id, names))
	return "\n".join(lines)


## 이 턴에 기사가 몇 편 나가는가.
##
## **편수는 문체가 아니라 규칙이다.** 모델에게 맡겼더니 사건이 하나도 없는 턴에
## 세 편을 썼다 (§19.6.1 의 실측). 같은 방 사건은 한 편으로 묶이므로
## 방의 수가 곧 편수이고, 이동만 남은 방들은 마지막 한 편에 몰아 담는다.
static func article_count(events: Array[GameEvent]) -> int:
	if events.is_empty():
		return 1
	var hot: Dictionary = {}
	var moved_only: Dictionary = {}
	for event in events:
		if event.kind == GameEvent.Kind.MOVED:
			moved_only[event.room_id] = true
		else:
			hot[event.room_id] = true
	if hot.is_empty():
		return 1
	var count := mini(MAX_ARTICLES, hot.size())
	for room_id in moved_only:
		if not hot.has(room_id) and count < MAX_ARTICLES:
			return count + 1
	return count


## 기사 하나에 배정할 결. `index` 는 판이 시작한 뒤로 몇 번째 기사인가다.
##
## 결을 프롬프트의 지침으로만 두면 모델이 지키지 않는다. 실측에서
## 턴별 호출만으로는 최빈 형태가 오히려 66%까지 올라갔고,
## 이 배정을 넣은 뒤에야 22%로 내려갔다 (§19.6.2).
##
## 36편까지 같은 짝이 두 번 나오지 않는다.
static func shape_hint(index: int) -> String:
	var title: String = TITLE_SHAPES[index % TITLE_SHAPES.size()]
	var body: String = BODY_SHAPES[(index / BODY_SHAPES.size() + index) % BODY_SHAPES.size()]
	return "제목 %s / 본문 %s" % [title, body]


## 한 턴의 결 지시문. 사용자 메시지에서 사건 블록 뒤에 붙는다.
static func serialize_order(start_index: int, count: int) -> String:
	var lines: Array[String] = ["이번 턴에 나갈 기사는 정확히 %d편이다. 더도 덜도 쓰지 마라." % count]
	lines.append("각 편에 쓸 결을 지정한다.")
	for offset in count:
		lines.append("  %d번째 기사 - %s" % [offset + 1, shape_hint(start_index + offset)])
	lines.append("결은 협상 대상이 아니다. 지정된 대로 써라. 사실은 입력 그대로 유지한다.")
	return "\n".join(lines)


## 값이 경계값 몇 개를 넘었는가. 그대로 등급 배열의 첨자가 된다.
static func _bucket(value: int, cuts: Array[int]) -> int:
	var index := 0
	for cut in cuts:
		if value >= cut:
			index += 1
	return index


## id 를 표시명으로 바꾼다. 모르는 id 는 그대로 둔다.
##
## GameEvent 는 주인공의 이름만 보존하고 얽힌 상대는 id 로만 남긴다.
## 기사에 "누구와" 를 실으려면 여기서 이름을 되찾아야 한다 (§19.9).
static func _resolve_names(ids: Array[String], names: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in ids:
		result.append(str(names.get(id, id)))
	return result
