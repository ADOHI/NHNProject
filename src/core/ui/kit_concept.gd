class_name KitConcept
extends RefCounted
## 공통 시각 언어 후보 여섯. **매개변수만 들고 그리기는 모른다.**
##
## docs/design/20-ui-kit.md §20.26.
##
## ## 왜 매개변수를 뗐나
##
## 안을 고르려면 **여섯이 정말 다른 방향인지**를 물을 수 있어야 한다. 그리기 코드
## 안에 색과 굵기가 흩어져 있으면 *"이 둘이 사실 같은 안 아닌가"* 를 눈으로만 답하게 된다.
##
## 여기 모아 두면 **창 없이 잰다** — 모서리가 여섯 다 다른가, 면을 채우는 방식이
## 겹치지 않는가, 밝기가 서로 붙어 있지 않은가.

enum Kind {
	ENGRAVE,  ## 각인 — 면이 파인다. 테두리가 없다
	FOIL,  ## 박엽 — 금박이 얇게 겹친다. 가장자리에서 빛난다
	SCAN,  ## 주사 — 반투명에 주사선. 빛이 안에서 나온다
	PRESS,  ## 호외 — 망점으로 찬다. 두 번 찍힌다
	GRID,  ## 격자 — 가는 선만. 면이 비었다
	STACK,  ## 적층 — 꽉 찬 판이 층으로. 모서리가 둥글다
}

## 면을 채우는 방식. **여섯이 서로 달라야 안이 갈린다.**
enum Fill {
	CARVED,  ## 파인다
	LAYERED,  ## 얇게 겹친다
	SHEER,  ## 반투명
	HALFTONE,  ## 망점
	EMPTY,  ## 비었다
	SOLID,  ## 꽉 찬다
}

const _NAMES := ["각인", "박엽", "주사", "호외", "격자", "적층"]

const _SAYS := [
	"차가운 돌에 새겨 놓은 것. 지워지지 않는다",
	"손으로 두드려 붙인 귀한 것",
	"지금 갱신되고 있는 화면. 살아 있다",
	"방금 찍혀 나온 종이. 급하다",
	"재고 있는 기계. 정확하다",
	"만질 수 있는 물건. 안전하다",
]

const _WEAK := [
	"밝은 배경에서 사라진다 — 음각은 그림자로만 산다",
	"작은 글자에 약하다 — 광택이 획을 먹는다",
	"정지 화면에서 밋밋하다 — 잔상이 움직여야 뜻이 생긴다",
	"작은 부품에서 뭉갠다 — 망점이 요소보다 굵어진다",
	"위계가 안 생긴다 — 전부 같은 무게다",
	"화려함이 없다 — 안 죽지만 안 튄다",
]

## 바탕색. **여섯이 다 다른 바탕에 산다** — 같은 바탕에 놓으면 재료 차이가 안 보인다.
const _BACKDROP := [
	Color("#26262b"),  ## 각인 — 돌
	Color("#191614"),  ## 박엽 — 어두워야 금이 산다
	Color("#070d10"),  ## 주사 — 거의 검다
	Color("#e7e2d6"),  ## 호외 — 종이
	Color("#0d1116"),  ## 격자 — 계측기
	Color("#dfe3e8"),  ## 적층 — 밝은 판
]

## 판의 색.
const _SURFACE := [
	Color("#2e2e34"),
	Color("#241f1a"),
	Color("#0d1a20"),
	Color("#e7e2d6"),
	Color("#0d1116"),
	Color("#f4f6f8"),
]

## 글자와 선의 색.
const _INK := [
	Color("#d3d1cc"),
	Color("#e8d8a8"),
	Color("#8fe6d6"),
	Color("#1b1a18"),
	Color("#93b7c9"),
	Color("#22262b"),
]

## 강조색. **「지금 여기」가 이 색으로만 흐른다** (§20.26.4).
const _ACCENT := [
	Color("#c8763f"),
	Color("#f0c14b"),
	Color("#4de2c0"),
	Color("#b5342a"),
	Color("#e0a33a"),
	Color("#3b6fd4"),
]

