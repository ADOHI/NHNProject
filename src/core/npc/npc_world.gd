class_name NpcWorld
extends RefCounted
## 세계 하나 — 인구 · 태생 관계 · 사건. **세우는 순서를 아는 곳이 여기 하나다.**
##
## docs/design/24-npc-relations.md §24.18 · §24.16.2.
##
## ## 순서가 규칙이다
##
##     인구 -> 태생 관계(가족 · 사제) -> 사건
##
## **사건이 마지막인 이유가 설계에 적혀 있다** (§24.18) — 유대가 전부 0 이면
## 목격자 가중이 0 이라 첫 사건이 아무에게도 안 닿는다. 태생 관계가 그 씨앗이다.
##
## 이 순서를 화면마다 다시 쓰면 **한 곳이 빠졌을 때 그 화면만 조용히 반쪽 세계가 된다.**
## 실제로 화면 하나와 도구 둘과 시험 둘이 같은 여섯 줄을 베껴 쓰고 있었다.
##
## ## 나눠 돌릴 수 있다
##
## **웹은 단일 스레드다.** 3000명을 한 프레임에 만들면 그만큼 화면이 멈춘다 (§24.16.2).
## `build_chunk()` 를 프레임마다 부르면 되고, 한 번에 다 세울 거면 `create()` 다.
## **둘의 결과가 같다** — 조각 경계가 난수 흐름에 안 들어간다 (§24.24.2).

## 세계가 서는 단계. 화면이 어디까지 왔는지 말할 때 쓴다.
enum Stage {
	POPULATION,  ## 인구를 만드는 중
	KIN,  ## 태생 관계를 심는 중
	EVENTS,  ## 사건을 굴리는 중
	READY,  ## 다 섰다
}

## 목표 인구. §24.8 의 상한이다.
const DEFAULT_POPULATION := 3000

## 한 조각에 만드는 인원. 3000명 20.4ms 기준으로 한 조각이 2ms 남짓이다 (§24.16.9).
const PEOPLE_CHUNK := 250

## 한 조각에 굴리는 사건 수. **사건 하나가 인물 하나보다 비싸다** —
## 목격자마다 성향 내적을 돌고 전멸은 유대로 이웃을 훑는다 (§24.21.5).
const EVENT_CHUNK := 60

## 연줄 있는 인물을 고를 때 찔러 보는 수 (`pick_connected`).
##
## **실측으로 정했다** (시드 20260808 · 인구 3000, 서로 아는 수의 세계 최대는 7) —
##
## | 표본 | 대표의 서로 아는 수 | 그중 영입 가능 |
## | --- | --- | --- |
## | 32 | 2 | **0** |
## | **128** | **4** | **2** |
## | 512 | 5 | 2 |
##
## 32 로는 대표의 연줄이 둘뿐이라 **영입이 한 번도 안 열린다.**
## 512 는 128 보다 나은 것이 없다. 비용은 한 번뿐인 짧은 걷기 128번이다.
const LEADER_SAMPLES := 128

## 이 세계의 씨앗. **같은 씨앗은 같은 세계다** (§24.16.7).
var seed_value: int

var registry := PersonRegistry.new()

## 관계. 인구가 다 만들어진 뒤에 생긴다.
var graph: RelationGraph = null

## 사건 기록. 사건 단계에 들어갈 때 생긴다.
var ledger: RelationLedger = null

## 소속 크기 색인. **마지막에 선다** — 인구가 다 있어야 셀 수 있다.
var factions: FactionIndex = null

var _population: int
var _spreads: bool
var _stage := Stage.POPULATION
var _generator: PersonGenerator
var _kin: KinSeeder
var _events: EventSeeder


## spreads_rumors 를 끄면 **소문이 없는 세계**가 선다. 게임은 안 끄고,
## 전파가 성김을 죽이는지 재는 도구만 쓴다 (설계 24.28.3).
func _init(
	world_seed: int, population: int = DEFAULT_POPULATION, spreads_rumors: bool = true
) -> void:
	seed_value = world_seed
	_population = maxi(population, 0)
	_spreads = spreads_rumors
	_generator = PersonGenerator.new(world_seed, _population)


