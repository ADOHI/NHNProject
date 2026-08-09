extends SceneTree
## **자세 쌍을 아이템에 붙이면 무엇이 걸리나.** 정하는 것이 아니라 재 보는 것이다.
##
##     godot --headless --path . -s res://tools/survey_guard_link.gd
##
## `docs/design/28-combat.md` §28.2.2 · §28.20.6 · §28.20.45 · §28.20.48.
##
## ## 왜 지금 이걸 재나
##
## §28.20.45 가 「누가 자세 쌍을 고르나」에 후보 셋을 적고 **아이템 성질** 쪽으로
## 기울어 있다고 했다. 근거가 셋이었다. **그럼 그 방향으로 한 판 만들어 보고
## 무엇이 걸리는지 봐야 한다.**
##
## §28.20.13 이 이미 시켜 둔 일이기도 하다:
## *"여기에 입력 셀이나 자세 조건을 얹으면 더 빡빡해진다. 정할 때 이 수치를 보고 정한다."*
##
## ## 코어를 안 고치고 잰다
##
## `ChainResolver` 가 `ChainLinkRule` 을 받으므로 **규칙을 여기서 만들어 넘기면 된다.**
## `BackpackItem` 에 필드를 안 붙여도 재진다 — 자세는 **옆 표**로 들고 있는다.
##
## **그것 자체가 첫 발견이다:** 재는 데는 필드가 필요 없다.
## 필드가 필요해지는 것은 **게임이 그 값을 들고 다녀야 할 때**다.

## 자세를 몇 가지로 두고 재나. 애니 레인은 넷인데 찌르기는 쓰는 동작이 없다 (§28.20.46).
const _GUARD_COUNTS: Array[int] = [2, 3, 4]

const _TRIALS := 300
const _PLACE_ATTEMPTS := 60


## 아이템 id -> [시작 자세, 마무리 자세]. **옆 표다** — 아이템에 안 붙인다.
class GuardTable:
	extends RefCounted

	var _pairs: Dictionary = {}

	## 자세를 `count` 가지로 두고 아이템마다 한 쌍씩 **결정적으로** 배당한다.
	##
	## **무작위로 배당하면 판마다 답이 달라진다.** 여기서 재는 것은 「어떤 배당이
	## 좋은가」가 아니라 「조건이 얼마나 빡빡해지는가」다.
	func _init(items: Array[BackpackItem], count: int) -> void:
		for index in items.size():
			var opening := index % count
			var closing := (index * 2 + 1) % count
			_pairs[items[index].id] = Vector2i(opening, closing)

	func opening(item: BackpackItem) -> int:
		return (_pairs.get(item.id, Vector2i.ZERO) as Vector2i).x

	func closing(item: BackpackItem) -> int:
		return (_pairs.get(item.id, Vector2i.ZERO) as Vector2i).y


## **앞 동작의 마무리 자세가 다음의 시작 자세여야 이어진다** (§28.20.6 의 후보 그대로).
class GuardLinkRule:
	extends ChainLinkRule

	var _table: GuardTable

	func _init(table: GuardTable) -> void:
		_table = table

	func can_link(from: BackpackPlacement, to: BackpackPlacement) -> bool:
		return _table.closing(from.item) == _table.opening(to.item)


func _initialize() -> void:
	var items := SampleBackpack.create_items()
	print("== 자세 쌍을 아이템에 붙이면 무엇이 걸리나 ==")
	print("  표본 %d 종 · 격자 6x6 · 시작 노드 1개 · 무작위 %d 판." % [items.size(), _TRIALS])
	print("  **정하는 것이 아니라 재 보는 것이다** (§28.20.45).")
	print("")
	_report_tightening(items)
	_report_frictions()
	quit()


# ---------------------------------------------------------------- 얼마나 빡빡해지나


func _report_tightening(items: Array[BackpackItem]) -> void:
	print("== 조건을 얹으면 얼마나 빡빡해지나 ==")
	print("  %-16s %-16s %-16s %s" % ["자세 가짓수", "표본 배치", "무작위 평균", "무작위 완주율"])

	var base_sample := _sample_length(null)
	var base_random := _random_average(items, null)
	print(
		(
			"  %-16s %-16s %-16s %s"
			% [
				"없음 (지금)",
				"%d타" % base_sample,
				"%.2f타" % base_random.x,
				"%.0f%%" % (base_random.y * 100.0)
			]
		)
	)

	for count in _GUARD_COUNTS:
		var table := GuardTable.new(items, count)
		var rule := GuardLinkRule.new(table)
		var sample := _sample_length(rule)
		var random := _random_average(items, rule)
		print(
			(
				"  %-16s %-16s %-16s %s"
				% [
					"%d 가지" % count,
					"%d타" % sample,
					"%.2f타" % random.x,
					"%.0f%%" % (random.y * 100.0),
				]
			)
		)
	print("")
	# **해설을 지금 잰 값에서 짓는다** (§28.20.29). 「자세가 적을수록 느슨하다」로
	# 적어 두려 했는데 표에 그게 안 나왔다 — 짐작을 적기 전에 재서 걸렸다.
	var tight := GuardLinkRule.new(GuardTable.new(items, 3))
	var after_sample := _sample_length(tight)
	var after_random := _random_average(items, tight).x
	print(
		(
			"  손으로 짠 것: %d타 -> %d타 (%.0f%% 로 준다)   아무렇게나: %.2f타 -> %.2f타 (%.0f%%)"
			% [
				base_sample,
				after_sample,
				100.0 * float(after_sample) / float(base_sample),
				base_random.x,
				after_random,
				100.0 * after_random / base_random.x,
			]
		)
	)
	print("")
	print("  **깎이는 쪽이 한쪽뿐이다.** 아무렇게나는 이미 바닥이라 더 깎일 것이 없고,")
	print("  작정하고 짠 것만 반토막 난다. **그래서 둘의 격차가 좁아진다** —")
	print("  §28.20.13 이 「그 격차가 결정이 사는 자리」라고 한 그 격차다.")
	print("  **깐깐한 조건이 결정을 무겁게 만들 것 같지만 여기서는 반대로 나왔다.**")
	print("")
	print("  자세 가짓수(2·3·4)는 **거의 차이가 없다.** 체인이 이미 짧아서 가짓수가")
	print("  걸릴 자리가 없다 — 밸런스 손잡이로 쓸 만한 축이 아니다.")
	print("")


