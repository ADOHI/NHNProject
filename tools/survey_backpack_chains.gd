extends SceneTree
## **배치가 실제로 어려운가**, 그리고 **그 어려움이 표본에 얼마나 매여 있는가.**
##
##     godot --headless --path . -s res://tools/survey_backpack_chains.gd
##
## ## 무엇을 묻는가
##
## 지금 규칙은 「방향이 맞으면 연결된다」 하나뿐이다(§28.2.2 는 미정).
## 6x6 · 13종에서 재 보니 **무작위 0.79타 · 손으로 5타**였다.
## **그 격차가 결정이 사는 자리**인데, 그것이 이 표본에서만 나오는 것인지 확인한다.
##
## ## 두 수를 잰다
##
## | 수 | 무엇 | 어떻게 |
## | --- | --- | --- |
## | **아무렇게나** | 생각 없이 쑤셔 넣었을 때 | 무작위 배치 여러 판의 평균 |
## | **작정하고** | 최적화하는 사람의 상한 | 시작 노드에서 **체인을 이어 붙여 나가는** 탐색 |
##
## **둘의 격차가 곧 「배치가 결정인 정도」다.** 격차가 없으면 아무렇게나 해도
## 되는 것이고, 그러면 배치는 결정이 아니다.
##
## ## 한 번 재고 적지 않는다
##
## 표본 하나는 잡음이다. 판을 여러 번 돌려 평균과 분포를 낸다.

const _TRIALS := 300

## 탐색 재시작 수.
##
## **이 수가 작으면 잡음을 사실로 적게 된다.** 200 회에서는 격자별 결과가
## 5 -> 7 -> 10 -> 8 -> 8 로 나왔는데, 큰 격자가 작은 격자보다 짧을 수는 없다
## (자리가 더 많으니 최소한 같은 배치는 들어간다). 못 찾은 것이었다.
##
## 2000 회에서 7 -> 8 -> 9 -> 9 -> 11 로 **단조 비감소**가 되었다.
## 그것이 이 탐색이 수렴했는지 보는 검사다.
const _BUILD_RESTARTS := 2000

## 한 아이템을 놓아 볼 자리 시도 수. 작으면 "못 찾은 것" 이 "안 들어간다" 로 잘못 읽힌다.
const _PLACE_ATTEMPTS := 60


func _initialize() -> void:
	print("각 칸: 아무렇게나(평균) -> 작정하고(최대)   · 무작위 %d판 · 탐색 %d회" % [_TRIALS, _BUILD_RESTARTS])
	print("")
	_sweep_grid_sizes()
	_sweep_item_shapes()
	_sweep_start_nodes()
	quit()


# ---------------------------------------------------------------- 쓸어 보기


func _sweep_grid_sizes() -> void:
	print("== 격자 크기 (표본 13종 · 시작 노드 1개) ==")
	for size in [4, 5, 6, 8, 10]:
		_measure("%dx%d" % [size, size], size, size, _sample_items(), 1)
	print("")


func _sweep_item_shapes() -> void:
	print("== 아이템 모양 (6x6 · 시작 노드 1개) ==")
	_measure("표본 13종 (섞임)", 6, 6, _sample_items(), 1)
	_measure("전부 1칸", 6, 6, _tiny_items(), 1)
	_measure("전부 큰 것", 6, 6, _bulky_items(), 1)
	print("")


func _sweep_start_nodes() -> void:
	print("== 시작 노드 개수 (6x6 · 표본 13종) — §28.8 은 미정이다. 재 보기만 한다 ==")
	_measure("1개", 6, 6, _sample_items(), 1)
	_measure("2개", 6, 6, _sample_items(), 2)
	print("")


## 시작 노드를 격자에 흩어 놓는다. 몰려 있으면 개수를 늘린 뜻이 없다.
func _start_nodes(width: int, height: int, count: int) -> Array[Vector2i]:
	var nodes: Array[Vector2i] = [Vector2i(0, 0)]
	if count >= 2:
		nodes.append(Vector2i(width - 1, height - 1))
	return nodes


func _measure(
	label: String, width: int, height: int, items: Array[BackpackItem], starts: int
) -> void:
	var nodes := _start_nodes(width, height, starts)
	var random_total := 0
	var random_best := 0
	var covered := 0
	for trial in _TRIALS:
		var rng := RandomNumberGenerator.new()
		rng.seed = trial * 7919 + 11
		var grid := BackpackGrid.new(width, height, nodes)
		_fill_randomly(grid, rng, items)
		var length := _total_chain(grid, nodes)
		random_total += length
		random_best = maxi(random_best, length)
		if length > 0:
			covered += 1

	var built := _build_best(width, height, nodes, items)
	var average := float(random_total) / float(_TRIALS)
	print(
		(
			"  %-18s 아무렇게나 %.2f타 (최대 %d) -> 작정하고 %d타   격차 %.1f배   시작 덮인 판 %.0f%%"
			% [
				label,
				average,
				random_best,
				built,
				float(built) / maxf(0.01, average),
				100.0 * float(covered) / float(_TRIALS),
			]
		)
	)


