class_name Grain
extends RefCounted
## **축 하나 — 얼마나 노이즈인가.** 선명함이 곧 주의(注意)다.
##
## docs/design/20-ui-kit.md §20.44 · §20.47.
##
## ## 왜 순수 클래스인가
##
## 노이즈가 **화면의 성질**이라서다. 찢김을 부품마다 따로 흔들면 스물다섯 개가 각자
## 떨고, 그건 노이즈가 아니라 고장이다. 격자를 **화면 좌표에 한 벌** 깔고 부품은
## **그 격자에 얼마나 참여하는지**만 정한다 — 그러면 같은 높이에 있는 것들이 같은 줄에서
## 같은 방향으로 어긋나고, 화면 하나가 **한 신호**로 읽힌다.
##
## ## 노이즈 하나가 셋을 정한다
##
## | 무엇 | 노이즈 0 | 노이즈 1 |
## | --- | --- | --- |
## | **밀림** | 없다 | 띠마다 ±`TEAR` px |
## | **빠짐** | 없다 | 띠 여섯 중 하나가 통째로 없다 |
## | **대비** | 그대로 | 바탕 쪽으로 `FADE`, 알파 `SINK` 만큼 죽는다 |
##
## 셋이 한 손잡이에서 나오므로 **화면에 손잡이가 하나**다. 이것이 §20.28~20.43 이
## 매 판 하나씩 더해 열 몇 개가 된 자리를 대신한다.
##
## ## 축은 언덕이 아니라 **벼랑**이다 (§20.47)
##
## 앞 판의 사다리는 0.00 → 0.18 → 0.42 → 0.62 → 0.92 로 고르게 올라갔다. 그러면
## **선명한 것이 「덜 시끄러운 것」이 되지 「맑은 것」이 안 된다** — 고른 줄(0.18)은
## 이미 찢겨 있었고, 그것이 화면에서 시선이 가장 오래 머무는 자리였다.
##
## 여기서는 **맑은 구역과 흐린 구역 사이가 비어 있다.** 포커스가 있는 것은 전부
## 진짜 0 이고(찢김 0 · 알갱이 0 · 대비 100% · 떨림 0), 그다음 칸은 0.55 에서 시작한다.

## **노이즈 사다리** (§20.44.3 · §20.47.1). 화면이 아니라 **축이 들고 있다** —
## 화면마다 다시 정하면 사다리가 화면 수만큼 생기고, 축이 하나라는 말이 거짓이 된다.
##
## | 칸 | 무엇 | 구역 |
## | --- | --- | --- |
## | `HERE` | **지금 여기 — 신호색이 붙는 한 곳** | 맑음 |
## | `NEAR` | 고른 것 · 손이 닿은 것 · 열린 창 | **맑음** |
## | `LIVE` | 손 닿는 부품 | 흐림 |
## | `KEPT` | 늘 있는 것 — 제목 · 창 · 판 | 흐림 |
## | `LOST` | 안 보는 것 · 비활성 · **가려진 것** | 흐림 |
const HERE := 0.0

## **고른 것도 맑다.** 「포커스 있거나 시선 가는 것은 맑아야 한다」가 이 칸을 0 으로 민다.
##
## `HERE` 와 값이 같아도 **칸이 둘인 것은 거짓이 아니다** — 한 부품은 축을 둘 갖는다
## (§20.46.1). 노이즈 축은 「보고 있나」만 말하고, 「지금 여기가 어디인가」는 **형태 축**이
## 말한다: 뾰족한 끝 · 신호색 · 「자리」. 그래서 맑은 것이 둘 있어도 신호는 여전히 하나다.
const NEAR := 0.0

## 여기서부터 흐림이다. 맑음(0.00)과 이 값 사이가 **비어 있는 것이 이 사다리의 전부**다.
const LIVE := 0.55
const KEPT := 0.74
const LOST := 0.92