## 표본 배치의 체인 길이.
func _sample_length(rule: ChainLinkRule) -> int:
	var grid := SampleBackpack.create_grid()
	SampleBackpack.fill(grid, SampleBackpack.create_items())
	var total := 0
	for chain in ChainResolver.resolve_all(grid, rule):
		total += chain.length()
	return total


## [평균 타수, 완주율].
func _random_average(items: Array[BackpackItem], rule: ChainLinkRule) -> Vector2:
	var total := 0
	var complete := 0
	for trial in _TRIALS:
		var rng := RandomNumberGenerator.new()
		rng.seed = trial * 31 + 7
		var grid := SampleBackpack.create_grid()
		_fill_randomly(grid, rng, items)
		for chain in ChainResolver.resolve_all(grid, rule):
			total += chain.length()
			if chain.is_complete():
				complete += 1
	return Vector2(float(total) / float(_TRIALS), float(complete) / float(_TRIALS))


func _fill_randomly(
	grid: BackpackGrid, rng: RandomNumberGenerator, items: Array[BackpackItem]
) -> void:
	var pool: Array[BackpackItem] = items.duplicate()
	pool.shuffle()
	for item in pool:
		var candidate := item
		for _turn in rng.randi_range(0, 3):
			candidate = candidate.rotated()
		for _attempt in _PLACE_ATTEMPTS:
			var origin := Vector2i(
				rng.randi_range(0, grid.width - 1), rng.randi_range(0, grid.height - 1)
			)
			if grid.place(candidate, origin) != null:
				break


# ---------------------------------------------------------------- 무엇이 걸렸나


## **수보다 이쪽이 중요하다.** 만들어 보니 걸린 것들이다.
func _report_frictions() -> void:
	print("== 만들어 보니 걸린 것 다섯 ==")
	print("")
	print("  1. **회전이 자세를 어떻게 하나**")
	print("     BackpackItem.rotated() 는 모양과 출력을 90도 돌린다. 자세도 돌아야 하나?")
	print("     자세는 방향이 아니라 **몸의 자세**라 안 돌 것 같은데, 그러면")
	print("     **회전이 자세를 안 바꾸는 유일한 성질**이 된다. 규칙이 하나 더 생긴다.")
	print("")
	print("  2. **첫 타의 시작 자세는 무엇과 맞나**")
	print("     체인의 첫 아이템 앞에는 아무것도 없다. 「제자리에서 시작한다」로 두면")
	print("     **시작 자세가 제자리인 아이템만 시작 노드에 놓을 수 있다.**")
	print("     그건 배치를 크게 조이는 규칙이고 아직 아무도 안 정했다.")
	print("")
	print("  3. **전리품에 자세가 있나**")
	print("     출력이 없어 체인의 끝이다. 마무리 자세는 쓸 데가 없고 시작 자세만 필요하다.")
	print("     **한 쌍이 아니라 반 쌍인 아이템이 생긴다.**")
	print("")
	print("  4. **자세가 실제로 몇 가지인가**")
	print("     애니 레인은 넷인데 찌르기는 쓰는 동작이 없다 (§28.20.46). 실질 셋이다.")
	print("     그런데 **위 표에서 가짓수가 거의 아무것도 안 바꿨다** — 손잡이가 못 된다.")
	print("")
	print("  5. **아이템에 고정하면 저쪽의 자유도를 우리가 없앤다**  <- 제일 크다")
	print("     애니 레인은 무기와 무관하게 자세 쌍을 만들어 두고 **부르는 쪽이 고르게** 했다.")
	print("     아이템에 한 쌍을 박으면 **같은 무기로 내려치기도 올려치기도 못 한다.**")
	print("     저쪽이 일부러 열어 둔 자유를 우리가 닫는 셈이다.")
	print("")
	print("  **그래서 제안하지 않는다.** 5번이 풀리기 전에는 「아이템 성질」이 답이라고 못 한다.")
	print("  아이템이 **자세 쌍 하나**가 아니라 **쓸 수 있는 자세 묶음**을 갖는 쪽이면")
	print("  자유도를 안 죽이는데, 그러면 체인 조건이 「맞아야 이어진다」가 아니라")
	print("  **「맞출 수 있으면 이어진다」**가 된다 — 조건의 성질 자체가 달라진다.")
