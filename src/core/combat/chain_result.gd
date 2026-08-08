class_name ChainResult
extends RefCounted
## 시작 노드 하나에서 풀려 나온 콤보 순서. **그리고 어디서 왜 멈췄는가.**
##
## `docs/design/28-combat.md` §28.10.5.
##
## ## 멈춘 이유를 왜 같이 내는가
##
## 이유가 없으면 화면에서 "왜 안 이어지지" 를 눈으로 추측하게 된다.
## 격자 밖을 가리킨 것과, 빈 칸을 가리킨 것과, 전리품에서 정상 종료한 것은
## 전부 「체인이 짧다」로 보이지만 고치는 방법이 다르다.

enum StopReason {
	NO_START_ITEM,  ## 시작 노드를 덮은 아이템이 없다. 체인이 시작조차 안 했다
	NO_OUTPUT,  ## 출력 블럭이 없는 아이템에 닿았다. **유일한 정상 종료다**
	OUT_OF_BOUNDS,  ## 출력 방향이 격자 밖을 가리킨다
	EMPTY_CELL,  ## 가리킨 칸이 비어 있다
	ALREADY_CHAINED,  ## 이미 체인에 들어온 아이템으로 돌아왔다 (고리)
	LINK_REJECTED,  ## 연결 조건이 거절했다 (ChainLinkRule)
	MAX_LENGTH,  ## 상한에 닿았다. 무한 방지용 안전장치
}

const _REASON_LABELS := {
	StopReason.NO_START_ITEM: "시작 노드가 비어 있다",
	StopReason.NO_OUTPUT: "출력 블럭이 없어 끝났다",
	StopReason.OUT_OF_BOUNDS: "격자 밖을 가리킨다",
	StopReason.EMPTY_CELL: "가리킨 칸이 비어 있다",
	StopReason.ALREADY_CHAINED: "이미 지나온 아이템이다",
	StopReason.LINK_REJECTED: "연결 조건이 막았다",
	StopReason.MAX_LENGTH: "길이 상한에 닿았다",
}

var start_node: Vector2i

## 발동 순서. 0 번이 시작 아이템이다.
var steps: Array[BackpackPlacement] = []

var stop_reason: StopReason = StopReason.NO_START_ITEM

## 체인이 끊긴 칸. 마지막 아이템의 출력 블럭이 가리킨 자리다.
## `has_break_cell` 이 거짓이면 값에 의미가 없다.
var break_cell: Vector2i = Vector2i.ZERO
var has_break_cell: bool = false


func _init(p_start_node: Vector2i) -> void:
	start_node = p_start_node


func length() -> int:
	return steps.size()


## 끊긴 것이 아니라 **끝난** 것인가.
##
## 전리품에 닿아 멈춘 것만이 정상 종료다 (§28.10.5). 나머지는 전부
## "여기서 더 갈 수 있었는데 못 갔다" 는 뜻이다.
func is_complete() -> bool:
	return stop_reason == StopReason.NO_OUTPUT


## 순서대로의 이름들. 화면과 테스트가 같은 것을 읽는다.
func item_names() -> PackedStringArray:
	var names := PackedStringArray()
	for placement in steps:
		names.append(placement.item.display_name)
	return names


func stop_label() -> String:
	return _REASON_LABELS[stop_reason]


static func reason_label(reason: StopReason) -> String:
	return _REASON_LABELS[reason]
