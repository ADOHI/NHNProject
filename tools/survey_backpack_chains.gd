extends SceneTree
## **배치가 실제로 어려운가**를 잰다. 연결 조건(§28.2.2) 논의의 재료다.
##
##     godot --headless --path . -s res://tools/survey_backpack_chains.gd
##
## ## 무엇을 묻는가
##
## 지금 규칙은 「방향이 맞으면 연결된다」 하나뿐이다. 그것만으로 충분히 빡빡한가,
## 아니면 아무렇게나 쑤셔 넣어도 긴 체인이 나오는가.
##
## **아무렇게나 넣어도 잘 이어지면 배치가 결정이 아니다.** 그때는 깐깐한 조건이
## 필요하다는 근거가 된다. 반대로 무작위로는 거의 안 이어지는데 손으로는 이어진다면
## 지금 규칙만으로도 이미 결정이 있다는 뜻이다.
##
## ## 한 번 재고 적지 않는다
##
## 표본 하나는 잡음이다. 여러 판을 돌려 **분포**를 찍는다.

const _TRIALS := 600

## 한 아이템을 놓아 볼 자리 시도 수. 이 수가 작으면 격자가 빈 것이 아니라
## 못 찾은 것인데 "안 들어간다" 로 잘못 읽힌다.
const _PLACE_ATTEMPTS := 60


func _initialize() -> void:
	var items := SampleBackpack.create_items()
	print(
		(
			"아이템 %d 종 · 격자 %dx%d · 시작 노드 %d 개 · %d 판"
			% [
				items.size(),
				SampleBackpack.GRID_WIDTH,
				SampleBackpack.GRID_HEIGHT,
				SampleBackpack.START_NODES.size(),
				_TRIALS,
			]
		)
	)
	print("")
	_run("무작위 배치 (회전 포함)", true)
	_run("무작위 배치 (회전 없음)", false)
	_report_sample()
	quit()


func _run(title: String, allow_rotation: bool) -> void:
	var lengths: Array[int] = []
	var histogram := {}
	var completed := 0
	var started := 0
	var placed_total := 0
	var chained_total := 0

	for trial in _TRIALS:
		var rng := RandomNumberGenerator.new()
		rng.seed = trial * 7919 + 11
		var grid := SampleBackpack.create_grid()
		var placed := _fill_randomly(grid, rng, allow_rotation)
		var chain := ChainResolver.resolve_from(grid, SampleBackpack.START_NODES[0])

		lengths.append(chain.length())
		histogram[chain.length()] = int(histogram.get(chain.length(), 0)) + 1
		if chain.length() > 0:
			started += 1
		if chain.is_complete():
			completed += 1
		placed_total += placed
		chained_total += chain.length()

	print("== %s ==" % title)
	print("  놓인 아이템 평균 %.1f 개" % (float(placed_total) / float(_TRIALS)))
	print("  시작 노드가 덮인 판 %.0f%%" % (100.0 * float(started) / float(_TRIALS)))
	print("  체인 길이 평균 %.2f · 최대 %d" % [_mean(lengths), _max(lengths)])
	print(
		"  놓인 것 중 체인에 든 비율 %.0f%%" % (100.0 * float(chained_total) / maxf(1.0, float(placed_total)))
	)
	print("  전리품까지 닿아 완주한 판 %.0f%%" % (100.0 * float(completed) / float(_TRIALS)))
	print("  길이 분포: %s" % _histogram_text(histogram))
	print("")


## 아이템을 순서 섞어 무작위 자리에 밀어 넣는다. 놓인 개수를 돌려준다.
func _fill_randomly(grid: BackpackGrid, rng: RandomNumberGenerator, rotate: bool) -> int:
	var items := SampleBackpack.create_items()
	items.shuffle()
	var placed := 0
	for item in items:
		var candidate := item
		if rotate:
			for _turn in rng.randi_range(0, 3):
				candidate = candidate.rotated()
		for _attempt in _PLACE_ATTEMPTS:
			var origin := Vector2i(
				rng.randi_range(0, grid.width - 1), rng.randi_range(0, grid.height - 1)
			)
			if grid.place(candidate, origin) != null:
				placed += 1
				break
	return placed


## 손으로 짠 표본 배치는 어디쯤인가. 무작위 분포와 견줄 기준점이다.
func _report_sample() -> void:
	var grid := SampleBackpack.create_grid()
	SampleBackpack.fill(grid, SampleBackpack.create_items())
	var chain := ChainResolver.resolve_from(grid, SampleBackpack.START_NODES[0])
	print("== 손으로 짠 표본 배치 ==")
	print(
		(
			"  길이 %d · %s · %s"
			% [
				chain.length(),
				"완주" if chain.is_complete() else "끊김",
				chain.stop_label(),
			]
		)
	)


func _mean(values: Array[int]) -> float:
	var total := 0
	for value in values:
		total += value
	return float(total) / maxf(1.0, float(values.size()))


func _max(values: Array[int]) -> int:
	var best := 0
	for value in values:
		best = maxi(best, value)
	return best


func _histogram_text(histogram: Dictionary) -> String:
	var keys := histogram.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%d타 %d판" % [key, histogram[key]])
	return "  ".join(parts)
