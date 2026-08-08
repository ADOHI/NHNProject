extends SceneTree
## 실제 판을 굴려서 렉카 게시글 프롬프트의 **사용자 메시지**를 뽑아낸다.
##
##     godot --headless --path . -s res://tools/dump_rekka_prompts.gd
##
## 결과는 `user://rekka_prompts.json` 이고 경로를 표준 출력에 찍는다.
## 그 파일을 언어 모델에 넣은 산출이 `docs/design/samples/rekka/` 의 표본이다.
##
## ## 왜 손으로 안 적는가
##
## 5차 표본의 "판이 이미 아는 것" 은 손으로 적은 것이었다
## (docs/design/19-rekka-voice.md §19.A.7). 손으로 적으면 표본은 좋아지고
## **수집기가 실제로 그런 줄을 뽑아내는지는 영영 검증되지 않는다.**
## 여기서 나가는 모든 줄은 `RekkaContext` 가 `DungeonGraph` 와 `EventLog` 에서
## 읽어 만든 것이다.
##
## ## 이 파일은 턴 시스템이 아니다
##
## 계획/행동 페이즈와 동시 해결은 구현 2단계에서 붙는다
## (docs/design/16-build-order.md §16.4). 여기 있는 것은 표본을 뽑기 위한
## **최소한의 몰이꾼**이고, 게임 코드가 아니라 `tools/` 에 있다.
## 규칙은 05-rules.md 가 아니라 "사건 종류가 골고루 나온다" 하나뿐이다.

## 표본을 뽑을 판들. 시드를 적어 두지 않으면 다시 못 만든다 (§17.7).
##
## 두 판인 이유는 한 판이 열몇 턴이면 끝나기 때문이다. 표본은 이어서 읽었을 때
## 기계 같은지를 보는 것이므로 스무 편은 있어야 한다.
## 판이 갈리면 방 이름과 지형이 통째로 바뀌어서 수집기도 함께 검증된다.
const SEEDS: Array[int] = [20260808, 771]
const SIZE := 5
const TURNS := 16

## 아무 일도 없는 턴이 이만큼 이어지면 그 판은 끝난 것으로 본다.
##
## 조용한 턴도 기사가 나가야 하지만(§19.7.1) 여섯 턴을 연달아 조용하게 두면
## 표본의 뒤쪽이 전부 같은 입력이 된다.
const QUIET_LIMIT := 1

const OUT_PATH := "user://rekka_prompts.json"

var _seed := 0

var _run: DungeonRun
var _rng := RandomNumberGenerator.new()
var _walkers: Array[Actor] = []
var _targets: Dictionary = {}
var _hauls: Dictionary = {}
var _searched: Dictionary = {}
var _retired: Dictionary = {}
var _turn_events: Array[GameEvent] = []


func _initialize() -> void:
	var dumped: Array = []
	for seed_value in SEEDS:
		dumped.append_array(_play(seed_value))
	_write(dumped)
	quit(0)


## 판 하나를 끝까지 굴리고 턴마다 사용자 메시지를 남긴다.
func _play(seed_value: int) -> Array:
	_seed = seed_value
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_run = SampleDungeons.create_run(seed_value, SIZE)
	_walkers = []
	_targets = {}
	_hauls = {}
	_searched = {}
	_retired = {}
	_add_walkers()

	var dumped: Array = []
	var quiet := 0
	for turn in range(1, TURNS + 1):
		_run.turn = turn
		_turn_events = []
		_advance(turn)
		for event in _turn_events:
			_run.event_log.record(event)
		quiet = quiet + 1 if _turn_events.is_empty() else 0
		if quiet > QUIET_LIMIT:
			break
		dumped.append(_message_for(turn))
		# **스쿼드가 나가면 판이 끝난다.** 계획 페이즈가 없는 턴의 기사는
		# 플레이어가 아무것도 결정할 수 없는 글이다. 심사자 둘이 각각
		# "24편 중 10편이 내가 이미 던전 밖인 시점의 방송" 을 최대 결함으로 짚었다.
		if _retired.has(_run.player.id):
			break
	return dumped


