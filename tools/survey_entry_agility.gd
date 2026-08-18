extends SceneTree
## **던전이 요구하는 민첩** — 입장 제한을 걸 값을 고르기 위한 자.
##
##     godot --headless --path . -s res://tools/survey_entry_agility.gd
##
## 이 자가 내는 표는 §17.40 이다.
##
## ## 왜 필요한가
##
## §17.38.2 가 「민첩 한 칸이 절벽」임을 쟀다 — 민첩 2 에서 1 로 내려가면 판이
## 20~49%p 닫힌다. 그런데 지금은 **들어가 봐야 안다.** 스쿼드를 꾸려 들어간 뒤에
## 3 분의 1 만 열리는 것은 선택이 아니라 사고다.
##
## **그래서 「이 던전을 보려면 민첩 얼마가 필요한가」를 판이 스스로 말하게 한다.**
## 크기·성격처럼 입장 전에 보이는 값이 되고, 모자라면 못 들어간다.
##
## ## 물음은 **몇 %를 볼 수 있어야 하는가**다
##
## **「전부」로 잡으면 안 될 수 있다.** V2 가 민첩 0 탈출구를 보장하므로 판에 갇히지는
## 않고, **안쪽 일부를 못 가는 것은 의도된 대가**일 수 있다(§17.4 — 보스와 귀중품은
## 민첩을 치르고 얻는 것이다). 100% 를 요구하면 던전이 거의 다 막힐 수 있다.
##
## 그래서 **덮는 비율마다** 필요 민첩을 따로 내고, 그 정책에서 어느 스쿼드가
## 몇 판을 못 여는지까지 같이 낸다. **정책을 고르는 것이 이 표의 목적이다.**

const _SEEDS := 8

## 덮는 비율 후보. **이 중 하나를 고르는 것이 판정이다.**
const _COVERAGES := [1.00, 0.95, 0.90, 0.80]

## **막는 기준 후보.** 덮는 비율은 「얼마나 보나」를 묻는데, 막는 것은 그것과 다른 물음일
## 수 있다 — **「이 판이 성립하나」**다. 보스에 못 닿으면 클리어가 아예 없고,
## 방 몇 개를 못 보는 것은 §17.4 가 정한 **대가**다. 둘을 나란히 놓고 고른다.
const _TARGETS := ["보스 방", "귀중 방 전부", "탈출구"]

## 스쿼드 민첩 후보. 편성이 생기면 대원 평균이라 정수가 아닐 수 있지만,
## 통과 판정은 정수 비교라 여기서는 정수만 본다 (§14.3.1).
const _SQUADS := [0, 1, 2, 3, 4]

## 어떤 민첩으로도 안 닿는 방이 있을 때 쓰는 값. 실제로 나오면 표에 그대로 뜬다.
const _UNREACHABLE := 99


func _initialize() -> void:
	print("== 던전이 요구하는 민첩 (성격마다 크기 1~5 x 시드 %d) ==" % _SEEDS)
	print("")
	var needs := _collect()

	_print_by_character(needs)
	print("")
	_print_by_size(needs)
	print("")
	_print_blocked(needs)
	print("")
	_print_targets(needs)
	print("")
	print("덮는 비율 = 입구에서 그 민첩으로 닿는 방의 비율. **탈출구는 V2 가 민첩 0 으로 보장한다**")
	print("막히는 판 = 그 정책에서 스쿼드가 입장을 거절당하는 판의 비율")
	quit()


## 판마다 [성격, 크기, 덮는 비율별 필요 민첩] 을 모은다.
func _collect() -> Array:
	var rows := []
	for character in DungeonCatalog.count():
		for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
			for seed_value in _SEEDS:
				var params := SampleDungeons.params_for_size(size, character)
				var plan := DungeonGenerator.new(seed_value * 977 + character, params).generate()
				(
					rows
					. append(
						{
							"character": character,
							"size": size,
							"needs": _needs_of(plan),
							"targets": _targets_of(plan),
						}
					)
				)
	return rows


## 판 하나가 **자리마다** 요구하는 민첩. 순서는 `_TARGETS` 와 같다.
func _targets_of(plan: DungeonBlueprint) -> PackedInt32Array:
	var graph := plan.build()
	var costs := graph.required_agility_from(DungeonRoutes.entrance_of(plan))
	return PackedInt32Array(
		[
			_worst_of(costs, plan.rooms_of_kind(Room.Kind.BOSS)),
			_worst_of(costs, plan.rooms_of_kind(Room.Kind.TREASURE)),
			_worst_of(costs, plan.rooms_of_kind(Room.Kind.EXIT)),
		]
	)


## 그 종류의 방에 **전부** 닿는 데 드는 민첩. 그런 방이 없으면 0 이다.
func _worst_of(costs: Dictionary, ids: Array) -> int:
	var worst := 0
	for id in ids:
		worst = maxi(worst, int(costs.get(id, _UNREACHABLE)))
	return worst


