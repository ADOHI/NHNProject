extends SceneTree
## 성격 축을 **더 세게 밀면 흩어짐도 같이 커지나.**
##
##     godot --headless --path . -s res://tools/survey_axis_spread.gd
##
## 이 자가 내는 표는 §17.34 다.
##
## ## 왜 이걸 재나
##
## §17.31.3 에서 둘이 「아깝다」로 나왔다 — 수직 회랑(최고 고도 12.8 대 4.5~6.5)과
## 먼 출구(막다른방% 26.3 대 15~16). **평균은 충분히 벌어졌는데 흩어짐이 먹는다.**
## 그리고 **플레이어는 한 판만 본다.**
##
## 그러니 물음은 "평균을 더 벌릴까"가 아니라 **"흩어짐을 줄일 수 있나"** 다.
##
## | 나오면 | 뜻 |
## | --- | --- |
## | 변동계수가 **일정** | 밀수록 평균도 흩어짐도 같은 비로 커진다. **밀어서는 못 가른다** |
## | 변동계수가 **내려간다** | 더 밀면 갈린다. 값만 바꾸면 된다 |
##
## **변동계수(표준편차/평균)를 쓰는 이유가 그것이다.** 표준편차만 보면 "밀었더니
## 흩어짐이 커졌다"까지만 알고, 그것이 **평균이 커진 몫인지 진짜 나빠진 것인지** 모른다.

## 한 설정마다 만들 판 수.
const _RUNS := 20

## 판정 크기 (§17.27.7).
const _SIZE := 3

## 밀어 볼 축들. [성격 색인, 파라미터 이름, 재는 값, 밀 값들]
##
## **성격 색인을 함께 둔다.** `params_for_size(size)` 는 성격을 안 주면 0(얕은 갱도)을
## 쓴다 — 그걸 기준으로 삼으면 **엉뚱한 성격의 판에 손잡이를 밀어 넣고** 그 결과를
## 수직 회랑의 것으로 읽게 된다. 축을 가진 성격 위에서 그 축만 밀어야 뜻이 맞는다.
##
## 첫 값은 그 파라미터의 **기본값**이라, 그 줄이 곧 "축을 안 민 판"이 된다.
const _SWEEPS: Array = [
	[2, "elevation_gain", "최고 고도", [2.0, 3.5, 5.0, 7.0, 9.0, 12.0]],
	[3, "dead_end_ratio_min", "막다른방%", [0.14, 0.22, 0.30, 0.38, 0.45]],
]


func _initialize() -> void:
	print("== 축을 더 세게 밀면 흩어짐도 같이 커지나 (크기 %d, 설정마다 %d 판) ==" % [_SIZE, _RUNS])
	for sweep in _SWEEPS:
		_run_sweep(sweep)
	print("")
	print("변동계수 : 표준편차/평균. **일정하면 밀어도 안 갈린다**")
	print("d'       : 기준과의 거리를 흩어짐으로 나눈 것. 2 를 넘어야 띠가 갈리기 시작한다")
	print("띠       : 기준의 ±2 표준편차 띠와 안 겹치면 「갈린다」")
	quit()


func _run_sweep(sweep: Array) -> void:
	print("")
	print("%s — %s (손잡이: %s)" % [DungeonCatalog.name_of(int(sweep[0])), sweep[2], sweep[1]])
	print("%-8s %8s %8s %9s %8s %8s" % ["값", "평균", "표준편차", "변동계수", "d'", "띠"])

	var base_mean := 0.0
	var base_sd := 0.0
	for index in (sweep[3] as Array).size():
		var knob: float = sweep[3][index]
		var stats := _measure(int(sweep[0]), String(sweep[1]), knob, String(sweep[2]))
		var mean: float = stats[0]
		var sd: float = stats[1]
		if index == 0:
			base_mean = mean
			base_sd = sd
		var pooled := sqrt((sd * sd + base_sd * base_sd) * 0.5)
		var d := 0.0 if pooled <= 0.0001 else (mean - base_mean) / pooled
		var apart := mean - 2.0 * sd > base_mean + 2.0 * base_sd
		print(
			(
				"%-8.2f %8.2f %8.2f %9.3f %8.2f %8s"
				% [
					knob,
					mean,
					sd,
					sd / maxf(mean, 0.0001),
					d,
					"(기준)" if index == 0 else ("갈린다" if apart else "겹친다")
				]
			)
		)


## 그 손잡이 값으로 판을 만들어 재는 값의 [평균, 표준편차].
func _measure(character: int, knob: String, value: float, metric: String) -> Array:
	var values: Array[float] = []
	for run in _RUNS:
		var params := SampleDungeons.params_for_size(_SIZE, character)
		params.set(knob, value)
		var plan := DungeonGenerator.new(run * 977 + character, params).generate()
		values.append(_value_of(plan, metric))

	var total := 0.0
	for value_seen in values:
		total += value_seen
	var mean := total / float(values.size())
	var variance := 0.0
	for value_seen in values:
		variance += pow(value_seen - mean, 2.0)
	return [mean, sqrt(variance / float(values.size()))]


func _value_of(plan: DungeonBlueprint, metric: String) -> float:
	if metric == "최고 고도":
		var highest := 0
		for id in plan.room_ids():
			highest = maxi(highest, plan.elevation_of(id))
		return float(highest)

	# 막다른방%
	var graph := plan.build()
	var dead := 0.0
	for id in plan.room_ids():
		if graph.is_dead_end(id):
			dead += 1.0
	return 100.0 * dead / maxf(float(plan.room_ids().size()), 1.0)
