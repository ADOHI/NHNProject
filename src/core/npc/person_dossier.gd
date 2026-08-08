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
		var body := _section_lines(section)
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
		lines.append(
			(
				"- %s: %s" % [field.label, field.value]
				if not field.label.is_empty()
				else "- %s" % field.value
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
				RelationKind.label(graph.kind_of(person, other)),
				registry.age_of(other),
				graph.affinity(person, other),
				graph.bond(person, other),
			]
		)
		lines.append(entry)
	return lines