## 다 선 세계 하나. 도구와 시험이 쓴다 — 화면은 `build_chunk()` 쪽이다.
static func create(
	world_seed: int, population: int = DEFAULT_POPULATION, spreads_rumors: bool = true
) -> NpcWorld:
	var world := NpcWorld.new(world_seed, population, spreads_rumors)
	while not world.build_chunk():
		pass
	return world


## 한 조각 세운다. 다 섰으면 true.
func build_chunk() -> bool:
	match _stage:
		Stage.POPULATION:
			_build_population()
		Stage.KIN:
			_build_kin()
		Stage.EVENTS:
			_build_events()
		_:
			return true
	return _stage == Stage.READY


func stage() -> Stage:
	return _stage


func is_ready() -> bool:
	return _stage == Stage.READY


func population() -> int:
	return _population


## 사건의 총수. 사건 단계 전에는 0 이다 — 아직 생성기가 없다.
func event_count() -> int:
	return 0 if _events == null else _events.event_count()


## 지금 단계에서 몇 개까지 됐나. 화면의 진행 표시가 쓴다.
func built() -> int:
	match _stage:
		Stage.POPULATION:
			return registry.size()
		Stage.KIN:
			return _kin.seeded()
		Stage.EVENTS:
			return _events.seeded()
		_:
			return 0


## 지금 단계의 총량.
func total() -> int:
	match _stage:
		Stage.POPULATION:
			return _population
		Stage.KIN:
			return registry.size()
		Stage.EVENTS:
			return _events.event_count()
		_:
			return 0


## 표본 중 **가장 연줄이 많은** 인물. 인구가 비면 NO_PERSON.
##
## **길드 대표를 세울 때 쓴다.** 관계가 하나도 없는 사람을 대표로 세우면
## 접선처가 아무도 못 찾는데, 그것은 **세계의 사실이 아니라 뽑기 실패다.**
## 인구의 24.8%가 관계가 없으므로(§24.26.4) 그냥 뽑으면 넷 중 하나가 그렇게 된다.
##
## **문턱을 넘는 첫 사람이 아니라 표본 중 최고를 고른다.** 차수 중위가 1 이고
## 90%가 3 이하라(§24.26.4) 문턱을 4 로 두면 32번 찔러도 못 찾는 시드가 생긴다.
## 최고를 고르면 **뽑기가 실패하지 않으면서** 대표가 늘 두터운 사람이 된다 —
## 길드를 세운 사람이 아는 사람이 둘뿐일 리 없다.
##
## **차수가 아니라 서로 아는 수로 센다.** 그냥 차수로 세면 표본 중 최고가
## **전멸을 여러 번 낸 사람**이 된다 — 죽은 사람들에게 한쪽 관계가 쌓여서
## 차수만 크고 아무도 그를 모른다 (실측으로 잡았다). 연줄은 서로 아는 사이다.
##
## 전수 조사를 안 하는 이유는 §24.16.1 과 같다 — 인구가 늘 때 비용이 따라 늘면 안 된다.
func pick_connected(rng: RandomNumberGenerator, samples: int = LEADER_SAMPLES) -> int:
	if registry.size() == 0:
		return PersonRegistry.NO_PERSON
	var best := PersonRegistry.NO_PERSON
	var best_degree := -1
	for _try in maxi(samples, 1):
		var person := rng.randi() % registry.size()
		var degree := 0 if graph == null else graph.mutuals_of(person).size()
		if degree > best_degree:
			best_degree = degree
			best = person
	return best


func _build_population() -> void:
	if not _generator.append_to(registry, PEOPLE_CHUNK):
		return
	_generator = null
	_stage = Stage.KIN
	graph = RelationGraph.new(registry.size())
	_kin = KinSeeder.new(seed_value, registry, graph)


func _build_kin() -> void:
	if not _kin.seed_chunk(PEOPLE_CHUNK):
		return
	_kin = null
	_stage = Stage.EVENTS
	ledger = RelationLedger.new()
	_events = EventSeeder.new(seed_value, registry, graph, ledger, _spreads)


func _build_events() -> void:
	if not _events.seed_chunk(EVENT_CHUNK):
		return
	_stage = Stage.READY
	# 소속 색인은 여기서 선다. **이것이 준비 신호다** — 도구가 이 하나를 보고 기다린다.
	factions = FactionIndex.new(registry)
