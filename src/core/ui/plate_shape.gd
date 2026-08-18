class_name PlateShape
extends RefCounted
## 버튼 판의 **윤곽 기하**. 노드에 의존하지 않는 순수 계산이다.
##
## ## 왜 사각형이 아니라 팔각인가 — 기본을 깨지 않고 형태를 얻는다
##
## 「반듯한 직사각형」은 어느 UI 에나 있고, 그렇다고 모서리를 삐뚤게 자르면
## **누를 수 있는 자리가 어디까지인지** 흐려진다. 45도로 같은 크기를 잘라낸
## 팔각은 좌우상하 대칭이라 **적중 영역이 그대로 직사각형으로 읽히면서**
## 실루엣은 깎아 만든 판이 된다.
##
## ## 왜 안쪽 윤곽을 따로 계산하나
##
## 테두리를 두 겹으로 두르고 안쪽에 글자 칸을 파려면 같은 모양을 여러 번, 다른
## 크기로 그려야 한다. 45도 모따기는 안쪽으로 `d` 만큼 밀 때 **모따기가
## `d * (√2 - 1)` 만큼 줄어든다.** 이걸 빼먹고 그냥 사각형만 줄이면 모서리에서
## 두 윤곽이 어긋나 **틈이 벌어진다.**

## √2 − 1. 45도 모따기가 안쪽으로 `d` 밀릴 때 줄어드는 비율.
const CHAMFER_SHRINK: float = 0.41421356


## `rect` 의 네 모서리를 45도로 `chamfer` 만큼 잘라낸 팔각형. 시계 방향이다.
static func octagon(rect: Rect2, chamfer: float) -> PackedVector2Array:
	var c := clampf(chamfer, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	return PackedVector2Array(
		[
			Vector2(x0 + c, y0),
			Vector2(x1 - c, y0),
			Vector2(x1, y0 + c),
			Vector2(x1, y1 - c),
			Vector2(x1 - c, y1),
			Vector2(x0 + c, y1),
			Vector2(x0, y1 - c),
			Vector2(x0, y0 + c),
		]
	)


## 같은 팔각을 안쪽으로 `distance` 만큼 민 것. 모따기도 같이 줄어든다.
static func inset(rect: Rect2, chamfer: float, distance: float) -> PackedVector2Array:
	return octagon(rect.grow(-distance), chamfer - distance * CHAMFER_SHRINK)


## 닫힌 윤곽의 둘레 길이.
static func perimeter(points: PackedVector2Array) -> float:
	var total := 0.0
	var count := points.size()
	for i in count:
		total += points[i].distance_to(points[(i + 1) % count])
	return total


## 둘레를 따라 `ratio`(0..1) 만큼 간 자리. 테두리를 타고 도는 빛이 이걸 쓴다.
##
## **각 변을 균등하게 나누면 안 된다** — 모따기 변은 8px 이고 긴 변은 200px 이라,
## 변마다 같은 시간을 주면 빛이 모서리에서 **거의 멈춘 것처럼** 보인다.
static func along(points: PackedVector2Array, ratio: float) -> Vector2:
	var count := points.size()
	if count == 0:
		return Vector2.ZERO
	var target := fposmod(ratio, 1.0) * perimeter(points)
	var walked := 0.0
	for i in count:
		var from := points[i]
		var to := points[(i + 1) % count]
		var length := from.distance_to(to)
		if walked + length >= target:
			if length <= 0.0:
				return from
			return from.lerp(to, (target - walked) / length)
		walked += length
	return points[0]


## 사선 띠 하나. `at` 이 0 이면 `rect` 의 왼쪽 밖, 1 이면 오른쪽 밖에 선다.
##
## 위쪽이 앞서 기울어 있어서 판 위를 지날 때 **훑는 방향**이 생긴다.
static func sweep_band(rect: Rect2, at: float, width: float, slant: float) -> PackedVector2Array:
	var span := rect.size.x + width * 2.0 + absf(slant) * 2.0
	var x := rect.position.x - width - absf(slant) + span * at
	var y0 := rect.position.y - 4.0
	var y1 := rect.end.y + 4.0
	return PackedVector2Array(
		[
			Vector2(x + slant, y0),
			Vector2(x + slant + width, y0),
			Vector2(x + width, y1),
			Vector2(x, y1),
		]
	)
