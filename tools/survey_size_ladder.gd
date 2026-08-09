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

const _SEEDS := 20


func _initialize() -> void:
	print("크기 사다리 — 화면이 적는 수와 판이 내는 수 (성격 %d x 시드 %d)" % [DungeonCatalog.count(), _SEEDS])
	print("")
	print("크기  표기   실제(최소~최대)  중앙  표기대비   규모 등급 분포 1..5")
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_report(size)
	print("")
	print("규모 경계: %s (DungeonGrade._SCALE_STEPS)" % str(DungeonGrade._SCALE_STEPS))
	quit()


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
