class_name PersonSheet
extends RefCounted
## 인물 하나의 상세 내용. **무엇을 보여줄지만 정하고 픽셀은 모른다.**
##
## docs/design/24-npc-relations.md §24.17. 사용자가 지정한 칸 다섯에
## 이미 있는 수치를 얹은 것이다 — 생김새/머리/성향/길드/관계/열전.
##
## ## 없는 자료는 빈칸이고, 빈칸은 왜 비었는지 말한다
##
## `recruit_prospect.gd` 의 `blocked_reason()` 이 막힌 사유를 화면에 그대로 내보낸다.
## **이 저장소의 방식이고 그대로 따른다** (§24.17.4).
## 사유가 절 번호를 가리키므로 그 자리를 채울 사람이 어디를 읽어야 하는지도 같이 나간다.
##
## ## 칸 순서가 「인물이란 무엇인가」의 선언이다
##
## 왼쪽은 **이 사람이 누구와 엮여 있나**(생김새/길드/관계),
## 오른쪽은 **이 사람 자체**(머리/성향/열전)다. 뷰가 그 두 열로 나눠 그린다.

## 왼쪽 열에 놓이는 칸 제목. 순서가 곧 위에서 아래다.
const LEFT_TITLES := ["생김새", "길드", "관계"]

## 오른쪽 열에 놓이는 칸 제목.
const RIGHT_TITLES := ["인물", "성향", "인물 열전"]

## 관계 칸이 쓸 수 있는 줄 수. **왼쪽 열의 세로 예산이 이 값을 정했다.**
##
## 초상 액자가 340 이고(§24.20.4) 그 아래 소속 칸이 서므로 720 짜리 화면에서
## 관계 칸에 남는 것이 **일곱 줄**이다. 실제로 아홉 줄을 내 보고 화면 밖으로 밀려
## 이 값을 못 박았다 — **`--import` 이 0에러여도 배치는 화면에서만 드러난다.**
##
## 자르는 것이 옳은 이유는 따로 있다. §24.2 가 관계를 **인물당 2~4개**로 못 박았으므로
## 일곱 줄을 넘긴다는 것은 칸이 좁은 것이 아니라 **희소가 깨졌다는 신호**다.
const RELATION_ROWS := 7

## 얻은 관계를 무리마다 최대 몇 개까지 내나.
const EARNED_SHOWN := 2

## 태생 관계를 최대 몇 개까지 내나. 유대가 두꺼운 순으로 자른다.
const INBORN_SHOWN := 3

## 열전이 채워졌을 때의 예상 줄 수.
##
## §24.20.2 의 조각 조합이라 극 축 하나에 한 문장씩 붙는다고 보면
## 딱지에 이름으로 적히는 수(PersonTag.MAX_NAMED)만큼이 최소고, 줄바꿈을 감아 두 배로 잡는다.
const CHRONICLE_LINES := PersonTag.MAX_NAMED * 2

## 열전에 내는 사건의 수. 오래된 것부터 잘라 낸다 —
## §24.5 가 *"극단적인 건만 기억된다"* 고 했으므로 전부 낼 필요가 없다.
const CHRONICLE_SHOWN := 6


## 인물 하나의 칸 목록을 만든다.
##
## factions 는 소속 크기를 아는 색인이다. 없으면 소속 칸이 번호만 낸다 —
## 매번 3000명을 다시 세지 않기 위해 호출자가 들고 있게 한다.
##
## ledger 는 사건 기록이다. 없으면 관계가 「왜 그런지」를 못 말하고 열전이 빈다 —
## **관계 수치만 있고 사연이 없으면 §24.2 가 경계한 "이유 없는 수치" 다.**
static func build(
	registry: PersonRegistry,
	person: int,
	factions: FactionIndex = null,
	level: SheetDisclosure.Level = SheetDisclosure.Level.DEV,
	graph: RelationGraph = null,
	ledger: RelationLedger = null
) -> Array[SheetSection]:
	var sections: Array[SheetSection] = []
	if not registry.has(person):
		return sections

	sections.append(_portrait())
	sections.append(_head(registry, person))
	sections.append(_traits(registry, person))
	sections.append(_guild(registry, person, factions))
	sections.append(_relations(registry, person, graph, ledger))
	sections.append(_chronicle(registry, person, graph, ledger))

	var veiled: Array[SheetSection] = []
	for section in sections:
		veiled.append(SheetDisclosure.apply(section, level))
	return veiled


