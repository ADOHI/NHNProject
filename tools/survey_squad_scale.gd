extends SceneTree
## **몇 명짜리 스쿼드가 몇 명짜리 적을 이기나.** 대련장을 실제로 굴려 잰다.
##
##     godot --headless --path . -s res://tools/survey_squad_scale.gd
##
## `docs/design/28-combat.md` §28.6 · §28.20.36.
##
## ## 왜 이 표가 필요한가
##
## 사용자 구술: *"숫자가 엄청 많이 나오거나 겁나 쎈 한 마리 나오려면
## **사람은 스쿼드니까 한계가 있고 몬스터여야 가능**하거든."*
##
## **그 「한계」가 어디인지 지금까지 아무 수도 없었다.** §28.20.35 가 잰 것은
## 대원 하나가 적 1~3 에게 맞을 때였다. 우리도 여럿이면 그 표가 뒤집히는지를 여기서 본다.
##
## ## 측정 가정 넷 — **규칙이 아니다**
##
## 1. **전원이 같은 자리에 선다.** 자리와 붙는 순서는 §28.4 의 RTS 자동 이동이 정할 일이다
## 2. **적이 대원을 번갈아 문다** (적 i -> 대원 i % M). 한 명에게 몰면 스쿼드가 실제보다
##    약하게 나오고, 나눠 물리면 스쿼드에게 **가장 좋은 쪽**이다. 상한을 재는 셈이다
## 3. **체인은 계속 돈다.** §28.2.1 이 *"체인은 그냥 콤보어택 같은 거야"* 로 확정했으므로
##    표본 체인을 이어 붙여 길게 준다. 한 번 내고 멈추면 그건 교전이 아니다
## 4. **일어나기는 없다.** §28.5 미정이라 만들지 않는다
##
## ## 두 판을 나란히 낸다
##
## §28.8 이 *"경직 · 띄우기가 우리 대원에게도 걸리나"* 를 미정으로 뒀다.
## **끊는 쪽과 안 끊는 쪽을 둘 다 낸다. 값은 안 박는다.**

## 대원마다 줄 체인 길이. 표본 체인을 이 길이까지 이어 붙인다.
const _CHAIN_HITS := 80

## 여기까지 굴려도 안 끝나면 "안 난다" 로 적는다.
const _MAX_SECONDS := 60.0

const _STEP := 1.0 / 120.0

## 적들이 서는 자리. 전원이 서로 리치 안이라 **붙어서 싸우는** 판이다.
const _NEAR := 60.0
const _SPACING := 4.0

const _SQUAD_SIZES: Array[int] = [1, 2, 3, 4]
const _ENEMY_SIZES: Array[int] = [1, 2, 3, 4, 6]


func _initialize() -> void:
	var tuning := BreakTuning.new()
	print("== 몇 명짜리 스쿼드가 몇 명짜리 적을 이기나 ==")
	print(
		(
			"문턱 %.0f / %.0f / %.0f   감쇠 초당 %.0f"
			% [tuning.stagger_at, tuning.launch_at, tuning.knockdown_at, tuning.decay_per_second]
		)
	)
	print("**측정 가정이 넷 있다. 규칙이 아니다** — 파일 머리말에 적어 뒀다.")
	print("")
	print('  칸 읽는 법:  "3.4초" = 그때 적 전원을 눕혔다 (이김)')
	print('               "패 2.1초" = 그때 우리 전원이 먼저 누웠다')
	print('               "무승부" = 60초 안에 어느 쪽도 전원이 안 누웠다')
	print("")
	_report_table(BreakState.Kind.NONE, true, false, "가. 양쪽 다 1칸 무기 — 수만 다르다")
	_report_table(BreakState.Kind.NONE, false, false, "나. 표본 백팩 대 2칸 무기 적 (지금 값)")
	_report_table(BreakState.Kind.NONE, false, true, "다. 나와 같되 걸침을 켰다 (부피대로)")
	_report_table(BreakState.Kind.KNOCKDOWN, false, false, "라. 나와 같되 쓰러지면 그동안 못 친다")
	_report_difference()
	quit()


# ---------------------------------------------------------------- 표


func _report_table(cut: BreakState.Kind, matched: bool, splash: bool, title: String) -> void:
	print("== %s ==" % title)
	var header := "  %-10s" % "대원 / 적"
	for enemies in _ENEMY_SIZES:
		header += "%-14s" % ("%d명" % enemies)
	print(header)
	for squad in _SQUAD_SIZES:
		var line := "  %-10s" % ("%d명" % squad)
		for enemies in _ENEMY_SIZES:
			line += "%-14s" % _cell(squad, enemies, cut, matched, splash)
		print(line)
	print("")


## 한 칸. 이겼으면 "3.4초", 졌으면 "패 2.1초", 아무도 안 눕으면 "무승부".
func _cell(
	squad: int, enemies: int, cut: BreakState.Kind, matched: bool = false, splash: bool = false
) -> String:
	var outcome := _fight(squad, enemies, cut, matched, splash)
	var ours := outcome.x
	var theirs := outcome.y
	if theirs < INF and (ours == INF or theirs < ours):
		return "%.1f초" % theirs
	if ours < INF:
		return "패 %.1f초" % ours
	return "무승부"


