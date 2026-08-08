class_name PersonGenerator
extends RefCounted
## 인물 수천 명을 절차 생성한다. **런타임 · 코드만이다.**
##
## docs/design/24-npc-relations.md §24.9 가 갈라 둔 대로 이름 풀과 초상은 빌드 타임이고,
## 성향 · 능력치 · 소속은 런타임 절차 생성이다. 제출 빌드는 정적 호스팅이라
## 런타임 LLM 이 없다 — 그래서 이쪽은 전부 코드여야 한다.
##
## ## 나눠 돌릴 수 있다 (§24.16.2)
##
## 웹은 단일 스레드다. 3000명을 한 프레임에 만들면 그만큼 화면이 멈춘다.
## 그래서 이 클래스가 **목표 인구와 진행도, 그리고 RNG 상태를 자기 안에 들고 있다.**
##
##     var generator := PersonGenerator.new(seed, 3000)
##     while not generator.append_to(registry, 250):
##         await frame                     # 이 자리는 아직 비어 있다
##
## 한 번에 다 부르든 250명씩 부르든 **결과가 같다.** 분할 스케줄러는 이번 범위가 아니지만
## 못 나누는 구조로 짜지 않는 것까지가 이번 몫이다.
##
## ## 결정론 (§24.16.7)
##
## `randi()` 를 직접 부르지 않는다. 시드를 받은 RNG 하나가 모든 값을 낸다 —
## DungeonGenerator 와 같은 규율이다. 같은 시드 + 같은 인구 = 같은 세계.

## 소속 하나에 들어가는 평균 인원. 소속 수는 인구를 이것으로 나눈 값이다.
##
## 40 인 이유: 스쿼드 정원이 3~4명(docs/design/14-squad.md §14.4.3)이라
## 소속 하나가 스쿼드 열 팀쯤 굴리는 규모가 된다. 3000명이면 소속 75개다.
const PEOPLE_PER_FACTION := 40

## 무소속 비율. §24.2 의 "기본은 모르는 사이" 와 같은 이유다 —
## 아무 데도 안 걸린 사람이 있어야 소속이 뜻을 갖는다.
const UNAFFILIATED_CHANCE := 0.22

## 소속 크기의 지프 지수. 1.0 이면 꼬리가 전부 1~2명이 되어 소속이랄 게 없어진다.
## 0.8 이면 최대 소속이 최소의 서른 배쯤이라 "대형 길드와 잔챙이" 가 생긴다 (§24.16.5).
const FACTION_ZIPF := 0.8

## 유명세의 치우침 지수. 클수록 무명이 많다.
##
## 8 인 이유: 상위 1% 만 유명세 90 을 넘긴다. 3000명 기준 실측으로
## 중위값 0 · 50 이상 7.8% · 90 이상 1.2% 다.
## §24.7 의 "무명인 사람 얘기는 아무도 보지 않는다" 가 성립하려면
## **대다수가 무명이어야** 렉카의 기사 선정이 일을 한다.
const FAME_EXPONENT := 8.0

## 유명세 상한. 0 ~ 이 값 사이의 정수다.
const FAME_MAX := 100

## 계열 기본값에 얹는 편차의 폭. 계열 기본값이 1~4 라(MemberDiscipline)
## 이보다 넓히면 계열의 뜻이 사라진다.
const STAT_SPREAD := 1

var _rng := RandomNumberGenerator.new()
var _population: int
var _made := 0

## 이미 쓴 이름. MemberNames.pick() 이 이 사전을 보고 중복을 피한다.
var _used_names: Dictionary = {}

## 소속 크기의 누적 가중치. 지프 분포를 이진 탐색으로 뽑는다.
var _faction_weights := PackedFloat32Array()


func _init(seed_value: int, population: int) -> void:
	_population = maxi(population, 0)
	_rng.seed = seed_value
	_faction_weights = _build_faction_weights(faction_count())


## 목표 인구를 한 번에 만든다.
func generate() -> PersonRegistry:
	var registry := PersonRegistry.new()
	while not append_to(registry, _population):
		pass
	return registry


## 최대 chunk 명을 이어서 만든다. **다 만들었으면 true 를 돌려준다.**
##
## chunk 를 몇으로 주든 결과가 같다 — RNG 상태와 이름 장부가 이 객체에 있다.
func append_to(registry: PersonRegistry, chunk: int) -> bool:
	var target := mini(_made + maxi(chunk, 1), _population)
	while _made < target:
		_append_one(registry)
		_made += 1
	return _made >= _population


## 지금까지 만든 인원.
func made() -> int:
	return _made


## 목표 인구.
func population() -> int:
	return _population


## 소속의 개수. 인구가 적으면 하나다.
func faction_count() -> int:
	return maxi(1, _population / PEOPLE_PER_FACTION)


## 이름 풀이 이 인구를 감당하는가. 감당하지 못하면 중복 이름이 나오고
## 그 순간 §24.2 의 "기억되는 인물" 이 죽는다.
func has_name_capacity() -> bool:
	return MemberNames.capacity() >= _population


func _append_one(registry: PersonRegistry) -> void:
	var discipline := (_rng.randi() % MemberDiscipline.count()) as MemberDiscipline.Kind
	var person_name := MemberNames.pick(_rng, _used_names)
	# 계열 기본값을 베끼지 않고 MemberDiscipline 에 물어본다 — 상수를 복제하면
	# 계열 밸런스를 고쳤을 때 세계만 옛 수치로 남는다.
	var threat := _stat(MemberDiscipline.base_threat(discipline))
	var agility := _stat(MemberDiscipline.base_agility(discipline))
	var faction := _pick_faction()
	var fame := _pick_fame()
	var traits := TraitDistribution.sample_person(_rng)
	registry.add(person_name, discipline, threat, agility, faction, fame, traits)


## 계열 기본값 주변의 값. 1 미만으로는 내리지 않는다 —
## 전투력 0 인 대원은 스쿼드 합(§14.3)에 아무것도 더하지 않아 존재 이유가 없다.
func _stat(base: int) -> int:
	return maxi(1, base + _rng.randi_range(-STAT_SPREAD, STAT_SPREAD))


func _pick_fame() -> int:
	return int(round(float(FAME_MAX) * pow(_rng.randf(), FAME_EXPONENT)))


func _pick_faction() -> int:
	if _rng.randf() < UNAFFILIATED_CHANCE or _faction_weights.is_empty():
		return PersonRegistry.NO_FACTION

	var roll := _rng.randf() * _faction_weights[_faction_weights.size() - 1]
	var low := 0
	var high := _faction_weights.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if _faction_weights[middle] < roll:
			low = middle + 1
		else:
			high = middle
	return low


func _build_faction_weights(total: int) -> PackedFloat32Array:
	var cumulative := PackedFloat32Array()
	var running := 0.0
	for index in total:
		running += 1.0 / pow(float(index + 1), FACTION_ZIPF)
		cumulative.append(running)
	return cumulative
