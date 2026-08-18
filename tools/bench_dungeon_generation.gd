extends SceneTree
## 던전 생성의 속도와 판의 성질을 실측하는 개발 도구.
##
## 웹은 단일 스레드라 생성이 한 프레임 안에 끝나지 않으면 슬라이더를 움직일 때
## 화면이 멈칫한다 (docs/design/01-constraints.md §1.2). 눈으로는 그 경계를
## 판단할 수 없어서 숫자로 잰다.
##
## PoissonDiskSampler._DENSITY 를 다시 잡을 때도 여기서 나온 실제 방 개수를 본다.
##
##   godot --headless --path . -s res://tools/bench_dungeon_generation.gd

## 크기마다 몇 판을 만들어 볼지. 한 판만 재면 편차에 속는다.
const _RUNS := 30


func _initialize() -> void:
	print("size | rooms(min/avg/max) | edges | dead-end | msec(avg/max) | routes(avg/max)")
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_measure(size)
	quit()


func _measure(size: int) -> void:
	var rooms_total := 0
	var rooms_min := 9999
	var rooms_max := 0
	var edges_total := 0
	var dead_ends := 0
	var elapsed_total := 0.0
	var elapsed_max := 0.0
	# **화면이 판마다 한 번 더 내는 값이다.** DungeonBoard.setup() 이 두 길을 여기서 잰다.
	# 생성 시간에 얹히는 몫이라 같이 재야 "판 하나가 한 프레임에 들어가나"의 답이 맞는다.
	var routes_total := 0.0
	var routes_max := 0.0

	for run in _RUNS:
		var started := Time.get_ticks_usec()
		var run_state := SampleDungeons.create_run(run * 7919 + size, size)
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		elapsed_total += elapsed
		elapsed_max = maxf(elapsed_max, elapsed)

		var blueprint := run_state.blueprint
		var count := blueprint.room_ids().size()
		rooms_total += count
		rooms_min = mini(rooms_min, count)
		rooms_max = maxi(rooms_max, count)
		edges_total += blueprint.connections().size()
		dead_ends += _dead_ends(run_state.graph, blueprint)

		var routes_started := Time.get_ticks_usec()
		var routes := DungeonRoutes.to_boss(blueprint)
		var routes_elapsed := float(Time.get_ticks_usec() - routes_started) / 1000.0
		routes_total += routes_elapsed
		routes_max = maxf(routes_max, routes_elapsed)
		# 결과를 안 쓰면 최적화로 사라질 수 있다.
		if routes.is_empty():
			push_error("두 길 계산이 빈 사전을 냈다")

	print(
		(
			"%d | %d/%.1f/%d | %.1f | %.0f%% | %.2f/%.2f | %.3f/%.3f"
			% [
				size,
				rooms_min,
				float(rooms_total) / float(_RUNS),
				rooms_max,
				float(edges_total) / float(_RUNS),
				100.0 * float(dead_ends) / float(rooms_total),
				elapsed_total / float(_RUNS),
				elapsed_max,
				routes_total / float(_RUNS),
				routes_max,
			]
		)
	)


func _dead_ends(graph: DungeonGraph, blueprint: DungeonBlueprint) -> int:
	var count := 0
	for id in blueprint.room_ids():
		if graph.is_dead_end(id):
			count += 1
	return count
