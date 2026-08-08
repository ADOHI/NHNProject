extends Control
## 백팩을 만지고 **체인이 어느 순서로 도는지 보는** 화면.
##
## `docs/design/28-combat.md` §28.20.9.
##
## ## 이것이 판정 수단이다
##
## 「이 배치에서 이 순서로 돈다」가 눈에 보여야 §28.2 의 설계가 맞는지 안다.
## 그래서 배치를 만질 때마다 체인을 **그 자리에서 다시 푼다.**
##
## ## 하는 일은 셋뿐이다
##
## 표본을 세우고, 격자가 바뀌면 해석기를 돌리고, 결과를 글자로 적는다.
## 규칙은 하나도 여기 없다 — 전부 `src/core/combat/` 에 있다.

var _grid: BackpackGrid

## 무너짐 수치들. **확정이 아니다** (§28.8). 여기서 갈아 끼우면 화면이 따라온다.
var _break_tuning := BreakTuning.new()

@onready var _board: BackpackBoard = %Board
@onready var _help_label: Label = %HelpLabel
@onready var _chain_label: Label = %ChainLabel


func _ready() -> void:
	_grid = SampleBackpack.create_grid()
	var leftover := SampleBackpack.fill(_grid, SampleBackpack.create_items())
	_board.bind(_grid, leftover)
	_board.layout_changed.connect(_refresh)
	_help_label.text = _help_text()
	_refresh()


## 배치가 바뀌었다. 체인을 다시 풀어 화면과 글자에 함께 반영한다.
func _refresh() -> void:
	var chains := ChainResolver.resolve_all(_grid)
	var outcomes: Array[ChainBreakOutcome] = []
	for chain in chains:
		outcomes.append(ChainBreakSim.run(chain, _break_tuning))
	_board.set_chains(chains)
	_board.set_break(outcomes, _break_tuning)
	_chain_label.text = _chain_text(chains, outcomes)


func _help_text() -> String:
	return (
		"백팩 배치가 콤보 루트를 정한다. 아이템을 옮기면 체인이 그 자리에서 다시 풀린다.\n"
		+ "왼쪽 끌기: 옮기기    오른쪽 클릭: 대기줄로 빼기    R: 회전    "
		+ "C: 격자 비우기    Space: 표본 배치로 되돌리기"
	)


## 체인을 읽을 수 있는 글자로. **번호는 아라비아 숫자, 방향은 한글이다** —
## 본문 폰트에 원문자도 화살표도 없다 (§28.20.9).
func _chain_text(chains: Array[ChainResult], outcomes: Array[ChainBreakOutcome]) -> String:
	var lines := PackedStringArray()
	for index in chains.size():
		if index > 0:
			lines.append("")
		lines.append_array(_one_chain_text(chains[index], index + 1))
		lines.append_array(_break_text(outcomes[index]))
	return "\n".join(lines)


## **긴 체인이 왜 좋은가**를 글자로도 적는다 (§28.5).
##
## 격자 아래 막대가 눈금을 보여 주고, 여기는 **몇 번째 타에서** 넘겼는지를 적는다.
func _break_text(outcome: ChainBreakOutcome) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("")
	lines.append("    무너짐: %s" % outcome.summary_line())
	if outcome.hits() == 0:
		return lines
	var stages: Array[BreakState.Kind] = [
		BreakState.Kind.STAGGER, BreakState.Kind.LAUNCH, BreakState.Kind.KNOCKDOWN
	]
	for kind in stages:
		var step := outcome.first_step_reaching(kind)
		if step > 0:
			lines.append("      %s  %d번째 타에서" % [BreakState.label(kind), step])
	if outcome.highest == BreakState.Kind.NONE:
		lines.append("      문턱을 못 넘었다. 체인이 더 길어야 한다")
	return lines


func _one_chain_text(chain: ChainResult, number: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var node := chain.start_node
	lines.append("체인 %d    시작 노드 (%d, %d)" % [number, node.x, node.y])
	lines.append("")

	if chain.length() == 0:
		lines.append("    비어 있다. 시작 노드에 아이템을 놓아라.")
		return lines

	for step in chain.steps.size():
		lines.append("    %d.  %s" % [step + 1, _step_text(chain.steps[step])])

	lines.append("")
	lines.append("    %s     %d 타" % ["완주" if chain.is_complete() else "끊김", chain.length()])
	lines.append("    끝난 이유: %s" % chain.stop_label())
	if chain.has_break_cell and not chain.is_complete():
		lines.append("    끊긴 자리: (%d, %d)" % [chain.break_cell.x, chain.break_cell.y])
	return lines


func _step_text(placement: BackpackPlacement) -> String:
	var item := placement.item
	if not item.has_output():
		return "%s  (전리품 - 여기서 끝)" % item.display_name
	var cell := placement.output_cell()
	return (
		"%s  (%s 칸에서 %s)"
		% [
			item.display_name,
			"(%d, %d)" % [cell.x, cell.y],
			ChainDirection.label(item.output_direction)
		]
	)
