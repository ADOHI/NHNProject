extends SceneTree
## V5 하한을 못 맞추는 판이 **얼마나 모자라고, 채우려면 무엇을 내주나.**
##
##     godot --headless --path . -s res://tools/survey_dead_end_floor.gd
##
## 이 자가 내는 표는 §17.36 이다.
##
## ## 왜 재나
##
## §17.32.4 가 "벌집 5/40, 먼 출구 20/40 이 하한 아래"라고만 적었다. **그것만으로는
## 값을 매길 수 없다** — 한 방 모자란 것과 다섯 방 모자란 것은 다른 문제다.
##
## 그리고 채우는 대가가 **보스 차수**다. `_carve_dead_ends` 는 두 경로와 **보상 방에
## 붙은 간선 전부**를 지킨다(`DungeonGenerator` 주석). 그 보호를 풀면 하한은 채워지지만
## 노출(P3, 차수 4 이상)이 깎인다 — 실측에서 보스 차수가 4 에서 2 로 떨어진 전례가 있다.
##
## **그래서 「모자란 양」과 「보스 차수」를 같은 줄에 놓는다.** 그것이 이 거래의 가격표다.

const _RUNS := 8


func _initialize() -> void:
	print("== V5 하한을 못 맞추는 판과 그 대가 (성격마다 크기 1~5 x 시드 %d) ==" % _RUNS)
	print("")
	print(
		(
			"%-10s %6s %8s %9s %10s %10s %10s"
			% ["성격", "하한", "미달판", "평균모자람", "최대모자람", "미달판 보스차수", "전체 보스차수"]
		)
	)
	for character in DungeonCatalog.count():
		_report(character)
	print("")
	print("모자람 : 하한이 요구하는 막다른 방 수에서 실제로 몇 개가 비는가 (**방 수**)")
	print("보스차수: 채우려면 보상 방 간선을 끊어야 한다. P3 목표는 **4 이상**")
	quit()


func _report(character: int) -> void:
	var short_boards := 0
	var boards := 0
	var shortfall_total := 0
	var shortfall_max := 0
	var boss_short := 0.0
	var boss_all := 0.0
	var floor_ratio := 0.0

	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		for run in _RUNS:
			var params := SampleDungeons.params_for_size(size, character)
			floor_ratio = params.dead_end_ratio_min
			var plan := DungeonGenerator.new(run * 977 + character, params).generate()
			var graph := plan.build()

			var rooms := plan.room_ids().size()
			var dead := 0
			for id in plan.room_ids():
				if graph.is_dead_end(id):
					dead += 1

			var target := int(ceil(float(rooms) * params.dead_end_ratio_min))
			var missing := maxi(0, target - dead)
			var boss := _boss_degree(plan, graph)

			boards += 1
			boss_all += boss
			if missing > 0:
				short_boards += 1
				shortfall_total += missing
				shortfall_max = maxi(shortfall_max, missing)
				boss_short += boss

	print(
		(
			"%-10s %6.2f %8s %9.1f %10d %10.2f %10.2f"
			% [
				DungeonCatalog.name_of(character),
				floor_ratio,
				"%d/%d" % [short_boards, boards],
				float(shortfall_total) / maxf(float(short_boards), 1.0),
				shortfall_max,
				boss_short / maxf(float(short_boards), 1.0),
				boss_all / float(boards),
			]
		)
	)


## 보스 방의 연결 수. 보스가 없으면 0.
func _boss_degree(plan: DungeonBlueprint, graph: DungeonGraph) -> float:
	var boss := DungeonRoutes.boss_of(plan)
	return 0.0 if boss.is_empty() else float(graph.neighbors_of(boss).size())
