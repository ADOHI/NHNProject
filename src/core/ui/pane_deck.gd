class_name PaneDeck
extends RefCounted
## **떠 있는 창 여럿.** 태블릿 화면에 창이 여러 개 떠 있는 배치다. 순수 계산이다.
##
## ## 탭이 아니라 창인 이유
##
## | | 탭 | 떠 있는 창 |
## | --- | --- | --- |
## | 동시에 보이는 것 | **하나** | **여럿** |
## | 겹침 | 없다 | **있다. 앞뒤가 있다** |
## | 자리 | 고정 | **자리가 뜻을 갖는다** |
## | 「지금 어디」 | 탭이 밝다 | **앞에 있는 창** |
##
## 「한 눈에 브리핑」과 맞물리는 자리다 — 탭이면 한 번에 하나만 보이는데
## 창이 여럿이면 **중요한 것 몇을 동시에 띄워 놓을 수 있다.**
##
## ## 새로 짜지 않았다 — 이미 만든 둘을 밀었다
##
## 「겹친 장」(판이 넉 겹, 앞장만 글을 든다)이 그대로 다중 창이고,
## 「끝에 붙은 판」이 그대로 도킹된 창이다(§20.14).
##
## ## 미래지향은 조형이 아니라 **어느 세계에 속하는가**로 바꾼다
##
## 이 킷의 가장 센 장치가 겹인쇄인데 그건 인쇄 은유다. 그런데 **같은 조형이
## 색수차 · 신호 어긋남으로도 읽힌다** — 디지털 결함의 언어이기도 하다.
## 「선만」이 버튼에서 살고 팝업에서 죽은 것과 같다: **같은 조형이 맥락에 따라 달리 읽힌다.**
## 그러니 조형을 버리지 말고 소속을 바꾼다.
##
## **흔한 「미래」는 배제한다** — 청록 발광선 · 육각 격자 · 홀로그램 주사선 ·
## 떠 있는 코너 브래킷. 모따기는 **덧붙인 장식이 아니라 판의 실루엣에서 잘라낸 것**이라
## 그 목록에 안 걸린다.

enum Kind {
	## 창 넷이 계단으로 겹친다. 앞장만 글을 들고 뒤는 제목 띠만 보인다.
	CASCADE,
	## 왼쪽 끝에 좁은 창이 물려 있고 큰 창과 작은 창이 그 옆에 뜬다.
	RAIL,
	## 겹치지 않게 갈라 붙였다. 셋이 동시에 다 읽힌다 — 브리핑에 가장 좋다.
	TILE,
	## 크기가 제각각인 창 넷이 흩어져 살짝씩 겹친다. **큰 것이 중요한 것이다.**
	DRIFT,
}

## 어느 세계의 미래인가. **하나만 만들면 진부한 쪽으로 간다.**
enum Air {
	## 계측면 — 얇은 선 · 눈금 · 모따기. 빛나지 않는다. 「재는 장비」
	INSTRUMENT,
	## 신호 — 겹인쇄를 색수차로 다시 읽는다. 테두리가 갈라졌다 붙는다. 「끊기는 전송」
	SIGNAL,
}

const NAMES := ["층진 창", "끝에 물린 창", "갈라 붙인 창", "흩어 띄운 창"]
const AIR_NAMES := ["계측면", "신호"]

## 태블릿 화면 하나. 게임 화면과 같은 크기여야 창 크기가 거짓말을 안 한다.
const SCREEN := Vector2(1280.0, 720.0)

## 제목 띠 높이(px). **절대값이다** — 손이 잡는 자리라 창 크기와 무관하다(§20.12).
const TITLE_H: float = 30.0

## 모따기(px). **절대값이다.** 창이 커진다고 모서리가 더 깎이지 않는다.
const CHAMFER: float = 10.0

## 색수차가 갈라지는 거리(px). **절대값이다** — 겹인쇄 어긋남과 같은 이유다(§20.12).
const SPLIT: float = 3.0

## 글이 앉는 자리의 안쪽 여백(px).
const PAD: float = 14.0


static func count() -> int:
	return NAMES.size()


static func label(kind: Kind) -> String:
	return NAMES[int(kind)]


static func air(kind: Kind) -> Air:
	match kind:
		Kind.TILE, Kind.DRIFT:
			return Air.SIGNAL
		_:
			return Air.INSTRUMENT


static func air_label(kind: Kind) -> String:
	return AIR_NAMES[int(air(kind))]