## 경쟁자를 더 푼다. 하나만으로는 조우도 관계도 생기지 않는다.
##
## 이름은 `sample_dungeons.gd` 의 `칼날의 요한` 과 같은 결로 짓는다.
func _add_walkers() -> void:
	var graph := _run.graph
	var rooms := graph.room_ids()
	var recruits := [
		Actor.new("mina", "두더지 미나", Actor.Kind.NPC_EXPLORER, 3, 2),
		Actor.new("bern", "웃는 베른", Actor.Kind.NPC_EXPLORER, 5, 1),
		Actor.new("rahk", "장부의 라흐", Actor.Kind.NPC_EXPLORER, 4, 2),
		Actor.new("kai", "그림자 카이", Actor.Kind.NPC_EXPLORER, 3, 3),
	]
	var index := 0
	for actor in recruits:
		graph.place_actor(actor, rooms[(rooms.size() / 2 + index * 4) % rooms.size()])
		index += 1

	for room_id in rooms:
		for actor in graph.get_room(room_id).occupants():
			if actor.kind == Actor.Kind.NPC_EXPLORER:
				_walkers.append(actor)
	_walkers.append(_run.player)
	for actor in _walkers:
		_hauls[actor.id] = 0
		_targets[actor.id] = _next_target(actor)


## 한 턴을 굴린다. 옮기고, 뒤지고, 마주친 것을 처리한다.
func _advance(turn: int) -> void:
	for actor in _walkers:
		if _retired.has(actor.id):
			continue
		var here := _run.graph.find_actor_room(actor)
		if here.is_empty():
			continue
		if _try_room_business(turn, actor, here):
			continue
		_step(turn, actor, here)
	_resolve_meetings(turn)


## 그 방에서 할 일이 있으면 한다. 했으면 이번 턴은 안 움직인다.
func _try_room_business(turn: int, actor: Actor, here: String) -> bool:
	var room := _run.graph.get_room(here)
	# 빈손으로 나가는 것도 탈출이다. 수확을 조건으로 걸면 허탕 친 자가
	# 출구에 눌러앉아 판이 끝나지 않는다.
	if room.kind == Room.Kind.EXIT:
		_record(turn, GameEvent.Kind.ESCAPED, actor, room, _hauls[actor.id])
		_run.graph.remove_actor(actor)
		_retired[actor.id] = true
		return true
	if room.kind != Room.Kind.TREASURE or _searched.has(here):
		return false
	_searched[here] = true
	var value := _rng.randi_range(0, 13)
	_record(turn, GameEvent.Kind.SEARCHED, actor, room, value)
	if value > 0:
		_record(turn, GameEvent.Kind.ACQUIRED, actor, room, value)
		_hauls[actor.id] = _hauls[actor.id] + value
		_targets[actor.id] = _next_target(actor)
	return true


## 목표를 향해 한 칸 간다. 못 가면 목표를 다시 고른다.
func _step(turn: int, actor: Actor, here: String) -> void:
	var target: String = _targets.get(actor.id, "")
	if target.is_empty() or target == here:
		_targets[actor.id] = _next_target(actor)
		target = _targets[actor.id]
	var distance := _hops_from(target)
	var best := ""
	var best_cost: int = distance.get(here, 9999)
	for neighbor_id in _run.graph.traversable_neighbors(here, actor.agility):
		var cost: int = distance.get(neighbor_id, 9999)
		if cost < best_cost:
			best = neighbor_id
			best_cost = cost
	if best.is_empty():
		# 목표에 가까워지는 이웃이 없으면 아무 데나 한 칸 간다.
		# 제자리에 서 있으면 그 턴이 통째로 같은 문장으로 반복된다.
		var open := _run.graph.traversable_neighbors(here, actor.agility)
		if open.is_empty():
			return
		best = open[_rng.randi() % open.size()]
		_targets[actor.id] = _next_target(actor)
	if not _run.graph.move_actor(actor, best):
		return
	_record(turn, GameEvent.Kind.MOVED, actor, _run.graph.get_room(best))


