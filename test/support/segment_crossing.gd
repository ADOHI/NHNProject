extends RefCounted
## 선분 교차 판정. **테스트 전용이다.**
##
## 생성기의 평면성은 "후보가 들로네 부분집합이니 교차할 수 없다"는 논증 위에 서 있다.
## 그 논증이 실제로 성립하는지는 논증과 무관한 방법으로 확인해야 한다.
## 그래서 여기서는 삼각분할도 그래프도 쓰지 않고 **화면에 그려질 선분끼리 직접 비교한다.**
##
## 파일 이름이 test_ 로 시작하지 않으므로 GUT 은 이 파일을 테스트로 실행하지 않는다.

## 좌표는 픽셀 단위(방 간격 200~280)라 이 정도면 부동소수 잡음만 걸러낸다.
const EPSILON := 1e-6


## 두 선분이 "지저분하게" 만나는가.
##
## 끝점을 공유하는 것은 교차가 아니다 — 한 방에서 여러 통로가 뻗는 정상적인 모양이다.
## 그 외에 닿는 경우는 전부 교차로 본다. 겹쳐 지나가는 것도, 한쪽 끝이 다른 선 위에
## 놓이는 것도 화면에서는 똑같이 "선이 엉킨" 것으로 보이기 때문이다.
static func crosses(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	if _shares_endpoint(a1, a2, b1, b2):
		return false
	var d1 := _side(b1, b2, a1)
	var d2 := _side(b1, b2, a2)
	var d3 := _side(a1, a2, b1)
	var d4 := _side(a1, a2, b2)
	if d1 * d2 < 0 and d3 * d4 < 0:
		return true
	return _touches(a1, a2, b1, b2, [d1, d2, d3, d4])


## 한쪽 선분의 끝점이 다른 선분 위에 놓여 있는가 (일직선으로 겹치는 경우 포함).
static func _touches(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2, sides: Array) -> bool:
	if sides[0] == 0 and _on_segment(b1, b2, a1):
		return true
	if sides[1] == 0 and _on_segment(b1, b2, a2):
		return true
	if sides[2] == 0 and _on_segment(a1, a2, b1):
		return true
	return sides[3] == 0 and _on_segment(a1, a2, b2)


## 점이 선분 from-to 의 어느 쪽에 있는가. 0 이면 일직선이다.
static func _side(from: Vector2, to: Vector2, point: Vector2) -> int:
	var cross := (to - from).cross(point - from)
	if cross > EPSILON:
		return 1
	if cross < -EPSILON:
		return -1
	return 0


## 일직선인 점이 선분의 범위 안에 있는가.
static func _on_segment(from: Vector2, to: Vector2, point: Vector2) -> bool:
	return (
		point.x >= minf(from.x, to.x) - EPSILON
		and point.x <= maxf(from.x, to.x) + EPSILON
		and point.y >= minf(from.y, to.y) - EPSILON
		and point.y <= maxf(from.y, to.y) + EPSILON
	)


static func _shares_endpoint(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	return (
		a1.is_equal_approx(b1)
		or a1.is_equal_approx(b2)
		or a2.is_equal_approx(b1)
		or a2.is_equal_approx(b2)
	)
