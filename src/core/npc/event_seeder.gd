class_name EventSeeder
extends RefCounted
## 세계에 사건을 굴린다. **관계는 여기서 나온 찌꺼기다.**
##
## docs/design/24-npc-relations.md §24.5 · §24.11.
##
## ## 왜 관계를 직접 뿌리지 않는가
##
## 설계 24.5 —
## *"랜덤으로 간선을 뿌리면 이유 없는 수치가 나오고, 이유가 없으면 렉카가 쓸 것도
## 플레이어가 읽을 것도 없다."*
##
## 그래서 이 클래스는 **관계를 만들지 않는다.** 사건을 만들어
## `RelationResolver` 에 넘기고, 관계는 그 결과로 생긴다.
##
## ## 자리를 어떻게 채우나 — 목격자가 이 설계의 요점이다
##
## 행위자와 대상만 있으면 관계가 늘 쌍으로만 생겨서 **비대칭이 화면에 안 드러난다.**
## 목격자를 **대상 쪽 사람 중에서도** 뽑는 이유가 그것이다 —
## 다자 조우(설계 5.10)에서 저쪽 팀 사람이 이쪽 사람의 배신을 본다.
## 그 사람은 행위자를 **모른다.** 사건이 끝나면 한쪽만 아는 관계가 남는다.
##
## ## 나눠 돌릴 수 있다
##
## 인구 생성 · 가족 심기와 같은 규율이다 (설계 24.16.2). 웹은 단일 스레드라
## 3000명 분을 한 프레임에 돌리면 그만큼 화면이 멈춘다.
##
## ## 인구가 안 밀린다
##
## 사건은 `PersonSeed.Field.EVENT` 흐름을 쓴다. **생성 흐름과 갈려 있어서
## 사건을 몇 개를 굴리든 같은 시드의 같은 인덱스가 같은 사람이다** (설계 24.24.2).

## 몇 명당 사건 하나인가.
##
## 사건 하나가 만드는 방향 관계가 대략 여덟 개(행위자·대상 둘 + 목격자 몇)라
## 6명당 하나면 인물당 한둘이 더 붙는다. 태생이 이미 중위 1 이므로(설계 24.22.5)
## **합이 설계 24.2 의 예산 2~4개 안에 든다.**
const PEOPLE_PER_EVENT := 6

## 사건 종류의 상대 가중치 — 협력 · 배신 · 전멸.
##
## **협력이 압도적으로 흔해야 한다.** 배신이 흔하면 배신이 특별하지 않고,
## 설계 24.5 가 *"배신이 이 시스템의 핵심"* 이라 한 것이 값을 잃는다.
const KIND_WEIGHTS := [64, 24, 12]

## 그 자리에 있던 사람 수.
const WITNESS_MIN := 2
const WITNESS_MAX := 5

## 전멸에서 죽는 인원.
const FALLEN_MIN := 2
const FALLEN_MAX := 4

## 후보를 몇 번 찔러 보나. 통이 작으면 같은 사람만 나오므로 포기가 필요하다.
const _TRIES := 8

var _rng := RandomNumberGenerator.new()
var _seed: int
var _registry: PersonRegistry
var _resolver: RelationResolver
var _graph: RelationGraph
var _total: int
var _done := 0

## 소속 -> 그 소속의 인물들. 같이 던전에 들어갈 만한 사람을 여기서 고른다.
##
## 값이 `Array` 인 이유는 KinSeeder 와 같다 — `PackedInt32Array` 는 사전에서 꺼낼 때
## 복사본이 나와 append 가 사전에 안 남는다.
var _by_faction: Dictionary = {}


func _init(
	seed_value: int,
	registry: PersonRegistry,
	graph: RelationGraph,
	ledger: RelationLedger,
	spreads_rumors: bool = true
) -> void:
	_seed = seed_value
	_registry = registry
	_graph = graph
	_resolver = RelationResolver.new(registry, graph, ledger, spreads_rumors)
	_total = maxi(registry.size() / PEOPLE_PER_EVENT, 1) if registry.size() > 0 else 0
	_build_buckets()


## 이 인구에 굴릴 사건의 총수.
func event_count() -> int:
	return _total


func seeded() -> int:
	return _done


## 전부 굴린다.
func seed_all() -> void:
	while not seed_chunk(maxi(_total, 1)):
		pass


