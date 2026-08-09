extends SceneTree
## 성격 하나의 축 값을 바꿔 보고 **나머지 넷에 대해 알아볼 수 있게 되나**를 잰다.
##
##     godot --headless --path . -s res://tools/survey_character_candidate.gd
##
## 이 자가 내는 표는 §17.35 다.
##
## ## 무엇을 재나
##
## **「티 나는 판」** — 그 판 하나가 **나머지 네 성격의 ±2 표준편차 띠 밖**에 있는 비율.
## §17.34.3 이 정한 자다. 띠 겹침이 아니라 이것이 "한 판만 보고 알아보나"의 답이다.
##
## **나머지 넷의 띠는 고정이다.** 후보 성격만 흔들고 남들은 지금 값 그대로 둔다 —
## 비교 대상이 같이 움직이면 무엇 때문에 좋아졌는지 알 수 없다.
##
## ## 함께 보는 것 — 고치다가 다른 것을 깨지 않게
##
## 축을 세게 밀면 §17.12.6 의 목표(순환 계수 12~15, 갈림길 55~60%)나 V5 하한이 깨질 수
## 있다. **좋아진 것만 보고 채택하면 다른 데가 조용히 무너진다** — 그래서 같은 표에 낸다.

const Metrics := preload("res://tools/dungeon_metrics.gd")

const _SIZE := 3
const _RUNS := 20

## 살릴 성격. 0 = 얕은 갱도 (§17.34.3 에서 25% 로 홀로 낮다).
const _TARGET := 0

## 재는 지표. `survey_character_overlap.gd` 와 같은 열하나여야 견줄 수 있다.
const _METRICS: Array = [
	["rooms", "방 수"],
	["cycles", "순환 계수"],
	["deg3_pct", "갈림길%"],
	["diameter", "지름"],
	["boss_degree", "보스 차수"],
	["avg_degree", "평균 차수"],
	["deg1_pct", "막다른방%"],
	["max_elev", "최고 고도"],
	["flat_pct", "평지%"],
	["treasure", "귀중 방"],
	["hazard", "위험 방"],
]

## 후보. [이름, 곁가지, 단차]. 첫 줄이 지금 값이다.
const _CANDIDATES: Array = [
	["지금 (0.10 / 1.0)", 0.10, 1.0],
	["곁가지만 0.06", 0.06, 1.0],
	["곁가지만 0.03", 0.03, 1.0],
	["단차만 0.6", 0.10, 0.6],
	["단차만 0.3", 0.10, 0.3],
	["단차만 0.0", 0.10, 0.0],
	["둘 다 (0.06 / 0.3)", 0.06, 0.3],
	["둘 다 (0.03 / 0.0)", 0.03, 0.0],
]


func _initialize() -> void:
	var others := _other_bands()
	print("== %s 를 살릴 수 있나 (크기 %d, 후보마다 %d 판) ==" % [DungeonCatalog.name_of(_TARGET), _SIZE, _RUNS])
	print("나머지 넷의 띠는 지금 값으로 고정한다")
	print("")
	print(
		(
			"%-20s %9s %-12s %7s %7s %7s %6s %6s %6s"
			% ["후보", "티나는판", "가장 센 지표", "순환", "갈림길%", "막다른%", "최고", "V2%", "V3%"]
		)
	)
	for candidate in _CANDIDATES:
		_report(candidate, others)
	print("")
	print("티나는판 : 그 판이 나머지 넷의 띠 밖에 있는 비율. **높을수록 알아본다**")
	print("순환/갈림길 : §17.12.6 목표는 12~15 / 55~60%. **성격 하나가 벗어나도 되는지는 기획 판단**")
	print("막다른% : V5 하한 14% (얕은 갱도 기준). 밑돌면 정찰 지점이 모자란다")
	print("V2% : 민첩 0 으로 탈출구에 닿는 판의 비율. **100 이어야 한다** (§17.5 V2)")
	print("V3% : 귀중·보스 방이 민첩을 치르는 판의 비율. **판을 평평하게 만들면 여기가 깨진다**")
	quit()


## 나머지 네 성격의 지표별 [평균, 표준편차].
func _other_bands() -> Dictionary:
	var bands := {}
	for entry in _METRICS:
		bands[entry[0]] = []
	for character in DungeonCatalog.count():
		if character == _TARGET:
			continue
		var per := {}
		for entry in _METRICS:
			per[entry[0]] = [] as Array[float]
		for run in _RUNS:
			var params := SampleDungeons.params_for_size(_SIZE, character)
			var plan := DungeonGenerator.new(run * 977 + character, params).generate()
			var measured := _measure(plan)
			for entry in _METRICS:
				(per[entry[0]] as Array[float]).append(float(measured[entry[0]]))
		for entry in _METRICS:
			(bands[entry[0]] as Array).append(_band(per[entry[0]]))
	return bands


