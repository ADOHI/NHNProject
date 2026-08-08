class_name PersonDossier
extends RefCounted
## 인물 하나의 설정을 **한 덩어리 글로** 꺼낸다. LLM 입력이 된다.
##
## docs/design/24-npc-relations.md §24.22.6. 사용자 순서 —
## **코드로 설정 생성(성향 · 길드 · 가족 · 나이) → GPT 로 설정 시트와 이미지 프롬프트 → 이미지.**
##
## ## 두 번 만들지 않는다
##
## 레코드가 병렬 배열이라 인덱스로 흩어져 있다(설계 24.16.1).
## 그런데 **상세 화면이 이미 인물 하나를 전부 모으는 일을 하고 있다** — `PersonSheet` 다.
## 그것을 글로 옮기기만 한다. 칸을 하나 더하면 화면과 LLM 입력에 같이 나온다.
##
## | | 상세 화면 | 여기 |
## | --- | --- | --- |
## | 재료 | `PersonSheet` | **같다** |
## | 내는 것 | 픽셀 | 글 |
## | 가림 | `SheetDisclosure` | **DEV — 전부 넣는다** |
##
## ## 해석을 모델에게 시키지 않는다
##
## 성향을 `+52` 로 내보내면 **어느 쪽으로 52 인지는 `NpcAxis` 배열 순서를 봐야 알고
## 모델은 그 배열을 본 적이 없다.** 실제로 초상 레인이 이 부호를 뒤집어 읽었다.
## `NpcAxis.pole_label()` 이 그 해석을 이미 들고 있으므로 **코드가 풀어서 준다** —
## `정직/기만 축: 정직 쪽으로 52`.
##
## **입력 형식이 해석을 요구하면 모델이 해석을 틀린다.**
##
## ## 없는 것은 말하지 않는다
##
## `MISSING` 인 필드를 넣지 않는다. *"초상 미구현"* 을 LLM 에 넣으면 **그것을 설정으로 읽는다.**

## 관계를 몇 개까지 적나. 인물당 2~4개라(설계 24.2) 넉넉한 값이다.
const MAX_RELATIONS := 8


## 인물 하나의 설정 전문.
static func text(
	registry: PersonRegistry,
	person: int,
	factions: FactionIndex = null,
	graph: RelationGraph = null
) -> String:
	if not registry.has(person):
		return ""

	var lines := PackedStringArray()
	for section in PersonSheet.build(registry, person, factions):
		var body := (
			_axis_lines(registry, person) if section.title == "성향" else _section_lines(section)
		)
		if body.is_empty():
			continue
		lines.append("[%s]" % section.title)
		lines.append_array(body)
		lines.append("")
	lines.append_array(_relation_lines(registry, person, graph))
	return "\n".join(lines).strip_edges()


## 화면과 같은 칸을 글로. `MISSING` 과 `HIDDEN` 은 통째로 빠진다.
static func _section_lines(section: SheetSection) -> PackedStringArray:
	var lines := PackedStringArray()
	for field in section.fields:
		if not field.is_filled():
			continue
		var row := (
			"- %s: %s" % [field.label, field.value]
			if not field.label.is_empty()
			else "- %s" % field.value
		)
		lines.append(row)
	return lines


## 성향은 부호가 아니라 **쪽 이름으로** 낸다.
##
## `+52` 는 NpcAxis 배열 순서를 알아야 읽히고 모델은 그 배열을 본 적이 없다.
## 코드가 이미 아는 것을 모델에게 다시 알아내라고 시키지 않는다.
static func _axis_lines(registry: PersonRegistry, person: int) -> PackedStringArray:
	var traits := registry.traits_of(person)
	var lines := PackedStringArray()
	lines.append("- 한 줄 요약: %s" % PersonTag.of(traits))
	for axis in NpcAxis.count():
		var kind := axis as NpcAxis.Kind
		var value := traits[axis]
		var strength := "뚜렷하게" if TraitDistribution.is_pole(value) else "약하게"
		lines.append(
			(
				"- %s 축: %s 쪽으로 %d (%s)"
				% [NpcAxis.label(kind), NpcAxis.pole_label(kind, value), absi(value), strength]
			)
		)
	return lines


## 관계는 상대의 이름이 필요해서 칸 밖에서 만든다.
##
## **여기가 LLM 에게 가장 값진 자리다** — 성향은 숫자지만 관계는 사람 이야기다.
static func _relation_lines(
	registry: PersonRegistry, person: int, graph: RelationGraph
) -> PackedStringArray:
	var lines := PackedStringArray()
	if graph == null:
		return lines
	var targets := graph.targets_of(person)
	if targets.is_empty():
		return lines

	lines.append("[관계]")
	for slot in mini(targets.size(), MAX_RELATIONS):
		var other := targets[slot]
		var entry := (
			"- %s (%s, %d세): 호감 %d 유대 %d"
			% [
				registry.name_of(other),
				RelationKind.label_for(
					graph.kind_of(person, other),
					registry.gender_of(person),
					registry.gender_of(other)
				),
				registry.age_of(other),
				graph.affinity(person, other),
				graph.bond(person, other),
			]
		)
		lines.append(entry)
	return lines
