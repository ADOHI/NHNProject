extends SceneTree
## **목록 넷이 다 막히는 일이 있나** — 입장 제한이 놓은 마지막 구멍.
##
##     godot --headless --path . -s res://tools/survey_gate_agility.gd
##
## 이 자가 내는 표는 §17.42 다.
##
## ## 왜 필요한가
##
## §17.40 이 민첩으로 입장을 막았다. 판 하나만 보면 막히는 비율이 1% 라 안전해 보이는데,
## **플레이어가 보는 것은 판 하나가 아니라 목록 하나**다. `GateBoard.create` 는 스쿼드를
## 안 보고 게이트를 뽑으므로 **넷이 다 막힌 목록이 원리적으로 가능하다.**
## 그러면 그 판에서 할 수 있는 일이 없다 — **막다른 상태**다.
##
## ## 시드 하나로 답하면 안 된다
##
## 목록은 시드에서 나오고 시드마다 성격·크기·씨앗이 통째로 달라진다.
## **한 목록을 보고 "괜찮다"고 적으면 그 문장은 그 시드의 이야기일 뿐이다.**
## 그래서 목록 시드를 많이 돌린다.

## 돌릴 목록 시드 수. 목록 하나가 게이트 네 개를 뽑으므로 실제 게이트 수는 이것의 네 배다.
const _BOARDS := 200

## 한 목록에 뜨는 게이트 수. 화면이 쓰는 값과 같다.
const _GATES_PER_BOARD := 4

## 볼 스쿼드 민첩. 계열 기본값이 [1, 4, 2, 2, 3] 이라 1~4 가 실제로 나온다
## (`MemberDiscipline._AGILITIES`, 평균 내림).
const _SQUADS := [1, 2, 3, 4]

## 볼 길드 등급. 등급이 오르면 큰 판이 열리고, 큰 판은 안쪽이 깊다.
const _RANKS := [1, 3, 5]


func _initialize() -> void:
	print("== 목록 하나에서 들어갈 수 있는 게이트 (목록 시드 %d x 게이트 %d) ==" % [_BOARDS, _GATES_PER_BOARD])
	print("")
	for rank in _RANKS:
		_report(rank)
	print("")
	print("**막다른 목록** = 넷 다 못 들어가는 목록. 그 판에서 할 수 있는 일이 없다")
	print("들어갈 수 있는 게이트 평균이 1 을 넘어도 0 인 목록이 있으면 그것이 사고다")
	quit()


func _report(guild_rank: int) -> void:
	print("-- 길드 등급 %d --" % guild_rank)
	print("%-9s%-14s%-14s%s" % ["스쿼드", "열린 게이트 평균", "막다른 목록", "게이트 하나가 막힐 확률"])

	# **목록마다 필요 민첩 넷을 한 번만 재고 재사용한다.** 스쿼드마다 다시 만들면
	# 같은 판을 네 번 생성하게 되고, 그러면 이 자가 분 단위로 느려진다.
	var boards := []
	for board_seed in _BOARDS:
		var gates := GateBoard.create(board_seed * 7919 + guild_rank, guild_rank, _GATES_PER_BOARD)
		var needs := PackedInt32Array()
		for gate in gates:
			needs.append(gate.required_agility())
		boards.append(needs)

	for squad in _SQUADS:
		var open_total := 0
		var dead_boards := 0
		var blocked_gates := 0
		var gate_total := 0
		for needs in boards:
			var open := 0
			for need in needs:
				gate_total += 1
				if int(need) <= squad:
					open += 1
				else:
					blocked_gates += 1
			open_total += open
			if open == 0:
				dead_boards += 1
		print(
			(
				"%-9s%-14s%-14s%.1f%%"
				% [
					"민첩 %d" % squad,
					"%.2f / %d" % [float(open_total) / float(boards.size()), _GATES_PER_BOARD],
					(
						"%d / %d (%.1f%%)"
						% [
							dead_boards,
							boards.size(),
							100.0 * float(dead_boards) / float(boards.size())
						]
					),
					100.0 * float(blocked_gates) / float(gate_total),
				]
			)
		)