## 제목으로 칸을 찾는다. 뷰가 열을 나눠 그릴 때 쓴다.
static func section_of(sections: Array[SheetSection], title: String) -> SheetSection:
	for section in sections:
		if section.title == title:
			return section
	return null


## 생김새 — 규격 정사각 액자 (설계 24.20.4).
##
## **전원이 자기 초상을 갖는다.** 설계 24.8 의 두 계층(초상은 소수만)은 폐기됐다.
## 그래서 사유가 하나뿐이다 — 있을 것인데 아직 안 만들었다.
##
## **초상 자체를 들고 있지 않고 어느 초상인지만 말한다.** 텍스처 3000장을 동시에
## 올리면 웹에서 죽으므로(설계 24.20.5) 불러오기와 버리기는 뷰 쪽 일로 남겨 둔다.
static func _portrait() -> SheetSection:
	var section := SheetSection.new("생김새", SheetSection.Shape.FRAME, 1)
	section.add(SheetField.missing("초상", "초상 미구현 — 빌드 타임 생성 (설계 24.9)"))
	return section


static func _head(registry: PersonRegistry, person: int) -> SheetSection:
	var section := SheetSection.new("인물", SheetSection.Shape.LINES, 6)
	section.add(SheetField.filled("이름", registry.name_of(person)))
	# 나이가 가족 관계를 정한다 (설계 24.22). 머리에 두는 이유는 관계를 읽을 때
	# 나이차가 바로 보여야 부모인지 형제인지가 납득되기 때문이다.
	section.add(SheetField.filled("나이", "%d세" % registry.age_of(person)))
	# 초상과 어긋나는지 사람이 확인할 수 있어야 한다 (설계 24.23).
	section.add(SheetField.filled("성별", PersonGender.label(registry.gender_of(person))))
	section.add(SheetField.filled("계열", MemberDiscipline.label(registry.discipline_of(person))))
	section.add(
		SheetField.filled(
			"전투 / 민첩", "%d / %d" % [registry.threat_of(person), registry.agility_of(person)]
		)
	)
	# 유명세만 막대를 다는 이유: 0~100 이라 비율이 뜻을 갖고, 대다수가 무명이라
	# (§24.16.6) 숫자만으로는 "이 사람이 알려진 사람인가" 가 안 읽힌다.
	var fame := registry.fame_of(person)
	section.add(SheetField.meter("유명세", str(fame), float(fame) / float(PersonGenerator.FAME_MAX)))
	return section


## 성향 — 딱지 한 줄과 6축 막대 여섯 줄 (§24.17.5).
static func _traits(registry: PersonRegistry, person: int) -> SheetSection:
	var traits := registry.traits_of(person)
	var section := SheetSection.new("성향", SheetSection.Shape.GAUGES, NpcAxis.count() + 1)
	section.add(SheetField.filled("딱지", PersonTag.of(traits)))
	for axis in NpcAxis.count():
		var kind := axis as NpcAxis.Kind
		var value := traits[axis]
		section.add(
			SheetField.gauge(
				NpcAxis.label(kind),
				_axis_value(kind, value),
				float(value) / float(NpcAxis.MAX_VALUE)
			)
		)
	return section


## `무모 72` 처럼 가리키는 극과 세기를 함께. 값만 있으면 부호를 머리로 풀어야 한다.
static func _axis_value(kind: NpcAxis.Kind, value: int) -> String:
	if not TraitDistribution.is_pole(value):
		return "%+d" % value
	return "%+d  %s" % [value, NpcAxis.pole_label(kind, value)]


## 길드(소속) — 번호 · 인원 · 크기 순위 (§24.17.6).
static func _guild(registry: PersonRegistry, person: int, factions: FactionIndex) -> SheetSection:
	var section := SheetSection.new("길드", SheetSection.Shape.LINES, 2)
	var faction := registry.faction_of(person)
	if faction == PersonRegistry.NO_FACTION:
		section.add(SheetField.filled("소속", "무소속"))
		section.add(SheetField.missing("이름", "소속 이름 미구현 — 인물-길드 층 (설계 24.1)"))
		return section

	if factions == null:
		section.add(SheetField.filled("소속", "#%d" % faction))
	else:
		# 인원 막대가 지프 분포를 눈에 넣는다 — 318 대 6 이 보여야 한다 (§24.17.6).
		section.add(
			SheetField.meter(
				"소속",
				factions.describe(faction),
				float(factions.size_of(faction)) / float(maxi(factions.largest_size(), 1))
			)
		)
	section.add(SheetField.missing("이름", "소속 이름 미구현 — 인물-길드 층 (설계 24.1)"))
	return section


