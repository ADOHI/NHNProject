class_name ChainBreakSim
extends RefCounted
## 체인을 무너짐 눈금에 통과시킨다. **여기서 「10타가 왜 좋은가」가 답해진다.**
##
## `docs/design/28-combat.md` §28.5.
##
## [codeblock]
## 한 타 친다  ->  눈금이 그 무기 무게만큼 오른다
##      ->  다음 타까지 시간이 흐른다  ->  그만큼 눈금이 빠진다
##      ->  반복
## [/codeblock]
##
## ## 눈금이 빠지는 속도가 전부를 정한다
##
## 빨리 빠지면 **긴 체인만** 눈금을 넘긴다 — 짧게 치면 차오르기 전에 도로 빠진다.
## 안 빠지면 **여러 번 나눠 쳐도** 되어 체인이 이어질 이유가 없어진다.
##
## 그래서 이 값은 `BreakTuning` 에 손잡이로 있고 **아직 정해지지 않았다** (§28.8).
## `tools/survey_break_gauge.gd` 가 빠짐 속도별로 몇 타에서 무엇이 되는지를 잰다.
##
## ## 마지막 타 뒤에는 시간을 흘리지 않는다
##
## 체인이 끝난 순간의 눈금이 그 체인의 성과다. 끝난 뒤에 빠지는 것은
## **다음 교전의 이야기**이지 이 체인의 결과가 아니다.


## 체인 하나를 돌린다.
static func run(chain: ChainResult, tuning: BreakTuning = null) -> ChainBreakOutcome:
	return run_items(_items_of(chain), tuning)


## 아이템 목록을 순서대로 친다. 체인 없이 재 볼 때 쓴다 (측정 도구).
static func run_items(items: Array[BackpackItem], tuning: BreakTuning = null) -> ChainBreakOutcome:
	var rules := tuning if tuning != null else BreakTuning.new()
	var gauge := BreakGauge.new(rules)
	var outcome := ChainBreakOutcome.new()

	# **한 타의 시간은 그 무기의 것이다** — 휘두르는 동안 눈금이 빠지고, 그 끝에 닿는다.
	# 무거운 무기는 세게 치지만 그만큼 오래 걸려서 그동안 더 빠진다.
	for item in items:
		gauge.tick(rules.strike_seconds_for(item))
		gauge.hit_with(item)
		outcome.record(gauge.value(), gauge.state())
	return outcome


static func _items_of(chain: ChainResult) -> Array[BackpackItem]:
	var items: Array[BackpackItem] = []
	for placement in chain.steps:
		items.append(placement.item)
	return items