## 한 방에 둘 이상이 모였을 때. 힘이 벌어지면 붙고, 비슷하면 거래한다.
func _resolve_meetings(turn: int) -> void:
	for room_id in _run.graph.room_ids():
		var room := _run.graph.get_room(room_id)
		var present: Array[Actor] = []
		for actor in room.occupants():
			if actor.is_mobile():
				present.append(actor)
		if present.size() < 2:
			continue
		var first := present[0]
		var second := present[1]
		var others: Array[String] = [second.id]
		# 힘이 크게 벌어질 때만 눕는다. 마주칠 때마다 하나씩 빠지면
		# 열 턴이면 판이 비고 표본의 뒤쪽이 전부 조용한 턴이 된다.
		var gap: int = absi(first.threat - second.threat)
		if gap >= 4:
			_record(turn, GameEvent.Kind.FOUGHT, first, room, present.size(), others)
			var loser: Actor = second if first.threat > second.threat else first
			var winner: Actor = first if loser == second else second
			var by: Array[String] = [winner.id]
			_record(turn, GameEvent.Kind.DOWNED, loser, room, 1, by)
			_run.graph.remove_actor(loser)
			_retired[loser.id] = true
		elif _rng.randf() < 0.5:
			# 오간 값어치는 양쪽 장부에 실제로 반영한다. 안 하면 한몫을 받은 자가
			# 다음 턴에 빈손으로 보도되어 게시글끼리 정면 충돌한다.
			var traded := _rng.randi_range(1, 6)
			_record(turn, GameEvent.Kind.NEGOTIATED, first, room, traded, others)
			_record(turn, GameEvent.Kind.ACQUIRED, second, room, traded)
			_hauls[second.id] = int(_hauls.get(second.id, 0)) + traded
		else:
			_record(turn, GameEvent.Kind.ENCOUNTERED, first, room, present.size(), others)
			_record(turn, GameEvent.Kind.FLED, second, room, present.size(), [first.id])
			_targets[second.id] = _next_target(second)


func _record(
	turn: int,
	kind: GameEvent.Kind,
	actor: Actor,
	room: Room,
	magnitude: int = 0,
	related: Array[String] = [] as Array[String]
) -> void:
	_turn_events.append(GameEvent.new(turn, kind, actor, room, magnitude, related))


## 다음 목표 방. 아직 안 뒤진 귀중품 방이 있으면 그쪽, 없으면 탈출구.
func _next_target(actor: Actor) -> String:
	var here := _run.graph.find_actor_room(actor)
	var reach := _hops_from(here) if not here.is_empty() else {}
	# 민첩으로 못 오르는 방을 목표로 잡으면 영영 도착하지 못하고 제자리를 돈다.
	var costs := _run.graph.required_agility_from(here) if not here.is_empty() else {}
	var best := ""
	var best_cost := 9999
	for room_id in _run.graph.room_ids():
		var room := _run.graph.get_room(room_id)
		var wanted := room.kind == Room.Kind.TREASURE and not _searched.has(room_id)
		if _hauls.get(actor.id, 0) > 6:
			wanted = room.kind == Room.Kind.EXIT
		if not wanted or int(costs.get(room_id, 99)) > actor.agility:
			continue
		var cost: int = reach.get(room_id, 9999)
		if cost < best_cost:
			best = room_id
			best_cost = cost
	if best.is_empty():
		for room_id in _run.graph.room_ids():
			if _run.graph.get_room(room_id).kind == Room.Kind.EXIT:
				return room_id
	return best


func _hops_from(start_id: String) -> Dictionary:
	if start_id.is_empty() or not _run.graph.has_room(start_id):
		return {}
	var distance := {start_id: 0}
	var queue: Array[String] = [start_id]
	var head := 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		for neighbor_id in _run.graph.neighbors_of(current):
			if distance.has(neighbor_id):
				continue
			distance[neighbor_id] = distance[current] + 1
			queue.append(neighbor_id)
	return distance


func _message_for(turn: int) -> Dictionary:
	var picked := RekkaPrompt.pick_events(_turn_events)
	var names := RekkaContext.name_index(_run)
	var context := RekkaContext.for_turn(_run, picked)
	var rooms: Array[String] = []
	for room_id in _run.graph.room_ids():
		rooms.append(_run.graph.get_room(room_id).display_name)
	return {
		"seed": _seed,
		"turn": turn,
		"user": RekkaPrompt.serialize_turn(picked, context, names),
		"events": _turn_events.size(),
		# 후처리가 방 이름 띄어쓰기를 되돌리는 데 쓴다 (RekkaPost.normalize_names).
		"rooms": rooms,
	}


func _write(dumped: Array) -> void:
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"seeds": SEEDS, "size": SIZE, "turns": dumped}, "\t"))
	file.close()
	print(ProjectSettings.globalize_path(OUT_PATH))
