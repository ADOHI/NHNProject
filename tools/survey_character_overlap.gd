extends SceneTree
## 성격 다섯이 **한 판만 보고 알아볼 수 있을 만큼** 갈리는가.
##
##     godot --headless --path . -s res://tools/survey_character_overlap.gd
##
## 이 자가 내는 표는 §17.31 이다.
##
## ## 왜 `survey_dungeon_characters.gd` 로는 안 되나
##
## 그 자는 **평균만** 낸다. 평균이 갈린다는 것은 "성격을 바꾸면 값이 움직인다"까지만
## 말하고, **"판 하나를 보고 어느 성격인지 알 수 있다"** 는 말해 주지 않는다.
## 값이 갈려도 **흩어진 폭이 그보다 넓으면 겹치고**, 겹치면 사람은 못 알아본다.
##
## `docs/conventions.md` §6.3 이 적은 그대로다 — **자가 대상을 잘못 고른 것이 아니라
## 통계를 잘못 고른 것**이고, 그쪽이 더 안 보인다. 그 자는 보장 확인(V2 가 성격마다
## 100% 인가)이 목적이라 그대로 두고, **알아볼 수 있는가는 이 자가 잰다.**
##
## ## 겹침을 재는 법
##
## 평균에 ±2 표준편차 띠를 붙여 이웃과 포개지는지 본다. §17.20.4 가 등급 단계 수를
## 정할 때 쓴 것과 **같은 방법**이라 결과를 나란히 읽을 수 있다.

const Metrics := preload("res://tools/dungeon_metrics.gd")

## 판정 크기. §17.27.7 이 "판정은 크기 3 안팎에서 한다"고 정했다.
const _SIZE := 3

const _RUNS := 20

## §17.30.3 이 제안한 복잡 경계. **성격마다 어떻게 갈리는지 함께 보려고 여기 둔다.**
## 채택되면 `DungeonGrade._COMPLEXITY_STEPS` 로 옮기고 이 줄을 지운다.
const _PROPOSED_COMPLEXITY := [2.42, 2.70]

## 재는 지표. [키, 화면 이름].
##
## **위 여섯은 전부 그래프 지표다.** 처음에는 그것만 쟀는데 다섯 중 **벌집 하나만**
## 짚어낼 수 있다고 나왔다. 그런데 그건 판이 아니라 **자가 눈이 하나뿐**이어서였다 —
## 성격 다섯이 흔드는 축은 서로 다르고 **그래프를 흔드는 것은 벌집뿐**이다
## (`DungeonCatalog`: 얕은 갱도·수직 회랑은 고도, 먼 출구는 막다른 방과 탈출구,
## 금고층은 방 종류).
##
## **아래 다섯을 더 넣어야 다섯 축을 다 본다.** 안 그러면 "네 성격이 이름표뿐"이라는
## **틀린 결론**이 나온다 (docs/design/17-dungeon-generation.md §17.31.1).
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


func _initialize() -> void:
	var samples := _collect()
	print("== 성격 다섯이 갈리나 (크기 %d, 성격마다 %d 판) ==" % [_SIZE, _RUNS])
	print("")
	_print_header()
	for entry in _METRICS:
		_print_metric(samples, String(entry[0]), String(entry[1]))
	print("")
	print("겹친쌍 : 열 쌍 중 ±2 표준편차 띠가 포개지는 쌍의 수. **0 이면 다섯이 다 갈린다**")
	print("")
	_print_identifiable(samples)
	print("")
	_print_pairs(samples)
	print("")
	_print_complexity()
	quit()


## 성격마다 판을 만들어 지표를 모은다. samples[키][성격] = 값 배열.
func _collect() -> Dictionary:
	var samples := {}
	for entry in _METRICS:
		samples[entry[0]] = []
	for character in DungeonCatalog.count():
		var per := {}
		for entry in _METRICS:
			per[entry[0]] = [] as Array[float]
		for run in _RUNS:
			var params := SampleDungeons.params_for_size(_SIZE, character)
			var plan := DungeonGenerator.new(run * 977 + character, params).generate()
			var measured := Metrics.measure(Metrics.from_blueprint(plan))
			measured.merge(_axis_values(plan))
			for entry in _METRICS:
				(per[entry[0]] as Array[float]).append(float(measured[entry[0]]))
		for entry in _METRICS:
			(samples[entry[0]] as Array).append(per[entry[0]])
	return samples


