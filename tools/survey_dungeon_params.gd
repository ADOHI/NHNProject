extends SceneTree
## 파라미터를 하나씩 흔들어 **판이 실제로 얼마나 달라지는가**를 잰다.
##
## 지금은 파라미터 9개 중 8개가 전 던전 공통이고, 그래서 던전끼리 "강함"만 다르다
## (docs/design/07-level-design.md §7.3). 성격을 주려면 무엇을 흔들지 골라야 하는데,
## **흔들어도 판이 안 변하는 파라미터를 흔들면 잡음만 는다.**
##
## 그래서 축마다 낮음 / 지금 / 높음 세 값으로 돌려 **플레이어가 읽을 수 있는 지표**가
## 얼마나 움직이는지 본다. 안 움직이면 그 축은 성격이 될 수 없다.
##
##   godot --headless --path . -s res://tools/survey_dungeon_params.gd

const Metrics := preload("res://tools/dungeon_metrics.gd")

const _RUNS := 24
const _ROOMS := 50

## 흔들 축. [이름, 필드, 낮음, 지금, 높음]
##
## **고도 축의 뜻이 바뀌었다** (덩어리 3). `elevation_gain` 은 이제 "입구에서 방 하나
## 거리당 상승"이 아니라 **"구역 등급 하나당 단차"** 다. 그래서 값의 범위도 다시 잡았다.
const _AXES := [
	["곁가지 비율", "extra_edge_ratio", 0.08, 0.24, 0.48],
	["막다른 방 하한", "dead_end_ratio_min", 0.06, 0.14, 0.30],
	["구역 단차", "elevation_gain", 1.0, 2.0, 4.0],
	["층 안 기복", "elevation_amplitude", 0.4, 1.0, 2.4],
	["기복의 잔 정도", "elevation_frequency", 0.10, 0.22, 0.44],
	["탈출구 최소 거리", "exit_distance_ratio", 0.30, 0.65, 0.95],
	["귀중품 비율", "treasure_ratio", 0.05, 0.14, 0.30],
	["위험방 비율", "hazard_ratio", 0.05, 0.16, 0.36],
]


func _initialize() -> void:
	print("== 파라미터를 흔들면 판이 얼마나 달라지나 (방 %d개 목표, 시드 %d개) ==" % [_ROOMS, _RUNS])
	print("")
	print(
		(
			"%-16s %6s %6s %5s %5s %6s %6s %6s %6s %6s %6s"
			% ["축", "값", "차수", "d1%", "d3+%", "지름", "민첩2%", "탈출홉", "보스민첩", "귀중", "위험"]
		)
	)
	var spread := {}
	for axis in _AXES:
		var low := {}
		var high := {}
		for slot in range(2, 5):
			var measured := _row(String(axis[0]), String(axis[1]), float(axis[slot]), slot == 3)
			if slot == 2:
				low = measured
			elif slot == 4:
				high = measured
		spread[String(axis[0])] = _difference(low, high)
		print("")
	_signal_table(spread)
	print("차수=평균 연결 수 · d1=막다른 방 · 민첩2%=기본 민첩으로 닿는 방 · 탈출홉=입구에서 탈출구까지")
	print("보스민첩=보스 방의 필요 민첩 · 귀중/위험=그 종류 방의 개수")
	print("* 표시가 지금 값이다. 위아래로 움직이지 않는 지표는 그 축으로 성격을 만들 수 없다.")
	quit()


## 축 하나를 흔들었을 때와 시드를 흔들었을 때를 견줘 **성격이냐 운이냐**를 가른다.
##
## 던전마다 파라미터를 달리 주면 「이 던전은 저 던전과 다르다」가 되어야 하는데,
## **같은 던전 안에서 시드만 바꿔도 그만큼 흔들리면** 플레이어에게는 그냥
## 「이번 판은 운이 나빴다」로 읽힌다. 그 경계를 수로 놓는다.
##
##     신호대잡음 = |높음 - 낮음| / (시드 표준편차 x 2)
##
## 1 보다 크면 축을 흔든 폭이 시드가 흔드는 폭보다 넓다는 뜻이다.
func _signal_table(spread: Dictionary) -> void:
	var noise := _seed_noise()
	print("== 성격이냐 운이냐 — 축을 흔든 폭 / 시드가 흔드는 폭 ==")
	print("%-16s %10s %8s %8s %8s" % ["축", "가장 큰 지표", "축 폭", "시드폭", "신호대잡음"])
	for label in spread:
		var best := ""
		var best_ratio := 0.0
		var best_axis := 0.0
		var best_noise := 0.0
		for key in spread[label] as Dictionary:
			var band: float = 2.0 * float(noise.get(key, 0.0))
			if band <= 0.001:
				continue
			var ratio: float = float((spread[label] as Dictionary)[key]) / band
			if ratio > best_ratio:
				best_ratio = ratio
				best = key
				best_axis = float((spread[label] as Dictionary)[key])
				best_noise = band
		print("%-16s %10s %8.1f %8.1f %8.2f" % [label, best, best_axis, best_noise, best_ratio])
	print("")
	print("시드폭 = 같은 파라미터에서 시드만 바꿨을 때의 표준편차 x 2")
	print("신호대잡음이 1 아래면 그 축은 성격이 아니라 잡음으로 읽힌다.")


