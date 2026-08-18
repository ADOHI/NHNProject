extends GutTest
## 「막다른 방」이 **한 가지 뜻으로만** 쓰이는지 지킨다.
##
## 이 판정은 한때 다섯 곳에 각각 적혀 있었다 — 방 종류를 정하는 곳 · 렉카 기사 ·
## 테스트 · 벤치 · 계측 도구. **그중 렉카만 `== 1` 이었고 나머지는 `<= 1` 이었다.**
## 200 판에서 결과는 같았지만 그건 **지금 우연히 같은 것**이지 같은 것을 말한 것이 아니다.
##
## **위험한 방향이 조용한 쪽이다.** 런타임 정의가 바뀌면 테스트는 제가 적어 둔 옛 정의로
## 계속 통과하고, 벤치는 게임과 다른 수를 조용히 보고한다. **아무 데도 안 빨개진다.**
##
## ## 합쳐진 것은 용어이고, 남은 것은 주장이다
##
## 여기서 지키는 것은 **「무엇이 막다른 방인가」** 하나다.
## **「비율이 적정한가」는 `test_dungeon_generator.gd` 가 자기 숫자로 단언한다.**
## 그쪽이 `is_dead_end()` 로 세되 단언은 스스로 하는 이유는, 런타임 함수에 판정까지
## 맡기면 **"생성기가 스스로 옳다고 말하는지"** 를 묻는 빈 테스트가 되기 때문이다.

const GeneratorScript := preload("res://src/core/dungeon/dungeon_generator.gd")
const MetricsScript := preload("res://tools/dungeon_metrics.gd")

const _SEEDS := 6


func test_a_room_with_one_corridor_or_none_is_a_dead_end() -> void:
	var plan := DungeonBlueprint.new()
	plan.add_room("hub", "허브")
	plan.add_room("leaf", "잎")
	plan.add_room("middle", "가운데")
	plan.add_room("lonely", "외딴방")
	plan.connect_rooms("hub", "leaf")
	plan.connect_rooms("hub", "middle")
	plan.connect_rooms("middle", "leaf")

	var graph := plan.build()
	assert_true(graph.is_dead_end("lonely"), "통로가 없는 방이 막다른 방이 아니라고 나온다")
	assert_false(graph.is_dead_end("hub"), "통로가 둘인 방을 막다른 방이라고 한다")
	assert_false(graph.is_dead_end("middle"), "통로가 둘인 방을 막다른 방이라고 한다")


func test_a_room_with_exactly_one_corridor_is_a_dead_end() -> void:
	var plan := DungeonBlueprint.new()
	plan.add_room("hall", "복도")
	plan.add_room("closet", "벽장")
	plan.connect_rooms("hall", "closet")

	var graph := plan.build()
	assert_true(graph.is_dead_end("closet"), "통로가 하나인 방이 막다른 방이 아니라고 나온다")
	assert_true(graph.is_dead_end("hall"), "통로가 하나인 방이 막다른 방이 아니라고 나온다")


func test_asking_about_a_room_that_is_not_there_is_loud() -> void:
	# 조용히 false 를 돌려주면 오타 하나가 "막다른 방이 하나도 없다"로 나타난다.
	var graph := DungeonBlueprint.new().add_room("only", "하나").build()
	assert_false(graph.is_dead_end("nowhere"), "없는 방을 막다른 방이라고 한다")
	assert_push_error("존재하지 않는 방입니다: nowhere")


## **같은 판정이 두 곳에 있다.** 게임은 `DungeonGraph` 로 세고, 계측 도구는 색인으로 센다
## (설계안 프로토타입에는 그래프가 없어서다). **두 수가 같아야 한다.**
func test_the_graph_and_the_metrics_count_the_same_dead_ends() -> void:
	for seed_value in _SEEDS:
		for rooms in [12, 32, 52]:
			var params := DungeonGenerator.Params.new()
			params.room_count = rooms
			var plan: DungeonBlueprint = GeneratorScript.new(seed_value, params).generate()
			var graph := plan.build()

			var by_graph := 0
			for id in plan.room_ids():
				if graph.is_dead_end(id):
					by_graph += 1

			var measured: Dictionary = MetricsScript.measure(MetricsScript.from_blueprint(plan))
			var by_index := int(
				round(float(measured["deg1_pct"]) * float(measured["rooms"]) / 100.0)
			)
			assert_eq(
				by_graph, by_index, "시드 %d 방 %d 에서 그래프와 계측기가 막다른 방을 다르게 센다" % [seed_value, rooms]
			)
