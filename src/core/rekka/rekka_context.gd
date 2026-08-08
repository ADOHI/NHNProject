class_name RekkaContext
extends RefCounted
## 게시글에 함께 넘길 **판 문맥**을 게임 상태에서 뽑아낸다.
##
## ## 왜 이것이 있어야 하는가
##
## 사건 한 줄만 넘기면 모델은 할 말이 없다. 그래서 짧게 쓰거나, 늘리라고 하면
## 되풀이하거나, 놓아주면 지어낸다. **판이 이미 아는 것을 함께 넘기면 셋 다 사라진다**
## (docs/design/19-rekka-voice.md §19.A.3). 실측에서 같은 길이의 본문이
## 군더더기 절반에서 판단 재료 절반으로 바뀌었다.
##
## 그래서 게시글은 분위기가 아니라 **첩보**가 된다. 방의 역할, 인접 상황, 인물별 이력,
## 관계 이력이 가십의 형태로 배달된다 (13-information-design.md §13.3.0).
##
## ## 규칙 하나 — 전부 실제 값이어야 한다
##
## **지어낸 설정을 넣으면 그 순간 게시글이 거짓말이 된다.** 여기서 나가는 모든 줄은
## `DungeonGraph` · `EventLog` · `Actor` 를 읽어 만든 것이고,
## 게임이 아직 들고 있지 않은 것(지난 판 관계, 주목도)은 **넣지 않는다.**
## 없는 것의 목록은 §19.B.2 에 있다.
##
## ## 몬스터는 인접 상황에 넣지 않는다
##
## 이 게임의 핵심은 인접 위험도 **합**만 보이고 그 구성은 안 보이는 모호함이다
## (07-level-design.md §7.2, 13-information-design.md §13.6).
## 옆방 몬스터를 이름으로 불러 주면 그 모호함이 통째로 무너진다.
## 그래서 인접 상황에는 **움직이는 것들**(NPC 탐험가 · 플레이어 스쿼드)만 싣는다.
## 몬스터는 어차피 제자리를 지키므로 숫자로 이미 전달되고 있다.

## 한 번에 넘길 문맥 줄 수의 상한.
##
## 프롬프트가 길수록 산출이 나빠진다(§19.A.2 발견 1).
##
## **여섯에서 넷으로 줄였다.** 여섯을 주면 모델이 그것을 다 쓴다 — 실측 사용률이
## 90~100%였고, 한 편은 입력 여섯 줄이 본문 여섯 줄에 순서까지 1:1 로 옮겨졌다.
## 그 편에는 판단도 의심도 없어서 기사가 아니라 로그 뷰어가 됐다.
## **본문이 대여섯 줄인데 사건 넷에 문맥 여섯이면 받아쓰기 말고는 할 수가 없다.**
## 넷이면 자리가 남고, 남은 자리를 화자가 채운다.
const MAX_FACTS := 4

## 종류별로 뽑을 줄 수의 상한. 한 종류가 판을 다 차지하면 나머지가 안 나간다.
const _ROOM_CAP := 2
const _NEIGHBOR_CAP := 2
const _ACTOR_CAP := 3

## 수확을 "몇 턴 전" 으로 되짚어 주는 한계.
##
## 이 값을 넘기면 언제였는지를 말하지 않는다. 말하면 턴 차 숫자만 하나씩 오르는
## 같은 문장이 판 끝까지 이어진다 — 실측에서 `두 턴 전` 부터 `일곱 턴 전` 까지
## 여섯 편이 숫자만 다른 같은 줄이었다.
const _RECALL_TURNS := 3