func _report(candidate: Array, others: Dictionary) -> void:
	var samples := {}
	for entry in _METRICS:
		samples[entry[0]] = [] as Array[float]
	samples["v2"] = [] as Array[float]
	samples["v3"] = [] as Array[float]
	for run in _RUNS:
		var params := SampleDungeons.params_for_size(_SIZE, _TARGET)
		params.extra_edge_ratio = float(candidate[1])
		params.elevation_gain = float(candidate[2])
		var plan := DungeonGenerator.new(run * 977 + _TARGET, params).generate()
		var measured := _measure(plan)
		for entry in _METRICS:
			(samples[entry[0]] as Array[float]).append(float(measured[entry[0]]))
		var guards := _guarantees(plan)
		(samples["v2"] as Array[float]).append(guards[0])
		(samples["v3"] as Array[float]).append(guards[1])

	var best_share := 0.0
	var best_name := "-"
	for entry in _METRICS:
		var outside := 0.0
		for value in samples[entry[0]] as Array[float]:
			if _outside_all(others[entry[0]], value):
				outside += 1.0
		var share := 100.0 * outside / float(_RUNS)
		if share > best_share:
			best_share = share
			best_name = String(entry[1])

	print(
		(
			"%-20s %8d%% %-12s %7.1f %7.1f %7.1f %6.1f %6.0f %6.0f"
			% [
				candidate[0],
				int(round(best_share)),
				best_name,
				_mean(samples["cycles"]),
				_mean(samples["deg3_pct"]),
				_mean(samples["deg1_pct"]),
				_mean(samples["max_elev"]),
				_mean(samples["v2"]),
				_mean(samples["v3"]),
			]
		)
	)


func _outside_all(bands: Array, value: float) -> bool:
	for band in bands:
		if value >= band[0] - 2.0 * band[1] and value <= band[0] + 2.0 * band[1]:
			return false
	return true


func _band(values: Array[float]) -> Array:
	var mean := _mean(values)
	var variance := 0.0
	for value in values:
		variance += pow(value - mean, 2.0)
	return [mean, sqrt(variance / maxf(float(values.size()), 1.0))]


func _mean(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total / maxf(float(values.size()), 1.0)


func _measure(plan: DungeonBlueprint) -> Dictionary:
	var measured: Dictionary = Metrics.measure(Metrics.from_blueprint(plan))
	var highest := 0
	for id in plan.room_ids():
		highest = maxi(highest, plan.elevation_of(id))
	var edges := plan.connections()
	var flat := 0.0
	for pair in edges:
		if plan.elevation_of(pair[0]) == plan.elevation_of(pair[1]):
			flat += 1.0
	(
		measured
		. merge(
			{
				"max_elev": float(highest),
				"flat_pct": 100.0 * flat / maxf(float(edges.size()), 1.0),
				"treasure": float(plan.rooms_of_kind(Room.Kind.TREASURE).size()),
				"hazard": float(plan.rooms_of_kind(Room.Kind.HAZARD).size()),
			}
		)
	)
	return measured


## 보장 둘을 판마다 확인한다. [V2, V3] 를 100 또는 0 으로 돌려준다.
##
## **판을 평평하게 만들면 V3 가 깨질 수 있다** — 고도가 없으면 귀중·보스 방에 오르는
## 대가가 사라진다(§17.4). 좋아진 것만 보고 채택하지 않으려고 같이 잰다.
func _guarantees(plan: DungeonBlueprint) -> Array:
	var graph := plan.build()
	var entrance := DungeonRoutes.entrance_of(plan)
	var costs := graph.required_agility_from(entrance)

	var exits := plan.rooms_of_kind(Room.Kind.EXIT)
	var v2 := 100.0 if not exits.is_empty() and int(costs.get(exits[0], 99)) == 0 else 0.0

	var prized := plan.rooms_of_kind(Room.Kind.BOSS)
	prized.append_array(plan.rooms_of_kind(Room.Kind.TREASURE))
	var costly := 0
	for id in prized:
		if int(costs.get(id, 0)) > 0:
			costly += 1
	var v3 := 100.0 if not prized.is_empty() and costly > 0 else 0.0
	return [v2, v3]
