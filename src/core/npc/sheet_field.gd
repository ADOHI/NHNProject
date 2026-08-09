class_name SheetField
extends RefCounted
## 상세 화면의 한 줄. **값이 아니라 「상태를 가진 값」이다.**
##
## docs/design/24-npc-relations.md §24.17.7.
##
## ## 왜 상태가 필요한가
##
## 상세 화면에는 세 가지가 섞여 있다 — 값이 있는 것, **아직 안 만든 것**,
## **있지만 이 문맥에서 안 보이는 것**. 이 셋을 빈 문자열로 뭉개면
## 화면이 *"아직 안 만들었다"* 와 *"당신이 모른다"* 를 같은 말로 하게 되고,
## **개발 중에 미구현을 게임 규칙으로 착각한다.**
##
## `MISSING` 과 `HIDDEN` 을 가른 것이 이 구조의 값이다.
##
## ## 가림은 상태를 바꾸는 것이다
##
## 문맥(disclosure)이 `FILLED` 을 `HIDDEN` 으로 **내릴 수만** 있다.
## `MISSING` 은 못 건드린다 — **없는 자료를 가리는 것은 뜻이 없다.**

enum State {
	FILLED,  ## 값이 있고 보인다
	MISSING,  ## 자료가 아직 없다. reason 이 왜인지 말한다
	HIDDEN,  ## 있지만 이 문맥에서는 안 보인다
}

## 막대가 없는 필드의 값. 0 을 쓰면 "막대 길이 0" 과 구분되지 않는다.
##
## **이 값만으로는 못 가른다.** 성향 축은 부호 있는 막대라 -1.0 이 **정당한 값**이다
## (축값 -100 인 인물이 인구 3000 중 98 명, 3.3%). 그 사람들의 막대가 조용히 안
## 그려지고 있었다 — 화면에는 값 글자만 남아서 「막대가 없는 줄」로 보였다.
## 그래서 **있고 없음은 `has_meter` 가 들고 값은 `bar` 가 든다.**
const NO_BAR := -1.0

## 이 줄이 아무도 안 가리킬 때의 `link`.
const NO_LINK := -1

## 왼쪽에 적히는 이름. 비어 있으면 값만 한 줄로 나간다 (문장처럼).
var label: String

## 화면에 나가는 값.
var value: String

var state: State

## `MISSING` 일 때 왜 비었는지. **화면에 그대로 나간다** —
## recruit_prospect.gd 의 blocked_reason() 과 같은 방식이다 (§24.17.4).
var reason: String

## 막대로 그릴 값. NO_BAR 면 막대가 없다.
##
## 수치를 막대로도 보이는 이유는 §24.17.6 의 지프 분포처럼 **숫자만으로는
## 크기 비교가 안 읽히는** 자리가 있기 때문이다.
var bar: float = NO_BAR

## 막대가 있는가. **값과 따로 둔다** — 어떤 값도 「없음」을 겸할 수 없다.
var has_meter := false

## 막대에 부호가 있는가.
##
## **성향 축은 가운데가 0 이고 좌우로 자란다** — 부호가 방향으로 읽혀야 두 극이
## 대칭으로 보인다 (§24.17.5). 유명세나 소속 인원은 0 부터 차오르는 값이라 왼쪽에서 자란다.
##
## 뷰가 칸 종류로 짐작하게 두지 않는다. 짐작하면 칸을 하나 더할 때 조용히 틀린다.
var is_signed_bar := false

## 이 줄이 가리키는 인물. `NO_LINK` 면 아무도 안 가리킨다.
##
## **누르면 그 사람으로 간다** — 관계 줄이 쓴다 (§20.23.4). 화면에 나가는 값이 아니라
## **줄이 들고 있는 목적지**다.
##
## 이름 글자에서 인물을 되찾는 길(문자열 검색)을 안 쓴 이유는 §24.22.7 이 성 분포를
## 일부러 치우치게 했기 때문이다 — **동명이인에서 조용히 틀린다.**
var link := NO_LINK


func _init(
	field_label: String,
	field_value: String,
	field_state: State = State.FILLED,
	field_reason: String = "",
	field_bar: float = NO_BAR
) -> void:
	label = field_label
	value = field_value
	state = field_state
	reason = field_reason
	bar = field_bar


## 값이 있는 필드.
static func filled(field_label: String, field_value: String) -> SheetField:
	return SheetField.new(field_label, field_value)


## 부호 있는 막대. 가운데가 0 이고 좌우로 자란다. 성향 축이 쓴다.
static func gauge(field_label: String, field_value: String, ratio: float) -> SheetField:
	var field := SheetField.new(
		field_label, field_value, State.FILLED, "", clampf(ratio, -1.0, 1.0)
	)
	field.is_signed_bar = true
	field.has_meter = true
	return field


## 부호 없는 막대. 0 부터 차오른다. 유명세 · 소속 인원이 쓴다.
static func meter(field_label: String, field_value: String, ratio: float) -> SheetField:
	var field := SheetField.new(field_label, field_value, State.FILLED, "", clampf(ratio, 0.0, 1.0))
	field.has_meter = true
	return field


## 아직 만들지 않은 자료. **사유가 반드시 있어야 한다** — 없으면 고장으로 읽힌다.
static func missing(field_label: String, field_reason: String) -> SheetField:
	return SheetField.new(field_label, "", State.MISSING, field_reason)


## 있지만 이 문맥에서 안 보이는 자료. 게임 내 화면이 쓴다 (§24.17.2).
static func hidden(field_label: String) -> SheetField:
	return SheetField.new(field_label, "", State.HIDDEN, "알 수 없다")


## 화면이 이 줄에 무엇을 쓸지. 상태마다 다른 문장이 나간다.
func display_text() -> String:
	match state:
		State.MISSING:
			return reason
		State.HIDDEN:
			return reason
		_:
			return value


## 누르면 갈 곳이 있는가.
func has_link() -> bool:
	return link != NO_LINK


func has_bar() -> bool:
	return has_meter


func is_filled() -> bool:
	return state == State.FILLED
