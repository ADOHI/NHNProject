class_name SocialReach
extends RefCounted
## **연줄로 사람을 찾는다.** 한 사람을 중심으로 밖으로 퍼지며 후보를 고른다.
##
## docs/design/24-npc-relations.md §24.27.3 · §24.29.
##
## ## 왜 무작위로 뽑으면 안 되나
##
## 3000명에서 아무나 뽑으면 관계가 없다. 관계가 없으면 영입 판정은 늘 「모르는 사이」이고
## 조우 화면에는 **아는 얼굴이 한 번도 안 섞인다.** 그러면 관계도를 만든 값이 없다.
##
## ## 밖으로 퍼지는 차례
##
## | 차례 | 누구 | 무엇이 되나 |
## | --- | --- | --- |
## | 1 | **나를 아는 사람** | 이미 호감과 유대가 있다 |
## | 2 | 내가 일방적으로 아는 사람 | 저쪽은 나를 모른다 |
## | 3 | **그 사람들이 아는 사람** | *"내가 아는 사람의 원수"*. **소개한 사람이 남는다** |
## | 4 | 같은 소속 | 얼굴은 아는 사이 |
## | 5 | 아무나 | 세상에는 낯선 사람도 있다 |
##
## **1과 2를 가른 것이 실측에서 값을 했다.** 한쪽만 아는 관계가 12% 인데(§24.26.4)
## 안 가르면 그만큼 헛돈다 — 영입은 **저쪽이 나를 어떻게 보느냐**의 문제다.
##
## ## 전수 조사를 안 한다
##
## 마지막 차례(아무나)는 몇 번만 찔러 본다. 인구가 늘 때 비용이 따라 늘면 안 된다
## (§24.16.1 과 같은 규율).

## 계열을 안 가린다는 뜻.
const ANY_DISCIPLINE := -1

## 길드 하나가 나오려면 소속이 이만큼은 돼야 한다.
##
## 계열 다섯을 하나씩 채워야 하는데(docs/design/14-squad.md §14.4.3) 계열이 균등하므로
## 열둘이면 다섯 계열이 다 있을 확률이 높다. 소속 중위가 18명이라(§24.16.9)
## 절반 넘는 소속이 이 문턱을 넘는다.
const GUILD_FACTION_MIN := 12

## 아무나 뽑을 때 찔러 보는 횟수.
const _TRIES := 16

## 아무에게도 못 닿았을 때.
const NOBODY := PersonRegistry.NO_PERSON


## 한 사람에게 닿는다. `[인물, 소개한 사람]` 을 돌려주고 못 닿으면 둘 다 NOBODY 다.
##
## **소개한 사람을 같이 돌려주는 이유**는 화면이 *"누구를 통해"* 를 말해야 하기 때문이다.
## 후보가 누구인지가 아니라 **누구를 통해 왔는지**가 정보가 된다 (§24.8).
##
## discipline 을 주면 그 계열만 고른다 — 길드가 계열 하나씩 채울 때 쓴다.
static func near(
	world: NpcWorld,
	anchor: int,
	taken: Dictionary,
	rng: RandomNumberGenerator,
	discipline: int = ANY_DISCIPLINE
) -> Array:
	if world == null or world.registry.size() == 0:
		return [NOBODY, NOBODY]

	if world.registry.has(anchor):
		var mutual := _pick(world, world.graph.mutuals_of(anchor), taken, rng, discipline)
		if mutual != NOBODY:
			return [mutual, NOBODY]

		var known := _pick(world, world.graph.targets_of(anchor), taken, rng, discipline)
		if known != NOBODY:
			return [known, NOBODY]

		for friend in world.graph.targets_of(anchor):
			var referred := _pick(world, world.graph.targets_of(friend), taken, rng, discipline)
			if referred != NOBODY:
				return [referred, friend]

		var mate := _faction_mate(world, anchor, taken, rng, discipline)
		if mate != NOBODY:
			return [mate, NOBODY]

	return [_anyone(world, taken, rng, discipline), NOBODY]


## 길드 하나가 될 만한 소속을 고른다. 없으면 NO_FACTION.
##
## **길드는 소속이다.** 3000명에서 연줄로 다섯을 뽑아 보니 대원끼리 아는 사이가
## 열 쌍 중 한 쌍뿐이었다 — 계열을 하나씩 채워야 해서 연줄 탐색이 계열 문턱에서
## 계속 미끄러지고 결국 무작위로 떨어진다. **소속이 그 「같은 바닥」이고,
## §24.16.5 가 지프 분포를 준 이유가 여기서 값을 한다.**
static func pick_faction(
	world: NpcWorld, rng: RandomNumberGenerator, wanted: int = GUILD_FACTION_MIN
) -> int:
	var big := world.factions.factions_of_at_least(wanted)
	if big.is_empty():
		return PersonRegistry.NO_FACTION
	return big[rng.randi() % big.size()]


## 이 사람이 저 사람을 아는가. 어느 방향이든 한쪽이라도 알면 참이다.
##
## **조우 화면이 「아는 얼굴」을 세는 기준이다.** 내가 저 사람을 아는 것과
## 저 사람이 나를 아는 것은 둘 다 조우에서 뜻이 있다 — 한쪽만 알아도
## 그 자리에 정보가 생긴다 (§24.8).
static func familiar(graph: RelationGraph, one: int, other: int) -> bool:
	return graph.knows(one, other) or graph.knows(other, one)


## 후보 목록에서 아직 안 쓴 사람 하나. 순서가 결정론적이라 같은 시드면 같은 결과다.
static func _pick(
	world: NpcWorld,
	people: PackedInt32Array,
	taken: Dictionary,
	rng: RandomNumberGenerator,
	discipline: int
) -> int:
	var free := PackedInt32Array()
	for person in people:
		if taken.has(person):
			continue
		if discipline != ANY_DISCIPLINE and int(world.registry.discipline_of(person)) != discipline:
			continue
		free.append(person)
	if free.is_empty():
		return NOBODY
	return free[rng.randi() % free.size()]


static func _faction_mate(
	world: NpcWorld, anchor: int, taken: Dictionary, rng: RandomNumberGenerator, discipline: int
) -> int:
	var faction := world.registry.faction_of(anchor)
	if faction == PersonRegistry.NO_FACTION:
		return NOBODY
	for _try in _TRIES:
		var other := rng.randi() % world.registry.size()
		if world.registry.faction_of(other) != faction or taken.has(other):
			continue
		if discipline == ANY_DISCIPLINE or int(world.registry.discipline_of(other)) == discipline:
			return other
	return NOBODY


static func _anyone(
	world: NpcWorld, taken: Dictionary, rng: RandomNumberGenerator, discipline: int
) -> int:
	for _try in _TRIES:
		var other := rng.randi() % world.registry.size()
		if taken.has(other):
			continue
		if discipline == ANY_DISCIPLINE or int(world.registry.discipline_of(other)) == discipline:
			return other
	return NOBODY
