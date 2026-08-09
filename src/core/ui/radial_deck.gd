class_name RadialDeck
extends RefCounted
## **원형 인물 배치와 그 둘레에 뜨는 홀로그램 창.** 순수 계산이다.
##
## ```
##         [관계]                       [성향]
##            \                          /
##   [신원]----[ 캐릭터 전신 ]----[열전]
##                  o o @ o o
##             (원형, 휠로 돌리면 다음 인물)
## ```
##
## ## 층 넷 — 전부 「조우 중」이다
##
## | 층 | 무엇 | 목적 | 휠이 하는 일 |
## | --- | --- | --- | --- |
## | 전장 | 누가 어디 서 있나 | — | **자리만 비워 둔다** |
## | **스쿼드 여섯** | 얼굴 + 이름 + 위협 신호 하나 | **비교** | 회전 |
## | **한 명** | 원형 + 둘레의 창 다섯 | **판단** | **회전** |
## | **창 하나** | 그 칸의 세부 | **이해** | **줌 또는 스크롤** |
##
## **던전 지도까지 잇지 않는다.** 지도는 계획 단계에서 보고 이 화면은 조우 단계에서
## 본다 — **시간대가 다르면 이어붙일 이유가 없다.** 위로는 전장 한 칸만 열어 둔다.
##
## ## 같은 휠이 층마다 다른 뜻이다
##
## 원형 층에서는 인물이 줄지어 있고 확대 층에서는 하나가 꽉 차 있다.
## **화면이 무엇을 하는 중인지가 보이므로 안내가 필요 없다.**

## 창 = 카테고리. 클릭하면 그 창으로 들어간다(= 줌인).
enum Slot { TIES, TRAITS, IDENTITY, GEAR, CHRONICLE }

## 배율이 어느 층인가.
enum Layer { SQUAD, ONE, WINDOW }

const SLOT_NAMES := ["관계", "성향", "신원", "장비", "열전"]

## 층 경계 배율. **배율이 곧 정보 층위다** — 멀어지면 작아지는 게 아니라 다른 걸 본다.
##
## | 배율 | 층 | 나타나는 것 | 사라지는 것 |
## | --- | --- | --- | --- |
## | 0.0 ~ 0.50 | 스쿼드 | 위협 신호 · 이름 | 창 전부 |
## | 0.50 ~ 1.50 | 한 명 | 창 다섯의 **테두리와 제목** | 위협 신호 |
## | 0.85 ~ | " | 창 **내용** | |
## | 1.50 ~ | 창 하나 | 그 칸 전부 | 나머지 창 |
const TO_ONE: float = 0.50
const TO_WINDOW: float = 1.50

## 창 안의 글이 나타나는 배율. 테두리보다 늦게 온다 — **판이 다 온 뒤에 글이 든다**(§20.11.2).
const TEXT_AT: float = 0.85

## 원형이 눕는 정도. 1 이면 정원이고 작을수록 위에서 본 것에 가깝다.
const TILT: float = 0.20

## 접힌 창의 두께(px). **절대값이다** — 접힌 표식은 재료의 성질이지 창의 성질이 아니다(§20.12).
const FOLDED_H: float = 7.0

## 창이 붙는 자리. **의미가 있는 자리에 붙인다** — 관계는 머리 위, 신원은 가슴,
## 장비는 손, 열전은 발치. 선이 아무 데나 붙으면 선이 장식이 된다.
const ANCHORS := [0.08, 0.30, 0.44, 0.66, 0.86]

## 창이 어느 쪽에 서는가. **좌우로만 둔다** — 전신 일러스트가 세로로 길어(832x1216)
## 위아래에는 자리가 없다.
const SIDES := [1, 1, -1, -1, 1]


static func count() -> int:
	return SLOT_NAMES.size()


static func label(slot: Slot) -> String:
	return SLOT_NAMES[int(slot)]


static func side(slot: Slot) -> int:
	return SIDES[int(slot)]


static func anchor(slot: Slot) -> float:
	return ANCHORS[int(slot)]


static func layer_at(zoom: float) -> Layer:
	if zoom < TO_ONE:
		return Layer.SQUAD
	if zoom < TO_WINDOW:
		return Layer.ONE
	return Layer.WINDOW


## 한 쪽에 선 창들을 **붙는 자리의 위아래 순서 그대로** 낸다.
##
## > **같은 쪽 창은 앵커의 세로 순서 그대로 쌓는다. 순서가 어긋나면 그 두 선은 반드시 교차한다.**
##
## 이 한 줄이 선 엉킴 문제 전부다. 두 선분이 같은 반평면에 있고 양쪽 끝이 **둘 다
## 같은 순서로 정렬**되어 있으면 교차할 수 없다. 그래서 배치가 규칙을 지키는지만
## 확인하면 되고, 선을 꺾어 피해 다닐 필요가 없다.
static func on_side(which: int) -> Array[Slot]:
	var out: Array[Slot] = []
	for i in count():
		if SIDES[i] == which:
			out.append(i as Slot)
	out.sort_custom(func(a: Slot, b: Slot) -> bool: return anchor(a) < anchor(b))
	return out


