class_name CharFlourish
extends RefCounted
## 타격감을 얹는 **연출 장치들의 손잡이.** 전부 따로 끄고 켠다.
##
## `docs/design/25-character-animation.md` §25.23.
##
## **한꺼번에 넣으면 어느 것이 얼마나 듣는지 아무도 모른다.** 그래서 장치마다 축을
## 따로 두고, 축마다 **약하게 · 세게 · 과하게** 셋을 만들어 나란히 본다.
## **과한 것이 반드시 있어야 한다** — 경계를 알려면 넘어가 본 것이 있어야 하기 때문이다.
##
## ## 왜 잔상이 공짜인가
##
## 클립이 **시각의 순수 함수**라(§25.3) 과거 자세가 그냥 `sample(t - Δ)` 다.
## **링 버퍼도 기록도 없다.** 프레임률이 튀어도 잔상 간격이 안 변하고, 캡처에서도
## 실시간과 똑같이 나온다. §25.3 에서 「기록하지 않는다」를 고른 값이 여기서 또 나온다.
##
## ## 블러를 안 쓴다
##
## 셰이더 블러는 `gl_compatibility` 웹 단일 스레드에서 **채움률을 먹는다.**
## **잔상 여러 장이 싸고 비슷하게 읽힌다** — 그래서 블러는 아예 안 만들었다.

## 잔상 몇 장. `0` 이면 끈다.
var trail_count := 0

## 잔상 사이의 시간 간격(초). 넓으면 띄엄띄엄, 좁으면 뭉개진다.
var trail_gap := 0.022

## 가장 진한 잔상의 불투명도. 뒤로 갈수록 옅어진다.
var trail_alpha := 0.30

## 잔상에 몸까지 넣는가. `false` 면 **무기만** 남긴다 — 훨씬 싸고 대개 그것으로 충분하다.
var trail_body := false

## 검이 지나간 호를 **면으로** 그린다. 2D 액션의 타격감 절반이 이것이다.
var arc_on := false

## 호가 덮는 시간(초). 길면 크게 휘두른 것으로 보인다.
var arc_span := 0.10

## 호의 두께 배수. **무기 무게를 탄다** — 4 칸은 굵고 길게, 1 칸은 가늘고 짧게.
var arc_weight := 1.0

## 진행 방향으로 늘이는 양. `0` 이면 끈다. **정지 프레임에서 이상하게 생긴 것이 정상이다.**
var stretch := 0.0

## 가장 빠른 한두 프레임을 **줄무늬로** 뭉갠다. 2D 액션의 고전 기법이다.
var smear := 0.0

## 닿는 순간 몇 초 동안 **실루엣이 하얗게 번쩍인다.** `0` 이면 끈다.
##
## **켜져 있는 시간이지 밝기가 아니다.** 그동안 짙기는 일정하고 그다음 꺼진다 —
## 줄어들게 두면 하나뿐인 표본이 꺼지기 직전에 걸려 아무것도 안 보인다.
##
## **한 프레임(25 fps 에서 0.04 초)보다 길어야 한다.** 짧으면 표본 사이로 빠져나가
## 눈금에 있는데 화면에서 아무 일도 안 난다 (§25.28.3).
var flash := 0.0

## **초당 몇 장으로 끊어 보여 주나.** `0` 이면 안 끊는다(연속).
##
## **격투게임은 보간을 안 한다** — 그림 12 장을 딱딱 넘긴다. 부드럽게 흐르면
## 3D 처럼 읽힌다. 일본 애니메이션의 `on 2s`(24 fps 에 12 장)와 같은 원리다.
##
## **공짜다.** 클립이 시각의 순수 함수라 `sample(floor(t·N)/N)` 이면 끝이고,
## 링 버퍼도 보간 상태도 없다 — §25.3 의 「기록하지 않는다」가 네 번째로 값을 한다.
##
## **표현 층에만 둔다.** 클립은 계속 연속 함수라 코어 검사가 표본 사이까지 본다 (§25.26.4).
var hold_fps := 0.0


## 아무 장치도 없는 상태. **비교의 바닥이다.**
static func none() -> CharFlourish:
	return CharFlourish.new()


## 이름으로 고른 조합. 벤치와 캡처가 같은 이름을 쓰게 하려는 것이다.
##
## **`over` 는 일부러 과하다.** 경계를 알려면 넘어가 본 것이 있어야 한다.
static func preset(name: String) -> CharFlourish:
	var it := CharFlourish.new()
	match name:
		"hold_8":
			it.hold_fps = 8.0
		"hold_12":
			it.hold_fps = 12.0
		"hold_16":
			it.hold_fps = 16.0
		"trail_soft":
			it.trail_count = 3
			it.trail_alpha = 0.18
		"trail_hard":
			it.trail_count = 6
			it.trail_alpha = 0.34
		"trail_over":
			it.trail_count = 12
			it.trail_gap = 0.014
			it.trail_alpha = 0.55
			it.trail_body = true
		"arc_soft":
			it.arc_on = true
			it.arc_span = 0.07
			it.arc_weight = 0.7
		"arc_hard":
			it.arc_on = true
			it.arc_span = 0.13
			it.arc_weight = 1.3
		"arc_over":
			it.arc_on = true
			it.arc_span = 0.26
			it.arc_weight = 2.4
		"stretch_soft":
			it.stretch = 0.35
		"stretch_hard":
			it.stretch = 0.9
		"stretch_over":
			it.stretch = 2.2
		"smear_soft":
			it.smear = 0.5
		"smear_hard":
			it.smear = 1.2
		"smear_over":
			it.smear = 2.6
		"flash_soft":
			it.flash = 0.05
		"flash_hard":
			it.flash = 0.09
		"flash_over":
			it.flash = 0.20
		"all":
			it.trail_count = 5
			it.trail_alpha = 0.28
			it.arc_on = true
			it.arc_span = 0.12
			it.arc_weight = 1.1
			it.stretch = 0.7
			it.smear = 1.0
			it.flash = 0.05
		"all_over":
			it.trail_count = 10
			it.trail_gap = 0.016
			it.trail_alpha = 0.5
			it.trail_body = true
			it.arc_on = true
			it.arc_span = 0.24
			it.arc_weight = 2.2
			it.stretch = 1.8
			it.smear = 2.4
			it.flash = 0.09
	return it


## 이 이름들이 전부다. 캡처와 벤치가 같은 목록을 본다.
static func preset_names() -> PackedStringArray:
	return PackedStringArray(
		[
			"none",
			"hold_8",
			"hold_12",
			"hold_16",
			"trail_soft",
			"trail_hard",
			"trail_over",
			"arc_soft",
			"arc_hard",
			"arc_over",
			"stretch_soft",
			"stretch_hard",
			"stretch_over",
			"smear_soft",
			"smear_hard",
			"smear_over",
			"flash_soft",
			"flash_hard",
			"flash_over",
			"all",
			"all_over",
		]
	)
