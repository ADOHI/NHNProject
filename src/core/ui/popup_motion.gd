class_name PopupMotion
extends RefCounted
## 팝업의 **열림과 닫힘.** 노드에 의존하지 않는 순수 계산이다.
##
## ## 버튼과 무엇이 다른가 — 사건의 종류가 다르다
##
## 버튼의 사건은 **있던 것이 반응하는 것**이고(커서 · 눌림), 팝업의 사건은
## **없던 것이 생기는 것**이다(열림 · 닫힘). 그래서 버튼에서는 형태가 *변하고*
## 팝업에서는 형태가 **태어난다.**
##
## ## 닫힘은 열림의 역재생이 아니다
##
## 되감기로 만들면 싸구려로 읽힌다. 그리고 그건 규칙 위반이기도 하다 —
## **사건이 둘이면 같은 축의 양끝을 써야 구분이 산다**(docs/design/20-ui-kit.md §20.9.7).
## 역재생은 같은 축을 같은 방향으로 되짚는 것이라 두 사건이 한 몸이 된다.
##
## | | 축 | 어느 끝 |
## | --- | --- | --- |
## | **열림** | 흩어짐 ↔ 맞물림 | 조각이 **밖에서 날아와 맞물린다.** 차례로, 지나쳤다 되돌아온다 |
## | **닫힘** | 펼침 ↔ 접힘 | 판이 **한 줄로 접혀** 사라진다. 조각 순서가 반대고 되튐이 없다 |
##
## 축이 아예 다르므로 되감기로 보이지 않는다.
##
## ## 닫힘이 더 빠르다
##
## 열림은 「무엇이 왔는지」를 읽혀야 하고 닫힘은 이미 읽은 것을 치우는 것이다.
## 같은 길이면 닫힘이 굼떠 보인다.

enum Phase { SHUT, OPENING, OPEN, CLOSING }

## 조각 하나가 제자리에 앉는 데 걸리는 시간.
const PIECE_TIME: float = 0.30

## 다음 조각이 출발하기까지의 지연. 조각 수만큼 곱한 것이 열림 전체 길이다.
const STAGGER: float = 0.045

## 판이 접혀 사라지는 시간. **열림보다 짧다.**
const CLOSE_TIME: float = 0.24

## 뒤가 어두워지는 데 걸리는 시간. 판보다 **먼저** 끝나야 판이 그 위에 얹힌다.
const VEIL_TIME: float = 0.18

var phase: Phase = Phase.SHUT

## 평상시에도 흐르는 시계. 열려 있는 동안의 잔잔한 움직임이 이걸 읽는다.
var ambient: float = 0.0

var _since_open: float = -1.0
var _since_close: float = -1.0


func advance(delta: float) -> void:
	ambient += delta
	if _since_open >= 0.0:
		_since_open += delta
	if _since_close >= 0.0:
		_since_close += delta


## 캡처 도구가 시각을 직접 앉힌다.
func pose(clock: float, since_open: float, since_close: float) -> void:
	ambient = clock
	_since_open = since_open
	_since_close = since_close


func open() -> void:
	phase = Phase.OPENING
	_since_open = 0.0
	_since_close = -1.0


func close() -> void:
	phase = Phase.CLOSING
	_since_close = 0.0


## 열림이 다 끝났나. 확인 화면이 단계를 넘길 때 쓴다.
func settled(count: int) -> bool:
	return _since_open >= 0.0 and _since_open >= PIECE_TIME + STAGGER * float(count)


## 판이 화면에 있는 정도 0..1. 색과 뒤 가림이 이걸 읽는다 — **오버슛하지 않는다.**
func presence() -> float:
	if phase == Phase.SHUT:
		return 0.0
	if phase == Phase.CLOSING:
		return 1.0 - clampf(KitEase.in_quad(_since_close / CLOSE_TIME), 0.0, 1.0)
	if _since_open < 0.0:
		return 0.0
	return clampf(KitEase.out_expo(_since_open / VEIL_TIME, 5.0), 0.0, 1.0)


## 뒤 가림의 진행 0..1. 판보다 **먼저** 자리잡는다.
func veil() -> float:
	if phase == Phase.SHUT:
		return 0.0
	if phase == Phase.CLOSING:
		# 뒤는 판이 다 접힌 **뒤에** 걷힌다. 같이 사라지면 판이 어디로 갔는지 안 보인다.
		return 1.0 - clampf(KitEase.in_quad((_since_close - CLOSE_TIME * 0.5) / 0.20), 0.0, 1.0)
	if _since_open < 0.0:
		return 0.0
	return clampf(KitEase.out_expo(_since_open / VEIL_TIME, 6.0), 0.0, 1.0)


## 조각 `index` 가 제자리에 온 정도. **1 을 지나쳤다 되돌아온다.**
##
## 차례로 오게 하는 것이 핵심이다. 한꺼번에 오면 판 하나가 커지는 것으로 보이고,
## 차례로 오면 **조립되는 것**으로 보인다.
func piece(index: int, count: int) -> float:
	if phase == Phase.SHUT:
		return 0.0
	if phase == Phase.CLOSING:
		return 1.0
	if _since_open < 0.0:
		return 0.0
	# 가운데부터 바깥으로 온다. 왼쪽부터 오면 글이 왼쪽에서 밀려 들어오는 것처럼 보인다.
	var middle := float(count - 1) * 0.5
	var order := absf(float(index) - middle)
	var u := (_since_open - order * STAGGER) / PIECE_TIME
	if u <= 0.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	return KitEase.out_back(u, 2.1)


## 판이 접힌 정도 0..1. 닫힘에서만 0 이 아니다.
func fold() -> float:
	if phase != Phase.CLOSING or _since_close < 0.0:
		return 0.0
	return clampf(KitEase.in_quad(_since_close / CLOSE_TIME), 0.0, 1.0)


## 조각 `index` 가 접히는 순서. 열림과 **반대로** 바깥부터 접힌다.
func fold_of(index: int, count: int) -> float:
	var base := fold()
	if base <= 0.0:
		return 0.0
	var middle := float(count - 1) * 0.5
	var order := 1.0 - absf(float(index) - middle) / maxf(1.0, middle)
	return clampf(base * (1.0 + 0.55) - order * 0.55, 0.0, 1.0)


## 내용(제목 · 본문 · 단추)이 보이는 정도. **판이 다 온 뒤에 든다.**
##
## 판과 같이 들어오면 글자가 날아다니는 것으로 보이고 그건 읽는 것을 방해한다.
func content() -> float:
	if phase == Phase.SHUT:
		return 0.0
	if phase == Phase.CLOSING:
		# 내용이 **먼저** 꺼진다. 빈 판이 접히는 것이 읽기 좋다.
		return 1.0 - clampf(KitEase.in_quad(_since_close / (CLOSE_TIME * 0.5)), 0.0, 1.0)
	if _since_open < 0.0:
		return 0.0
	return clampf(KitEase.out_expo((_since_open - 0.16) / 0.20, 5.0), 0.0, 1.0)