## 관계 — 태생과 얻은 것을 나눠 낸다 (§24.18).
##
## **가족은 바뀌지 않고 우호 · 원수는 변한다.** 그 차이가 읽혀야
## 플레이어가 "관계를 쌓아서 저 사람의 형이 될 수 있나" 를 착각하지 않는다.
##
## 얻은 것은 다시 **가까운 사람 · 척진 사람**으로 갈린다. 호감의 부호가 그 경계다 —
## 목록 하나에 섞어 놓으면 *"이 사람이 나를 어떻게 보나"* 가 수치를 읽어야만 나온다.
static func _relations(
	registry: PersonRegistry, person: int, graph: RelationGraph, ledger: RelationLedger
) -> SheetSection:
	var section := SheetSection.new("관계", SheetSection.Shape.ENTRIES, RELATION_ROWS)
	if graph == null:
		section.add(SheetField.missing("태생", "가족/사제 없음 — 관계도가 안 붙었다 (설계 24.18)"))
		section.add(SheetField.missing("얻은 것", "우호/원수 없음 — 관계도 미구현 (설계 24.2)"))
		return section

	var inborn: Array[int] = []
	var liked: Array[int] = []
	var disliked: Array[int] = []
	# **호감 0 을 가까운 쪽에 넣는다.** 행위자는 호감이 안 움직이므로(§24.21.5)
	# 자기가 벌인 일로 생긴 관계가 늘 0 이다. 어느 무리에도 안 넣으면
	# **자기 사건으로 생긴 관계가 자기 화면에서만 사라진다.**
	for other in graph.targets_of(person):
		if RelationKind.is_inborn(graph.kind_of(person, other)):
			inborn.append(other)
		elif graph.affinity(person, other) < 0:
			disliked.append(other)
		else:
			liked.append(other)

	# 유대가 두꺼운 순. 태생은 유대가 안 변하므로(§24.18) 이 순서가 안 흔들린다.
	inborn.sort_custom(
		func(a: int, b: int) -> bool: return graph.bond(person, a) > graph.bond(person, b)
	)
	liked.sort_custom(
		func(a: int, b: int) -> bool: return graph.affinity(person, a) > graph.affinity(person, b)
	)
	disliked.sort_custom(
		func(a: int, b: int) -> bool: return graph.affinity(person, a) < graph.affinity(person, b)
	)

	if inborn.is_empty():
		section.add(SheetField.missing("태생", "가족도 스승도 없다 — 혼자다"))
	for other in inborn.slice(0, INBORN_SHOWN):
		section.add(_inborn_entry(registry, person, other, graph))

	if liked.is_empty() and disliked.is_empty():
		section.add(SheetField.missing("얻은 것", "아직 아무 사건에도 안 엮였다 (설계 24.5)"))
		return section

	# **척진 쪽을 먼저 놓는다.** 자리가 모자랄 때 살아남아야 하는 것은 원수 쪽이다 —
	# 설계 5.4 가 협상 판단에 필요하다고 한 단서가 "저 사람이 누구와 척졌나" 이지
	# "누구와 친한가" 가 아니다.
	var groups: Array = []
	if not disliked.is_empty():
		groups.append(["척진 사람", disliked])
	if not liked.is_empty():
		groups.append(["가까운 사람", liked])

	var quotas := _earned_quotas(section.fields.size(), groups.size())
	for slot in groups.size():
		if quotas[slot] <= 0:
			continue
		var others: Array[int] = groups[slot][1]
		section.add(SheetField.filled(str(groups[slot][0]), "%d명" % others.size()))
		for other in others.slice(0, quotas[slot]):
			section.add(_earned_entry(registry, person, other, graph, ledger))
	return section


## 무리마다 몇 개씩 낼 것인가. **한 무리가 남은 자리를 다 먹으면 반대쪽이 통째로 사라지고**,
## 그러면 화면이 *"이 사람은 척진 사람이 없다"* 라고 거짓말한다.
##
## 그래서 무리마다 머리글 한 줄을 먼저 떼어 두고 남는 줄을 고르게 나눈다.
## 나머지는 앞 무리(척진 쪽)가 가져간다.
static func _earned_quotas(used: int, group_count: int) -> PackedInt32Array:
	var quotas := PackedInt32Array()
	quotas.resize(group_count)
	var room := RELATION_ROWS - used - group_count
	if room <= 0:
		return quotas
	for slot in group_count:
		var share := room / group_count + (1 if slot < room % group_count else 0)
		quotas[slot] = mini(share, EARNED_SHOWN)
	return quotas


