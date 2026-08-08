class_name KinSeeder
extends RefCounted
## 태생 관계를 심는다 — 부모 · 자식 · 형제 · 사제.
##
## docs/design/24-npc-relations.md §24.22.5.
##
## ## 왜 이것이 먼저인가
##
## **유대가 전부 0 이면 설계 24.6 의 목격자 가중이 0 이라 첫 사건이 아무에게도 안 닿는다.**
## 태생 관계가 세계의 씨앗이다 (설계 24.18).
##
## ## 나이가 정한다
##
## 부모는 자식보다 위고, 형제는 비슷하고, 스승은 제자보다 위다.
## **나이가 없으면 「가족」이 그냥 무작위 쌍이 되고**, 그 순간 설계 24.5 가 경계한
## "이유 없는 수치" 가 된다.
##
## ## 성이 후보를 거른다
##
## 부모 · 자식 · 형제는 **성이 같아야 한다.** 그래서 성별 · 나이별 통에 미리 담아 두고
## 그 통에서만 고른다. **사제는 성을 안 보고 계열을 본다** — 기술을 물려받는 관계다.
##
## ## 나눠 돌릴 수 있다
##
## 인구 생성과 같은 규율이다 (설계 24.16.2). `seed_chunk()` 를 몇 번 부르든 결과가 같다.

## 가족 관계를 하나라도 가질 확률.
##
## 전원에게 주면 설계 24.2 의 예산(인물당 2~4개)을 태생이 다 써서
## **사건이 채울 자리가 남지 않는다.** 아무도 없으면 씨앗이 없다.
## 절반 남짓이면 "저 사람은 혼자다" 와 "저 사람은 형이 있다" 가 둘 다 정보가 된다.
const KIN_CHANCE := 0.55

## 가족이 있는 인물이 형제일 확률. 나머지는 부모 · 자식이다.
const SIBLING_SHARE := 0.45

## 사제 관계를 가질 확률. 가족과 별개로 굴린다.
const MASTER_CHANCE := 0.18

## 부모와 자식의 나이차.
const PARENT_GAP_MIN := 20
const PARENT_GAP_MAX := 40

## 형제의 나이차.
const SIBLING_GAP_MAX := 12

## 스승과 제자의 나이차.
const MASTER_GAP_MIN := 12
const MASTER_GAP_MAX := 35

## 유대와 호감의 범위. **호감의 아래끝이 음수다** — 가족이라고 다 사이가 좋지 않다.
## 설계 24.2 의 "유대 높음 + 호감 낮음" 이 사건 없이도 세계에 있어야 한다.
const PARENT_BOND := Vector2i(70, 92)
const PARENT_AFFINITY := Vector2i(-15, 85)
const SIBLING_BOND := Vector2i(62, 88)
const SIBLING_AFFINITY := Vector2i(-20, 80)
const MASTER_BOND := Vector2i(45, 72)
const MASTER_AFFINITY := Vector2i(5, 70)

## 후보를 몇 번 뽑아 보나. 통이 비었거나 이미 엮인 상대만 나오면 포기한다.
const _TRIES := 12

var _rng := RandomNumberGenerator.new()
var _registry: PersonRegistry
var _graph: RelationGraph
var _seeded := 0

## 성 -> 그 성을 가진 인물 목록. 부모 · 형제 후보를 여기서만 고른다.
##
## 값이 `Array` 다. **`PackedInt32Array` 를 쓰면 사전에서 꺼낼 때 복사본이 나와
## append 가 사전에 안 남는다** — 통이 영원히 비어 가족이 하나도 안 생긴다.
var _by_surname: Dictionary = {}

## 계열 -> 인물 목록. 사제 후보를 여기서 고른다.
var _by_discipline: Dictionary = {}


func _init(seed_value: int, registry: PersonRegistry, graph: RelationGraph) -> void:
	_rng.seed = seed_value
	_registry = registry
	_graph = graph
	_build_buckets()


## 전부 심는다.
func seed_all() -> void:
	while not seed_chunk(_registry.size()):
		pass