## 창들. **뒤에서 앞 순서다** — 마지막이 맨 앞이다.
##
## 자리를 비율이 아니라 실제 픽셀로 적는다. 화면이 1280x720 하나뿐이고,
## **자리 자체가 뜻을 갖는 배치**라 비례로 늘리면 뜻이 바뀐다.
static func panes(kind: Kind) -> Array[Rect2]:
	match kind:
		Kind.CASCADE:
			var out: Array[Rect2] = []
			for i in 3:
				out.append(Rect2(300.0 + 44.0 * float(i), 80.0 + 38.0 * float(i), 520.0, 360.0))
			out.append(Rect2(432.0, 194.0, 620.0, 420.0))
			return out
		Kind.RAIL:
			return [
				# 좁은 창이다. **두 열이 되는지 여기서 갈린다.**
				Rect2(28.0, 70.0, 256.0, 600.0),
				Rect2(312.0, 70.0, 700.0, 470.0),
				Rect2(560.0, 452.0, 480.0, 218.0),
			]
		Kind.TILE:
			return [
				Rect2(752.0, 64.0, 496.0, 290.0),
				Rect2(752.0, 374.0, 496.0, 290.0),
				Rect2(32.0, 64.0, 700.0, 600.0),
			]
		_:
			return [
				Rect2(60.0, 60.0, 430.0, 300.0),
				Rect2(556.0, 44.0, 380.0, 250.0),
				Rect2(150.0, 300.0, 400.0, 330.0),
				Rect2(620.0, 250.0, 600.0, 420.0),
			]


## 창 하나의 실루엣. **모따기는 덧그린 장식이 아니라 판에서 잘라낸 것이다.**
## 그래야 「떠 있는 코너 브래킷」이 안 된다.
static func outline(rect: Rect2, cut: float = CHAMFER) -> PackedVector2Array:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.25)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	return PackedVector2Array(
		[
			Vector2(left + c, top),
			Vector2(right, top),
			Vector2(right, bottom - c),
			Vector2(right - c, bottom),
			Vector2(left, bottom),
			Vector2(left, top + c),
		]
	)


## 제목 띠. 창 폭 전체를 쓰되 모따기 안쪽이다.
static func title_bar(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x, rect.position.y, rect.size.x, TITLE_H)


## 글이 앉는 자리.
static func body(rect: Rect2) -> Rect2:
	return Rect2(
		rect.position.x + PAD,
		rect.position.y + TITLE_H + PAD * 0.6,
		rect.size.x - PAD * 2.0,
		rect.size.y - TITLE_H - PAD * 1.6
	)


## 창마다 어느 칸을 드는가. **뒤에서 앞 순서로** `panes()` 와 짝이 맞는다.
##
## **자리 표시물이다** — 정보 설계 명세가 오면 이 배정이 명세에서 온다.
## 지금 정하는 것은 「무엇을 담느냐」가 아니라 **「창이 저마다 다른 것을 든다」**는 사실뿐이다.
static func cargo(kind: Kind) -> Array:
	match kind:
		Kind.CASCADE:
			return [["관계"], ["길드"], ["생김새"], ["인물", "성향"]]
		Kind.RAIL:
			return [["생김새", "길드"], ["인물", "성향"], ["관계"]]
		Kind.TILE:
			return [["길드"], ["관계"], ["인물", "성향"]]
		_:
			return [["길드"], ["생김새"], ["관계"], ["인물", "성향"]]


## 창 제목. 든 칸을 이어 붙인다 — 창의 이름이 곧 **그 창이 무엇을 맡았나**다.
static func title_of(kind: Kind, index: int) -> String:
	var load_here: Array = cargo(kind)[index]
	return " | ".join(load_here)


## 창이 몇 번째로 앞인가 0..1. 1 이 맨 앞이다. 깊이가 그림자 · 크기 · 밝기를 정한다.
static func depth(order: int, total: int) -> float:
	if total <= 1:
		return 1.0
	return float(order) / float(total - 1)


## 앞으로 나오는 것과 뒤로 가는 것. **같은 축의 양끝이다**(§20.10).
##
## 앞으로 오는 창은 **커지며 그림자가 깊어지고**, 뒤로 가는 창은 **작아지며 평평해진다.**
## 세기만 다르게 주면 두 사건이 같은 모양이 되어 구분이 사라진다.
static func rise(u: float) -> float:
	return KitEase.out_back(clampf(u, 0.0, 1.0), 1.7)


static func sink(u: float) -> float:
	return KitEase.in_quad(clampf(u, 0.0, 1.0))


## 이 창이 아래 창을 가리고 있나. 가려진 창은 글을 안 그린다 — **안 보이는 글을
## 그리면 자리 계산이 거짓말한다.**
static func covers(front: Rect2, back: Rect2) -> bool:
	return front.encloses(back.grow(-2.0))


## 신호 세계에서 테두리가 갈라지는 방향. 둘이 반대라야 색수차로 읽힌다.
static func splits() -> Array[Vector2]:
	return [Vector2(-SPLIT, -SPLIT * 0.6), Vector2(SPLIT, SPLIT * 0.6)]
