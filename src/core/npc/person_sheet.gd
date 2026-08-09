class_name PersonSheet
extends RefCounted
## 인물 하나의 상세 내용. **무엇을 보여줄지만 정하고 픽셀은 모른다.**
##
## docs/design/24-npc-relations.md §24.17. 사용자가 지정한 칸 다섯에
## 이미 있는 수치를 얹은 것이다 — 생김새/머리/성향/길드/관계/열전.
##
## ## 없는 자료는 빈칸이고, 빈칸은 왜 비었는지 말한다
##
## `recruit_prospect.gd` 의 `blocked_reason()` 이 *"관계가 부족하다 (관계도 미구현)"* 를
## 화면에 그대로 내보낸다. **이 저장소의 방식이고 그대로 따른다** (§24.17.4).
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

## 관계 칸이 채워졌을 때의 예상 항목 수. §24.2 가 인물당 2~4개로 못 박았다.
##
## 태생 관계(§24.18)와 얻은 관계를 나눠 내므로 머리글 둘을 더한다.
const RELATION_LINES := 6

## 열전이 채워졌을 때의 예상 줄 수.
##
## §24.20.2 의 조각 조합이라 극 축 하나에 한 문장씩 붙는다고 보면
## 딱지에 이름으로 적히는 수(PersonTag.MAX_NAMED)만큼이 최소고, 줄바꿈을 감아 두 배로 잡는다.
const CHRONICLE_LINES := PersonTag.MAX_NAMED * 2


## 인물 하나의 칸 목록을 만든다.
##
## factions 는 소속 크기를 아는 색인이다. 없으면 소속 칸이 번호만 낸다 —
## 매번 3000명을 다시 세지 않기 위해 호출자가 들고 있게 한다.
static func build(
	registry: PersonRegistry,
	person: int,
	factions: FactionIndex = null,
	level: SheetDisclosure.Level = SheetDisclosure.Level.DEV,
	graph: RelationGraph = null
) -> Array[SheetSection]:
	var sections: Array[SheetSection] = []
	if not registry.has(person):
		return sections

	sections.append(_portrait())
	sections.append(_head(registry, person))
	sections.append(_traits(registry, person))
	sections.append(_guild(registry, person, factions))
	sections.append(_relations(registry, person, graph))
	sections.append(_chronicle())

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
		# **극이 아닌 축에는 막대를 안 단다.** 생성기가 극이 아닌 축을 0~59 균등으로
		# 뽑으므로(TraitDistribution) **45 와 12 는 같은 주사위의 다른 눈**이다.
		# 45 에 막대를 그리면 굴림값을 신념으로 넘기게 된다 — 전체 축 칸의 29.1%가
		# 그 구간이다. 경계를 POLE_MIN(60)에 맞추면 **딱지에 이름이 있는 축과 막대가
		# 차는 축이 정확히 같은 집합**이 된다.
		if not TraitDistribution.is_pole(value):
			section.add(SheetField.filled(NpcAxis.label(kind), _axis_value(kind, value)))
			continue
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
static func _relations(registry: PersonRegistry, person: int, graph: RelationGraph) -> SheetSection:
	var section := SheetSection.new("관계", SheetSection.Shape.ENTRIES, RELATION_LINES)
	if graph == null:
		section.add(SheetField.missing("태생", "가족/사제 없음 — 관계도가 안 붙었다 (설계 24.18)"))
		section.add(SheetField.missing("얻은 것", "우호/원수 없음 — 관계도 미구현 (설계 24.2)"))
		return section

	var inborn := 0
	for other in graph.targets_of(person):
		var kind := graph.kind_of(person, other)
		if not RelationKind.is_inborn(kind):
			continue
		inborn += 1
		var label := RelationKind.label_for(
			kind, registry.gender_of(person), registry.gender_of(other)
		)
		var line := (
			"%s %d세 %s  호감 %+d 유대 %d"
			% [
				registry.name_of(other),
				registry.age_of(other),
				PersonGender.label(registry.gender_of(other)),
				graph.affinity(person, other),
				graph.bond(person, other),
			]
		)
		section.add(SheetField.filled(label, line))
	if inborn == 0:
		section.add(SheetField.missing("태생", "가족도 스승도 없다 — 혼자다"))
	section.add(SheetField.missing("얻은 것", "우호/원수 없음 — 사건 미구현 (설계 24.21)"))
	return section


## 인물 열전 — 사건 이력에서 나온다 (§24.19).
##
## **문장 여러 줄이 들어올 자리다.** 한 줄짜리 라벨 자리로 잡으면
## §24.20.2 의 조각 조합이 들어올 때 배치가 터진다.
static func _chronicle() -> SheetSection:
	var section := SheetSection.new("인물 열전", SheetSection.Shape.PARAGRAPHS, CHRONICLE_LINES)
	section.add(SheetField.missing("이력", "이력 없음 — 사건 기록 미구현 (설계 24.19)"))
	section.add(SheetField.missing("서술", "문장 조각 미구현 — 빌드 타임 생성 (설계 24.20)"))
	return section
