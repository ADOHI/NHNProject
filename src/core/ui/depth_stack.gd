class_name DepthStack
extends RefCounted
## **여러 단으로 된 화면의 셈.** 시차 · 가라앉음 · 파면 — 전부 자리와 시각만으로 나온다.
##
## docs/design/20-ui-kit.md §20.43.
##
## 화면 코드에서 떼어 낸 이유는 재사용이 아니라 **한 곳에 모으기 위해서**다.
## 단을 자리마다 손으로 계산하면 스물다섯 군데 중 하나는 반드시 빠지고,
## **한 판이라도 어긋나면 층이라는 거짓말**이 된다.


## 이 단이 시선을 따라 어긋나는 양.
##
## **가운데 단을 기준으로 앞뒤가 반대로 움직인다** — 한쪽으로만 밀면 화면이 통째로
## 미끄러지지 파고들지 않는다. 단이 하나면 0 이라 **1 단은 시차가 없는 화면**과 같다.
static func shift(look: Vector2, depth: int, count: int, reach: float) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var mid := float(count - 1) * 0.5
	return look * (mid - float(depth)) * reach


## 깊을수록 바탕 쪽으로 내려앉은 색. **알파는 안 건드린다** —
## 반투명한 판이 더 어두워지면 뒤가 비치는 정도까지 같이 바뀌어 층이 뒤섞인다.
static func sunk(tint: Color, depth: int, deep: Color, per: float) -> Color:
	if depth <= 0:
		return tint
	return Color(tint.lerp(deep, float(depth) * per), tint.a)


## 이 단에서 파면이 지금 어디까지 갔나(px). 아직 안 왔으면 음수.
##
## **깊은 단일수록 늦게 도착한다.** 그래서 파면이 화면을 가로지르는 것이 아니라
## **화면을 뚫고 지나간다** — 이것 하나가 「층이 있다」를 사건으로 증명한다.
static func front(since: float, depth: int, speed: float, lag: float) -> float:
	if since < 0.0:
		return -1.0
	return speed * (since - float(depth) * lag)


## 그 자리가 지금 파면에 걸려 있나 0..1.
static func lit(spot: Vector2, origin: Vector2, reach: float, band: float) -> float:
	if reach < 0.0 or band <= 0.0:
		return 0.0
	var off := absf(spot.distance_to(origin) - reach)
	if off > band:
		return 0.0
	return 1.0 - off / band
