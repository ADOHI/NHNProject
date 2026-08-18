class_name CellField
extends RefCounted
## **판의 윤곽을 이웃과의 협상으로 정한다** — 가중 보로노이(power diagram).
##
## docs/design/20-ui-kit.md §20.42.
##
## 부품마다 **씨앗 하나와 무게 하나**만 준다. 화면이 그 씨앗들로 쪼개지고, 부품의 판은
## 자기 칸을 줄인 것이다. **사이의 빈 줄은 그리는 것이 아니라 줄이고 남은 것**이다.
##
## ## 왜 이것이 코드가 아니면 안 되나
##
## **씨앗 하나를 옮기면 이웃 전부의 윤곽이 바뀐다.** 자로 그리려면 화면을 통째로 다시
## 그려야 하고, 무게를 조금 바꿀 때마다 또 다시 그려야 한다. 그래서 아무도 이 모양의
## UI 를 안 그려 봤다 — 사람이 할 수 있는 일이 아니다.
##
## ## 보통 보로노이가 아니라 **가중**이어야 하는 이유
##
## 무게가 없으면 칸의 크기가 **씨앗 사이의 거리로만** 정해진다. 그러면 「이 부품이
## 더 중요하다」를 말할 방법이 자리를 옮기는 것밖에 없고, 자리는 배치가 이미 정해 놨다.
## 무게는 **자리를 안 옮기고 크기만** 바꾼다 — 그래서 강조가 형태의 원인이 될 수 있다.

## 두 씨앗이 같은 자리에 겹쳤다고 볼 거리(px²).
const _SAME := 0.01


## `which` 번 씨앗의 칸. `bounds` 를 이웃마다 반평면으로 잘라 나간다.
##
## 판정식은 **거듭제곱 거리**다 — `|p-s|² - w` 가 가장 작은 씨앗이 그 점을 갖는다.
## 정리하면 이웃마다 **직선 하나**가 되므로, 원을 그리지 않고 반평면 클리핑만으로 끝난다.
##
## 무게가 아주 크면 이웃의 칸이 통째로 없어질 수 있다 — 그때는 빈 다각형을 낸다.
## **부르는 쪽이 빈 것을 견뎌야 한다**: 무게는 화면이 시간에 따라 바꾸는 값이고,
## 어느 프레임에서 칸 하나가 사라지는 것은 오류가 아니라 그 판의 정직한 결과다.
static func cell(
	seeds: PackedVector2Array, weights: PackedFloat32Array, which: int, bounds: Rect2
) -> PackedVector2Array:
	var poly := PackedVector2Array(
		[
			bounds.position,
			Vector2(bounds.end.x, bounds.position.y),
			bounds.end,
			Vector2(bounds.position.x, bounds.end.y),
		]
	)
	var mine := seeds[which]
	var my_weight := weights[which]
	for j in seeds.size():
		if j == which:
			continue
		var other := seeds[j]
		var gap := other - mine
		if gap.length_squared() < _SAME:
			continue
		# 남길 쪽: 2(sj-si)·p <= |sj|² - |si|² - wj + wi
		var limit := other.length_squared() - mine.length_squared() - weights[j] + my_weight
		poly = clipped_by(poly, gap * 2.0, limit)
		if poly.size() < 3:
			return PackedVector2Array()
	return poly


## `normal·p <= limit` 인 쪽만 남긴다 (서덜랜드–호지먼).
##
## `Geometry2D` 에 반평면 클리핑이 없어서 직접 쓴다. 큰 사각형을 잘라 오는 것이라
## **잘리는 도형이 늘 볼록**이고, 그래서 이 짧은 구현으로 충분하다.
static func clipped_by(
	poly: PackedVector2Array, normal: Vector2, limit: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := poly.size()
	for i in count:
		var here := poly[i]
		var next := poly[(i + 1) % count]
		var side_here := normal.dot(here) - limit
		var side_next := normal.dot(next) - limit
		if side_here <= 0.0:
			out.append(here)
		if (side_here <= 0.0) != (side_next <= 0.0):
			var span := side_here - side_next
			if absf(span) > 0.000001:
				out.append(here.lerp(next, side_here / span))
	return out


## 칸을 `by` 만큼 줄인 판. **줄이고 남은 사이가 곧 빈 줄이다.**
##
## `Geometry2D.offset_polygon` 은 감는 방향에 따라 부호가 뒤집힌다(§20.34.2).
## 여기 다각형은 반평면 클리핑에서 나오므로 방향이 한결같지 않다 —
## **둘 다 해 보고 좁아진 쪽을 고른다.**
static func shrunk(poly: PackedVector2Array, by: float) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	var start := area_of(poly)
	var best := PackedVector2Array()
	var best_area := 0.0
	for way in [-by, by]:
		for piece in Geometry2D.offset_polygon(poly, way):
			var got := area_of(piece)
			if got < start and got > best_area:
				best = piece
				best_area = got
	return best


## 다각형이 `y0..y1` 띠에서 실제로 차지하는 **가로 폭**. 글자를 앉힐 자리를 재는 쪽이 쓴다.
##
## 칸이 직사각형이 아니라서 글자를 가운데에 그냥 놓으면 삐져나온다.
## **형태가 아무리 새로워도 글자가 먼저다** — 그 규율이 이 함수 하나에 걸려 있다.
static func chord(poly: PackedVector2Array, y0: float, y1: float) -> Vector2:
	var band := clipped_by(poly, Vector2(0.0, -1.0), -y0)
	band = clipped_by(band, Vector2(0.0, 1.0), y1)
	if band.size() < 2:
		return Vector2.ZERO
	var low := band[0].x
	var high := band[0].x
	for point in band:
		low = minf(low, point.x)
		high = maxf(high, point.x)
	return Vector2(low, high)


## 다각형의 무게중심. 씨앗은 칸 안의 아무 데나 있으므로 **글자는 칸의 가운데**에 놓는다.
static func middle(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for point in poly:
		sum += point
	return sum / float(poly.size())


static func area_of(poly: PackedVector2Array) -> float:
	var twice := 0.0
	var count := poly.size()
	for i in count:
		var here := poly[i]
		var next := poly[(i + 1) % count]
		twice += here.x * next.y - next.x * here.y
	return absf(twice) * 0.5
