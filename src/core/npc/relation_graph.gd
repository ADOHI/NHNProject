class_name RelationGraph
extends RefCounted
## 인물 사이의 관계. **비대칭이고 희소하다** (설계 24.2 · 24.21.1).
##
## 관계 하나가 드는 것 — 대상 / 호감 / 유대 / 유형 / 근거 사건.
##
## ## 왜 인접 목록인가
##
## 인물당 2~4개라 3000명이면 방향 간선이 만 개 남짓이고 **가능한 쌍의 0.1%** 다.
## 행렬은 900만 칸 중 만 개만 쓴다. 사전은 조회마다 해시가 돌고 항목을 만 개 든다.
##
## `_head[인물]` 이 첫 슬롯을 가리키고 `_next[슬롯]` 이 다음을 가리킨다.
## **인물당 배열 객체를 만들지 않는다** — PersonRegistry 와 같은 이유다 (설계 24.16.1).
##
## **조회가 차수만큼 걷는다.** 차수가 2~4 이므로 비교 서너 번이고 해시 한 번보다 싸다.
##
## ## 비대칭이다
##
## `A→B` 와 `B→A` 는 서로 모르는 두 슬롯이고 한쪽만 있을 수도 있다 —
## **내가 아는 사람이 나를 모를 수 있다.** 유대를 대칭으로 묶으면 그 모양을 못 만든다.

## 관계 없음.
const NO_RELATION := -1

## 호감의 범위. 감정의 방향과 세기 (설계 24.2).
const AFFINITY_MIN := -100
const AFFINITY_MAX := 100

## 유대의 범위. **얼마나 엮여 있나.** 0 이면 모르는 사이다.
const BOND_MIN := 0
const BOND_MAX := 100

## 근거 사건이 없는 관계. 태생 관계가 이것이다 — 사건에서 나오지 않았다.
const NO_CAUSE := -1

var _head := PackedInt32Array()
var _next := PackedInt32Array()
var _from := PackedInt32Array()
var _to := PackedInt32Array()
var _affinity := PackedInt32Array()
var _bond := PackedInt32Array()
var _kind := PackedInt32Array()
var _cause := PackedInt32Array()

## 이 관계를 **직접 봤나 전해 들었나** (설계 24.10).
##
## **근거 사건만으로는 못 가른다.** 같은 사건이 누구에게는 목격이고 누구에게는 소문이다 —
## 그러므로 이것은 사건의 성질이 아니라 **관계의 성질**이고 여기 있어야 한다.
##
## 안 가르면 화면이 *"나는 목격자였다"* 를 소문으로 안 사람에게도 쓰게 되고,
## 그러면 **모두가 모든 것을 목격한 것처럼 보인다.**
var _heard := PackedInt32Array()


## 인물 수만큼 자리를 잡는다. 관계는 하나도 없는 상태다 —
## **기본은 「모르는 사이」** 이고 명시적으로 만든 것만 존재한다 (설계 24.2).
func _init(person_count: int) -> void:
	_head.resize(maxi(person_count, 0))
	_head.fill(NO_RELATION)


func person_count() -> int:
	return _head.size()


## 방향 관계의 총수. 쌍이 아니라 방향이다.
func size() -> int:
	return _to.size()


## `from → to` 슬롯. 없으면 NO_RELATION. **밖에서는 knows() 를 쓴다** —
## 슬롯 번호는 이 클래스 안의 이야기다.
func _find(from: int, to: int) -> int:
	if from < 0 or from >= _head.size():
		return NO_RELATION
	var slot := _head[from]
	while slot != NO_RELATION:
		if _to[slot] == to:
			return slot
		slot = _next[slot]
	return NO_RELATION


func knows(from: int, to: int) -> bool:
	return _find(from, to) != NO_RELATION


## 관계를 만든다. 이미 있으면 그 슬롯을 돌려주고 값은 안 건드린다.
func link(
	from: int, to: int, kind: RelationKind.Kind, affinity: int, bond: int, cause: int = NO_CAUSE
) -> int:
	if from == to or from < 0 or from >= _head.size() or to < 0 or to >= _head.size():
		return NO_RELATION
	var existing := _find(from, to)
	if existing != NO_RELATION:
		return existing

	var slot := _to.size()
	_from.append(from)
	_to.append(to)
	_affinity.append(clampi(affinity, AFFINITY_MIN, AFFINITY_MAX))
	_bond.append(clampi(bond, BOND_MIN, BOND_MAX))
	_kind.append(int(kind))
	_cause.append(cause)
	# 기본은 직접 안 것이다. 소문으로 생긴 관계만 따로 표시한다 (set_heard).
	_heard.append(0)
	_next.append(_head[from])
	_head[from] = slot
	return slot


