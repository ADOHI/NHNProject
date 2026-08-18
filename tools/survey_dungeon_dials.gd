extends SceneTree
## 던전 선택 화면에 **표시할 수치**를 고르기 위한 계측.
##
## 사용자 요구: "얼마나 큰지, 얼마나 복잡한지, 얼마나 고도차가 심한지" 를 복합적으로.
##
## 그런데 §17.16 에서 **한 던전에 축 둘까지**로 제한했다. 축이 서로 상쇄하기 때문이다.
## 「복합적으로」와 정면으로 부딪히므로, **서로 독립인 축을 찾는 것**이 이 도구의 목적이다.
##
## 두 가지를 잰다.
##
## | 무엇 | 왜 |
## | --- | --- |
## | 표시 후보끼리의 **상관** | 둘이 같이 움직이면 축이 둘이 아니라 하나다 |
## | 입력 축마다의 **신호대잡음** | 시드보다 크게 반응해야 표시할 값이 된다 |
##
## **표시값은 입력이 아니라 결과다.** 입력이 5 인데 결과가 3 이면 화면이 거짓말한다.
## 그래서 후보를 전부 「생성된 판을 재서 나온 값」으로 둔다.
##
##   godot --headless --path . -s res://tools/survey_dungeon_dials.gd

const Metrics := preload("res://tools/dungeon_metrics.gd")

const _SEEDS := 12

## 입력 격자. 셋을 서로 곱해 돌린다.
const _ROOMS := [12, 22, 32, 50]
const _EXTRA := [0.08, 0.24, 0.46]
const _GAIN := [1.0, 2.0, 5.0]

## 표시 후보. 전부 생성된 판에서 잰 값이다.
const _CANDIDATES: Array[String] = [
	"rooms",
	"avg_degree",
	"cycles",
	"cycle_density",
	"junction_pct",
	"diameter",
	"dead_end_pct",
	"max_elev",
	"locked_pct",
	"climb_mean",
	"steep_pct",
	"climb_edge_pct",
]

## 표시 등급을 몇 단계까지 낼 수 있나. [이름, 표시 지표, 입력 필드, 입력 다섯]
const _LEVELS := [
	["복잡", "junction_pct", "extra_edge_ratio", [0.02, 0.14, 0.28, 0.46, 0.70]],
	["복잡(평균 차수)", "avg_degree", "extra_edge_ratio", [0.02, 0.14, 0.28, 0.46, 0.70]],
	["험난", "climb_mean", "elevation_gain", [0.5, 1.5, 2.5, 4.0, 6.0]],
	["험난(상승 간선%)", "climb_edge_pct", "elevation_gain", [0.5, 1.5, 2.5, 4.0, 6.0]],
	["규모", "rooms", "room_count", [12, 22, 32, 42, 55]],
]


func _initialize() -> void:
	var samples := _collect()
	_print_axis_response(samples)
	_print_correlation(samples)
	_print_levels()
	quit()


## **다섯 단계가 실제로 갈리는가.**
##
## 표시 수치는 시드 잡음보다 단계 간격이 넓어야 뜻을 갖는다. 각 단계의 평균에
## ±2 표준편차 띠를 붙여 이웃 단계와 겹치는지 본다. 겹치면 그 단계는 구분되지 않는다.
func _print_levels() -> void:
	print("")
	print("== 다섯 단계가 갈리나 (판마다 시드 %d개) ==" % _SEEDS)
	for entry in _LEVELS:
		print("")
		print("-- %s (%s) --" % [entry[0], entry[1]])
		var means: Array[float] = []
		var bands: Array[float] = []
		for value in entry[3]:
			var values: Array[float] = []
			for run in _SEEDS:
				values.append(
					float(_measure_field(run * 7919 + 5, String(entry[2]), float(value))[entry[1]])
				)
			means.append(_mean(values))
			bands.append(2.0 * _deviation(values))
			print(
				(
					"  %-6s -> %7.2f  ±%.2f"
					% [str(value), means[means.size() - 1], bands[bands.size() - 1]]
				)
			)
		var clashes := 0
		for index in range(1, means.size()):
			if absf(means[index] - means[index - 1]) < (bands[index] + bands[index - 1]) * 0.5:
				clashes += 1
		print("  이웃 단계가 겹치는 곳: %d / %d" % [clashes, means.size() - 1])