## 최대 chunk 명까지 이어서 심는다. 다 심었으면 true.
func seed_chunk(chunk: int) -> bool:
	var target := mini(_seeded + maxi(chunk, 1), _registry.size())
	while _seeded < target:
		_seed_one(_seeded)
		_seeded += 1
	return _seeded >= _registry.size()


func seeded() -> int:
	return _seeded


func _build_buckets() -> void:
	for person in _registry.size():
		var surname := _registry.surname_of(person)
		if not _by_surname.has(surname):
			_by_surname[surname] = ([] as Array[int])
		(_by_surname[surname] as Array[int]).append(person)

		var discipline := int(_registry.discipline_of(person))
		if not _by_discipline.has(discipline):
			_by_discipline[discipline] = ([] as Array[int])
		(_by_discipline[discipline] as Array[int]).append(person)


func _seed_one(person: int) -> void:
	if _rng.randf() < KIN_CHANCE:
		if _rng.randf() < SIBLING_SHARE:
			_try_sibling(person)
		else:
			_try_parent(person)
	if _rng.randf() < MASTER_CHANCE:
		_try_master(person)


## 상대가 내 부모다. 반대 슬롯은 자식이 된다.
func _try_parent(person: int) -> void:
	var age := _registry.age_of(person)
	var pool: Array[int] = _by_surname.get(_registry.surname_of(person), [] as Array[int])
	# **성을 물려주는 쪽만 부모로 잡는다.** 성이 부계라(설계 24.22.7) 어머니는
	# 성이 다르고, 성이 다른 부모를 여기서 만들면 혈연이 성으로 안 묶인다.
	var other := _find(pool, person, age + PARENT_GAP_MIN, age + PARENT_GAP_MAX, true)
	if other < 0:
		return
	_bind(person, other, RelationKind.Kind.PARENT, PARENT_BOND, PARENT_AFFINITY)


func _try_sibling(person: int) -> void:
	var age := _registry.age_of(person)
	var pool: Array[int] = _by_surname.get(_registry.surname_of(person), [] as Array[int])
	var other := _find(pool, person, age - SIBLING_GAP_MAX, age + SIBLING_GAP_MAX)
	if other < 0:
		return
	_bind(person, other, RelationKind.Kind.SIBLING, SIBLING_BOND, SIBLING_AFFINITY)


## 상대가 내 스승이다. **성을 안 보고 계열을 본다.**
func _try_master(person: int) -> void:
	var age := _registry.age_of(person)
	var bucket := int(_registry.discipline_of(person))
	var pool: Array[int] = _by_discipline.get(bucket, [] as Array[int])
	var other := _find(pool, person, age + MASTER_GAP_MIN, age + MASTER_GAP_MAX)
	if other < 0:
		return
	_bind(person, other, RelationKind.Kind.MASTER, MASTER_BOND, MASTER_AFFINITY)


## 통에서 나이가 맞고 아직 안 엮인 상대를 찾는다. 없으면 -1.
##
## 통 전체를 훑지 않고 몇 번만 찔러 본다 — 흔한 성은 통이 수백 명이라
## 매번 훑으면 인구가 늘 때 제곱으로 비싸진다.
func _find(pool: Array[int], person: int, low: int, high: int, male_only: bool = false) -> int:
	if pool.size() < 2:
		return -1
	for _try in _TRIES:
		var other := pool[_rng.randi() % pool.size()]
		if other == person or _graph.knows(person, other):
			continue
		if male_only and _registry.gender_of(other) != PersonGender.Kind.MALE:
			continue
		var age := _registry.age_of(other)
		if age >= low and age <= high:
			return other
	return -1


## 두 슬롯을 만든다. **비대칭이라 방향마다 호감이 따로다** (설계 24.21.2).
##
## 유대는 같은 값을 준다 — 엮인 정도는 상호적이다. 호감은 따로 굴린다.
func _bind(
	person: int, other: int, kind: RelationKind.Kind, bond: Vector2i, affinity: Vector2i
) -> void:
	var tie := _rng.randi_range(bond.x, bond.y)
	_graph.link(person, other, kind, _rng.randi_range(affinity.x, affinity.y), tie)
	_graph.link(
		other, person, RelationKind.opposite(kind), _rng.randi_range(affinity.x, affinity.y), tie
	)