## 인물 `index` 가 원형에서 어디 서 있나.
##
## `picked` 는 **고른 인물의 번호**다. 정수면 그 인물이 정확히 가운데 앞에 서고,
## 2.5 처럼 사이값이면 도는 중이다.
##
## > **가운데가 곧 선택됨이다.** 별도 선택 표시가 필요 없다 — **자리가 상태다.**
##
## 각도에서 `picked` 를 빼고 4분의 1바퀴를 더한다. 그러면 `index == picked` 일 때
## sin 이 1 이 되어 **화면 아래 한복판**에 선다. 각도가 주기함수라 **한 바퀴가 저절로
## 이어진다** — 끝에서 처음으로 넘어가는 자리를 따로 만들 필요가 없고, 인원이
## 셋이든 여덟이든 같은 식이다.
static func spot(index: int, total: int, picked: float, center: Vector2, radius: float) -> Vector2:
	var angle := _angle(index, total, picked)
	return center + Vector2(cos(angle) * radius, sin(angle) * radius * TILT)


## 앞에 있는 정도 0..1. **1 은 고른 인물 하나뿐이다.** 크기와 밝기가 이걸 읽는다.
static func nearness(index: int, total: int, picked: float) -> float:
	return (sin(_angle(index, total, picked)) + 1.0) * 0.5


## 지금 가운데 있는 인물. 도는 중이면 **더 가까운 쪽**이고, 그 바뀌는 순간이
## 창이 접혔다 펴지는 경계다.
static func front_index(total: int, picked: float) -> int:
	return int(posmod(int(round(picked)), maxi(total, 1)))


## 한 칸 안에서 얼마나 왔나 0..1. 0 이나 1 에 가까우면 멈춘 것이다.
static func within_step(picked: float) -> float:
	return fposmod(picked, 1.0)


## 창이 붙어 있어도 되는 정도 0..1. **도는 동안 0 이다.**
##
## 가운데가 바뀌는 순간(반 칸)에서 0 이고 멈춘 자리에서 1 이다. 그래서 **창이 옮겨
## 붙는 순간에는 창이 접혀 있다** — 옮겨 붙는 것을 볼 일이 아예 없어진다.
## 회전과 접힘이 따로 노는 것이 아니라 **한 동작의 두 면이다.**
static func settled(picked: float) -> float:
	var within := within_step(picked)
	return 1.0 - minf(within, 1.0 - within) * 2.0


static func _angle(index: int, total: int, picked: float) -> float:
	return TAU * (float(index) - picked) / float(maxi(total, 1)) + PI * 0.5


## 인물이 서는 배율. **가운데만 크고 옆으로 갈수록 작다.**
##
## 밝기와 함께 이 값이 「누가 골렸는가」를 말한다. 표지를 따로 얹지 않는다.
static func figure_scale(index: int, total: int, picked: float, zoom: float) -> float:
	if zoom < TO_ONE:
		return 0.62
	var near := nearness(index, total, picked)
	# 뒤쪽이 너무 크면 가운데가 안 도드라진다. 세제곱으로 눌러 앞만 크게 남긴다.
	return 0.30 + 0.44 * (near * near * near)


## 여섯을 나란히 세우는 자리. **원형은 비교에 불리하다** — 뒤쪽이 안 보인다.
## 그래서 멀리 가면 링이 펼쳐져 평면이 된다.
static func laid_out(index: int, total: int, screen: Vector2) -> Vector2:
	var step := screen.x / float(maxi(total, 1))
	return Vector2(step * (float(index) + 0.5), screen.y * 0.52)


## 배율에 따라 원형과 펼침 사이를 오간다. **연속이다** — 끊기면 「같은 공간」이 아니다.
static func stand(index: int, total: int, picked: float, zoom: float, screen: Vector2) -> Vector2:
	var ring := spot(index, total, picked, screen * Vector2(0.5, 0.60), screen.x * 0.245)
	var flat := laid_out(index, total, screen)
	return flat.lerp(ring, clampf(zoom / TO_ONE, 0.0, 1.0))


## 창이 펴진 정도 0..1 에서의 창 자리. 접히면 높이만 줄고 **가로는 그대로다.**
##
## 가로까지 줄이면 접힌 표식이 어디 있었는지 모르게 되고, 선의 끝점이 크게 움직여
## 「창이 날아갔다」로 읽힌다.
static func slot_rect(slot: Slot, figure: Rect2, screen: Vector2, unfold: float) -> Rect2:
	var mates := on_side(side(slot))
	var rank := mates.find(slot)
	var wide := minf(300.0, (screen.x - figure.size.x) * 0.5 - 60.0)
	var tall := 128.0
	var gap := 22.0
	var block := float(mates.size()) * tall + float(mates.size() - 1) * gap
	var top := figure.position.y + (figure.size.y - block) * 0.5 + float(rank) * (tall + gap)
	var left := figure.end.x + 76.0 if side(slot) > 0 else figure.position.x - 76.0 - wide
	var open_h := lerpf(FOLDED_H, tall, clampf(unfold, 0.0, 1.0))
	return Rect2(left, top + (tall - open_h) * 0.5, wide, open_h)


