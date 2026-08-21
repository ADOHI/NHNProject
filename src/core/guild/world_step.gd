class_name WorldStep
extends RefCounted
## 세계가 **한 틱** 도는 것. 던전 1회 = 세계 1틱 (설계 15.1 · 24.11).
##
## docs/design/37-meta-loop.md §37.5.3.
##
## ## 한 틱이 하는 일은 여기 한 곳에만 적는다
##
## 정산이 이것을 부르고 **되감기도 이것을 부른다** (`WorldProgress.replay`).
## 반영과 되감기를 따로 적으면 언젠가 갈라지고, 그러면 **불러온 세계가 저장한
## 세계와 다른데 아무 오류도 안 난다** — 이 저장소가 가장 무서워하는 종류의 결함이다
## (docs/conventions.md §6.5 — *"같은 판정을 두 곳에 적지 마라"*).
##
## ## 왜 이것이 저장될 수 있는가
##
## `EventSeeder` 가 사건마다 흐름을 씨앗에서 다시 뽑고(`PersonSeed.Field.EVENT`),
## `RelationResolver.resolve()` 에는 **난수가 아예 없다.** 그래서 걸어온 순서만 알면
## 세계가 그대로 다시 선다 — **간선을 담을 필요가 없다** (설계 34.4.1 이 걱정한 크기).
##
## ## 사람은 대원 식별자가 아니라 인물 번호로 든다
##
## 되감을 때 길드는 아직 안 서 있다(`GameSave.restore` 가 세계를 먼저 세운다).
## 그리고 인물 번호는 **동결돼 있다** — 인덱스가 곧 그 사람이다 (설계 24.24).

## 같이 간 사람들 사이에 남는 것. 성패를 안 가린다 (설계 24.30.3).
const TOGETHER := RelationEvent.Kind.COOPERATION

## 이 틱에 세계 곳곳에서 굴린 사건 수.
var events: int

## 같이 나간 사람들. **세계 인물 번호다.**
var went: PackedInt32Array

## 아지트에 남아 소식을 들은 사람들. 목격자가 된다.
var stayed: PackedInt32Array

## 쓰러져 돌아왔나. 그때만 후유증이 걸린다 (설계 2.6.1.5).
var downed: bool

## 몇 번째 틱인가. 후유증 사건의 대상 칸에 적혀 열전이 시점을 말한다.
var tick: int


func _init(
	world_events: int = 0,
	went_people: PackedInt32Array = PackedInt32Array(),
	stayed_people: PackedInt32Array = PackedInt32Array(),
	was_downed: bool = false,
	tick_number: int = 0
) -> void:
	events = maxi(world_events, 0)
	went = went_people
	stayed = stayed_people
	downed = was_downed
	tick = tick_number


## 이 틱을 세계에 건다. 돌려주는 것은 **후유증을 입은 인원 수**다.
##
## 순서가 규칙이다 — **세계가 먼저 돌고 내 원정이 그 위에 얹힌다.**
## 뒤집으면 내가 만든 관계가 이번 세계 사건의 목격자 선택에 끼어든다.
func apply_to(world: NpcWorld) -> int:
	if world == null or not world.is_ready() or went.is_empty():
		return 0

	# 내가 던전에 있는 동안 세계도 돈다. **내 원정보다 이쪽이 훨씬 크다.**
	world.tick(events)

	var resolver := RelationResolver.new(world.registry, world.graph, world.ledger)
	_bind_together(resolver)

	if not downed:
		return 0
	for person in went:
		_shock(world, person)
	return went.size()


## 같이 간 사람들을 엮는다. **쌍마다 한 번씩** — 셋이 갔으면 세 쌍이다.
##
## 한 사람을 행위자로 두고 나머지를 대상으로 묶으면 **대상끼리는 안 엮인다.**
## 스쿼드 정원이 셋이라(GuildBalance) 쌍이 많아야 셋이고, 그 값이면 제곱이 싸다.
func _bind_together(resolver: RelationResolver) -> void:
	for one in went.size():
		for other in range(one + 1, went.size()):
			resolver.resolve(TOGETHER, went[one], PackedInt32Array([went[other]]), stayed)


## 한 사람의 후유증. **나가는 선의 호감만 내린다.**
##
## 유대는 안 건드린다 — 엮인 정도가 줄어드는 것이 아니라 **보는 눈이 나빠지는** 것이다.
## 크기는 `ExpeditionAftermath.shock_for` 가 성향에서 뽑는다.
func _shock(world: NpcWorld, person: int) -> void:
	var damage := ExpeditionAftermath.shock_for(world.registry.traits_of(person))
	if damage <= 0:
		return
	var cause := world.ledger.record(RelationEvent.Kind.AFTERMATH, person, PackedInt32Array([tick]))
	for other in world.graph.targets_of(person):
		world.graph.adjust(person, other, -damage, 0, RelationKind.Kind.NONE, cause)


# ---------------------------------------------------------------- 저장


func to_dict() -> Dictionary:
	return {
		"events": events,
		"went": Array(went),
		"stayed": Array(stayed),
		"downed": downed,
		"tick": tick,
	}


## 사전에서 되돌린다. **같이 간 사람이 없으면 틱이 아니다** — null 을 돌려준다.
##
## 그 틱은 애초에 기록되지 않는다(`ExpeditionAftermath.apply`). 손으로 고친 파일이
## 빈 틱을 넣어도 되감기가 그것 때문에 어긋나지 않게 여기서 걸러 낸다.
static func from_dict(data: Dictionary) -> WorldStep:
	var went_people := _ints_of(data.get("went", []))
	if went_people.is_empty():
		return null
	return WorldStep.new(
		int(data.get("events", 0)),
		went_people,
		_ints_of(data.get("stayed", [])),
		bool(data.get("downed", false)),
		int(data.get("tick", 0))
	)


## JSON 에서 온 배열을 정수 배열로. **JSON 의 수는 전부 실수로 돌아온다.**
static func _ints_of(value: Variant) -> PackedInt32Array:
	var found := PackedInt32Array()
	if not (value is Array):
		return found
	for item in value as Array:
		if item is float or item is int:
			found.append(int(item))
	return found