## 태생 한 줄 — `아버지 : 김건규 62세 호감+40 유대80`.
##
## **성별을 값에 안 쓴다.** 라벨이 이미 아버지 · 자매 · 남매로 성별을 말하고 있어서
## (§24.23.4) 한 번 더 쓰면 좁은 열에서 줄이 감긴다.
static func _inborn_entry(
	registry: PersonRegistry, person: int, other: int, graph: RelationGraph
) -> SheetField:
	var label := RelationKind.label_for(
		graph.kind_of(person, other), registry.gender_of(person), registry.gender_of(other)
	)
	return (
		SheetField
		. filled(
			label,
			(
				"%s %d세 호감%+d 유대%d"
				% [
					registry.name_of(other),
					registry.age_of(other),
					graph.affinity(person, other),
					graph.bond(person, other),
				]
			)
		)
	)


## 얻은 것 한 줄 — `원한 한쪽만 : 최윤호 호감-31 유대0 [42]`.
##
## **「한쪽만」이 이 화면에서 가장 중요한 글자다.** 상대가 나를 모르는 관계는
## 태생으로는 절대 안 생기고(가족은 늘 양방향이다) **사건의 목격자만 만든다**
## (§24.21.5). 비대칭을 고른 이유가 화면에 드러나는 자리가 여기뿐이다.
##
## 대괄호 안은 근거 사건 번호다. **같은 번호가 열전 칸에 문장으로 있다** —
## 좁은 열에 사연을 다 쓰면 줄이 감기므로 번호로 잇는다.
static func _earned_entry(
	registry: PersonRegistry, person: int, other: int, graph: RelationGraph, ledger: RelationLedger
) -> SheetField:
	var label := RelationKind.label(graph.kind_of(person, other))
	if not graph.knows(other, person):
		label = "%s 한쪽만" % label
	var cause := graph.cause_of(person, other)
	var mark := "" if ledger == null or not ledger.has(cause) else " [%d]" % cause
	return (
		SheetField
		. filled(
			label,
			(
				"%s 호감%+d 유대%d%s"
				% [
					registry.name_of(other),
					graph.affinity(person, other),
					graph.bond(person, other),
					mark,
				]
			)
		)
	)


## 인물 열전 — 사건 이력에서 나온다 (§24.19).
##
## **문장 여러 줄이 들어올 자리다.** 한 줄짜리 라벨 자리로 잡으면
## §24.20.2 의 조각 조합이 들어올 때 배치가 터진다.
##
## 지금 들어오는 것은 **이 사람의 관계가 기억하는 사건**이다. 인물별 색인을 따로 두지 않고
## 관계의 근거 사건을 모은다 (`RelationLedger.causes_of`) — §24.20.3 의
## *"저장하지 않고 계산한다"* 와 같은 판단이다.
##
## **문장 조각(§24.20.2)은 아직 없다.** 사건 줄과 서술 줄을 갈라 둔 이유가 그것이다 —
## 사건이 있어도 서술은 여전히 빌드 타임 자산을 기다린다.
static func _chronicle(
	registry: PersonRegistry, person: int, graph: RelationGraph, ledger: RelationLedger
) -> SheetSection:
	var section := SheetSection.new("인물 열전", SheetSection.Shape.PARAGRAPHS, CHRONICLE_LINES)
	if graph == null or ledger == null:
		section.add(SheetField.missing("이력", "이력 없음 — 사건 기록 미구현 (설계 24.19)"))
		section.add(SheetField.missing("서술", "문장 조각 미구현 — 빌드 타임 생성 (설계 24.20)"))
		return section

	var causes := ledger.causes_of(graph, person)
	if causes.is_empty():
		section.add(SheetField.missing("이력", "엮인 사건이 없다 — 세계가 이 사람을 아직 안 건드렸다"))
	else:
		# 최근 것부터. 사건 id 가 곧 시간순이라 뒤에서 잘라 낸다.
		var shown := causes.slice(maxi(causes.size() - CHRONICLE_SHOWN, 0))
		for slot in range(shown.size() - 1, -1, -1):
			var cause: int = shown[slot]
			section.add(
				SheetField.filled(
					"[%d]" % cause,
					(
						"%s — 나는 %s"
						% [ledger.describe(cause, registry), ledger.role_phrase(cause, person)]
					)
				)
			)
	section.add(SheetField.missing("서술", "문장 조각 미구현 — 빌드 타임 생성 (설계 24.20)"))
	return section
