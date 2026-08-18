extends SceneTree
## 스쿼드 민첩이 달라지면 **판이 얼마나 열리고 닫히나.**
##
##     godot --headless --path . -s res://tools/survey_agility_reach.gd
##
## 이 자가 내는 표는 §17.38 이다.
##
## ## 왜 이제 와서 재나
##
## 인물이 여덟 살부터 여든 살까지 생겼다. **민첩은 대원들의 평균**이므로
## (docs/design/14-squad.md §14.3.1) **누구를 데려가느냐로 민첩이 흔들린다.**
##
## 그런데 §17 의 값들은 **민첩 2 한 값**에서 나왔다 —
## `SampleDungeons.SQUAD_AGILITY`(자리값), `dungeon_metrics.measure()` 의 `reach_pct`
## (2026-08-10 부터 인자다. 기본값이 그 자리값을 가리킨다), §17.12.6 의
## "민첩 2 로 열리는 방 70~80%".
## **민첩 2 는 편성이 생기기 전의 자리값**이라 그 표는 **한 스쿼드의 값**이다.
## **이 자만 다섯 민첩을 다 훑는다.**
##
## **판이 민첩에 얼마나 민감한가**를 알아야 "어린 대원을 데려가면 판이 닫히나"에 답한다.
## 그리고 민감하면 **성격마다 다르게 민감할 수 있다** — 수직 회랑이 특히 그렇다.

const _RUNS := 12
const _AGILITIES: Array[int] = [0, 1, 2, 3, 4]


func _initialize() -> void:
	for size in [3, 5]:
		print("")
		print("== 크기 %d — 민첩마다 열리는 방 %% (성격마다 %d 판) ==" % [size, _RUNS])
		var header := "%-10s" % "성격"
		for agility in _AGILITIES:
			header += "%9s" % ("민첩 %d" % agility)
		print(header + "   민첩2->1 손실")
		for character in DungeonCatalog.count():
			_report(size, character)
	print("")
	print("민첩 0 이어도 탈출구에는 닿는다 (V2). **갇히지는 않는다** — 못 가는 것은 안쪽이다")
	print("§17.12.6 의 「민첩 2 로 열리는 방 70~80%」는 **민첩 2 한 값만** 본 목표다")
	quit()


func _report(size: int, character: int) -> void:
	var opened := {}
	for agility in _AGILITIES:
		opened[agility] = 0.0
	var rooms_total := 0.0

	for run in _RUNS:
		var params := SampleDungeons.params_for_size(size, character)
		var plan := DungeonGenerator.new(run * 977 + character, params).generate()
		var graph := plan.build()
		var entrance := DungeonRoutes.entrance_of(plan)
		var costs := graph.required_agility_from(entrance)

		var ids := plan.room_ids()
		rooms_total += float(ids.size())
		for agility in _AGILITIES:
			for id in ids:
				# 닿을 수 없는 방은 costs 에 없다. 큰 값으로 쳐서 안 세도록 한다.
				if int(costs.get(id, 99)) <= agility:
					opened[agility] += 1.0

	var line := "%-10s" % DungeonCatalog.name_of(character)
	for agility in _AGILITIES:
		line += "%8.1f%%" % (100.0 * float(opened[agility]) / maxf(rooms_total, 1.0))
	var at_two := 100.0 * float(opened[2]) / maxf(rooms_total, 1.0)
	var at_one := 100.0 * float(opened[1]) / maxf(rooms_total, 1.0)
	print(line + "%12.1f%%p" % (at_two - at_one))