## 최대 chunk 건까지 이어서 굴린다. 다 굴렸으면 true.
func seed_chunk(chunk: int) -> bool:
	var target := mini(_done + maxi(chunk, 1), _total)
	while _done < target:
		# 사건마다 자기 흐름이다. 사건 수를 바꿔도 앞의 사건이 안 밀린다.
		PersonSeed.apply(_rng, _seed, PersonSeed.Field.EVENT, _done)
		_roll_one()
		_done += 1
	return _done >= _total


func _build_buckets() -> void:
	for person in _registry.size():
		var faction := _registry.faction_of(person)
		if faction == PersonRegistry.NO_FACTION:
			continue
		if not _by_faction.has(faction):
			_by_faction[faction] = ([] as Array[int])
		(_by_faction[faction] as Array[int]).append(person)


func _roll_one() -> void:
	var actor := _rng.randi() % _registry.size()
	var kind := _pick_kind()
	var targets := _pick_targets(actor, kind)
	if targets.is_empty():
		return
	_resolver.resolve(kind, actor, targets, _pick_witnesses(actor, targets))


func _pick_kind() -> RelationEvent.Kind:
	var total := 0
	for weight in KIND_WEIGHTS:
		total += int(weight)
	var roll := _rng.randi() % maxi(total, 1)
	var running := 0
	for slot in KIND_WEIGHTS.size():
		running += int(KIND_WEIGHTS[slot])
		if roll < running:
			return slot as RelationEvent.Kind
	return RelationEvent.Kind.COOPERATION


## 대상. **배신은 아는 사이라야 뜻이 있다** — 설계 24.5 가 「협력 후 공격」이라 적었다.
## 그래서 이미 엮인 사람을 먼저 보고, 없으면 같은 소속에서 고른다.
func _pick_targets(actor: int, kind: RelationEvent.Kind) -> PackedInt32Array:
	var wanted := 1
	if kind == RelationEvent.Kind.WIPEOUT:
		wanted = _rng.randi_range(FALLEN_MIN, FALLEN_MAX)

	var found := PackedInt32Array()
	var taken := {actor: true}
	for _slot in wanted:
		var other := _known_of(actor, taken)
		if other < 0:
			other = _from_faction(actor, taken)
		if other < 0:
			other = _anyone(taken)
		if other < 0:
			break
		taken[other] = true
		found.append(other)
	return found


## 그 자리에 있던 사람들. **절반쯤은 대상 쪽에서 뽑는다** —
## 그래야 행위자를 모르는 목격자가 생기고, 그것이 한쪽만 아는 관계가 된다.
func _pick_witnesses(actor: int, targets: PackedInt32Array) -> PackedInt32Array:
	var taken := {actor: true}
	for target in targets:
		taken[target] = true

	var found := PackedInt32Array()
	for _slot in _rng.randi_range(WITNESS_MIN, WITNESS_MAX):
		var anchor: int = targets[_rng.randi() % targets.size()] if _rng.randf() < 0.5 else actor
		var other := _known_of(anchor, taken)
		if other < 0:
			other = _from_faction(anchor, taken)
		if other < 0:
			other = _anyone(taken)
		if other < 0:
			break
		taken[other] = true
		found.append(other)
	return found


## 이 사람이 아는 사람 중 아직 안 쓴 하나. 없으면 -1.
func _known_of(person: int, taken: Dictionary) -> int:
	var neighbours := _graph.targets_of(person)
	if neighbours.is_empty():
		return -1
	for _try in _TRIES:
		var other := neighbours[_rng.randi() % neighbours.size()]
		if not taken.has(other):
			return other
	return -1


func _from_faction(person: int, taken: Dictionary) -> int:
	var faction := _registry.faction_of(person)
	var pool: Array[int] = _by_faction.get(faction, [] as Array[int])
	if pool.size() < 2:
		return -1
	for _try in _TRIES:
		var other := pool[_rng.randi() % pool.size()]
		if not taken.has(other):
			return other
	return -1


## 무소속끼리도 던전에서 만난다. 마지막 수단이라 몇 번만 찔러 본다.
func _anyone(taken: Dictionary) -> int:
	for _try in _TRIES:
		var other := _rng.randi() % _registry.size()
		if not taken.has(other):
			return other
	return -1