func _total_chain(grid: BackpackGrid, nodes: Array[Vector2i]) -> int:
	var total := 0
	for node in nodes:
		total += ChainResolver.resolve_from(grid, node).length()
	return total


# ---------------------------------------------------------------- 아무렇게나


func _fill_randomly(
	grid: BackpackGrid, rng: RandomNumberGenerator, items: Array[BackpackItem]
) -> void:
	var pool: Array[BackpackItem] = items.duplicate()
	pool.shuffle()
	for item in pool:
		var candidate := item
		for _turn in rng.randi_range(0, 3):
			candidate = candidate.rotated()
		for _attempt in _PLACE_ATTEMPTS:
			var origin := Vector2i(
				rng.randi_range(0, grid.width - 1), rng.randi_range(0, grid.height - 1)
			)
			if grid.place(candidate, origin) != null:
				break


# ---------------------------------------------------------------- 작정하고


## 최적화하는 사람의 상한. 시작 노드마다 **체인을 이어 붙여 나가며** 가장 긴 것을 찾는다.
##
## 무작위를 여러 번 돌려 최댓값을 취하는 방식은 격자가 커질수록 못 찾는다 —
## 사람은 우연을 기다리지 않고 **다음 칸에 맞는 것을 골라 놓기** 때문이다.
func _build_best(
	width: int, height: int, nodes: Array[Vector2i], items: Array[BackpackItem]
) -> int:
	var best := 0
	for restart in _BUILD_RESTARTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = restart * 31 + 7
		var grid := BackpackGrid.new(width, height, nodes)
		var pool: Array[BackpackItem] = items.duplicate()
		pool.shuffle()
		for node in nodes:
			_grow_chain(grid, node, pool)
		best = maxi(best, _total_chain(grid, nodes))
	return best


## 시작 노드에서 출발해 다음 칸에 맞는 아이템을 계속 붙인다.
func _grow_chain(grid: BackpackGrid, node: Vector2i, pool: Array[BackpackItem]) -> void:
	var target := node
	while grid.contains(target) and grid.placement_at(target) == null:
		var placed := _place_covering(grid, target, pool)
		if placed == null:
			return
		if not placed.has_output():
			return
		target = placed.output_target()


## 그 칸을 덮도록 아이템 하나를 놓는다. 놓은 배치를 돌려준다.
##
## 출력이 있는 것을 먼저 시도한다 — 전리품을 붙이면 거기서 체인이 끝나기 때문이다.
func _place_covering(
	grid: BackpackGrid, cell: Vector2i, pool: Array[BackpackItem]
) -> BackpackPlacement:
	var fallback: BackpackPlacement = null
	for index in pool.size():
		var item: BackpackItem = pool[index]
		var candidate := item
		for _turn in 4:
			candidate = candidate.rotated()
			for shape_cell in candidate.shape:
				var origin := cell - shape_cell
				if not grid.can_place(candidate, origin):
					continue
				if not candidate.has_output():
					if fallback == null:
						fallback = BackpackPlacement.new(candidate, origin)
					continue
				var placed := grid.place(candidate, origin)
				pool.remove_at(index)
				return placed
	if fallback != null and grid.place(fallback.item, fallback.origin) != null:
		return grid.placement_at(cell)
	return null


# ---------------------------------------------------------------- 아이템 묶음


func _sample_items() -> Array[BackpackItem]:
	return SampleBackpack.create_items()


## 전부 1칸. 모양이 제약을 못 걸고 **방향만 남는다.**
func _tiny_items() -> Array[BackpackItem]:
	var directions := [
		ChainDirection.Kind.UP,
		ChainDirection.Kind.RIGHT,
		ChainDirection.Kind.DOWN,
		ChainDirection.Kind.LEFT,
	]
	var items: Array[BackpackItem] = []
	for index in 10:
		items.append(
			BackpackItem.new(
				"tiny_%d" % index,
				"작은%d" % index,
				BackpackItem.Kind.WEAPON,
				[Vector2i(0, 0)],
				Vector2i(0, 0),
				directions[index % directions.size()]
			)
		)
	for index in 3:
		items.append(
			BackpackItem.new(
				"t_loot_%d" % index, "짐%d" % index, BackpackItem.Kind.LOOT, [Vector2i(0, 0)]
			)
		)
	return items


## 전부 크다. 칸을 많이 먹어서 **자리 자체가 모자라진다.**
func _bulky_items() -> Array[BackpackItem]:
	var square: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var bar: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var items: Array[BackpackItem] = []
	for index in 5:
		items.append(
			BackpackItem.new(
				"square_%d" % index,
				"덩어리%d" % index,
				BackpackItem.Kind.WEAPON,
				square,
				Vector2i(1, 1),
				ChainDirection.Kind.RIGHT if index % 2 == 0 else ChainDirection.Kind.DOWN
			)
		)
	for index in 5:
		items.append(
			BackpackItem.new(
				"bar_%d" % index,
				"막대%d" % index,
				BackpackItem.Kind.WEAPON,
				bar,
				Vector2i(0, 2),
				ChainDirection.Kind.DOWN if index % 2 == 0 else ChainDirection.Kind.LEFT
			)
		)
	items.append(BackpackItem.new("big_loot", "큰짐", BackpackItem.Kind.LOOT, square))
	return items
