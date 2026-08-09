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

## **한 사람이 다른 사람을 아는 정도.** 세 단이고 그 사이는 없다 (설계 24.42.3).
##
## | 단 | 무엇 | 화면에 쓸 수 있는 말 |
## | --- | --- | --- |
## | `STRANGER` | 모르는 사람 | 없다 |
## | `HEARD_OF` | **이름을 들어 봤다** — 관계가 없는데 유명하다 | *"이름은 들어 봤다"* — 그게 전부다 |
## | `KNOWN` | **겪어서 안다** | *"당신 대원 차소경의 아들"* · *"그 판에서 배신한 자"* |
##
## **둘을 합치면 안 된다.** §24.32.2 가 재인을 재면서 *"조우 화면이 필요한 것은
## 얼굴이 아니라 아는 얼굴에만 붙는 한 줄"* 이라고 했는데 **그 한 줄이 둘은 서로 다르다.**
##
## **그리고 하나는 쌓이고 하나는 안 쌓인다** (§24.42.3) —
## `KNOWN` 은 판을 돌수록 늘고(10.9% → 12.4%) `HEARD_OF` 는 27.8% 에서 안 움직인다.
## 앞의 것은 플레이어가 쌓은 것이고 뒤의 것은 **세계의 유명세 분포**다.
enum Tier {
	STRANGER,
	HEARD_OF,
	KNOWN,
}

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


## **한 쌍의 아는 정도.** 화면이 부품 하나마다 이것을 묻는다 (설계 24.42.3).
##
## ## 순수 함수다 — 같은 쌍은 언제 물어도 같은 답이다
##
## 난수도 시간도 안 쓴다. 읽는 것은 관계 그래프와 유명세 둘뿐이고 **둘 다 사건이
## 일어날 때만 바뀐다.** 화면이 프레임마다 물어도 답이 안 흔들린다 —
## **흔들리면 그건 노이즈가 아니라 고장이다.**
##
## ## 겪어서 아는 것이 이긴다
##
## 유명하면서 아는 사이일 수 있다. 그때는 `KNOWN` 이다 —
## **부를 말이 있는 쪽이 이긴다.** *"이름은 들어 봤다"* 는 그 말이 없을 때 쓰는 말이다.
static func tier_of(world: NpcWorld, viewer: int, seen: int) -> Tier:
	if world == null or not world.is_ready() or viewer == seen:
		return Tier.STRANGER
	if not world.registry.has(viewer) or not world.registry.has(seen):
		return Tier.STRANGER
	if familiar(world.graph, viewer, seen):
		return Tier.KNOWN
	if is_heard_of(world.registry, seen):
		return Tier.HEARD_OF
	return Tier.STRANGER


## **이름값이 있는가.** 보는 사람을 안 받는다 —
## 유명한 것은 누구에 대해서가 아니라 **세계에 대해** 유명한 것이다 (설계 24.7).
##
## 문턱의 원본은 `PersonGenerator.FAME_KNOWN` 이고, 그것을 읽는 곳은 **이 함수 하나**다.
static func is_heard_of(registry: PersonRegistry, person: int) -> bool:
	return registry.has(person) and registry.fame_of(person) >= PersonGenerator.FAME_KNOWN


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