## 가림막. 팝업이 열리면 나머지가 이만큼 시끄러워진다.
## **가림막이 어둠이 아니라 노이즈다** — 어둡게 하면 축이 둘이 된다.
##
## 맑은 구역이 넓어진 만큼 가림막도 세졌다 — 0.24 로는 팝업 뒤의 고른 줄이 **팝업만큼
## 맑게** 남는다.
const VEIL := 0.30

## 띠 하나의 높이(px). **화면 좌표에 고정된 격자**라 부품이 어디 있든 같은 줄에서 끊긴다.
##
## 2px 로 하면 찢김이 알갱이로 보여 바탕 장과 구별이 안 되고, 8px 이면 띠가 부품보다
## 커서 **부품이 통째로 미끄러진다.** 4px 은 16px 글자가 네 띠에 걸리는 크기다.
const BAND := 4.0

## 노이즈 1 에서 띠 하나가 밀리는 최대 폭(px).
##
## 6 에서 올렸다. **글자가 이 폭을 그대로 안 타기 때문에** 올릴 수 있다 —
## 글자는 `LEGIBLE` 만큼 줄여서 탄다. 판만 더 찢긴다.
const TEAR := 9.0

## 노이즈 1 에서 띠가 통째로 빠질 확률. 빠진 자리로 바탕이 보인다.
const DROP := 0.22

## 노이즈가 이보다 작으면 **완전히 또렷하다.** 찢지도 흐리지도 않고 도형 하나로 나간다.
##
## 0 이 아니라 문턱인 이유는 초점이 맞아 가는 도중의 0.003 이 **한 프레임 깜빡임**으로
## 보이기 때문이다 — 다 맞았는데 마지막에 한 번 떠는 것으로 읽힌다.
const CRISP := 0.02

## 초당 몇 편이 갈리나. **노이즈는 가만히 있어도 움직인다** — idle 이 여기서 나온다.
##
## 30 이면 눈이 못 따라가 그냥 흐린 것이 되고, 4 면 편마다 자리가 보여 「끊긴 영상」이 된다.
const CHURN := 11.0

## 대비가 바탕 쪽으로 얼마나 죽나. 노이즈 1 에서 이 비율만큼 바탕색과 섞인다.
const FADE := 0.62

## 알파가 얼마나 죽나. 노이즈 1 에서 이 비율만큼 준다.
const SINK := 0.52

## **글자가 받는 노이즈의 비율.** 판이 1 을 받을 때 글자는 이만큼만 받는다.
##
## 「맑음 대 흐림」을 벌리려면 흐린 쪽을 더 흐리게 해야 하는데, 그것을 글자에까지
## 그대로 먹이면 **0.92 에서 글자를 못 읽는다** — 못 읽는 글자는 노이즈가 아니라
## 얼룩이다(§20.44.5 의 판정 기준). 그래서 판과 글자가 **같은 방향으로 갈리되 폭이 다르다**:
## 띠 주사위는 같으므로 어긋나는 쪽은 늘 같고, 글자는 그 폭의 `LEGIBLE` 배만 간다.
##
## 이 값은 **읽힘 경계를 앞 판 그대로 두는 자리**에서 나왔다 — 0.92 × 0.70 = 0.644 를
## 넣으면 밀림 ±5.8px · 대비 0.40 이라, 앞 판의 0.92(밀림 ±5.5px · 대비 0.41)와 같다.
const LEGIBLE := 0.70


## **글자가 받는 노이즈.** 판이 받는 값을 넣으면 글자용 값이 나온다 (`LEGIBLE`).
##
## 깎는 자리가 여기 하나다 — 부르는 쪽마다 곱하면 하나는 반드시 빠지고,
## 빠진 하나만 다른 폭으로 밀려 **그 글자만 고장 난 것처럼** 보인다.
static func read(noise: float) -> float:
	if noise <= CRISP:
		return 0.0
	return noise * LEGIBLE


## 이 `y` 가 몇 번째 띠인가. **음수 쪽에서도 격자가 안 어긋나야** 해서 내림이다.
static func band_of(y: float) -> int:
	return int(floor(y / BAND))


