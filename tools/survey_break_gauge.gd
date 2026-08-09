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
			"문턱: 경직 %.0f, 띄우기 %.0f, 쓰러짐 %.0f   검이 닿기까지 1칸 %.2f초 / 4칸 %.2f초"
			% [
				tuning.stagger_at,
				tuning.launch_at,
				tuning.knockdown_at,
				tuning.strike_seconds_for(_uniform_item(1)),
				tuning.strike_seconds_for(_uniform_item(4)),
			]
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
		var gain := (
			tuning.poise_for(_uniform_item(1)) - decay * tuning.strike_seconds_for(_uniform_item(1))
		)
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
		var limit := (
			tuning.poise_for(_uniform_item(cells)) / tuning.strike_seconds_for(_uniform_item(cells))
		)
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
	print("  **뒤집혔다.** 타 간격이 상수였을 때는 1칸 29 / 4칸 63 이라 큰 무기가 강했다.")
	print("  휘두르는 시간을 부피에서 뽑자 1칸 43 / 4칸 31 이 됐다 — **작은 무기가 더 강하다.**")
	print("  무게는 10->22 (2.2배) 인데 시간은 0.23->0.71 (3.1배) 라 초당 무게가 오히려 떨어진다.")
	print("  (오른쪽 칸의 「안 된다」는 %d타 안에 못 넘겼다는 뜻이다. 1칸은 순증 +0.8 이라 더 치면 된다.)" % _MAX_HITS)
	print("")
	_report_proportional_weight()


## **큰 무기가 값을 하려면 무게가 최소한 시간에 비례해야 한다.**
##
## 지금은 아니다. 그래서 큰 무기는 칸도 더 먹고, 시간도 더 걸리고, 감쇠에도 더 약하다 —
## **쓸 이유가 없다.**
##
## 아래는 「무게를 시간에 비례시키면 어떻게 되는가」를 재 본 것이다.
## **값을 바꾼 것이 아니다.** 정할 때 보라고 내는 표다 (§28.5 수치는 전부 미정).
func _report_proportional_weight() -> void:
	print("== 만약 무게를 휘두르는 시간에 비례시키면 (제안이지 채택이 아니다) ==")
	var reference := BreakTuning.new()
	# 1칸 무게를 그대로 두고 시간에 비례하도록 기울기를 잡는다.
	var rate := (
		reference.poise_for(_uniform_item(1)) / reference.strike_seconds_for(_uniform_item(1))
	)
	print("  %-10s %-14s %-14s %s" % ["무기", "지금 무게", "비례시킨 무게", "한계 빠짐 속도"])
	for cells: int in [1, 2, 3, 4]:
		var item := _uniform_item(cells)
		var proposed := rate * reference.strike_seconds_for(item)
		print(
			(
				"  %-10s %-14s %-14s %s"
				% [
					"%d칸" % cells,
					"%.0f" % reference.poise_for(item),
					"%.0f" % proposed,
					"초당 %.0f" % (proposed / reference.strike_seconds_for(item)),
				]
			)
		)
	print("")
	print("  그러면 한계가 전부 같아지고 부피 축이 **평평해진다** — 절벽이 무기를 안 고른다.")
	print("  대신 큰 무기의 값은 「적은 타로 끝낸다」와 「칸을 먹는다」로만 남는다.")
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
	print("== 체인이 몇 초짜리인가 — **무기 구성에 따라 다르다** ==")
	print("  %-10s %-12s %-12s %s" % ["체인 길이", "1칸만", "4칸만", "번갈아"])
	for hits: int in [2, 3, 5, 8, 10]:
		print(
			(
				"  %-10s %-12s %-12s %s"
				% [
					"%d타" % hits,
					"%.2f초" % _duration(tuning, hits, 1),
					"%.2f초" % _duration(tuning, hits, 4),
					"%.2f초" % _mixed_duration(tuning, hits),
				]
			)
		)
	print("")
	print("  **같은 5타라도 무기에 따라 길이가 세 배 갈린다.** 「5타 = 1.4초」는 이제 틀렸다.")


func _duration(tuning: BreakTuning, hits: int, cells: int) -> float:
	var items: Array[BackpackItem] = []
	for _index in hits:
		items.append(_uniform_item(cells))
	return SparringBout.new(items, tuning).swing_seconds()


## 1칸과 4칸을 번갈아 놓은 체인.
func _mixed_duration(tuning: BreakTuning, hits: int) -> float:
	var items: Array[BackpackItem] = []
	for index in hits:
		items.append(_uniform_item(1 if index % 2 == 0 else 4))
	return SparringBout.new(items, tuning).swing_seconds()


func _uniform_item(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return BackpackItem.new(
		"w", "무기", BackpackItem.Kind.WEAPON, shape, Vector2i(0, 0), ChainDirection.Kind.RIGHT
	)