## 한글 수관형사. 수치를 숫자로 적으면 후처리가 지운다(§19.B.3).
const _COUNT_WORDS: Array[String] = ["", "한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

## 한글 서수. `_ORDINAL_WORDS[1]` 은 "처음" 이라 따로 처리한다.
const _ORDINAL_WORDS: Array[String] = ["", "처음", "두 번째", "세 번째", "네 번째", "다섯 번째", "여섯 번째"]

## 방 종류를 사실 한 줄로 옮긴 것. 종류가 곧 방의 성격이다 (`room.gd` Kind).
const _KIND_FACTS := {
	Room.Kind.TREASURE: "귀중품이 있는 방이다",
	Room.Kind.HAZARD: "함정이 깔린 방이다",
	Room.Kind.EXIT: "던전 밖으로 나가는 방이다",
	Room.Kind.ENTRANCE: "모두가 들어온 방이다",
}

## 관계 이력으로 옮길 사건 종류. 지나간 사이를 한 줄로 요약한다.
const _RELATION_FACTS := {
	GameEvent.Kind.NEGOTIATED: "거래를 맺고 헤어진 사이다",
	GameEvent.Kind.FOUGHT: "이미 한 번 맞붙은 사이다",
	GameEvent.Kind.ENCOUNTERED: "이미 한 번 마주친 사이다",
	GameEvent.Kind.FLED: "한쪽이 한쪽을 피해 달아난 사이다",
}


## 이번 턴 사건 주위에서 판이 이미 아는 것들.
##
## 순서는 **화면에서 못 얻는 것이 먼저**다. 잘려 나가는 것은 언제나 뒤쪽이므로
## 순서가 곧 우선순위이고, 그 우선순위는 이 하나로 정해진다.
##
## | 층 | 화면에서 얻을 수 있는가 |
## | --- | --- |
## | 방의 종류 · 수색 상태 | **못 얻는다.** 인접 위험도 합은 방에 무엇이 있는지 말해 주지 않는다 |
## | 옆방에 누가 있는가 | **못 얻는다.** 합이 올랐다는 것까지만 보인다 (§7.2.5) |
## | 인물별 수확 이력 | **못 얻는다.** 남의 가방은 화면에 없다 |
## | 방의 위상 (길목 · 막다른 방) | **모른다.** [`07`](07-level-design.md) §7.2.4 의 "보이는 범위" 가 미정이다 |
##
## 위상을 맨 뒤로 민 것이 이 순서의 핵심이다. 판이 통째로 보이는 화면이면
## 갈래 수와 출구 거리는 플레이어가 이미 세고 있는 것이고, 그것을 기사로 다시
## 읽려 주면 정보원이 아니라 나레이션이 된다. **미정인 것에 앞자리를 주지 않는다.**
## `보이는 범위` 가 "인접 방만" 으로 정해지면 위상을 앞으로 올려야 한다.
static func for_turn(
	run: DungeonRun, events: Array[GameEvent], limit: int = MAX_FACTS
) -> Array[String]:
	if run == null or run.graph == null:
		return [] as Array[String]
	var names := name_index(run)
	var rooms := _rooms_in(events)
	if rooms.is_empty():
		return _quiet_facts(run).slice(0, maxi(0, limit))
	# 스쿼드가 나가는 턴은 이 판의 마지막 편이다. 그 편에서 방 이름과 옆방 상황을
	# 알려 줘 봐야 쓸 턴이 없다. **다음 판으로 넘어가는 것만 남긴다** —
	# 어느 방이 끝까지 안 털렸고 누가 아직 안에 있는가.
	if _player_left(run, events):
		return _quiet_facts(run).slice(0, maxi(0, limit))
	var facts: Array[String] = []
	facts.append_array(_state_facts(run, rooms, events))
	facts.append_array(_neighbor_facts(run, rooms))
	facts.append_array(_actor_facts(run, events))
	facts.append_array(_relation_facts(run, events, names))
	facts.append_array(_room_facts(run, rooms))
	return facts.slice(0, maxi(0, limit))


## 이번 턴에 플레이어 스쿼드가 던전을 빠져나갔는가.
static func _player_left(run: DungeonRun, events: Array[GameEvent]) -> bool:
	for event in events:
		if event.kind == GameEvent.Kind.ESCAPED and event.actor_id == run.player.id:
			return true
	return false


## 아무 일도 없는 턴에 넘길 것.
##
## **조용한 턴이야말로 문맥이 제일 필요한 턴이다.** 사건이 없으면 모델은 쓸 말이
## 하나도 없어서 "아무 일도 없었다" 를 여섯 줄로 늘려 쓴다. 실측에서 그 두 편이
## 서로 거의 같은 글이었다.
##
## 아무 일도 없었다는 것은 **부재가 알려 주는 사실**이다 — 판에 몇이 남았는지,
## 아직 아무도 손대지 않은 방이 몇인지. 그것을 대신 넘긴다.
static func _quiet_facts(run: DungeonRun) -> Array[String]:
	var facts: Array[String] = []
	var walkers: Array[String] = []
	for room_id in run.graph.room_ids():
		for actor in run.graph.get_room(room_id).occupants():
			if actor.is_mobile():
				walkers.append(actor.display_name)
	if walkers.is_empty():
		facts.append("던전 안에 움직이는 자가 하나도 남지 않았다")
	else:
		facts.append(
			(
				"던전에 아직 %s%s 남아 있다"
				% [_join_names(walkers), KoreanParticle.subject(walkers[walkers.size() - 1])]
			)
		)

	var untouched: Array[String] = []
	for room_id in run.graph.room_ids():
		var room := run.graph.get_room(room_id)
		if room.kind != Room.Kind.TREASURE:
			continue
		if _search_count(run, room_id) <= 0:
			untouched.append(room.display_name)
	if not untouched.is_empty():
		facts.append(
			(
				"%s%s 이번 판 들어 아무도 손대지 않은 귀중품 방이다"
				% [_join_names(untouched), KoreanParticle.topic(untouched[untouched.size() - 1])]
			)
		)
	return facts


## id -> 표시명. `GameEvent` 가 얽힌 상대를 id 로만 남기기 때문에 필요하다.
##
## 판 위에 있는 주체와 사건 기록에 이름이 남은 주체를 함께 훑는다.
## 쓰러져서 판에서 빠진 자도 게시글에는 이름으로 나와야 한다.
static func name_index(run: DungeonRun) -> Dictionary:
	var names: Dictionary = {}
	for event in run.event_log.all():
		names[event.actor_id] = event.actor_name
	for room_id in run.graph.room_ids():
		for actor in run.graph.get_room(room_id).occupants():
			names[actor.id] = actor.display_name
	return names


## 방 안에 무엇이 있고 그것이 아직 남아 있는가. **화면에서 절대 못 얻는 정보다.**
##
## 종류와 수색 상태를 한 줄로 합친다. 나눠 내보내면 여섯 줄 예산의 절반을
## 방 하나가 먹는다.
static func _state_facts(
	run: DungeonRun, rooms: Array[String], events: Array[GameEvent]
) -> Array[String]:
	var facts: Array[String] = []
	for room_id in rooms:
		if facts.size() >= _ROOM_CAP:
			break
		var line := _state_of(run, room_id, events)
		if not line.is_empty():
			facts.append(line)
	return facts


## 그 방의 종류와 수색 상태를 한 문장으로.
##
## **수색 상태는 시제를 지켜야 한다.** 앞선 판에서 이번 턴에 아무도 안 뒤진 방에
## "이번 판 들어 처음으로 수색된 방이다" 가 붙었고, 같은 방이 세 턴 간격으로
## 두 번 처녀지가 됐다. 그 글을 믿고 달려간 플레이어는 빈 방을 만난다.
## **정보원의 신뢰는 한 번 깨지면 그 판의 기사 전부가 무가치해진다.**
static func _state_of(run: DungeonRun, room_id: String, events: Array[GameEvent]) -> String:
	var room := run.graph.get_room(room_id)
	if room == null:
		return ""
	var name := RekkaPrompt.wrap_name(room.display_name)
	var topic := KoreanParticle.topic(room.display_name)
	var kind_fact: String = _KIND_FACTS.get(room.kind, "")
	var searched_now := _searched_in(events, room_id)
	# 이번 턴 사건이 아직 기록에 안 들어갔을 수 있다. 그 경우에도 최소 한 번은 세어야
	# `이번 판 들어 () 수색된 방` 같은 빈칸이 나가지 않는다.
	var count := maxi(_search_count(run, room_id), 1 if searched_now else 0)

	if searched_now:
		var ordinal := _ordinal_word(count)
		return (
			"%s%s 이번 판 들어 %s%s 수색된 방이다" % [name, topic, ordinal, KoreanParticle.direction(ordinal)]
		)
	if count > 0:
		return "%s%s 이번 판에 이미 수색이 끝난 방이다" % [name, topic]
	if not kind_fact.is_empty():
		if room.kind == Room.Kind.TREASURE:
			return "%s%s 귀중품이 있는 방인데 이번 판 들어 아직 아무도 손대지 않았다" % [name, topic]
		return "%s%s %s" % [name, topic, kind_fact]
	return ""


## 이 방이 판에서 하는 일. 길목 · 막다른 방 · 손이 닿지 않는 방 중 하나다.
##
## **갈래 수와 출구 거리는 뺐다.** 판이 통째로 보이는 화면이면 플레이어가 이미
## 세고 있는 것이고, 그것을 기사로 다시 읽어 주면 정보원이 아니라 나레이션이 된다.
## 실측에서 한 편의 본문 절반이 갈래 수 낭독이었다.
## 남긴 셋은 전부 **계산이 필요한** 것이라 화면에 그대로 나와 있지 않다.
##
## 길목 판정에 민첩을 넣지 않는 이유는, 넣는 순간 "누구 기준의 길목인가" 가
## 생기기 때문이다. NPC 마다 민첩이 다르므로 위상만으로 판정한다.
static func _room_facts(run: DungeonRun, rooms: Array[String]) -> Array[String]:
	var facts: Array[String] = []
	for room_id in rooms:
		if facts.size() >= _ROOM_CAP:
			break
		var line := _role_of(run, room_id)
		if not line.is_empty():
			facts.append(line)
	return facts


static func _role_of(run: DungeonRun, room_id: String) -> String:
	var graph := run.graph
	var room := graph.get_room(room_id)
	if room == null:
		return ""
	var name := RekkaPrompt.wrap_name(room.display_name)
	var topic := KoreanParticle.topic(room.display_name)

	# 손이 닿지 않는다는 것이 제일 앞이다. 못 가는 방은 경로에서 통째로 빠지므로
	# 그 방의 생김새를 알려 주는 것보다 훨씬 앞선 판단 재료다 (07-level-design.md §7.2.7).
	if _required_agility(run, room_id) > run.player.agility:
		return "%s%s 지금 스쿼드 민첩으로는 오를 수 없는 방이다" % [name, topic]

	var gate := _gateway_target(run, room_id)
	if not gate.is_empty():
		var target := graph.get_room(gate)
		return (
			"%s%s %s%s 가는 길목이라 지나갈 수밖에 없는 방이다"
			% [
				name,
				topic,
				RekkaPrompt.wrap_name(target.display_name),
				KoreanParticle.direction(target.display_name)
			]
		)

	if graph.neighbors_of(room_id).size() == 1:
		return "%s%s 막다른 방이라 들어가면 왔던 길로 되돌아 나와야 한다" % [name, topic]
	return ""


## 이번 판에 이 방이 수색된 횟수.
static func _search_count(run: DungeonRun, room_id: String) -> int:
	var count := 0
	for event in run.event_log.events_in_room(room_id):
		if event.kind == GameEvent.Kind.SEARCHED:
			count += 1
	return count


## 이번 턴 사건에 이 방의 수색이 들어 있는가.
static func _searched_in(events: Array[GameEvent], room_id: String) -> bool:
	for event in events:
		if event.kind == GameEvent.Kind.SEARCHED and event.room_id == room_id:
			return true
	return false


## 지금 옆방에 누가 있는가. 당장의 위험을 정하는 정보다.
static func _neighbor_facts(run: DungeonRun, rooms: Array[String]) -> Array[String]:
	var targets := rooms.duplicate()
	var here := run.player_room_id()
	if not here.is_empty() and not targets.has(here):
		targets.append(here)
	var facts: Array[String] = []
	for room_id in targets:
		if facts.size() >= _NEIGHBOR_CAP:
			break
		var line := _neighbor_line(run, room_id)
		if not line.is_empty():
			facts.append(line)
	return facts


static func _neighbor_line(run: DungeonRun, room_id: String) -> String:
	var room := run.graph.get_room(room_id)
	if room == null:
		return ""
	var found: Array[String] = []
	for neighbor_id in run.graph.neighbors_of(room_id):
		for actor in run.graph.get_room(neighbor_id).occupants():
			if actor.is_mobile():
				found.append(actor.display_name)
	if found.is_empty():
		return ""
	return (
		"지금 %s 옆방에 %s%s 있다"
		% [
			RekkaPrompt.wrap_name(room.display_name),
			_join_names(found),
			KoreanParticle.subject(found[found.size() - 1])
		]
	)


## 인물별 이번 판 이력. 누구를 쫓을지, 누가 아직 빈손인지.
static func _actor_facts(run: DungeonRun, events: Array[GameEvent]) -> Array[String]:
	var facts: Array[String] = []
	var seen: Dictionary = {}
	for event in events:
		if facts.size() >= _ACTOR_CAP:
			break
		if event.actor_id.is_empty() or seen.has(event.actor_id):
			continue
		seen[event.actor_id] = true
		# 이름은 사건에서 받는다. 사건 기록에서만 찾으면 이번 판에 처음 등장한 인물이
		# 통째로 빠진다 — 그리고 그 인물이야말로 "아직 빈손" 이라는 말이 필요한 쪽이다.
		var line := _haul_line(run, event.actor_id, event.actor_name)
		if not line.is_empty():
			facts.append(line)
	return facts


## 그 인물이 이번 판에 뭘 챙겼는가.
##
## **등급은 판 전체의 합으로 낸다.** 제일 큰 한 건만 보고 등급을 매겼더니,
## 나갈 때 합으로 계산된 등급과 어긋나 같은 사람의 수확이 `한몫` 에서 `대박` 으로
## 승격됐다. 값어치 등급은 플레이어가 "저 방에 아직 뭐가 남았나" 를 재는 축이라
## 소급 변경되면 축 자체가 못 쓰게 된다.
##
## 수확은 `ACQUIRED` 의 magnitude 만 센다. `SEARCHED` 도 값어치 축이지만
## 찾은 것과 챙긴 것을 둘 다 세면 같은 물건이 두 번 계산된다.
static func _haul_line(run: DungeonRun, actor_id: String, name: String) -> String:
	if name.is_empty():
		return ""
	var total := 0
	var best: GameEvent = null
	for event in run.event_log.events_involving(actor_id):
		if event.actor_id != actor_id:
			continue
		if event.kind != GameEvent.Kind.ACQUIRED or event.magnitude <= 0:
			continue
		total += event.magnitude
		if best == null or event.magnitude > best.magnitude:
			best = event
	var wrapped := RekkaPrompt.wrap_name(name)
	var topic := KoreanParticle.topic(name)
	if best == null:
		return "%s%s 이번 판 들어 아직 아무것도 못 챙겼다" % [wrapped, topic]
	var grade := RekkaPrompt.haul_grade(total)
	var carries := KoreanParticle.object_of(grade)
	# 여러 번 챙겼으면 방 이름을 대지 않는다. 등급은 합이고 방은 그중 한 곳이라,
	# 둘을 한 문장에 붙이면 `계단참에서 대박` 처럼 그 방에서 다 나온 것처럼 읽힌다.
	# 오래된 수확도 마찬가지로 언제였는지를 말하지 않는다 — 말하면 턴 차 숫자만
	# 하나씩 오르는 같은 문장이 판 끝까지 이어진다 (실측 여섯 턴 연속).
	# **합이라는 것을 말로 밝힌다.** 밝히지 않았더니 심사자 둘이 같은 모순을 짚었다 —
	# 한몫짜리를 두 번 챙긴 자가 어떤 편에서는 `대박`, 어떤 편에서는 `한몫씩` 으로 나갔다.
	# 둘 다 사실이지만 플레이어는 값이 편마다 바뀐다고 읽는다.
	if total > best.magnitude:
		return "%s%s 이번 판에 챙긴 것이 다 합쳐서 %s%s" % [wrapped, topic, grade, KoreanParticle.copula(grade)]
	if run.turn - best.turn > _RECALL_TURNS:
		return "%s%s 이번 판에 이미 %s%s 챙겨 둔 상태다" % [wrapped, topic, grade, carries]
	return (
		"%s%s %s %s에서 %s%s 챙겼다"
		% [
			wrapped,
			topic,
			_turn_gap(run.turn, best.turn),
			RekkaPrompt.wrap_name(best.room_name),
			grade,
			carries
		]
	)


## 이번 턴에 얽힌 둘이 전에도 얽힌 적이 있는가.
##
## **이번 판 안에서만 본다.** 판 사이를 잇는 관계 기록이 아직 없다 (§19.B.2).
static func _relation_facts(
	run: DungeonRun, events: Array[GameEvent], names: Dictionary
) -> Array[String]:
	for event in events:
		for other_id in event.related_actor_ids:
			var past := _past_between(run, event.actor_id, other_id, event.turn)
			if past == null:
				continue
			var other_name := str(names.get(other_id, other_id))
			return (
				[
					(
						"%s%s %s%s %s %s"
						% [
							RekkaPrompt.wrap_name(event.actor_name),
							KoreanParticle.conjunction(event.actor_name),
							RekkaPrompt.wrap_name(other_name),
							KoreanParticle.topic(other_name),
							_turn_gap(run.turn, past.turn),
							_RELATION_FACTS[past.kind]
						]
					)
				]
				as Array[String]
			)
	return [] as Array[String]


static func _past_between(
	run: DungeonRun, actor_id: String, other_id: String, before_turn: int
) -> GameEvent:
	var found: GameEvent = null
	for event in run.event_log.events_involving(actor_id):
		if event.turn >= before_turn or not _RELATION_FACTS.has(event.kind):
			continue
		if event.actor_id != other_id and not event.related_actor_ids.has(other_id):
			continue
		if found == null or event.turn > found.turn:
			found = event
	return found


## 그 방이 지금 자리에서 출구로 가는 길목인가. 길목이면 목적지 방 id 를 돌려준다.
##
##     지금자리 -> 그 방 -> 출구 의 최단 거리가 지금자리 -> 출구 와 같으면 길목이다.
static func _gateway_target(run: DungeonRun, room_id: String) -> String:
	var here := run.player_room_id()
	if here.is_empty() or here == room_id:
		return ""
	var from_here := _hops(run.graph, here)
	if not from_here.has(room_id):
		return ""
	var via := _hops(run.graph, room_id)
	for exit_id in _exit_ids(run.graph):
		if exit_id == room_id or not from_here.has(exit_id) or not via.has(exit_id):
			continue
		if from_here[room_id] + via[exit_id] == from_here[exit_id]:
			return exit_id
	return ""


## 지금 자리에서 그 방까지 가려면 필요한 민첩. 닿을 수 없으면 큰 값이다.
static func _required_agility(run: DungeonRun, room_id: String) -> int:
	var here := run.player_room_id()
	if here.is_empty():
		return 0
	var costs := run.graph.required_agility_from(here)
	return costs.get(room_id, 99)


## 방 id -> 시작 방에서의 최단 방 수. 민첩은 보지 않는다.
static func _hops(graph: DungeonGraph, start_id: String) -> Dictionary:
	if not graph.has_room(start_id):
		return {}
	var distance := {start_id: 0}
	var queue: Array[String] = [start_id]
	var head := 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		for neighbor_id in graph.neighbors_of(current):
			if distance.has(neighbor_id):
				continue
			distance[neighbor_id] = distance[current] + 1
			queue.append(neighbor_id)
	return distance


static func _exit_ids(graph: DungeonGraph) -> Array[String]:
	var found: Array[String] = []
	for room_id in graph.room_ids():
		if graph.get_room(room_id).kind == Room.Kind.EXIT:
			found.append(room_id)
	return found


## 사건에 등장한 방 id 를 등장 순서대로, 중복 없이.
static func _rooms_in(events: Array[GameEvent]) -> Array[String]:
	var found: Array[String] = []
	for event in events:
		if not event.room_id.is_empty() and not found.has(event.room_id):
			found.append(event.room_id)
	return found


## 사건의 주인공 id 를 등장 순서대로, 중복 없이.
static func _actors_in(events: Array[GameEvent]) -> Array[String]:
	var found: Array[String] = []
	for event in events:
		if not event.actor_id.is_empty() and not found.has(event.actor_id):
			found.append(event.actor_id)
	return found


## 이름들을 하나의 구로 잇는다. 이름은 여기서 홑화살괄호로 감싼다.
static func _join_names(names: Array[String]) -> String:
	var wrapped: Array[String] = []
	for name in names:
		wrapped.append(RekkaPrompt.wrap_name(name))
	if wrapped.size() <= 1:
		return "" if wrapped.is_empty() else wrapped[0]
	var pivot: String = names[names.size() - 2]
	var head := wrapped.slice(0, wrapped.size() - 1)
	return (
		"%s%s %s"
		% [", ".join(head), KoreanParticle.conjunction(pivot), wrapped[wrapped.size() - 1]]
	)


## 몇 턴 전인가. 숫자를 쓰지 않는다.
static func _turn_gap(now: int, then: int) -> String:
	var gap := now - then
	if gap <= 0:
		return "방금"
	return "%s 턴 전" % _count_word(gap)


static func _count_word(value: int) -> String:
	if value <= 0:
		return ""
	if value >= _COUNT_WORDS.size():
		return "여러"
	return _COUNT_WORDS[value]


static func _ordinal_word(value: int) -> String:
	if value <= 0:
		return ""
	if value >= _ORDINAL_WORDS.size():
		return "여러 번째"
	return _ORDINAL_WORDS[value]
