extends SceneTree
## 크기 사다리를 통째로 훑는다 — **화면이 적은 수와 판이 내는 수가 같은가.**
##
##     godot --headless --path . -s res://tools/survey_size_ladder.gd
##
## 한 번 어긋난 적이 있어서 만든 자다. 측정과 화면은 방 50 을 향해 맞춰졌는데
## 생성만 32 에 머물러 있었고, **아무도 둘을 나란히 놓아 보지 않았다**
## (docs/design/17-dungeon-generation.md §17.25.1).
##
## **「재는 값이 상한보다 작으면 상한을 잰 것이다」** — 이 자가 그것을 본다.
## 슬라이더가 적는 수(`room_estimate`)는 생성기에게 준 **목표**이고,
## 푸아송 디스크 샘플링은 그 목표를 정확히 맞추지 못한다.
## 목표와 결과를 나란히 두지 않으면 화면이 조용히 거짓말한다.
##
## 규모 등급까지 함께 세는 이유는, 방 개수가 바뀌면 **등급 경계도 같이 봐야** 하기
## 때문이다. 사다리만 올리고 경계를 그대로 두면 위쪽 등급이 붙어 버린다.
##
## 이 자가 내는 표는 §17.29.2 · §17.30.3 · §17.27.7 이다.

const _SEEDS := 20


func _initialize() -> void:
	print("크기 사다리 — 화면이 적는 수와 판이 내는 수 (성격 %d x 시드 %d)" % [DungeonCatalog.count(), _SEEDS])
	print("")
	print("크기  표기   실제(최소~최대)  중앙  표기대비   규모 등급 분포 1..5")
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_report(size)
	print("")
	print("규모 경계: %s (DungeonGrade._SCALE_STEPS)" % str(DungeonGrade._SCALE_STEPS))
	print("")
	# **다른 두 축도 크기를 따라 밀리는가.** 규모가 그랬으니 여기도 봐야 한다.
	# 복잡·험난은 크기와 **독립**이어야 한다 — 크기는 규모가 말하는 것이다(§17.20).
	print("크기  복잡 등급 분포 1..3   험난 등급 분포 1..3")
	var degrees := PackedFloat32Array()
	var climbs := PackedFloat32Array()
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_report_other_axes(size, degrees, climbs)
	print("")
	print(
		(
			"복잡 경계: %s   험난 경계: %s"
			% [str(DungeonGrade._COMPLEXITY_STEPS), str(DungeonGrade._HARDSHIP_STEPS)]
		)
	)
	# **경계를 다시 자르려면 분포의 백분위가 있어야 한다.** 없어서 한 번은 임시 계산으로
	# 뽑고 표만 남겼는데(§17.30.3), 그러면 다음 사람이 그 수를 다시 못 낸다
	# (`conventions.md` §6.3 규칙 2). 사다리 전 구간을 한 무더기로 놓고 낸다 —
	# 복잡·험난은 **크기와 독립이어야** 하므로 크기별로 나눌 값이 아니다.
	_report_cut_points("복잡(평균 차수)", degrees)
	_report_cut_points("험난(간선당 상승)", climbs)
	print("")
	# 크기가 「보스까지 두 길이 갈리는가」에 미치는 몫. 화면의 판정이 크기마다 얼마나
	# 자주 나오는지를 알아야 **크기 1 로 보고 잘못 판단하는 것**을 막을 수 있다 (§17.27.7).
	print("크기  판   갈린다        안갈림  외길  보스없음")
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_report_boss_routes(size)
	quit()


## 보스까지 두 길이 「짧고 가파른 길 · 길고 완만한 길」로 갈리는 판의 비율.
##
## 화면(§17.27)이 판마다 내리는 판정과 **같은 조건**으로 센다 —
## 지름길이 우회로보다 가파를 때만 갈린 것이다.
func _report_boss_routes(size: int) -> void:
	var split := 0
	var flat := 0
	var single := 0
	var none := 0
	var total := 0
	for character in DungeonCatalog.count():
		for seed_value in _SEEDS:
			var params := SampleDungeons.params_for_size(size, character)
			var plan := DungeonGenerator.new(seed_value * 977 + character, params).generate()
			var routes := DungeonRoutes.to_boss(plan)
			total += 1
			if (routes["shortcut"] as Array).size() < 2:
				none += 1
			elif (routes["detour"] as Array).size() < 2:
				single += 1
			elif int(routes["shortcut_climb"]) > int(routes["detour_climb"]):
				split += 1
			else:
				flat += 1
	print(
		(
			"%3d  %4d  %4d (%3.0f%%)   %6d %5d %8d"
			% [size, total, split, 100.0 * split / total, flat, single, none]
		)
	)


