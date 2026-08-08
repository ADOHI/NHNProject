class_name PersonTag
extends RefCounted
## 인물의 성향을 한 줄로 부르는 딱지. `무모 의리 기만 +3` · `무색`.
##
## docs/design/24-npc-relations.md §24.17.5 의 규칙을 코드로 옮긴 것이다.
##
## ## 왜 딱지가 필요한가
##
## **숫자 여섯은 안 읽힌다.** 성향 6축을 그대로 늘어놓으면 인물이 구분되지 않는데,
## 극(pole)인 축의 이름만 뽑으면 "저 사람은 그런 사람" 이 한 줄로 읽힌다.
##
## ## 왜 자를 수 있는가
##
## 여섯 축 전부가 극인 인물이 1.8% 있다(§24.16.9). 그 딱지는 너무 길다.
## 그래서 앞의 셋만 쓰고 나머지는 개수로 센다.
##
## **자를 수 있는 이유는 상세 화면에 6축 값이 같은 화면 바로 아래 있기 때문이다** —
## 딱지는 요약이고 근거가 옆에 있다. 목록 한 줄이라면 자를 수 없었다.
##
## ## 이 딱지는 게임 화면에 나가지 않는다
##
## 성향의 직접 요약이라 그대로 내보내면 완전 공개가 되어 §5.4 의
## *"단서는 보이지만 확신은 못 한다"* 가 무너진다. **개발용 전용이다** (§24.17.2).

## 딱지에 이름으로 적는 극 축의 최대 개수. 나머지는 `+n` 으로 센다.
const MAX_NAMED := 3

## 극이 하나도 없는 인물의 딱지. 빈칸으로 두면 화면에서 자료 누락으로 읽힌다.
const COLORLESS := "무색"

## 이름과 개수 사이의 구분자. 폰트에 없는 글자를 쓰지 않는다 (docs/conventions.md §5.1).
const SEPARATOR := " "


## 성향 6축을 받아 딱지 문자열을 만든다.
##
## 절댓값이 큰 순으로 정렬한다 — **가장 센 성향이 그 사람을 부르는 말이 되어야 한다.**
static func of(traits: PackedInt32Array) -> String:
	var poles := poles_of(traits)
	if poles.is_empty():
		return COLORLESS

	var named := PackedStringArray()
	for slot in mini(MAX_NAMED, poles.size()):
		var axis := poles[slot] as NpcAxis.Kind
		named.append(NpcAxis.pole_label(axis, traits[int(axis)]))

	var text := SEPARATOR.join(named)
	var hidden := poles.size() - named.size()
	return text if hidden <= 0 else "%s +%d" % [text, hidden]


## 극인 축을 절댓값 큰 순으로. 딱지와 상세 화면이 같은 순서를 쓰게 하려고 나눠 뒀다.
##
## 같은 절댓값이면 축 순서(NpcAxis.Kind)를 따른다 — 그렇지 않으면 같은 인물의 딱지가
## 부를 때마다 달라져서 화면이 깜빡인다.
static func poles_of(traits: PackedInt32Array) -> PackedInt32Array:
	var found: Array[int] = []
	for axis in NpcAxis.count():
		if axis < traits.size() and TraitDistribution.is_pole(traits[axis]):
			found.append(axis)
	found.sort_custom(func(one: int, other: int) -> bool: return _stronger(traits, one, other))

	var ordered := PackedInt32Array()
	for axis in found:
		ordered.append(axis)
	return ordered


static func _stronger(traits: PackedInt32Array, one: int, other: int) -> bool:
	var left := absi(traits[one])
	var right := absi(traits[other])
	return one < other if left == right else left > right
