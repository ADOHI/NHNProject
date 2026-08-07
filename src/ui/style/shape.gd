class_name UiShape
extends RefCounted
## 화면에 쓰는 **형태를 절차적으로 만든다.** 이미지 파일을 하나도 쓰지 않기 위한 도구다.
##
## 여기 있는 함수는 전부 순수하다 — 노드도 캔버스도 모르고, 점 목록만 돌려준다.
## 그리는 일은 부르는 쪽이 draw_polyline / draw_colored_polygon 으로 한다.
## 그래서 씬 없이 단위 테스트할 수 있다 (test/unit/test_ui_shape.gd).
##
## 아이콘을 글자로 찍지 않고 여기서 그리는 이유가 있다.
## 폰트가 SongMyung 하나뿐이고 그 안에 화살표·기호 글리프가 없다.
## 데스크톱에서는 시스템 폰트가 대신 그려 주지만 웹 빌드에서는 두부(□)가 된다
## (docs/conventions.md §5.1). **없는 글자를 쓰느니 형태를 만든다.**

## 모서리 순서. cuts 배열의 인덱스와 같다.
enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT }

## 45도 사선의 방향과 법선. 경고 사선에 쓴다.
const _DIAGONAL := Vector2(0.70710678, -0.70710678)
const _DIAGONAL_NORMAL := Vector2(0.70710678, 0.70710678)

## 점이 같은 자리인지 판정하는 기준. 잘라낸 크기가 0 일 때 생기는 겹친 점을 걸러낸다.
const _EPSILON := 0.001


## 모서리를 **잘라낸** 사각형. 둥글리지 않는다.
##
## cuts 는 [좌상, 우상, 우하, 좌하] 순서의 잘라낼 길이다. 0 이면 직각으로 둔다.
## 역할마다 자르는 모서리를 다르게 두는 것이 이 게임 화면의 형태 규칙이고,
## 그래서 네 값을 따로 받는다 (docs/design/18-visual-identity.md §18.4).
static func chamfer_polygon(rect: Rect2, cuts: PackedFloat32Array) -> PackedVector2Array:
	var limit := minf(rect.size.x, rect.size.y) * 0.5
	var top_left := clampf(cuts[Corner.TOP_LEFT], 0.0, limit)
	var top_right := clampf(cuts[Corner.TOP_RIGHT], 0.0, limit)
	var bottom_right := clampf(cuts[Corner.BOTTOM_RIGHT], 0.0, limit)
	var bottom_left := clampf(cuts[Corner.BOTTOM_LEFT], 0.0, limit)
	var low := rect.position
	var high := rect.end
	var points := PackedVector2Array(
		[
			Vector2(low.x + top_left, low.y),
			Vector2(high.x - top_right, low.y),
			Vector2(high.x, low.y + top_right),
			Vector2(high.x, high.y - bottom_right),
			Vector2(high.x - bottom_right, high.y),
			Vector2(low.x + bottom_left, high.y),
			Vector2(low.x, high.y - bottom_left),
			Vector2(low.x, low.y + top_left),
		]
	)
	return _dedupe(points)


