extends SceneTree
## **눈금이 빠지는 속도가 전부를 정한다.** 빠짐 속도별로 몇 타에서 무엇이 되는지 잰다.
##
##     godot --headless --path . -s res://tools/survey_break_gauge.gd
##
## `docs/design/28-combat.md` §28.5 · §28.8 (무너짐 회복은 **미정**).
##
## ## 왜 이것을 재는가
##
## 빨리 빠지면 **긴 체인만** 의미가 있다 — 짧게 치면 차오르기 전에 도로 빠진다.
## 안 빠지면 **여러 번 나눠 쳐도** 되어 체인이 이어질 이유가 없어진다.
##
## **그 사이 어디에 값을 둘 것인가**가 이 시스템이 콤보 게임인지 아닌지를 정한다.
## 값은 정하지 않는다. 표만 낸다.

## 여기까지 쳐 보고 못 넘기면 "안 된다" 로 적는다.
const _MAX_HITS := 40

const _DECAYS: Array[float] = [0.0, 5.0, 10.0, 20.0, 40.0, 60.0, 80.0, 120.0]


func _initialize() -> void:
	var tuning := BreakTuning.new()
	print(
		(
			"문턱: 경직 %.0f · 띄우기 %.0f · 쓰러짐 %.0f · 타 간격 %.2f초"
			% [tuning.stagger_at, tuning.launch_at, tuning.knockdown_at, tuning.seconds_per_hit]
		)
	)
	print("**이 수치는 확정이 아니다.** 정할 때 보라고 내는 표다.")
	print("")
	_report_thresholds()
	_report_sample_items()
	_report_cliff()
	_report_gap()
	_report_duration()
	quit()


# ---------------------------------------------------------------- 몇 타부터인가


func _report_thresholds() -> void:
	print(
		(
			"== 빠짐 속도별로 몇 타에서 무엇이 되나 (1칸 무기, 한 방 %.0f) =="
			% (BreakTuning.new().poise_for(_uniform_item(1)))
		)
	)
	print("  %-12s %-10s %-10s %-10s %s" % ["초당 빠짐", "경직", "띄우기", "쓰러짐", "한 타 순증"])
	for decay in _DECAYS:
		var tuning := BreakTuning.new(decay)
		var gain := tuning.poise_for(_uniform_item(1)) - decay * tuning.seconds_per_hit
		print(
			(
				"  %-12s %-10s %-10s %-10s %+.1f"
				% [
					"%.0f" % decay,
					_hits_to(tuning, 1, BreakState.Kind.STAGGER),
					_hits_to(tuning, 1, BreakState.Kind.LAUNCH),
					_hits_to(tuning, 1, BreakState.Kind.KNOCKDOWN),
					gain,
				]
			)
		)
	print("")
	print("  한 타 순증이 0 이하면 아무리 쳐도 안 쌓인다 — 그 아래로는 체인이 무의미해진다.")
	print("")


## 그 단계에 닿는 데 필요한 최소 타 수. 못 닿으면 "안 된다".
func _hits_to(tuning: BreakTuning, cells: int, kind: BreakState.Kind) -> String:
	var items: Array[BackpackItem] = []
	for count in _MAX_HITS:
		items.append(_uniform_item(cells))
		var outcome := ChainBreakSim.run_items(items, tuning)
		if not BreakState.is_worse(kind, outcome.highest):
			return "%d타" % (count + 1)
	return "안 된다"


# ---------------------------------------------------------------- 무기 크기


func _report_sample_items() -> void:
	print("== 무기가 크면 (초당 20 빠짐) ==")
	print("  %-14s %-10s %-10s %s" % ["무기 크기", "경직", "띄우기", "쓰러짐"])
	for cells: int in [1, 2, 3, 4]:
		var tuning := BreakTuning.new(20.0)
		print(
			(
				"  %-14s %-10s %-10s %s"
				% [
					"%d칸 (한 방 %.0f)" % [cells, tuning.poise_for(_uniform_item(cells))],
					_hits_to(tuning, cells, BreakState.Kind.STAGGER),
					_hits_to(tuning, cells, BreakState.Kind.LAUNCH),
					_hits_to(tuning, cells, BreakState.Kind.KNOCKDOWN),
				]
			)
		)
	print("")
	print("  **큰 무기는 적은 타로 무너뜨리지만 칸을 먹어 체인이 짧아진다** (§28.20.15).")
	print("  그 거래가 이 시스템의 결정이다.")
	print("")


