extends SceneTree
## 판을 오래 돌리면 세계가 어떻게 되나.
##
## docs/design/24-npc-relations.md §24.30, docs/design/02-overview.md §2.6.1.5.
##
## **「오래 돌리면 무너진다」는 이런 걸로만 보인다.** 한 판만 보면 안 보인다.
## 그래서 원정을 수십 번 돌리며 같은 표를 되풀이해 찍는다.
##
##   godot --headless --path . -s res://tools/survey_world_tick.gd

const _POPULATION := 3000
const _SEED := 20260808

## 몇 판을 돌리나. 데모 한 사이클이 스물 남짓이라 그 서너 배까지 본다.
const _RUNS := 400

## 표를 찍는 판 번호.
const _MARKS := [0, 20, 80, 200, 400]

## 아는 얼굴 비율을 잴 때 굴리는 조우 수.
##
## **200 으로는 사건 비율을 고를 수 없었다.** 비율이 10% 언저리라 200회의 표준오차가
## 2.1%p 이고, 후보 둘이 11% 와 15% 로 갈렸을 때 그것이 차이인지 흔들림인지 못 갈랐다.
## 1000회면 0.9%p 다. 조우 하나가 싸서 (연줄 훑기 한 번) 늘려도 도구가 몇 초다.
const _ENCOUNTERS := 1000

## 쓰러지는 비율. **실패가 흔한 게임이다** — 성공만 돌리면 후유증을 못 잰다.
const _DOWN_RATE := 0.35


func _initialize() -> void:
	print("== 판을 돌린다 (인구 %d, 시드 %d, 쓰러짐 %.0f%%) ==" % [_POPULATION, _SEED, _DOWN_RATE * 100.0])
	print("후유증 기본 크기 %d — 미정값이다 (설계 2.6.1.5)" % ExpeditionAftermath.SHOCK)
	_report_resilience()

	var world := NpcWorld.create(_SEED, _POPULATION)
	var guild := Guild.create_starting(_SEED, "새벽 길드", world)
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED

	print(
		(
			"\n%-5s %7s %6s %6s %6s %8s %8s %8s %8s %8s"
			% ["판", "관계", "중위", "90%", "최대", "세계호감", "대원호감", "외톨이", "한덩어리", "아는얼굴"]
		)
	)
	_row(world, guild, 0)
	for run in _RUNS:
		_settle(guild, rng, run)
		if _MARKS.has(run + 1):
			_row(world, guild, run + 1)
	_report_islands(world)
	quit()


## 견딤이 사람을 가르나. **손잡이가 결과와 같아 보이면 안 된다** (설계 24.29.3 의 원칙).
func _report_resilience() -> void:
	var world := NpcWorld.create(_SEED, 600)
	var counts := {}
	for person in world.registry.size():
		var hit := ExpeditionAftermath.shock_for(world.registry.traits_of(person))
		counts[hit] = int(counts.get(hit, 0)) + 1
	var keys := counts.keys()
	keys.sort()
	var text := PackedStringArray()
	for key in keys:
		text.append(
			"%d:%.0f%%" % [int(key), 100.0 * float(counts[key]) / float(world.registry.size())]
		)
	print("실제로 입는 크기의 분포   %s" % " ".join(text))


func _settle(guild: Guild, rng: RandomNumberGenerator, run: int) -> void:
	var everyone := guild.member_ids()
	var went: Array[String] = []
	for slot in mini(guild.squad_capacity(), everyone.size()):
		went.append(everyone[(run + slot) % everyone.size()])
	var stayed: Array[String] = []
	for member_id in everyone:
		if not went.has(member_id):
			stayed.append(member_id)

	var outcome := (
		ExpeditionReport.Outcome.DOWNED
		if rng.randf() < _DOWN_RATE
		else ExpeditionReport.Outcome.ESCAPED
	)
	var gate := Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED + run)
	GuildSettlement.apply(
		guild, ExpeditionReport.new("exp_%d" % run, gate, outcome, 5, went, stayed), _SEED + run
	)


