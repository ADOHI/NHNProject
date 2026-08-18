extends SceneTree
## 게이트 게시판 한 장이 화면에 무엇을 내놓는가 — **넷이 갈리는가.**
##
##     godot --headless --path . -s res://tools/survey_gate_board.gd
##
## 이 자가 내는 표는 §17.22.3 이다.
##
## **문서에 적힌 그 표는 두 번 낡았다.** 한 번은 §17.24 가 간선 선택을 손대면서
## 평균 차수가 움직였고, 한 번은 §17.29.3 이 규모 경계를 다시 자르면서다.
## **두 번 다 표를 다시 뽑는 자가 없어서 낡은 줄도 몰랐다** — 그래서 이 파일이 있다
## (docs/design/17-dungeon-generation.md §17.30.4).
##
## 등급 조합이 갈리는지는 `test_gate.gd` 가 못 박는다. 이 자는 **눈으로 볼 표**를 낸다.

## 목록 시드. 문서의 표는 1 번 것이다.
const _BOARD_SEEDS: Array[int] = [1, 2, 3]

## 게시판 하나에 걸리는 게이트 수.
const _GATES := 4


func _initialize() -> void:
	for board_seed in _BOARD_SEEDS:
		print("== 목록 시드 %d · 길드 등급 1 ==" % board_seed)
		print("%-14s %-6s %-8s %5s %5s %5s %5s" % ["이름", "등급", "성격", "방", "규모", "복잡", "험난"])
		for gate in GateBoard.create(board_seed, 1, _GATES):
			_report(gate)
		print("")
	quit()


func _report(gate: Gate) -> void:
	# 게이트가 여는 그 판을 그대로 만든다. 파라미터를 여기서 다시 조립하면
	# **게이트가 실제로 여는 판과 다른 판을 재게 된다.**
	var params := SampleDungeons.params_for_size(gate.dungeon_size(), gate.dungeon_character)
	var plan := DungeonGenerator.new(gate.dungeon_seed, params).generate()
	var grade := DungeonGrade.of(plan)
	print(
		(
			"%-14s %-6s %-8s %5d %5d %5d %5d"
			% [
				gate.display_name,
				GateRank.label(gate.rank),
				DungeonCatalog.name_of(gate.dungeon_character),
				int(grade["rooms"]),
				int(grade["scale"]),
				int(grade["complexity"]),
				int(grade["hardship"]),
			]
		)
	)