## 복잡·험난이 크기를 따라 밀리는지 본다.
##
## **밀리면 축이 하나로 붙은 것이다.** 크기를 올렸을 뿐인데 「복잡」이 따라 오르면
## 화면의 세 수치가 사실은 하나가 된다(§17.20.3 이 상관을 재 둔 이유다).
func _report_other_axes(size: int, degrees: PackedFloat32Array, climbs: PackedFloat32Array) -> void:
	var complexity := [0, 0, 0]
	var hardship := [0, 0, 0]
	for character in DungeonCatalog.count():
		for seed_value in _SEEDS:
			var params := SampleDungeons.params_for_size(size, character)
			var plan := DungeonGenerator.new(seed_value * 977 + character, params).generate()
			var grade := DungeonGrade.of(plan)
			complexity[clampi(int(grade["complexity"]) - 1, 0, 2)] += 1
			hardship[clampi(int(grade["hardship"]) - 1, 0, 2)] += 1
			degrees.append(float(grade["average_degree"]))
			climbs.append(float(grade["average_climb"]))
	print("%3d   %-20s %s" % [size, str(complexity), str(hardship)])


## 경계를 다시 자를 때 쓰는 백분위. **등급 몫을 정하는 것이 이 수다.**
##
## §17.20.8 의 목표 분포는 25 / 55 / 20 이라 자를 자리는 **25 백분위와 80 백분위**다.
## 50 · 75 도 같이 내는 이유는 분포가 통째로 움직였는지(가운데가 어디로 갔는지)를
## 한눈에 보기 위해서다 — 경계만 보면 그것을 놓친다(§17.30.3 이 놓쳤던 자리다).
func _report_cut_points(label: String, values: PackedFloat32Array) -> void:
	if values.is_empty():
		return
	var sorted_values := values.duplicate()
	sorted_values.sort()
	print(
		(
			"%s 백분위 25/50/75/80: %.3f / %.3f / %.3f / %.3f   -> 25·80 으로 자르면 [%.2f, %.2f]"
			% [
				label,
				_percentile(sorted_values, 0.25),
				_percentile(sorted_values, 0.50),
				_percentile(sorted_values, 0.75),
				_percentile(sorted_values, 0.80),
				_percentile(sorted_values, 0.25),
				_percentile(sorted_values, 0.80),
			]
		)
	)


func _percentile(sorted_values: PackedFloat32Array, ratio: float) -> float:
	var index := clampi(
		int(round(ratio * float(sorted_values.size() - 1))), 0, sorted_values.size() - 1
	)
	return sorted_values[index]


func _report(size: int) -> void:
	var labelled := SampleDungeons.room_estimate(size)
	var counts: Array[int] = []
	var grades := [0, 0, 0, 0, 0]
	for character in DungeonCatalog.count():
		for seed_value in _SEEDS:
			var params := SampleDungeons.params_for_size(size, character)
			var plan := DungeonGenerator.new(seed_value * 977 + character, params).generate()
			var rooms := plan.room_ids().size()
			counts.append(rooms)
			var grade := int(DungeonGrade.of(plan)["scale"])
			grades[clampi(grade - 1, 0, 4)] += 1

	counts.sort()
	var total := 0
	for value in counts:
		total += value
	var median := counts[counts.size() / 2]
	print(
		(
			"%3d  %5d   %5d~%-5d %7d  %+6.1f%%   %s"
			% [
				size,
				labelled,
				counts[0],
				counts[counts.size() - 1],
				median,
				100.0 * (float(total) / float(counts.size()) - labelled) / float(labelled),
				str(grades),
			]
		)
	)