## 닫힌 윤곽선. draw_polyline 은 마지막 점과 첫 점을 잇지 않으므로 첫 점을 덧붙인다.
static func closed_outline(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.is_empty():
		return polygon
	var outline := PackedVector2Array(polygon)
	outline.append(polygon[0])
	return outline


## 카메라 프레임의 코너 브래킷. 한 모서리에서 두 방향으로 뻗는 'ㄱ' 자다.
##
## 테두리를 사방에 두르는 대신 귀퉁이만 집는 이유는, 이 화면이 **촬영 중인 화면**이기
## 때문이다. 뷰파인더의 프레임 표시는 늘 귀퉁이에만 있다
## (docs/design/02-overview.md §2.6.1 — 던전은 방송용 시설이다).
## corner 는 Corner 열거값이지만 int 로 받는다.
## 클래스 밖에서 UiShape.Corner 로 넘기면 GDScript 가 다른 타입으로 보기 때문이다.
static func bracket(rect: Rect2, corner: int, arm: float) -> PackedVector2Array:
	var reach := minf(arm, minf(rect.size.x, rect.size.y) * 0.5)
	var low := rect.position
	var high := rect.end
	match corner:
		Corner.TOP_LEFT:
			return PackedVector2Array(
				[Vector2(low.x, low.y + reach), low, Vector2(low.x + reach, low.y)]
			)
		Corner.TOP_RIGHT:
			return PackedVector2Array(
				[
					Vector2(high.x - reach, low.y),
					Vector2(high.x, low.y),
					Vector2(high.x, low.y + reach)
				]
			)
		Corner.BOTTOM_RIGHT:
			return PackedVector2Array(
				[Vector2(high.x, high.y - reach), high, Vector2(high.x - reach, high.y)]
			)
		_:
			return PackedVector2Array(
				[
					Vector2(low.x + reach, high.y),
					Vector2(low.x, high.y),
					Vector2(low.x, high.y - reach)
				]
			)


## 점선 한 줄을 이루는 선분들. 각 원소는 점 두 개다.
##
## 통로를 이어진 선으로 그리지 않는 이유는 세계관에서 나온다.
## **통로는 중계 구역이 아니다** — 그림이 안 나오는 곳이라 신호가 끊긴 것처럼 보여야 한다
## (docs/design/02-overview.md §2.6.1).
static func dash_segments(
	from: Vector2, to: Vector2, dash: float, gap: float
) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var span := from.distance_to(to)
	var stride := maxf(dash + gap, _EPSILON)
	if span <= _EPSILON or dash <= _EPSILON:
		return segments
	var direction := (to - from) / span
	var travelled := 0.0
	while travelled < span:
		var tail := minf(travelled + dash, span)
		segments.append(PackedVector2Array([from + direction * travelled, from + direction * tail]))
		travelled += stride
	return segments


## 산업 안전 표지의 사선 무늬. rect 안쪽으로 잘라낸 조각들을 돌려준다.
##
## "못 간다"를 색만으로 말하면 색약자에게 사라지고, 글자로 말하면 자리를 먹는다.
## 사선은 **시설에 실제로 칠해져 있을 법한 표시**라 세계관과도 어긋나지 않는다.
static func hazard_stripes(
	rect: Rect2, pitch: float, thickness: float, clip: PackedVector2Array
) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	if pitch <= _EPSILON or clip.size() < 3:
		return pieces
	var reach := rect.size.length()
	var lowest := INF
	var highest := -INF
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		var projected: float = (corner as Vector2).dot(_DIAGONAL_NORMAL)
		lowest = minf(lowest, projected)
		highest = maxf(highest, projected)
	var offset := floorf(lowest / pitch) * pitch
	while offset < highest:
		var base := _DIAGONAL_NORMAL * offset
		var stripe := PackedVector2Array(
			[
				base - _DIAGONAL * reach,
				base + _DIAGONAL * reach,
				base + _DIAGONAL * reach + _DIAGONAL_NORMAL * thickness,
				base - _DIAGONAL * reach + _DIAGONAL_NORMAL * thickness,
			]
		)
		for piece in Geometry2D.intersect_polygons(stripe, clip):
			pieces.append(piece)
		offset += pitch
	return pieces


## 오르내림을 알리는 갈매기표. 글리프가 없어서 직접 그린다.
static func chevron(
	center: Vector2, half_width: float, height: float, upward: bool
) -> PackedVector2Array:
	var lift := height * (-0.5 if upward else 0.5)
	return PackedVector2Array(
		[
			Vector2(center.x - half_width, center.y - lift),
			Vector2(center.x, center.y + lift),
			Vector2(center.x + half_width, center.y - lift),
		]
	)


## 신호 세기 막대. 확신의 정도를 칸으로 보여 준다.
##
## 이 게임의 공짜 정보는 전부 결함이 있다 (docs/design/13-information-design.md §13.6).
## 몇 칸이 찼는지가 곧 **이 숫자를 얼마나 믿어도 되는가**다.
static func signal_bars(origin: Vector2, count: int, bar: Vector2, gap: float) -> Array[Rect2]:
	var bars: Array[Rect2] = []
	for index in count:
		var height := bar.y * (0.45 + 0.55 * (float(index) / maxf(float(count - 1), 1.0)))
		var left := origin.x + float(index) * (bar.x + gap)
		bars.append(Rect2(Vector2(left, origin.y + bar.y - height), Vector2(bar.x, height)))
	return bars


## 계측기의 눈금. 선 하나를 따라 수직으로 짧은 선을 세운다.
static func tick_ruler(
	from: Vector2, to: Vector2, count: int, length: float
) -> Array[PackedVector2Array]:
	var ticks: Array[PackedVector2Array] = []
	if count <= 0:
		return ticks
	var normal := (to - from).orthogonal().normalized()
	for index in count:
		var ratio := float(index) / float(maxi(count - 1, 1))
		var point := from.lerp(to, ratio)
		var reach := length if index % 2 == 0 else length * 0.5
		ticks.append(PackedVector2Array([point, point + normal * reach]))
	return ticks


## 사각형을 폴리곤으로. 잘라내기(clip)에 넘길 때 쓴다.
static func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)


## 겹쳐 놓인 점을 걷어낸다. 잘라낼 길이가 0 인 모서리에서 생긴다.
static func _dedupe(points: PackedVector2Array) -> PackedVector2Array:
	var cleaned := PackedVector2Array()
	for point in points:
		if cleaned.is_empty() or cleaned[cleaned.size() - 1].distance_to(point) > _EPSILON:
			cleaned.append(point)
	if cleaned.size() > 1 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) <= _EPSILON:
		cleaned.remove_at(cleaned.size() - 1)
	return cleaned