## 이 관계를 전해 들은 것으로 표시하거나 지운다.
##
## **직접 겪으면 지워진다.** 소문으로 알던 사람을 나중에 직접 보면 그것은 더 이상
## 들은 이야기가 아니다 — 표시가 안 지워지면 화면이 계속 *"들었다"* 라고 한다.
func set_heard(slot: int, heard: bool) -> void:
	if slot < 0 or slot >= _heard.size():
		return
	_heard[slot] = 1 if heard else 0


## 전해 들은 관계인가. 관계가 없으면 거짓이다.
func is_heard(from: int, to: int) -> bool:
	var slot := _find(from, to)
	return slot != NO_RELATION and _heard[slot] == 1


func slot_is_heard(slot: int) -> bool:
	return _heard[slot] == 1


## 사건이 관계를 움직인다. 없으면 만든다 — **관계는 사건의 찌꺼기다** (설계 24.5).
##
## **태생 관계는 유대와 유형을 안 건드린다** (설계 24.18 · 24.21.3).
## 배신해도 혈연은 혈연이고, 바뀌는 것은 호감과 근거 사건뿐이다.
func adjust(
	from: int,
	to: int,
	affinity_delta: int,
	bond_delta: int,
	kind: RelationKind.Kind,
	cause: int = NO_CAUSE
) -> int:
	var slot := _find(from, to)
	if slot == NO_RELATION:
		return link(from, to, kind, affinity_delta, maxi(bond_delta, 0), cause)

	_affinity[slot] = clampi(_affinity[slot] + affinity_delta, AFFINITY_MIN, AFFINITY_MAX)
	if not RelationKind.is_inborn(_kind[slot] as RelationKind.Kind):
		_bond[slot] = clampi(_bond[slot] + bond_delta, BOND_MIN, BOND_MAX)
		if kind != RelationKind.Kind.NONE:
			_kind[slot] = int(kind)
	if cause != NO_CAUSE:
		_cause[slot] = cause
	return slot


## 호감. 관계가 없으면 0 — 모르는 사이는 좋지도 싫지도 않다.
func affinity(from: int, to: int) -> int:
	var slot := _find(from, to)
	return 0 if slot == NO_RELATION else _affinity[slot]


## 유대. 관계가 없으면 0.
func bond(from: int, to: int) -> int:
	var slot := _find(from, to)
	return 0 if slot == NO_RELATION else _bond[slot]


func kind_of(from: int, to: int) -> RelationKind.Kind:
	var slot := _find(from, to)
	return RelationKind.Kind.NONE if slot == NO_RELATION else _kind[slot] as RelationKind.Kind


func cause_of(from: int, to: int) -> int:
	var slot := _find(from, to)
	return NO_CAUSE if slot == NO_RELATION else _cause[slot]


## 이 인물이 아는 사람들. 등록 역순이라 순서가 결정론적이다.
func targets_of(from: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	if from < 0 or from >= _head.size():
		return found
	var slot := _head[from]
	while slot != NO_RELATION:
		found.append(_to[slot])
		slot = _next[slot]
	return found


func degree_of(from: int) -> int:
	return targets_of(from).size()


## **서로 아는 사람들.** 한쪽만 아는 관계를 걷어낸다.
##
## 차수만 세면 「내가 아는 사람」이 나오는데, 그것은 연줄이 아니다 —
## 사건의 목격자는 유대 0 짜리 한쪽 관계를 남기고(설계 24.21.5) 전멸의 인솔자는
## **죽은 사람들에게** 한쪽 관계를 남긴다. 그래서 차수가 큰 사람이
## *"사람을 많이 죽인 사람"* 일 수 있다. 연줄을 묻는 자리에서는 이쪽을 써야 한다.
func mutuals_of(from: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	for other in targets_of(from):
		if knows(other, from):
			found.append(other)
	return found


## 슬롯 하나를 읽는다. 도구가 전체를 훑을 때 쓴다.
func slot_from(slot: int) -> int:
	return _from[slot]


func slot_to(slot: int) -> int:
	return _to[slot]


func slot_kind(slot: int) -> RelationKind.Kind:
	return _kind[slot] as RelationKind.Kind


func slot_affinity(slot: int) -> int:
	return _affinity[slot]


func slot_bond(slot: int) -> int:
	return _bond[slot]