## 한 판. [우리 전원이 쓰러진 시각, 적 전원이 쓰러진 시각]. 안 났으면 INF.
func _fight(squad: int, enemies: int, cut: BreakState.Kind, matched: bool, splash: bool) -> Vector2:
	var tuning := BreakTuning.new()
	tuning.chain_cut_at = cut
	if splash:
		tuning.splash_base = BreakTuning.VOLUME_SPLASH_BASE
		tuning.splash_per_cell = BreakTuning.VOLUME_SPLASH_PER_CELL

	var xs := PackedFloat32Array()
	for index in enemies:
		xs.append(_NEAR + float(index) * _SPACING)
	var field := SparringField.new()
	field.reset_with(0.0, xs)

	var chains: Array = []
	for _index in squad:
		chains.append(_uniform_chain() if matched else _repeating_chain())
	var bout := SparringBout.from_squad(chains, tuning, field, _sized(1 if matched else 2))
	bout.start()

	var clock := 0.0
	var ours := INF
	var theirs := INF
	while clock < _MAX_SECONDS and bout.is_running():
		bout.tick(_STEP)
		clock += _STEP
		if ours == INF and _all_down(bout, true, squad):
			ours = clock
		if theirs == INF and _all_down(bout, false, enemies):
			theirs = clock
		if ours < INF and theirs < INF:
			break
	return Vector2(ours, theirs)


## 그쪽 전원이 **쓰러짐 문턱을 한 번이라도 넘었나.**
##
## 지금 값이 아니라 최고 기록으로 본다 — 눈금은 빠지므로 지금 값으로 재면
## 「전원이 동시에 누워 있는 순간」이라는 훨씬 센 조건이 된다.
func _all_down(bout: SparringBout, ours: bool, count: int) -> bool:
	for index in count:
		var gauge := bout.ally_gauge(index) if ours else bout.enemy_gauge(index)
		if BreakState.is_worse(BreakState.Kind.KNOCKDOWN, gauge.peak_state()):
			return false
	return true


# ---------------------------------------------------------------- 무엇이 갈리나


## **끊는 쪽과 안 끊는 쪽의 차이가 이 물음의 전부다.**
##
## 해설에 수치를 박지 않는다 (§28.20.29 — 이 레인에서 두 번 거짓말했다).
## 지금 잰 값에서 문장을 짓는다.
func _report_difference() -> void:
	print("== 끊으면 무엇이 달라지나 (표본 판, 걸침 끔) ==")
	print("  %-14s %-14s %-14s %s" % ["판", "2대1", "3대3", "1대4"])
	var rows: Array = [
		[BreakState.Kind.NONE, "안 끊는다"],
		[BreakState.Kind.KNOCKDOWN, "쓰러지면"],
		[BreakState.Kind.STAGGER, "경직이면"],
	]
	for row in rows:
		var cut: BreakState.Kind = row[0]
		print(
			(
				"  %-14s %-14s %-14s %s"
				% [row[1], _cell(2, 1, cut), _cell(3, 3, cut), _cell(1, 4, cut)]
			)
		)
	print("")
	print("  끊으면 **먼저 무너뜨린 쪽이 그만큼 더 때린다** — 판이 한쪽으로 쏠린다.")
	print("  안 끊으면 무너짐은 연출이고 싸움은 순수한 화력 싸움이다.")
	print("  **어느 쪽이 옳다는 표가 아니다.** 값은 안 박았다 (§28.8 미정).")
	print("")
	print("== 표에서 제일 크게 읽히는 것 ==")
	print("  **동수(대각선)에서 우리가 진다.** 그런데 까닭이 화력이 아니다 —")
	print("  전원이 **가장 가까운 적 하나만** 때려서 뒷줄이 영영 안 맞기 때문이다.")
	print("  적을 하나 눕혀도 그 뒤가 그대로 남으므로 스쿼드를 키워도 안 뒤집힌다.")
	print("")
	print("  **답 후보가 둘이다. 둘 다 아직 없다.**")
	print("   1. 걸침 (§28.20.34 물음 1) — 표 다가 그것이다. 2 명까지 풀린다")
	print("   2. 대원마다 다른 적을 고르는 것 (§28.20.34 물음 2 — 지금은 NEAREST 하나뿐)")
	print("")
	print("  **그래서 물음 2 는 보이던 것보다 크다.** 걸침이 없어도 저것만으로 물량이 풀린다.")


## 양쪽이 같은 무기를 들었을 때. **수 말고 다른 것이 안 섞이게** 하는 판이다.
func _uniform_chain() -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for _index in _CHAIN_HITS:
		items.append(_sized(1))
	return items


# ---------------------------------------------------------------- 표본


## 표본 배치의 체인을 **계속 도는 평타**로 만든다 (§28.2.1).
func _repeating_chain() -> Array[BackpackItem]:
	var base := _sample_chain()
	if base.is_empty():
		base = [_sized(1)]
	var items: Array[BackpackItem] = []
	while items.size() < _CHAIN_HITS:
		items.append(base[items.size() % base.size()])
	return items


func _sample_chain() -> Array[BackpackItem]:
	var grid := SampleBackpack.create_grid()
	SampleBackpack.fill(grid, SampleBackpack.create_items())
	var items: Array[BackpackItem] = []
	for chain in ChainResolver.resolve_all(grid):
		for placement in chain.steps:
			items.append(placement.item)
	return items


func _sized(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return BackpackItem.new(
		"w%d" % cells,
		"무기%d" % cells,
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)