## 한 필드만 바꿔서 잰다. 나머지는 기본값이다.
func _measure_field(seed_value: int, field: String, value: float) -> Dictionary:
	var rooms := 32
	if field == "room_count":
		rooms = int(value)
	var extra := 0.24
	if field == "extra_edge_ratio":
		extra = value
	var gain := 2.0
	if field == "elevation_gain":
		gain = value
	return _measure(seed_value, rooms, extra, gain)


## 격자마다 시드를 돌려 후보값을 모은다.
func _collect() -> Array:
	var result: Array = []
	for rooms in _ROOMS:
		for extra in _EXTRA:
			for gain in _GAIN:
				var values := {}
				for key in _CANDIDATES:
					values[key] = [] as Array[float]
				for run in _SEEDS:
					var measured := _measure(run * 7919 + rooms, rooms, float(extra), float(gain))
					for key in _CANDIDATES:
						(values[key] as Array[float]).append(float(measured[key]))
				result.append({"rooms": rooms, "extra": extra, "gain": gain, "values": values})
	return result


func _measure(seed_value: int, rooms: int, extra: float, gain: float) -> Dictionary:
	var params := DungeonGenerator.Params.new()
	params.room_count = rooms
	params.extra_edge_ratio = extra
	params.elevation_gain = gain
	var blueprint := DungeonGenerator.new(seed_value, params).generate()
	var board := Metrics.from_blueprint(blueprint)
	var measured := Metrics.measure(board)

	var count := maxf(float(measured["rooms"]), 1.0)
	var highest := 0
	for id in blueprint.room_ids():
		highest = maxi(highest, blueprint.elevation_of(id))
	return {
		"rooms": float(measured["rooms"]),
		"avg_degree": float(measured["avg_degree"]),
		"cycles": float(measured["cycles"]),
		# 순환 계수를 방 개수로 나눈 값. 크기와 섞이지 않게 하려는 것이다.
		"cycle_density": float(measured["cycles"]) / count,
		"junction_pct": float(measured["deg3_pct"]),
		"diameter": float(measured["diameter"]),
		"dead_end_pct": float(measured["deg1_pct"]),
		"max_elev": float(highest),
		# 기본 민첩으로 못 가는 방의 비율. 고도가 실제로 막는 정도다.
		"locked_pct": 100.0 - float(measured["reach_pct"]),
		# 간선 하나당 평균 상승폭. **판이 커져도 커지지 않는다** — 최고 고도와 달리
		# 구역 수에 딸려 오지 않아서 규모와 섞이지 않는다.
		"climb_mean": _climb_mean(blueprint),
		# 상승 3 이상인 간선의 비율. 화면에서 빨간 선으로 보이는 것이다.
		"steep_pct": _steep_percent(blueprint),
		# 상승이 있는 간선의 비율. 많은 간선에 대한 비율이라 시드에 덜 흔들릴 것으로 보고 넣었다.
		"climb_edge_pct": _climbing_percent(blueprint),
	}


## 상승이 하나라도 있는 간선의 비율.
func _climbing_percent(blueprint: DungeonBlueprint) -> float:
	var climbing := 0.0
	var seen := 0.0
	for pair in blueprint.connections():
		if blueprint.elevation_of(pair[0]) != blueprint.elevation_of(pair[1]):
			climbing += 1.0
		seen += 1.0
	return 100.0 * climbing / maxf(seen, 1.0)


## 간선 하나당 평균 상승폭.
func _climb_mean(blueprint: DungeonBlueprint) -> float:
	var total := 0.0
	var seen := 0.0
	for pair in blueprint.connections():
		total += float(absi(blueprint.elevation_of(pair[0]) - blueprint.elevation_of(pair[1])))
		seen += 1.0
	return total / maxf(seen, 1.0)


