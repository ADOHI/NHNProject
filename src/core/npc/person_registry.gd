class_name PersonRegistry
extends RefCounted
## 세계의 인물 전부. **병렬 배열 하나씩이고, 인물은 정수 인덱스다.**
##
## docs/design/24-npc-relations.md §24.8 의 「레코드」 계층이다 —
## 이름 · 계열 · 수치 · 성향 6축 · 소속 · 유명세. 초상과 사연은 여기 없다.
##
## ## 왜 인물당 객체를 만들지 않는가 (§24.16.1)
##
## 목표가 1000~3000명이다(§24.8). 인물당 `Dictionary` 를 만들면 사전이 3000개 생기고
## 키 문자열이 인물마다 복제된다. 인물당 `RefCounted` 라도 참조 카운트가 3000개다.
## **필드마다 `Packed*Array` 하나**면 배열이 일곱 개뿐이고 접근이 연속 메모리다.
##
## 성향 6축은 인물당 배열을 만들지 않고 **`_traits` 하나에 stride 6 으로 눕힌다.**
##
## ## 왜 식별자가 String 이 아닌가
##
## `GuildMember` 는 `String id` 를 쓴다. 그것은 **길드 안 대원 수십 명**의 이야기다.
## 여기는 수천 명이고, 다음 덩어리에서 관계 간선이 인물 쌍으로 만들어진다.
## 간선 키가 문자열 쌍이면 조회마다 해시가 두 번 돌고 그 조회가 사건마다 여러 번 일어난다.
## **두 계층을 잇는 것은 영입 시점의 변환 하나로 족하다** (§24.13).

## 어떤 인물도 가리키지 않는 인덱스. 소속 없음과 구분하려고 이름을 따로 둔다.
const NO_PERSON := -1

## 소속 없음. 세계에는 아무 데도 안 걸린 사람이 있어야 소속이 뜻을 갖는다 (§24.16.5).
const NO_FACTION := -1

var _names := PackedStringArray()
var _disciplines := PackedInt32Array()
var _threats := PackedInt32Array()
var _agilities := PackedInt32Array()
var _factions := PackedInt32Array()
var _fames := PackedInt32Array()
var _ages := PackedInt32Array()
var _genders := PackedInt32Array()

## 성향 전체. 인물 i 의 축 a 는 _traits[i * NpcAxis.count() + a] 다.
var _traits := PackedInt32Array()


func size() -> int:
	return _names.size()


## 인물 하나를 등록하고 그 인덱스를 돌려준다.
##
## traits 는 NpcAxis.count() 개여야 한다. 모자라면 세계가 조용히 반쪽 성향을 갖게 되므로
## 여기서 막는다 — 성향은 화면에 직접 나오지 않아서 틀려도 눈에 안 보인다.
func add(
	person_name: String,
	discipline: MemberDiscipline.Kind,
	threat: int,
	agility: int,
	faction: int,
	fame: int,
	age: int,
	gender: PersonGender.Kind,
	traits: PackedInt32Array
) -> int:
	if traits.size() != NpcAxis.count():
		push_error("성향은 축 %d 개여야 합니다 (받은 것 %d)" % [NpcAxis.count(), traits.size()])
		return NO_PERSON

	var index := _names.size()
	_names.append(person_name)
	_disciplines.append(int(discipline))
	_threats.append(threat)
	_agilities.append(agility)
	_factions.append(faction)
	_fames.append(fame)
	_ages.append(age)
	_genders.append(int(gender))
	_traits.append_array(traits)
	return index


func has(person: int) -> bool:
	return person >= 0 and person < _names.size()


func name_of(person: int) -> String:
	return _names[person]


func discipline_of(person: int) -> MemberDiscipline.Kind:
	return _disciplines[person] as MemberDiscipline.Kind


## 전투력. 스쿼드에서 합산된다 (docs/design/14-squad.md §14.3).
func threat_of(person: int) -> int:
	return _threats[person]


## 민첩. 스쿼드에서 평균된다 (§14.3.1).
func agility_of(person: int) -> int:
	return _agilities[person]


## 소속 인덱스. 이름은 없다 — 인물↔길드 층에서 정한다 (§24.16.5).
func faction_of(person: int) -> int:
	return _factions[person]


## 판 밖의 누적 평판 (§24.7). 지금은 생성 시점 값이 그대로 남는다.
func fame_of(person: int) -> int:
	return _fames[person]


## 유명세를 올린다(내린다). 새 값을 돌려준다.
##
## **유명세는 누적이다** (설계 24.7) — 판 안의 「주목도」와 달리 리셋이 없다.
## 그래서 생성 시점의 값은 **시작점이지 끝값이 아니다**.
##
## **여기가 인구 레코드에서 유일하게 뒤에 바뀌는 값이다.** 나이 · 이름 · 성향 · 계열은
## 다 동결이고(설계 24.24), 유명세만 사건이 민다 — *"무엇을 했는가"* 이기 때문이다.
func gain_fame(person: int, delta: int) -> int:
	if not has(person) or delta == 0:
		return 0 if not has(person) else _fames[person]
	_fames[person] = clampi(_fames[person] + delta, 0, PersonGenerator.FAME_MAX)
	return _fames[person]


## 나이. **가족 관계가 여기서 나온다** (설계 24.22) — 부모는 자식보다 위고 형제는 비슷하다.
func age_of(person: int) -> int:
	return _ages[person]


## 성별. **레코드가 정한다** — 초상 생성 모델이 정하게 두면 계열마다 쏠린다 (설계 24.23).
func gender_of(person: int) -> PersonGender.Kind:
	return _genders[person] as PersonGender.Kind


## 성. **따로 저장하지 않고 이름에서 읽는다** — 열을 두면 두 진실이 생긴다 (설계 24.22.7).
func surname_of(person: int) -> String:
	return MemberNames.surname_of(_names[person])


func trait_of(person: int, axis: NpcAxis.Kind) -> int:
	return _traits[person * NpcAxis.count() + int(axis)]


## 인물의 성향 6축. 사건 반응 계산(§24.4)이 이 배열을 받는다.
func traits_of(person: int) -> PackedInt32Array:
	var stride := NpcAxis.count()
	return _traits.slice(person * stride, (person + 1) * stride)


## 극(pole)인 축이 몇 개인가. 인물이 얼마나 뚜렷한 사람인지의 척도다 (§24.16.3).
func pole_count_of(person: int) -> int:
	var found := 0
	for axis in NpcAxis.count():
		if TraitDistribution.is_pole(trait_of(person, axis as NpcAxis.Kind)):
			found += 1
	return found


## 한 줄 요약. 개발 도구와 렉카 재료가 같은 문장을 쓰게 하려고 여기 둔다.
func summary_of(person: int) -> String:
	var poles := PackedStringArray()
	for axis in NpcAxis.count():
		var value := trait_of(person, axis as NpcAxis.Kind)
		if TraitDistribution.is_pole(value):
			poles.append(NpcAxis.pole_label(axis as NpcAxis.Kind, value))
	var mark := "-".join(poles) if poles.size() > 0 else "무색"
	return (
		"%s (%s) %s %d세 전투 %d 민첩 %d 소속 %s 유명 %d [%s]"
		% [
			name_of(person),
			MemberDiscipline.label(discipline_of(person)),
			PersonGender.label(gender_of(person)),
			age_of(person),
			threat_of(person),
			agility_of(person),
			"없음" if faction_of(person) == NO_FACTION else str(faction_of(person)),
			fame_of(person),
			mark,
		]
	)
