class_name PersonSeed
extends RefCounted
## 인물 생성의 난수 흐름을 **필드마다 갈라 준다.** 시드와 인덱스만으로 값이 정해진다.
##
## docs/design/24-npc-relations.md §24.24.
##
## ## 왜 필요한가 — 인구가 두 번 바뀌었다
##
## 생성기가 RNG 하나를 순서대로 소비하고 있었다. 그래서 **필드를 하나 더하면
## 그 뒤의 모든 뽑기가 밀리고 같은 시드의 같은 인덱스가 다른 사람이 된다.**
## 성(`924fab1`)과 성별(`91fd59b`)을 넣을 때 실제로 두 번 그렇게 됐고,
## **초상 레인이 골라 둔 인물이 사라졌다.**
##
## ## 흐름을 필드마다 연다
##
##     흐름 시드 = 섞기(세계 시드, 필드 번호, 인물 번호)
##
## - **필드를 더해도** 새 번호를 쓰므로 기존 필드의 값이 안 바뀐다
## - **인물이 늘어도** 인덱스가 흐름에 직접 들어가므로 앞 인물이 안 밀린다
## - **뽑는 횟수가 달라져도** 그 필드 안에서만 달라진다 (이름의 거절 표집이 그렇다)
##
## **필드 번호를 지우거나 중간에 끼워 넣지 마라.** 그 순간 인구가 통째로 바뀐다.
## 새 필드는 **끝에 붙인다.**

## 난수 흐름의 이름표. **끝에만 붙인다. 순서를 바꾸지 마라.**
enum Field {
	NAME,
	DISCIPLINE,
	THREAT,
	AGILITY,
	FACTION,
	FAME,
	AGE,
	GENDER,
	TRAITS,
	KIN,
	EVENT,  ## 사건과 관계 변화. **생성 흐름과 갈라 두는 자리다**
	FACTION_NAME,  ## 소속의 이름. 인물이 아니라 **소속 번호**를 셋째 인자로 넣는다
}

## 섞기에 쓰는 홀수 상수들 (splitmix64). 값 자체에 뜻은 없고 비트를 흩는 역할만 한다.
const _FIELD_ODD := -7046029254386353131
const _PERSON_ODD := -4658895280553007687
const _MIX_A := -4658895280553007687
const _MIX_B := -7723592293110705685


## 이 필드 · 이 인물의 흐름 시드.
static func stream(world_seed: int, field: Field, person: int) -> int:
	var value := world_seed ^ (int(field) * _FIELD_ODD)
	value = _mix(value ^ (person * _PERSON_ODD))
	return _mix(value)


## 흐름 하나를 받아 갈 RNG. 호출자가 하나를 돌려 쓰면 객체를 3000번 안 만든다.
static func apply(rng: RandomNumberGenerator, world_seed: int, field: Field, person: int) -> void:
	rng.seed = stream(world_seed, field, person)


static func _mix(value: int) -> int:
	var x := value
	x = (x ^ (x >> 30)) * _MIX_A
	x = (x ^ (x >> 27)) * _MIX_B
	return x ^ (x >> 31)