func _row(world: NpcWorld, guild: Guild, run: int) -> void:
	var graph := world.graph
	var ours := PackedInt32Array()
	for member in guild.members:
		ours.append(member.person)
	var degrees := PackedInt32Array()
	var alone := 0
	for person in graph.person_count():
		var degree := graph.degree_of(person)
		degrees.append(degree)
		if degree == 0:
			alone += 1
	degrees.sort()

	var total := 0
	for slot in graph.size():
		total += graph.slot_affinity(slot)

	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var met := 0
	for trial in _ENCOUNTERS:
		if not RivalSquad.draw(world, rng, ours).familiar_to(ours).is_empty():
			met += 1

	print(
		(
			"%-5d %7d %6d %6d %6d %8.1f %8.1f %7.1f%% %7.1f%% %7.1f%%"
			% [
				run,
				graph.size(),
				degrees[degrees.size() / 2],
				degrees[degrees.size() * 9 / 10],
				degrees[degrees.size() - 1],
				float(total) / maxf(float(graph.size()), 1.0),
				_squad_affinity(graph, ours),
				100.0 * float(alone) / float(graph.person_count()),
				100.0 * float(_largest_share(graph)),
				100.0 * float(met) / float(_ENCOUNTERS),
			]
		)
	)


## 대원의 **나가는** 호감 평균. **후유증이 보이는 유일한 자리다** (§24.30.5) —
## 3000명 중 다섯만 겪으므로 세계 평균으로는 안 보인다.
##
## 나가는 쪽인 이유는 후유증이 **그가 남을 보던 눈**을 나쁘게 하기 때문이다
## (`ExpeditionAftermath`). 남이 그를 보는 눈은 안 바뀐다.
##
## **§24.30.5 가 「사용자가 SHOCK 을 정할 때 볼 숫자」라고 적어 놓고 도구가 안 냈다.**
func _squad_affinity(graph: RelationGraph, ours: PackedInt32Array) -> float:
	var total := 0
	var seen := 0
	for person in ours:
		for other in graph.targets_of(person):
			total += graph.affinity(person, other)
			seen += 1
	return float(total) / maxf(float(seen), 1.0)


## 가장 큰 덩어리에 든 사람의 비율. **이것이 1 에 닿으면 세계가 한 덩어리다.**
func _largest_share(graph: RelationGraph) -> float:
	var parent := PackedInt32Array()
	for person in graph.person_count():
		parent.append(person)
	for slot in graph.size():
		_union(parent, graph.slot_from(slot), graph.slot_to(slot))
	var sizes := {}
	var biggest := 0
	for person in graph.person_count():
		if graph.degree_of(person) == 0:
			continue
		var root := _root(parent, person)
		sizes[root] = int(sizes.get(root, 0)) + 1
		biggest = maxi(biggest, int(sizes[root]))
	return float(biggest) / float(graph.person_count())


## 섬이 생기나. **관계도가 끊기면 세계가 여러 조각이 된 것이다.**
func _report_islands(world: NpcWorld) -> void:
	var graph := world.graph
	var parent := PackedInt32Array()
	for person in graph.person_count():
		parent.append(person)
	for slot in graph.size():
		_union(parent, graph.slot_from(slot), graph.slot_to(slot))

	var sizes := {}
	for person in graph.person_count():
		if graph.degree_of(person) == 0:
			continue
		var root := _root(parent, person)
		sizes[root] = int(sizes.get(root, 0)) + 1
	var counts := PackedInt32Array()
	for root in sizes:
		counts.append(int(sizes[root]))
	counts.sort()
	counts.reverse()

	print("\n== 관계도가 끊기나 (판 %d 뒤) ==" % _RUNS)
	print("%-26s %d" % ["덩어리 수 (외톨이 제외)", counts.size()])
	if counts.is_empty():
		return
	print("%-26s %d명" % ["가장 큰 덩어리", counts[0]])
	print(
		(
			"%-26s %.1f%%"
			% [
				"그 안에 든 사람",
				100.0 * float(counts[0]) / float(graph.person_count()),
			]
		)
	)
	print("%-26s %d" % ["둘째 덩어리", counts[1] if counts.size() > 1 else 0])


func _root(parent: PackedInt32Array, person: int) -> int:
	var found := person
	while parent[found] != found:
		parent[found] = parent[parent[found]]
		found = parent[found]
	return found


func _union(parent: PackedInt32Array, one: int, other: int) -> void:
	var left := _root(parent, one)
	var right := _root(parent, other)
	if left != right:
		parent[left] = right