## 그래프 지표가 못 보는 축들. **성격 넷은 여기서만 갈린다.**
##
## 고도와 방 종류는 `dungeon_metrics.gd` 가 재지 않는다 — 그쪽은 판의 **모양**을 재는
## 자라서다. 성격을 알아보는 것은 모양만의 문제가 아니다.
func _axis_values(plan: DungeonBlueprint) -> Dictionary:
	var highest := 0
	for id in plan.room_ids():
		highest = maxi(highest, plan.elevation_of(id))

	var edges := plan.connections()
	var flat := 0.0
	for pair in edges:
		if plan.elevation_of(pair[0]) == plan.elevation_of(pair[1]):
			flat += 1.0

	return {
		"max_elev": float(highest),
		"flat_pct": 100.0 * flat / maxf(float(edges.size()), 1.0),
		"treasure": float(plan.rooms_of_kind(Room.Kind.TREASURE).size()),
		"hazard": float(plan.rooms_of_kind(Room.Kind.HAZARD).size()),
	}


func _print_header() -> void:
	var line := "%-11s" % "지표"
	for character in DungeonCatalog.count():
		line += "%-13s" % DungeonCatalog.name_of(character)
	print(line + "겹친쌍")


func _print_metric(samples: Dictionary, key: String, label: String) -> void:
	var bands := _bands(samples[key])
	var line := "%-11s" % label
	for band in bands:
		line += "%-13s" % ("%.1f+-%.1f" % [band[0], band[1]])
	print(line + "%d/10" % _overlapping_pairs(bands))


## 성격마다 [평균, 표준편차].
func _bands(per_character: Array) -> Array:
	var result: Array = []
	for values in per_character:
		var list: Array = values
		var total := 0.0
		for value in list:
			total += float(value)
		var mean := total / maxf(float(list.size()), 1.0)
		var variance := 0.0
		for value in list:
			variance += pow(float(value) - mean, 2.0)
		result.append([mean, sqrt(variance / maxf(float(list.size()), 1.0))])
	return result


## ±2 표준편차 띠가 포개지는 쌍의 수 (열 쌍 중).
func _overlapping_pairs(bands: Array) -> int:
	var count := 0
	for i in bands.size():
		for j in range(i + 1, bands.size()):
			if _overlaps(bands[i], bands[j]):
				count += 1
	return count


func _overlaps(a: Array, b: Array) -> bool:
	var a_low: float = a[0] - 2.0 * a[1]
	var a_high: float = a[0] + 2.0 * a[1]
	var b_low: float = b[0] - 2.0 * b[1]
	var b_high: float = b[0] + 2.0 * b[1]
	return a_low <= b_high and b_low <= a_high


## **한 판만 보고 알아볼 수 있는가.**
##
## 그 성격의 띠가 **나머지 넷 전부와** 안 겹치는 지표가 하나라도 있으면
## 그 지표 하나로 그 성격을 짚어낼 수 있다. 하나도 없으면 **이름표뿐이다.**
func _print_identifiable(samples: Dictionary) -> void:
	print("== 한 판만 보고 성격을 짚어낼 수 있나 ==")
	print("%-11s%-9s%-13s%s" % ["성격", "티나는판", "가장 센 지표", "홀로 떨어지는 지표"])
	for character in DungeonCatalog.count():
		var solo: Array[String] = []
		for entry in _METRICS:
			if _is_alone(_bands(samples[entry[0]]), character):
				solo.append(String(entry[1]))
		var best := _loudest(samples, character)
		var text := "  ".join(solo) if not solo.is_empty() else "(없다)"
		print(
			(
				"%-11s%-9s%-13s%s"
				% [DungeonCatalog.name_of(character), "%d%%" % int(best[1]), best[0], text]
			)
		)


## **그 성격의 판 중 몇 %가 한눈에 티가 나나** — 그리고 어느 지표에서.
##
## 띠 겹침(±2 표준편차)은 **「거의 모든 판이 갈리나」** 를 묻는 엄격한 자다.
## 그것만 보면 "안 갈린다"로 끝나는데, 실제로는 **판의 절반이 티가 날 수도** 있다.
## 그 둘은 다른 물음이고, 고를 때 쓰이는 것은 뒤쪽이다.
##
## 여기서는 그 성격의 판 하나하나를 놓고 **다른 넷의 띠 밖에 있나**를 센다.
## 밖에 있으면 그 판은 보는 순간 그 성격임이 드러난다.
func _loudest(samples: Dictionary, character: int) -> Array:
	var best_name := "-"
	var best_share := 0.0
	for entry in _METRICS:
		var bands := _bands(samples[entry[0]])
		var mine: Array = (samples[entry[0]] as Array)[character]
		var outside := 0.0
		for value in mine:
			if _outside_all_others(bands, character, float(value)):
				outside += 1.0
		var share := 100.0 * outside / maxf(float(mine.size()), 1.0)
		if share > best_share:
			best_share = share
			best_name = String(entry[1])
	return [best_name, best_share]