## 지금 값에서 시드만 바꿨을 때 각 지표가 얼마나 흔들리는가 (표준편차).
func _seed_noise() -> Dictionary:
	var samples := {}
	for run in _RUNS:
		var board := _build(run * 7919 + 5, "extra_edge_ratio", 0.24)
		var measured := Metrics.measure(board)
		var extra := _extras(board)
		var row := {
			"deg": float(measured["avg_degree"]),
			"d1": float(measured["deg1_pct"]),
			"d3": float(measured["deg3_pct"]),
			"diam": float(measured["diameter"]),
			"reach": float(measured["reach_pct"]),
			"exit": extra["exit_hops"],
			"boss": extra["boss_req"],
			"treasure": extra["treasure_n"],
			"hazard": extra["hazard_n"],
		}
		for key in row:
			if not samples.has(key):
				samples[key] = [] as Array[float]
			(samples[key] as Array[float]).append(float(row[key]))

	var result := {}
	for key in samples:
		result[key] = _deviation(samples[key])
	return result


static func _deviation(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	var average := total / float(values.size())
	var square := 0.0
	for value in values:
		square += (value - average) * (value - average)
	return sqrt(square / float(values.size()))


static func _difference(low: Dictionary, high: Dictionary) -> Dictionary:
	var result := {}
	for key in low:
		result[key] = absf(float(high.get(key, 0.0)) - float(low[key]))
	return result


func _row(label: String, field: String, value: float, is_current: bool) -> Dictionary:
	var totals := {}
	for key in ["deg", "d1", "d3", "diam", "reach", "exit", "boss", "treasure", "hazard"]:
		totals[key] = 0.0

	for run in _RUNS:
		var board := _build(run * 7919 + 5, field, value)
		var measured := Metrics.measure(board)
		totals["deg"] += float(measured["avg_degree"])
		totals["d1"] += float(measured["deg1_pct"])
		totals["d3"] += float(measured["deg3_pct"])
		totals["diam"] += float(measured["diameter"])
		totals["reach"] += float(measured["reach_pct"])
		var extra := _extras(board)
		totals["exit"] += extra["exit_hops"]
		totals["boss"] += extra["boss_req"]
		totals["treasure"] += extra["treasure_n"]
		totals["hazard"] += extra["hazard_n"]

	var runs := float(_RUNS)
	print(
		(
			"%-16s %6s %6.2f %5.1f %5.1f %6.1f %6.1f %6.1f %6.1f %6.1f %6.1f"
			% [
				label if is_current else "",
				("%.2f*" % value) if is_current else ("%.2f" % value),
				totals["deg"] / runs,
				totals["d1"] / runs,
				totals["d3"] / runs,
				totals["diam"] / runs,
				totals["reach"] / runs,
				totals["exit"] / runs,
				totals["boss"] / runs,
				totals["treasure"] / runs,
				totals["hazard"] / runs,
			]
		)
	)
	var averaged := {}
	for key in totals:
		averaged[key] = float(totals[key]) / runs
	return averaged


func _build(seed_value: int, field: String, value: float) -> Dictionary:
	var params := DungeonGenerator.Params.new()
	params.room_count = _ROOMS
	params.set(field, value)
	# 막다른 방 하한을 올릴 때 상한이 그 아래면 두 규칙이 서로 싸운다.
	if field == "dead_end_ratio_min":
		params.dead_end_ratio_max = maxf(params.dead_end_ratio_max, value + 0.12)
	return Metrics.from_blueprint(DungeonGenerator.new(seed_value, params).generate())


## Metrics 가 재지 않는 것들. 방 종류와 탈출구 거리는 이 도구에서만 쓴다.
func _extras(board: Dictionary) -> Dictionary:
	var count: int = (board["points"] as PackedVector2Array).size()
	var edges: Array[Vector2i] = board["edges"]
	var elevations: PackedInt32Array = board["elevations"]
	var kinds: Dictionary = board["kinds"]
	var entrance: int = board["entrance"]

	var hops := Metrics.depths(count, edges, entrance)
	var costs := Metrics.required_agility(count, edges, elevations, entrance)
	var result := {"exit_hops": 0.0, "boss_req": 0.0, "treasure_n": 0.0, "hazard_n": 0.0}
	for index in count:
		match kinds.get(index, Room.Kind.EMPTY):
			Room.Kind.EXIT:
				result["exit_hops"] = float(int(hops.get(index, 0)))
			Room.Kind.BOSS:
				result["boss_req"] = float(int(costs.get(index, 0)))
			Room.Kind.TREASURE:
				result["treasure_n"] += 1.0
			Room.Kind.HAZARD:
				result["hazard_n"] += 1.0
	return result
