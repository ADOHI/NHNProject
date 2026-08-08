class_name PolygonCut
extends RefCounted
## 볼록 다각형을 직선으로 자른다. 순수 정적 함수뿐이라 씬 없이 검증된다.
##
## 판을 「잘린 조각들」로 보이게 하려면 **진짜로 잘라야** 한다. 사각형 두 개를
## 위아래로 붙여 놓고 각각 미는 방식으로는 **사선으로 벤 자국**이 나오지 않고,
## 미는 순간 두 사각형의 모서리가 어긋나 계단이 보인다.


## 다각형을 `point` 를 지나고 법선이 `normal` 인 직선으로 자른다.
##
## 앞쪽(법선 방향)과 뒤쪽 조각을 함께 돌려준다. 선이 다각형을 안 지나가면
## 한쪽은 비어 있다. Sutherland-Hodgman 을 두 번 돌린 것이다.
static func split(
	polygon: PackedVector2Array, point: Vector2, normal: Vector2
) -> Array[PackedVector2Array]:
	var front := _clip(polygon, point, normal)
	var back := _clip(polygon, point, -normal)
	var result: Array[PackedVector2Array] = [front, back]
	return result


## 반평면 안쪽만 남긴다.
static func _clip(
	polygon: PackedVector2Array, point: Vector2, normal: Vector2
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := polygon.size()
	if count == 0:
		return out
	for i in range(count):
		var current := polygon[i]
		var next := polygon[(i + 1) % count]
		var d_current := (current - point).dot(normal)
		var d_next := (next - point).dot(normal)
		if d_current >= 0.0:
			out.append(current)
		# 변이 선을 가로지르면 만나는 점을 새 꼭짓점으로 넣는다.
		if (d_current >= 0.0) != (d_next >= 0.0):
			var span := d_current - d_next
			if absf(span) > 0.00001:
				out.append(current.lerp(next, d_current / span))
	return out


## 여러 번 잘라 조각 목록을 만든다. 자를 때마다 **뒤쪽 조각만** 다시 자르므로
## 자른 선의 순서가 곧 조각의 순서가 된다.
static func slice(
	polygon: PackedVector2Array, points: Array[Vector2], normal: Vector2
) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	var remainder := polygon
	for point in points:
		var halves := split(remainder, point, normal)
		if halves[0].size() >= 3:
			pieces.append(halves[0])
		remainder = halves[1]
		if remainder.size() < 3:
			break
	if remainder.size() >= 3:
		pieces.append(remainder)
	return pieces
