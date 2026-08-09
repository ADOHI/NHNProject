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
## ## 결정론 — 필드마다 흐름이 갈려 있다 (§24.24)
##
## 예전에는 RNG 하나를 순서대로 소비했다. 그래서 **필드를 하나 더하면 그 뒤의 모든
## 뽑기가 밀려 같은 시드의 같은 인덱스가 다른 사람이 됐다** — 성과 성별을 넣을 때
## 실제로 두 번 그랬고 초상 레인이 골라 둔 인물이 사라졌다.
##
## 지금은 `PersonSeed` 가 **(세계 시드, 필드, 인물 인덱스)** 로 흐름을 연다.
## **필드를 더해도 인물이 안 바뀌고**, 인구를 늘려도 앞 인물이 안 밀린다.
##
## 그래서 인덱스 하나가 곧 그 인물이다 — 초상 배치를 밤새 돌려도 아침에 같은 사람이다.

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

## **이름을 들어 봤다고 할 만한 유명세** (설계 24.42).
##
## §24.7 — *"관계가 없어도 유명하면 상대가 나를 안다. 처음 만나는데
## 「어 너 그 새끼 아니냐」가 성립한다."* 그 문턱이다.
##
## **50 인 것은 실측이다** — 생성 시점 인구의 7.8% 가 여기 위다 (설계 24.16.9).
## 여섯이 선 스쿼드라면 **셋에 하나쯤 아는 이름이 하나 섞인다.**
## 낮추면 다 유명해져서 유명세가 아무도 안 가르고, 올리면 조우에서 영영 안 나온다.
##
## **도구들이 이 값을 50 이라고 베껴 쓰고 있었다.** 원본은 여기 하나다.
const FAME_KNOWN := 50

## 여성일 확률. **계열과 독립이고 반반이다** (설계 24.23).
##
## 계열이 성별을 예측하면 초상 풀을 계열x성별로 쪼갤 때 한쪽이 비고,
## §14.4.2 가 경계한 "계열이 무언가를 확정하는" 자리가 하나 더 생긴다.
const FEMALE_CHANCE := 0.5

## 나이의 아래끝. 던전에 들어가는 직업이라 그 아래는 탐험가가 아니라 아이다 (설계 24.22.2).
const AGE_MIN := 16

## 나이의 위끝. 균등하게 뽑으면 여든 살 탐험가가 나온다 —
## **살아서 늙는 사람이 드문 직업**이므로 위끝을 낮춘다.
const AGE_MAX := 58

## 나이의 치우침 지수. 클수록 젊다. 1.8 이면 중위가 28 쯤이다.
##
## 젊은 쪽에 몰린 것은 **생존 편향**이다 — 위험한 일을 오래 하면 설계 24.5 의 전멸을 만난다.
## 그리고 설계 06 §6.1 의 영입과 성장이 뜻을 가지려면 젊은 후보가 많아야 한다.
const AGE_EXPONENT := 1.8

## 유명세가 천장에 닿는 나이. 이 나이부터는 나이가 유명세를 안 누른다.
##
## 설계 24.7 이 유명세를 **누적**이라 못 박았으므로 시간이 든다 —
## 스무 살에 유명세 100 은 그럴듯하지 않다.
## 이 뒤로도 계속 오르게 하면 **나이가 곧 유명세**가 되어 유명세가
## "무엇을 했는가" 가 아니라 "얼마나 오래 살았는가" 를 뜻하게 된다 (설계 24.22.4).
const FAME_PRIME_AGE := 35

## 가장 어릴 때의 유명세 계수. 0 이 아닌 이유는 **어린 유명인이 없어지면 안 되고
## 드물어야** 하기 때문이다.
const FAME_YOUNG_FACTOR := 0.35

## 계열 기본값에 얹는 편차의 폭. 계열 기본값이 1~4 라(MemberDiscipline)
## 이보다 넓히면 계열의 뜻이 사라진다.
const STAT_SPREAD := 1

var _rng := RandomNumberGenerator.new()
var _seed: int
var _population: int
var _made := 0

## 이미 쓴 이름. MemberNames.pick() 이 이 사전을 보고 중복을 피한다.
var _used_names: Dictionary = {}

## 소속 크기의 누적 가중치. 지프 분포를 이진 탐색으로 뽑는다.
var _faction_weights := PackedFloat32Array()


func _init(seed_value: int, population: int) -> void:
	_population = maxi(population, 0)
	_seed = seed_value
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
	# 필드마다 흐름을 갈아 끼운다. 순서를 바꿔도 값이 안 바뀐다 (§24.24).
	var index := _made
	_stream(PersonSeed.Field.DISCIPLINE, index)
	var discipline := (_rng.randi() % MemberDiscipline.count()) as MemberDiscipline.Kind
	_stream(PersonSeed.Field.NAME, index)
	var person_name := MemberNames.pick(_rng, _used_names)
	# 계열 기본값을 베끼지 않고 MemberDiscipline 에 물어본다 — 상수를 복제하면
	# 계열 밸런스를 고쳤을 때 세계만 옛 수치로 남는다.
	_stream(PersonSeed.Field.THREAT, index)
	var threat := _stat(MemberDiscipline.base_threat(discipline))
	_stream(PersonSeed.Field.AGILITY, index)
	var agility := _stat(MemberDiscipline.base_agility(discipline))
	_stream(PersonSeed.Field.FACTION, index)
	var faction := _pick_faction()
	_stream(PersonSeed.Field.AGE, index)
	var age := _pick_age()
	_stream(PersonSeed.Field.GENDER, index)
	var gender := _pick_gender()
	_stream(PersonSeed.Field.FAME, index)
	var fame := _pick_fame(age)
	_stream(PersonSeed.Field.TRAITS, index)
	var traits := TraitDistribution.sample_person(_rng)
	registry.add(person_name, discipline, threat, agility, faction, fame, age, gender, traits)


## 이 필드 · 이 인물의 흐름으로 갈아 끼운다.
func _stream(field: PersonSeed.Field, index: int) -> void:
	PersonSeed.apply(_rng, _seed, field, index)


## 계열 기본값 주변의 값. 1 미만으로는 내리지 않는다 —
## 전투력 0 인 대원은 스쿼드 합(§14.3)에 아무것도 더하지 않아 존재 이유가 없다.
func _stat(base: int) -> int:
	return maxi(1, base + _rng.randi_range(-STAT_SPREAD, STAT_SPREAD))


## 성별. **계열도 나이도 안 본다** — 보면 그 쏠림이 우리 선택이 된다.
func _pick_gender() -> PersonGender.Kind:
	return PersonGender.Kind.FEMALE if _rng.randf() < FEMALE_CHANCE else PersonGender.Kind.MALE


func _pick_age() -> int:
	return AGE_MIN + int(pow(_rng.randf(), AGE_EXPONENT) * float(AGE_MAX - AGE_MIN))


## 유명세. **상한만 나이로 누른다** — 분포의 치우침은 그대로 두고 젊은 쪽 꼬리만 깎는다.
func _pick_fame(age: int) -> int:
	var raw := float(FAME_MAX) * pow(_rng.randf(), FAME_EXPONENT)
	return int(round(raw * _fame_age_factor(age)))


func _fame_age_factor(age: int) -> float:
	if age >= FAME_PRIME_AGE:
		return 1.0
	var grown := float(age - AGE_MIN) / float(maxi(FAME_PRIME_AGE - AGE_MIN, 1))
	return FAME_YOUNG_FACTOR + (1.0 - FAME_YOUNG_FACTOR) * clampf(grown, 0.0, 1.0)


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