## 상승 3 이상인 간선의 비율.
func _steep_percent(blueprint: DungeonBlueprint) -> float:
	var steep := 0.0
	var seen := 0.0
	for pair in blueprint.connections():
		if absi(blueprint.elevation_of(pair[0]) - blueprint.elevation_of(pair[1])) >= 3:
			steep += 1.0
		seen += 1.0
	return 100.0 * steep / maxf(seen, 1.0)


## 후보마다 **어느 입력에 반응하는가**를 신호대잡음으로 낸다.
##
## 표시할 값이 되려면 **하나의 입력에만 크게 반응해야** 한다. 여럿에 반응하면
## 플레이어가 그 수치를 보고 무엇을 기대할지 정할 수 없다.
func _print_axis_response(samples: Array) -> void:
	print("== 표시 후보가 어느 입력에 반응하나 (신호대잡음) ==")
	print("%-16s %8s %8s %8s %10s" % ["후보", "크기", "곁가지", "단차", "시드편차"])
	for key in _CANDIDATES:
		var noise := _mean_within_deviation(samples, key)
		var band := maxf(2.0 * noise, 0.0001)
		print(
			(
				"%-16s %8.2f %8.2f %8.2f %10.2f"
				% [
					key,
					_span(samples, key, "rooms", _ROOMS[0], _ROOMS[_ROOMS.size() - 1]) / band,
					_span(samples, key, "extra", _EXTRA[0], _EXTRA[_EXTRA.size() - 1]) / band,
					_span(samples, key, "gain", _GAIN[0], _GAIN[_GAIN.size() - 1]) / band,
					noise,
				]
			)
		)
	print("")
	print("1 아래면 시드가 더 크게 흔든다 — 표시하면 「운이 나빴다」로 읽힌다 (§17.16.2)")


## 후보끼리 얼마나 같이 움직이는가. 1 에 가까우면 같은 것을 두 번 보여 주는 셈이다.
func _print_correlation(samples: Array) -> void:
	print("")
	print("== 표시 후보끼리의 상관 (절댓값이 클수록 겹친다) ==")
	var header := "%-16s" % ""
	for key in _CANDIDATES:
		header += "%9s" % key.substr(0, 8)
	print(header)
	for row in _CANDIDATES:
		var line := "%-16s" % row
		for column in _CANDIDATES:
			line += "%9.2f" % _correlation(samples, row, column)
		print(line)
	print("")
	print("|상관| 0.8 이상이면 두 수치가 같은 것을 말한다 — 하나로 합쳐야 한다")


## 그 입력 축의 양 끝에서 후보값 평균이 얼마나 벌어지는가.
func _span(samples: Array, key: String, axis: String, low: Variant, high: Variant) -> float:
	return absf(_mean_where(samples, key, axis, high) - _mean_where(samples, key, axis, low))


func _mean_where(samples: Array, key: String, axis: String, value: Variant) -> float:
	var total := 0.0
	var seen := 0.0
	for sample in samples:
		if not is_equal_approx(float(sample[axis]), float(value)):
			continue
		total += _mean(sample["values"][key])
		seen += 1.0
	return total / maxf(seen, 1.0)


## 같은 입력에서 시드만 바꿨을 때의 편차. 격자 전체에 대해 평균낸다.
func _mean_within_deviation(samples: Array, key: String) -> float:
	var total := 0.0
	for sample in samples:
		total += _deviation(sample["values"][key])
	return total / maxf(float(samples.size()), 1.0)


## 격자점 평균끼리의 피어슨 상관.
func _correlation(samples: Array, first: String, second: String) -> float:
	var xs: Array[float] = []
	var ys: Array[float] = []
	for sample in samples:
		xs.append(_mean(sample["values"][first]))
		ys.append(_mean(sample["values"][second]))

	var mean_x := _mean(xs)
	var mean_y := _mean(ys)
	var top := 0.0
	var left := 0.0
	var right := 0.0
	for index in xs.size():
		var dx := xs[index] - mean_x
		var dy := ys[index] - mean_y
		top += dx * dy
		left += dx * dx
		right += dy * dy
	var bottom := sqrt(left * right)
	return 0.0 if bottom < 0.000001 else top / bottom


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


static func _deviation(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var average := _mean(values)
	var total := 0.0
	for value in values:
		total += (value - average) * (value - average)
	return sqrt(total / float(values.size()))