## 선이 인물 몸에 붙는 점.
static func anchor_at(slot: Slot, figure: Rect2) -> Vector2:
	return Vector2(
		figure.position.x + figure.size.x * (0.62 if side(slot) > 0 else 0.38),
		figure.position.y + figure.size.y * anchor(slot)
	)


## 몸에서 창까지의 선. **곧은 선 하나다.**
##
## 꺾어 돌리면 꺾인 자리끼리 다시 교차할 수 있다. 앵커와 창이 둘 다 같은 순서로
## 정렬되어 있으므로 **곧은 선이 교차하지 않는다는 것이 증명된다** — 피해 다닐 필요가 없다.
static func tether(slot: Slot, figure: Rect2, screen: Vector2, unfold: float) -> PackedVector2Array:
	var box := slot_rect(slot, figure, screen, unfold)
	var lands := Vector2(box.position.x if side(slot) > 0 else box.end.x, box.get_center().y)
	return PackedVector2Array([anchor_at(slot, figure), lands])


## 창이 펴진 정도. `closing` 이면 접히는 중이다.
##
## **접힘과 펴짐은 같은 축의 양끝이다**(§20.10). 역재생이 아니다.
##
## | | 순서 | 곡선 |
## | --- | --- | --- |
## | **접힘** | **바깥 창부터** | 되튐 없이, 빠르게 |
## | **펴짐** | **안쪽 창부터** | 지나쳤다 되돌아온다 |
static func open_amount(slot: Slot, u: float, closing: bool) -> float:
	var outer := absf(anchor(slot) - 0.5) * 2.0
	# **지연이 클수록 늦게 시작한다.** 접힘은 바깥이 먼저라 바깥의 지연이 작아야 하고,
	# 펴짐은 안쪽이 먼저다. 처음에 이 둘을 뒤집어 놓았고 테스트가 잡았다.
	var order := (1.0 - outer) if closing else outer
	var t := clampf((clampf(u, 0.0, 1.0) - order * 0.28) / 0.72, 0.0, 1.0)
	if closing:
		return 1.0 - KitEase.in_quad(t)
	return clampf(KitEase.out_back(t, 2.0), 0.0, 1.4)


## 한 칸 안의 자리에서 **창이 펴진 정도**를 바로 낸다. 화면은 이것만 부르면 된다.
##
## > **`settled()` 와 `open_amount()` 를 잇는 자리는 하나여야 한다.**
##
## 둘을 화면에서 이어 붙였더니 **접힘이 한 번도 일어나지 않았다**(§20.20.8).
## `open_amount(..., closing)` 의 `u` 는 「접힌 정도」인데 화면이 `settled`(= 멈춘 정도)를
## 그대로 넘겼다. 두 값은 방향이 반대라 창이 **멈췄을 때 접히고 도는 중에 펴졌다.**
## 게다가 도는 내내 `closing` 이라 **펴짐 곡선은 불린 적이 없다.**
##
## 곡선 둘은 각각 시험을 통과하고 있었다 — **아무도 둘을 이어서 재지 않았다.**
static func unfolded(slot: Slot, picked: float) -> float:
	var within := within_step(picked)
	# 앞 반 칸은 떠나는 중이라 접히고, 뒤 반 칸은 다가오는 중이라 펴진다.
	var closing := within < 0.5
	var rest := settled(picked)
	return clampf(open_amount(slot, (1.0 - rest) if closing else rest, closing), 0.0, 1.0)


## 접힌 창이 **어떤 표식으로** 접히나. 접힌 모양이 그 창의 종류를 말한다.
##
## 성향은 막대 하나, 관계는 점 여럿, 열전은 얇고 긴 선. **접혀 있어도 무엇인지 안다.**
static func folded_marks(slot: Slot, box: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var mid := box.get_center().y - 1.5
	match slot:
		Slot.TIES:
			for i in 4:
				out.append(Rect2(box.position.x + float(i) * 15.0, mid, 8.0, 3.0))
		Slot.TRAITS:
			out.append(Rect2(box.position.x, mid, box.size.x * 0.62, 3.0))
		Slot.IDENTITY:
			out.append(Rect2(box.position.x, mid, box.size.x * 0.34, 3.0))
		Slot.GEAR:
			out.append(Rect2(box.position.x, mid, 12.0, 3.0))
			out.append(Rect2(box.position.x + 20.0, mid, 12.0, 3.0))
		_:
			out.append(Rect2(box.position.x, mid + 1.0, box.size.x, 1.0))
	return out


## 이 배율에서 창 안의 글이 보이나.
static func shows_text(zoom: float) -> bool:
	return zoom >= TEXT_AT


## 이 배율에서 위협 신호가 보이나. **멀리서는 글이 안 들어간다** — 실측이 그렇게 말했다
## (§20.16.4 — 창 폭 420px 아래는 한 열이고, 여섯을 한 화면에 놓으면 그보다 훨씬 좁다).
## 그래서 멀리서 보이는 것은 **도형 하나**여야 한다.
static func shows_threat(zoom: float) -> bool:
	return zoom < TO_ONE + 0.15
