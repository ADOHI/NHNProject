class_name FactionIndex
extends RefCounted
## 소속의 크기와 순위. **지프 분포가 읽히게 하려고 만든다.**
##
## docs/design/24-npc-relations.md §24.17.6.
##
## ## 왜 번호만으로는 안 되나
##
## 소속이 75개고 크기가 6 / 18 / 318명이다(§24.16.9). 화면에 `#12` 만 적으면
## `#61` 과 같은 무게로 보이고, **그 순간 지프 분포가 안 읽힌다.**
## 인원과 크기 순위를 같이 내야 "이게 큰 소속인가" 에 답이 나온다.
##
## ## 등급 이름을 만들지 않았다
##
## 대 · 중 · 소로 나누려면 문턱을 정해야 하고, **그 문턱이 근거 없는 상수가 된다.**
## 인원 숫자와 순위는 문턱 없이 읽힌다.

var _sizes := PackedInt32Array()

## 소속 -> 그 소속의 인물들. **길드와 상대 스쿼드가 여기서 나온다** (설계 24.29).
##
## 크기만으로는 "누가 그 소속인가" 에 답할 수 없다. 매번 3000명을 훑으면
## 조우마다 인구 전체를 도는 셈이라, 색인을 세울 때 같이 담는다.
var _members: Dictionary = {}

## 크기 순위. _ranks[소속] = 1 이면 가장 큰 소속이다.
var _ranks := PackedInt32Array()

var _largest := 0
var _populated := 0


func _init(registry: PersonRegistry) -> void:
	_build(registry)


## 소속의 인원. 없는 소속이면 0.
func size_of(faction: int) -> int:
	return 0 if faction < 0 or faction >= _sizes.size() else _sizes[faction]


## 크기 순위 (1 이 가장 크다). 인원 0 인 소속은 0 을 돌려준다.
func rank_of(faction: int) -> int:
	return 0 if faction < 0 or faction >= _ranks.size() else _ranks[faction]


## 인원이 1명 이상인 소속의 수. 순위의 분모다.
func populated_count() -> int:
	return _populated


## 가장 큰 소속의 인원. 막대의 기준이다.
func largest_size() -> int:
	return _largest


## 이 소속의 인물들. 없는 소속이면 빈 배열이다.
func members_of(faction: int) -> PackedInt32Array:
	return _members.get(faction, PackedInt32Array()) as PackedInt32Array


## 인원이 wanted 명 이상인 소속들. **길드가 될 만한 크기**를 고를 때 쓴다.
func factions_of_at_least(wanted: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	for faction in _sizes.size():
		if _sizes[faction] >= wanted:
			found.append(faction)
	return found


## 소속을 한 줄로. `#12 86명 4/75` 또는 `무소속`.
##
## 짧게 쓰는 이유는 왼쪽 열이 좁고 인원 막대가 같은 줄에 들어가야 해서다.
## 「크기」 같은 말머리를 빼도 `4/75` 가 순위로 읽힌다.
func describe(faction: int) -> String:
	if faction == PersonRegistry.NO_FACTION:
		return "무소속"
	return "#%d %d명 %d/%d" % [faction, size_of(faction), rank_of(faction), _populated]


func _build(registry: PersonRegistry) -> void:
	var highest := -1
	for person in registry.size():
		highest = maxi(highest, registry.faction_of(person))
	_sizes.resize(highest + 1)
	_ranks.resize(highest + 1)

	for person in registry.size():
		var faction := registry.faction_of(person)
		if faction < 0:
			continue
		_sizes[faction] += 1
		if not _members.has(faction):
			_members[faction] = PackedInt32Array()
		var bucket: PackedInt32Array = _members[faction]
		bucket.append(person)
		_members[faction] = bucket

	var order: Array[int] = []
	for faction in _sizes.size():
		if _sizes[faction] > 0:
			order.append(faction)
			_largest = maxi(_largest, _sizes[faction])
	_populated = order.size()

	# 같은 인원이면 번호 순으로 — 순위가 부를 때마다 달라지면 화면이 깜빡인다.
	order.sort_custom(
		func(one: int, other: int) -> bool:
			return one < other if _sizes[one] == _sizes[other] else _sizes[one] > _sizes[other]
	)
	for slot in order.size():
		_ranks[order[slot]] = slot + 1