## 그 값이 **다른 성격 넷의 띠 전부**의 밖에 있는가.
func _outside_all_others(bands: Array, character: int, value: float) -> bool:
	for other in bands.size():
		if other == character:
			continue
		var low: float = bands[other][0] - 2.0 * bands[other][1]
		var high: float = bands[other][0] + 2.0 * bands[other][1]
		if value >= low and value <= high:
			return false
	return true


func _is_alone(bands: Array, character: int) -> bool:
	for other in bands.size():
		if other != character and _overlaps(bands[character], bands[other]):
			return false
	return true


## **지표 둘을 함께 보면 갈리나.**
##
## 지표 하나로는 아무도 못 짚는 성격이라도, **둘을 함께 보면** 갈릴 수 있다 —
## 다른 성격과 첫째에서 겹쳐도 둘째에서 안 겹치면 그 성격은 구분된다.
##
## 화면이 이미 수치를 셋(규모·복잡·험난) 띄우므로 **사람도 하나만 보지 않는다.**
## 그래서 「짚어낼 수 있나」의 진짜 물음은 조합 쪽이다.
func _print_pairs(samples: Dictionary) -> void:
	print("== 지표를 둘씩 묶으면 갈리나 ==")
	print("%-11s%s" % ["성격", "그 성격을 홀로 떼어 놓는 지표 짝"])
	for character in DungeonCatalog.count():
		var found: Array[String] = []
		for i in _METRICS.size():
			for j in range(i + 1, _METRICS.size()):
				var first := _bands(samples[_METRICS[i][0]])
				var second := _bands(samples[_METRICS[j][0]])
				if _alone_on_pair(first, second, character):
					found.append("%s+%s" % [_METRICS[i][1], _METRICS[j][1]])
		var text := "  ".join(found.slice(0, 3)) if not found.is_empty() else "(없다)"
		if found.size() > 3:
			text += "  ... 모두 %d 짝" % found.size()
		print("%-11s%s" % [DungeonCatalog.name_of(character), text])


## 그 짝에서 홀로인가 — **다른 성격마다 둘 중 하나에서라도 안 겹치면** 갈린다.
func _alone_on_pair(first: Array, second: Array, character: int) -> bool:
	for other in first.size():
		if other == character:
			continue
		if (
			_overlaps(first[character], first[other])
			and _overlaps(second[character], second[other])
		):
			return false
	return true


## 복잡 등급이 성격마다 어떻게 나오나.
##
## **경계 하나로 다섯을 다 맞출 수 있는지**가 §17.30.3 의 재절단 제안에 붙는다.
## 성격마다 분포가 크게 다르면 경계 하나로는 어느 성격에서든 「가운데가 가장 흔하게」를
## 만들 수 없다.
func _print_complexity() -> void:
	print("== 복잡 등급 분포 (크기 %d, 성격마다 %d 판) ==" % [_SIZE, _RUNS])
	print("%-11s%-15s%-15s%s" % ["성격", "지금 1/2/3", "제안 1/2/3", "평균 차수"])
	for character in DungeonCatalog.count():
		var now := [0, 0, 0]
		var proposed := [0, 0, 0]
		var total := 0.0
		for run in _RUNS:
			var params := SampleDungeons.params_for_size(_SIZE, character)
			var plan := DungeonGenerator.new(run * 977 + character, params).generate()
			var grade := DungeonGrade.of(plan)
			var degree := float(grade["average_degree"])
			now[clampi(int(grade["complexity"]) - 1, 0, 2)] += 1
			proposed[_step(degree, _PROPOSED_COMPLEXITY)] += 1
			total += degree
		print(
			(
				"%-11s%-15s%-15s%.3f"
				% [DungeonCatalog.name_of(character), str(now), str(proposed), total / float(_RUNS)]
			)
		)
	print("지금 경계 %s   제안 경계 %s" % [str(DungeonGrade._COMPLEXITY_STEPS), str(_PROPOSED_COMPLEXITY)])


## 경계 목록에서 몇 번째 칸인가. 0 부터 센다 (배열 색인으로 바로 쓴다).
func _step(value: float, steps: Array) -> int:
	var index := 0
	for edge in steps:
		if value >= float(edge):
			index += 1
	return index