# ---------------------------------------------------------------- 절벽이 어디 있나


## **빠짐 속도에는 절벽이 있다.** 한 타로 오르는 것보다 타 사이에 빠지는 것이 크면
## 아무리 쳐도 안 쌓인다. 그 경계는 계산으로 나온다.
##
##     한계 빠짐 속도 = 한 방 무게 / 타 간격
##
## **그리고 그 경계가 무기 크기마다 다르다** — 그래서 빠짐 속도는 난이도 손잡이가
## 아니라 **어떤 무기가 쓸모 있는지를 고르는 체다.**
func _report_cliff() -> void:
	print("== 절벽 — 이 속도를 넘으면 그 무기로는 영영 못 무너뜨린다 ==")
	print("  %-16s %-14s %s" % ["무기 크기", "한계 빠짐 속도", "초당 40 에서"])
	for cells: int in [1, 2, 3, 4]:
		var tuning := BreakTuning.new(40.0)
		var limit := tuning.poise_for(_uniform_item(cells)) / tuning.seconds_per_hit
		print(
			(
				"  %-16s %-14s %s"
				% [
					"%d칸" % cells,
					"초당 %.0f" % limit,
					_hits_to(tuning, cells, BreakState.Kind.LAUNCH),
				]
			)
		)
	print("")
	print("  **같은 빠짐 속도에서 작은 무기는 죽고 큰 무기는 산다.**")
	print("  빠짐 속도를 올리는 것은 난이도가 아니라 무기 선택을 좁히는 것이다.")
	print("")


# ---------------------------------------------------------------- 나눠 쳐도 되나


func _report_gap() -> void:
	print("== 띄우기 문턱에서 눈금이 다 빠지는 데 걸리는 시간 ==")
	for decay in _DECAYS:
		if decay <= 0.0:
			print("  초당 %-5.0f  영원히 안 빠진다 — 나눠 쳐도 되므로 체인이 필요 없어진다" % decay)
			continue
		var seconds := BreakTuning.new(decay).launch_at / decay
		print("  초당 %-5.0f  %.2f초" % [decay, seconds])
	print("")
	print("  이 시간이 길면 교전 중에 몇 번이고 나눠 쳐서 쌓을 수 있다.")
	print("  짧으면 한 번의 체인 안에서 끝내야 한다 — 그때 배치가 진짜로 값을 한다.")


## **타 간격이 이제 진짜 값이다.** 계산 안의 수였는데 실시간이 되면 사람이 느끼는 속도다.
## 너무 빠르면 무너짐이 안 보이고 느리면 지루하다.
func _report_duration() -> void:
	var tuning := BreakTuning.new()
	print("")
	print("== 체인이 몇 초짜리인가 (타 간격 %.2f초) ==" % tuning.seconds_per_hit)
	for hits: int in [2, 3, 5, 8, 10, 12]:
		var items: Array[BackpackItem] = []
		for _index in hits:
			items.append(_uniform_item(1))
		var bout := SparringBout.new(items, tuning)
		print(
			(
				"  %2d타   %.2f초   (마무리 관찰 %.1f초 포함하면 %.2f초)"
				% [
					hits,
					bout.swing_seconds(),
					SparringBout.SETTLE_SECONDS,
					bout.swing_seconds() + SparringBout.SETTLE_SECONDS
				]
			)
		)
	print("")
	print("  타 간격을 바꾸면 이 표 전체가 움직인다. 무너짐 문턱과 함께 봐야 한다.")


func _uniform_item(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return BackpackItem.new(
		"w", "무기", BackpackItem.Kind.WEAPON, shape, Vector2i(0, 0), ChainDirection.Kind.RIGHT
	)