## 지금이 몇 번째 편인가. 시각을 편 번호로 끊는다 — **띠는 편 안에서 안 움직인다.**
static func frame_of(t: float) -> int:
	return int(floor(t * CHURN))


## 이 띠가 지금 얼마나 밀려 있나(px). 부호가 양쪽으로 간다.
static func slip(band: int, t: float, noise: float) -> float:
	if noise <= CRISP:
		return 0.0
	return (_dice(band, frame_of(t)) * 2.0 - 1.0) * noise * TEAR


## 이 띠가 지금 통째로 빠졌나.
static func gone(band: int, t: float, noise: float) -> bool:
	if noise <= CRISP:
		return false
	return _dice(band * 7 + 3, frame_of(t) * 13 + 1) < noise * DROP


## 도형 하나를 띠로 찢는다. 노이즈가 문턱 아래면 **원래 도형 하나**를 그대로 낸다.
##
## 잘라 낸 조각을 미는 것이지 **미리 밀어 놓고 자르는 것이 아니다** — 순서를 바꾸면
## 조각이 자기 띠 밖으로 나가서 위아래 띠와 겹치고, 겹친 자리만 진해져 얼룩이 된다.
static func shred(shape: PackedVector2Array, noise: float, t: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if shape.size() < 3:
		return out
	if noise <= CRISP:
		out.append(shape)
		return out
	var span := _bounds(shape)
	var first := band_of(span.position.y)
	var last := band_of(span.end.y - 0.001)
	for k in range(first, last + 1):
		if gone(k, t, noise):
			continue
		var lid := PackedVector2Array(
			[
				Vector2(span.position.x - TEAR - 1.0, float(k) * BAND),
				Vector2(span.end.x + TEAR + 1.0, float(k) * BAND),
				Vector2(span.end.x + TEAR + 1.0, float(k + 1) * BAND),
				Vector2(span.position.x - TEAR - 1.0, float(k + 1) * BAND),
			]
		)
		var push := Vector2(slip(k, t, noise), 0.0)
		for piece in Geometry2D.intersect_polygons(shape, lid):
			out.append(moved(piece, push))
	return out


## 노이즈에 묻힌 색. **바탕 쪽으로 섞이고 알파가 준다** — 신호 대 잡음이 내려간다.
##
## 색상을 안 돌린다. 색은 「무엇인가」를 말하고(§20.32) 노이즈는 「보고 있나」를 말한다 —
## 노이즈가 색상까지 건드리면 두 물음이 한 손잡이에 묶여 **둘 다 못 읽는다.**
static func dim(tint: Color, noise: float, deep: Color) -> Color:
	if noise <= CRISP:
		return tint
	var sunk := tint.lerp(deep, noise * FADE)
	return Color(sunk, tint.a * (1.0 - noise * SINK))


## 잔상 한 벌의 진하기. **글자에만 쓴다** — 획을 찢는 대신 겹쳐 찍는다 (§20.44.5).
static func echo_force(noise: float) -> float:
	if noise <= CRISP:
		return 0.0
	return noise * 0.42


static func moved(shape: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in shape:
		out.append(point + by)
	return out


## 씨앗 둘로 0..1. **난수를 들고 있지 않다** — 되감아도 같은 편이 나와야 캡처가 이어진다.
static func _dice(a: int, b: int) -> float:
	var raw := sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453
	return raw - floor(raw)


static func _bounds(shape: PackedVector2Array) -> Rect2:
	var span := Rect2(shape[0], Vector2.ZERO)
	for point in shape:
		span = span.expand(point)
	return span


## 가림막이 씌워진 노이즈. **더하는 자리가 한 곳이라야** 하나가 안 빠진다 —
## 빠진 하나는 팝업 위로 떠올라 「지금 여기」가 둘이 된다.
static func veiled(step: float, veil: float) -> float:
	return clampf(step + veil, 0.0, LOST)
