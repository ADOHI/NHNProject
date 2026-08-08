extends SceneTree
## 방 개수를 올렸을 때 **무엇이 무너지는가**를 잰다.
##
## 사용자 요구는 방 50개다. 지금 슬라이더 최대가 32 안팎이라 그 밖의 영역이다
## (docs/design/17-dungeon-generation.md §17.13).
##
## 지금 생성기와 설계안 프로토타입을 같은 개수에서 나란히 잰다.
##
##   godot --headless --path . -s res://tools/survey_dungeon_scale.gd

const Metrics := preload("res://tools/dungeon_metrics.gd")
const Proto := preload("res://tools/proto_organic_dungeon.gd")

const _RUNS := 40
const _COUNTS: Array[int] = [12, 22, 32, 50, 64]

const _COLUMNS: Array[String] = [
	"rooms",
	"edges",
	"cycles",
	"avg_degree",
	"deg1_pct",
	"deg2_pct",
	"deg3_pct",
	"diameter",
	"reach_pct",
	"alt_pct",
	"boss_alt_pct",
	"dominated_pct",
	"climb_fast",
	"climb_slow",
	"valuable_degree",
	"valuable_elev_pct",
]


func _initialize() -> void:
	print("== 방 개수를 올리면 (판마다 %d 회) ==" % _RUNS)
	_table("현재 생성기", true)
	print("")
	_table("설계안 프로토타입", false)
	print("")
	print("cycles=E-V+1 · diam=지름 · reach=민첩 2 로 닿는 방 %")
	print("alt=귀중 방 중 대안 경로 보유 % · dom=최단이 더 완만하기까지 한 %")
	print("valDeg=귀중 방의 평균 연결 수 · valEl=귀중 방 고도 백분위 · ms=생성 시간")
	quit()


func _table(title: String, current: bool) -> void:
	print("-- %s --" % title)
	print(
		(
			"%-6s %6s %6s %6s %5s %5s %5s %5s %5s %6s %5s %6s %5s %6s %6s %6s %6s"
			% [
				"want",
				"rooms",
				"edges",
				"cycles",
				"deg",
				"d1%",
				"d2%",
				"d3+%",
				"diam",
				"reach%",
				"alt%",
				"bAlt%",
				"dom%",
				"climbF",
				"climbS",
				"valDeg",
				"ms"
			]
		)
	)
	for wanted in _COUNTS:
		_row(wanted, current)


func _row(wanted: int, current: bool) -> void:
	var totals := {}
	for key in _COLUMNS:
		totals[key] = 0.0
	var elapsed := 0.0
	var runs := 0

	for run in _RUNS:
		var started := Time.get_ticks_usec()
		var board := _build(run * 7919 + wanted, wanted, current)
		elapsed += float(Time.get_ticks_usec() - started) / 1000.0
		if board.is_empty():
			continue
		runs += 1
		var measured := Metrics.measure(board)
		for key in _COLUMNS:
			totals[key] += float(measured.get(key, 0.0))

	var seen := maxf(float(runs), 1.0)
	print(
		(
			(
				"%-6d %6.1f %6.1f %6.1f %5.2f %5.1f %5.1f %5.1f %5.1f %6.1f"
				+ " %5.1f %6.1f %5.1f %6.2f %6.2f %6.2f %6.2f"
			)
			% [
				wanted,
				totals["rooms"] / seen,
				totals["edges"] / seen,
				totals["cycles"] / seen,
				totals["avg_degree"] / seen,
				totals["deg1_pct"] / seen,
				totals["deg2_pct"] / seen,
				totals["deg3_pct"] / seen,
				totals["diameter"] / seen,
				totals["reach_pct"] / seen,
				totals["alt_pct"] / seen,
				totals["boss_alt_pct"] / seen,
				totals["dominated_pct"] / seen,
				totals["climb_fast"] / seen,
				totals["climb_slow"] / seen,
				totals["valuable_degree"] / seen,
				elapsed / float(_RUNS),
			]
		)
	)


func _build(seed_value: int, wanted: int, current: bool) -> Dictionary:
	if not current:
		return Proto.build(seed_value, wanted)
	var params := DungeonGenerator.Params.new()
	params.room_count = wanted
	return Metrics.from_blueprint(DungeonGenerator.new(seed_value, params).generate())