## 판 하나가 덮는 비율마다 요구하는 민첩.
##
## **판정은 런타임 것을 쓴다** (`DungeonGraph.required_agility_from`).
## 여기서 다시 구현하면 게임과 다른 수를 조용히 내게 된다 (`conventions.md` §6.5).
func _needs_of(plan: DungeonBlueprint) -> PackedInt32Array:
	var graph := plan.build()
	var entrance := DungeonRoutes.entrance_of(plan)
	var costs := graph.required_agility_from(entrance)

	var ids := plan.room_ids()
	var sorted_costs := PackedInt32Array()
	for id in ids:
		sorted_costs.append(int(costs.get(id, _UNREACHABLE)))
	sorted_costs.sort()

	var result := PackedInt32Array()
	for coverage in _COVERAGES:
		# 「이 비율을 덮는 가장 싼 민첩」 = 정렬된 비용의 그 백분위.
		var index := clampi(
			int(ceil(float(coverage) * float(sorted_costs.size()))) - 1, 0, sorted_costs.size() - 1
		)
		result.append(sorted_costs[index])
	return result


func _print_by_character(rows: Array) -> void:
	print("성격마다 필요 민첩 (평균 / 최악) — 덮는 비율별")
	var header := "%-11s" % "성격"
	for coverage in _COVERAGES:
		header += "%14s" % ("%d%% 덮기" % int(coverage * 100.0))
	print(header)
	for character in DungeonCatalog.count():
		print(
			(
				"%-11s%s"
				% [
					DungeonCatalog.name_of(character),
					_cells(
						rows.filter(
							func(row: Dictionary) -> bool: return int(row["character"]) == character
						)
					),
				]
			)
		)


func _print_by_size(rows: Array) -> void:
	print("크기마다 필요 민첩 (평균 / 최악) — **크기를 따라 오르면 큰 던전이 통째로 막힌다**")
	var header := "%-11s" % "크기"
	for coverage in _COVERAGES:
		header += "%14s" % ("%d%% 덮기" % int(coverage * 100.0))
	print(header)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		print(
			(
				"%-11s%s"
				% [
					"크기 %d" % size,
					_cells(
						rows.filter(func(row: Dictionary) -> bool: return int(row["size"]) == size)
					),
				]
			)
		)


func _cells(rows: Array) -> String:
	var text := ""
	for index in _COVERAGES.size():
		var total := 0.0
		var worst := 0
		for row in rows:
			var need := int((row["needs"] as PackedInt32Array)[index])
			total += float(need)
			worst = maxi(worst, need)
		var mean := 0.0 if rows.is_empty() else total / float(rows.size())
		text += "%14s" % ("%.2f / %d" % [mean, worst])
	return text


## **자리를 기준으로 막으면 어떻게 되나.** 덮는 비율과 나란히 놓고 고른다.
func _print_targets(rows: Array) -> void:
	print("자리 기준 — 필요 민첩 (평균 / 최악) 과 민첩 2 스쿼드가 막히는 비율")
	print("%-13s%-16s%-16s%s" % ["자리", "필요 민첩", "성격별 최악", "민첩 2 막힘"])
	for index in _TARGETS.size():
		var total := 0.0
		var worst := 0
		var blocked := 0
		var by_character := PackedInt32Array()
		for character in DungeonCatalog.count():
			by_character.append(0)
		for row in rows:
			var need := int((row["targets"] as PackedInt32Array)[index])
			total += float(need)
			worst = maxi(worst, need)
			by_character[int(row["character"])] = maxi(by_character[int(row["character"])], need)
			if need > 2:
				blocked += 1
		print(
			(
				"%-13s%-16s%-16s%.0f%%"
				% [
					_TARGETS[index],
					"%.2f / %d" % [total / float(rows.size()), worst],
					str(by_character),
					100.0 * float(blocked) / float(rows.size()),
				]
			)
		)
	print("성격별 최악 순서: %s" % str(range(DungeonCatalog.count()).map(DungeonCatalog.name_of)))
	print("")
	# **보장을 걸 수 있는지는 「그 값이 존재하나」가 정한다.** 평균만 보면 1 짜리 판이
	# 있는 줄 알고 「목록에 하나는 넣자」로 가는데, 없으면 그건 못 거는 보장이다.
	print("보스 필요 민첩의 분포 — **1 이하가 있는가**")
	var histogram := {}
	for row in rows:
		var need := int((row["targets"] as PackedInt32Array)[0])
		histogram[need] = int(histogram.get(need, 0)) + 1
	var keys := histogram.keys()
	keys.sort()
	for key in keys:
		print(
			(
				"  민첩 %-3d %4d 판 (%.1f%%)"
				% [key, histogram[key], 100.0 * float(histogram[key]) / float(rows.size())]
			)
		)


## **정책마다 누가 못 들어가는가.** 이것이 고르는 근거다.
func _print_blocked(rows: Array) -> void:
	print("정책마다 막히는 판의 비율 (전체 %d 판)" % rows.size())
	var header := "%-11s" % "정책"
	for squad in _SQUADS:
		header += "%11s" % ("민첩 %d" % squad)
	print(header)
	for index in _COVERAGES.size():
		var line := "%-11s" % ("%d%% 덮기" % int(float(_COVERAGES[index]) * 100.0))
		for squad in _SQUADS:
			var blocked := 0
			for row in rows:
				if int((row["needs"] as PackedInt32Array)[index]) > squad:
					blocked += 1
			line += "%10.0f%%" % (100.0 * float(blocked) / float(rows.size()))
		print(line)