## 모서리 반지름. 0 이면 각지고 음수면 모따기(45도로 자른다).
const _CORNER := [0.0, 0.0, -7.0, 0.0, 0.0, 9.0]

## 테두리 굵기. 0 이면 테두리를 안 그린다 — **경계를 다른 방법으로 만든다는 뜻이다.**
const _EDGE := [0.0, 1.0, 1.0, 3.0, 1.0, 0.0]

const _FILLS := [
	Fill.CARVED,
	Fill.LAYERED,
	Fill.SHEER,
	Fill.HALFTONE,
	Fill.EMPTY,
	Fill.SOLID,
]


static func count() -> int:
	return _NAMES.size()


static func name_of(kind: Kind) -> String:
	return _NAMES[int(kind)]


## 파일 이름에 쓸 이름. 한글 파일명은 도구 사이를 지나며 깨진 전례가 있다.
static func slug(kind: Kind) -> String:
	return ["engrave", "foil", "scan", "press", "grid", "stack"][int(kind)]


## 이 안이 무엇을 말하나. 한 문장이다.
static func says(kind: Kind) -> String:
	return _SAYS[int(kind)]


## 어디서 약한가. **약점이 없는 안은 안 골라 본 안이다.**
static func weakness(kind: Kind) -> String:
	return _WEAK[int(kind)]


static func backdrop(kind: Kind) -> Color:
	return _BACKDROP[int(kind)]


static func surface(kind: Kind) -> Color:
	return _SURFACE[int(kind)]


static func ink(kind: Kind) -> Color:
	return _INK[int(kind)]


static func accent(kind: Kind) -> Color:
	return _ACCENT[int(kind)]


static func corner(kind: Kind) -> float:
	return _CORNER[int(kind)]


static func edge(kind: Kind) -> float:
	return _EDGE[int(kind)]


static func fill(kind: Kind) -> Fill:
	return _FILLS[int(kind)]


## 바탕이 밝은 안인가. 밝으면 그림자가 안 생기므로 재료를 다르게 써야 한다.
static func is_light(kind: Kind) -> bool:
	return backdrop(kind).get_luminance() > 0.5


## 판 하나의 외곽선. 모서리 규칙(각짐 · 모따기 · 둥금)이 여기 한 곳에서 나온다.
##
## **여섯이 같은 함수로 외곽을 얻어야 안 차이가 모서리로만 보인다** — 안마다 따로
## 그리면 굵기나 여백이 섞여 들어가 무엇 때문에 달라 보이는지 안 갈린다.
static func outline(kind: Kind, box: Rect2) -> PackedVector2Array:
	var radius := corner(kind)
	if is_equal_approx(radius, 0.0):
		return PackedVector2Array(
			[
				box.position,
				Vector2(box.end.x, box.position.y),
				box.end,
				Vector2(box.position.x, box.end.y)
			]
		)
	var cut := minf(absf(radius), minf(box.size.x, box.size.y) * 0.5)
	if radius < 0.0:
		return PackedVector2Array(
			[
				Vector2(box.position.x + cut, box.position.y),
				Vector2(box.end.x - cut, box.position.y),
				Vector2(box.end.x, box.position.y + cut),
				Vector2(box.end.x, box.end.y - cut),
				Vector2(box.end.x - cut, box.end.y),
				Vector2(box.position.x + cut, box.end.y),
				Vector2(box.position.x, box.end.y - cut),
				Vector2(box.position.x, box.position.y + cut),
			]
		)

	var out := PackedVector2Array()
	var corners := [
		Vector2(box.end.x - cut, box.position.y + cut),
		Vector2(box.end.x - cut, box.end.y - cut),
		Vector2(box.position.x + cut, box.end.y - cut),
		Vector2(box.position.x + cut, box.position.y + cut),
	]
	for i in corners.size():
		var middle: Vector2 = corners[i]
		var start := -PI * 0.5 + PI * 0.5 * float(i)
		for step in 5:
			var angle := start + PI * 0.5 * float(step) / 4.0
			out.append(middle + Vector2.from_angle(angle) * cut)
	return out
