class_name BreakTuning
extends RefCounted
## 무너짐 눈금의 수치들. **여기 있는 값은 하나도 확정이 아니다.**
##
## `docs/design/28-combat.md` §28.5 가 확정한 것은 **「체력과 별개로 무너짐이 있고
## 경직 · 띄우기 · 바닥 쓰러짐이 거기 얹힌다」** 까지다.
##
## §28.8 이 **미정**으로 남긴 것:
##
## - **무너짐 회복** (`decay_per_second` — 회복하는가, 얼마나 빨리)
## - 경직 · 띄우기가 **우리 대원에게도 걸리나**
## - **무너진 뒤 무엇이 되나**
##
## ## 그래서 값이 아니라 손잡이로 만든다
##
## 이 클래스를 갈아 끼우면 눈금이 통째로 달라진다. 굳은 수치가 코드 안에 박히지 않는다.
## `tools/survey_break_gauge.gd` 가 **빠짐 속도별로 몇 타에서 무엇이 되는지**를 재고,
## 그 표가 나중에 값을 정할 때의 재료다.
##
## ## 눈금이 빠지는 속도가 전부를 정한다
##
## 빨리 빠지면 긴 체인만 의미 있고, 안 빠지면 여러 번 나눠 쳐도 되어 체인이 필요 없어진다.
## **이 한 값이 「체인이 왜 필요한가」를 정한다.**

## 눈금의 최댓값. 여기까지 차면 더 안 오른다.
var max_value: float = 100.0

## 각 단계에 닿는 눈금. 오름차순이어야 한다.
var stagger_at: float = 30.0
var launch_at: float = 60.0
var knockdown_at: float = 100.0

## 초당 빠지는 양. **미정 중의 미정이다** (§28.8 「무너짐 회복」).
var decay_per_second: float = 20.0

## 한 타와 다음 타 사이의 시간. 체인이 도는 속도다.
var seconds_per_hit: float = 0.35

## 한 타의 기본 무게.
var poise_base: float = 6.0

## 아이템이 차지한 칸마다 더해지는 무게.
##
## **부피가 곧 한 방의 무게다.** 큰 무기는 세게 치지만 칸을 먹어서
## 체인을 짧게 만든다 (§28.20.15 — 큰 것만 있으면 작정해도 3 타뿐이다).
## **이것이 이 시스템의 거래다** — 한 방이 무거운 것과 여러 번 치는 것.
##
## > 이 관계 자체가 제안이다. 확정된 것이 아니다.
var poise_per_cell: float = 4.0


func _init(p_decay_per_second: float = 20.0) -> void:
	decay_per_second = p_decay_per_second


## 이 아이템 한 타가 눈금을 얼마나 올리나.
##
## 아이템에 수치를 따로 달지 않고 **모양에서 끌어낸다.** 그러면 표본을 늘릴 때마다
## 수치를 손으로 붙일 필요가 없고, 무엇보다 **부피와 무게가 어긋날 수 없다.**
func poise_for(item: BackpackItem) -> float:
	return poise_base + poise_per_cell * float(item.shape.size())


## 그 눈금이 어느 단계인가.
func state_for(value: float) -> BreakState.Kind:
	if value >= knockdown_at:
		return BreakState.Kind.KNOCKDOWN
	if value >= launch_at:
		return BreakState.Kind.LAUNCH
	if value >= stagger_at:
		return BreakState.Kind.STAGGER
	return BreakState.Kind.NONE
