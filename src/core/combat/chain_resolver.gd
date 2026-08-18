class_name ChainResolver
extends RefCounted
## 백팩 배치를 읽어 **콤보 순서**를 낸다. 이 시스템의 심장이다.
##
## `docs/design/28-combat.md` §28.2 · §28.20.4.
##
## [codeblock]
## 시작 노드를 덮고 있는 아이템  ->  그 아이템의 출력 블럭
##         ->  출력 방향으로 한 칸 이동
##         ->  그 칸을 덮고 있는 아이템이 다음 콤보
##         ->  반복
## [/codeblock]
##
## ## 한 칸이지 훑기가 아니다
##
## 출력 블럭 **바로 옆**에 다음 아이템이 붙어 있어야 이어진다. 그 방향으로 쭉
## 훑어서 처음 만나는 것을 잡지 않는다.
##
## 훑기로 하면 격자 어디에 두든 대충 이어지고, 그러면 **배치가 루트를 정한다**는
## 이 시스템의 심장이 죽는다. 붙여야 이어지니까 배치가 결정이 된다.
##
## ## 해석기는 조건을 모른다
##
## 「이어져도 되는가」는 `ChainLinkRule` 에게 물어본다. §28.2.2 의 미정된 조건이
## 나중에 정해져도 이 파일은 안 바뀐다.

## 한 체인이 가질 수 있는 아이템 수 상한.
##
## 고리는 `ALREADY_CHAINED` 로 이미 막힌다. 이것은 그 검사가 놓치는 경우에 대비한
## **안전장치**이지 게임 규칙이 아니다. 격자가 이 수보다 커지면 여기만 고친다.
const MAX_CHAIN_LENGTH := 64


## 격자의 **모든 시작 노드**에서 체인을 푼다.
##
## 시작 노드가 하나라는 보장이 없다 (§28.20.7). 그래서 결과도 목록이다.
static func resolve_all(grid: BackpackGrid, rule: ChainLinkRule = null) -> Array[ChainResult]:
	var results: Array[ChainResult] = []
	for start_node in grid.start_nodes:
		results.append(resolve_from(grid, start_node, rule))
	return results


## 시작 노드 하나에서 체인을 푼다.
static func resolve_from(
	grid: BackpackGrid, start_node: Vector2i, rule: ChainLinkRule = null
) -> ChainResult:
	var link_rule := rule if rule != null else ChainLinkRule.new()
	var result := ChainResult.new(start_node)

	var current := grid.placement_at(start_node)
	if current == null:
		result.stop_reason = ChainResult.StopReason.NO_START_ITEM
		result.break_cell = start_node
		result.has_break_cell = true
		return result

	var visited := {}
	result.steps.append(current)
	visited[current] = true

	while true:
		if not current.has_output():
			result.stop_reason = ChainResult.StopReason.NO_OUTPUT
			return result

		var target := current.output_target()
		result.break_cell = target
		result.has_break_cell = true

		if not grid.contains(target):
			result.stop_reason = ChainResult.StopReason.OUT_OF_BOUNDS
			return result

		var next := grid.placement_at(target)
		if next == null:
			result.stop_reason = ChainResult.StopReason.EMPTY_CELL
			return result

		if visited.has(next):
			result.stop_reason = ChainResult.StopReason.ALREADY_CHAINED
			return result

		if not link_rule.can_link(current, next):
			result.stop_reason = ChainResult.StopReason.LINK_REJECTED
			return result

		if result.steps.size() >= MAX_CHAIN_LENGTH:
			result.stop_reason = ChainResult.StopReason.MAX_LENGTH
			return result

		result.steps.append(next)
		visited[next] = true
		current = next
		result.has_break_cell = false

	# 도달하지 않는다. while 안의 모든 갈래가 return 한다.
	return result
