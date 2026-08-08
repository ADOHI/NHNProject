class_name PlateForm
extends RefCounted
## 버튼 판의 **형태**. 노드에 의존하지 않는 순수 계산이다.
##
## ## 여덟 판 동안 한 번도 안 건드린 축이 이것이다
##
## 나전도 사각형, 활판도 사각형, 현시도 사각형에 광선을 붙인 것, 파스텔도 사각형이었다.
## 색 · 재료 · 모션 · 컨셉만 갈아 끼우고 **윤곽은 매번 같았다.**
##
## > **사각형에 장식을 붙이면 아무리 해도 「장식 붙인 사각형」이다.**
##
## 그래서 여기서는 색도 모션도 건드리지 않고 **윤곽 · 글자의 자리와 각도 · 판이 몇
## 장인가** 만 바꾼다. 나머지가 같으므로 **무엇 때문에 달라 보이는지가 형태로 고정된다.**
##
## ## 위계가 색이 아니라 형태에서 나온다
##
## 「출격」과 「취소」가 같은 틀일 필요가 없다. `SLAB` 은 작고 조용하고 `FANG` 은
## 크고 시끄럽다. 색을 하나도 안 바꾸고 위계가 생긴다.
##
## ## 그래도 안 넘는 선 셋
##
## 형태가 파격이어도 **읽힌다 · 누를 수 있게 보인다 · 상태 넷이 갈린다** 는 지킨다.
## 글자가 기울어도 읽혀야 하고, 판이 찢어져 있어도 「이건 버튼이다」가 읽혀야 한다.
## 깨지면 그 형태를 버린다.

enum Kind {
	## 조용한 기준. 「취소」처럼 눌러도 그만인 것이 이걸 쓴다.
	SLAB,
	## 왼쪽 위가 크게 잘려 나가고 오른쪽이 뾰족하게 빠진다. 글자가 왼쪽으로 몰린다.
	SHARD,
	## 판이 둘로 어긋나 있다. 위 조각은 좁고 오른쪽으로 밀려 있다.
	RIFT,
	## 판도 글자도 기울어 있다.
	LEAN,
	## 과한 것. 왼쪽으로 뿔이 튀어나오고, 글자가 크고 기울고 **판을 넘어간다.**
	FANG,
}


## 형태마다 다른 높이. 크기가 곧 위계라 이 값이 서로 달라야 한다.
static func height(kind: Kind) -> float:
	match kind:
		Kind.SHARD:
			return 58.0
		Kind.RIFT:
			return 62.0
		Kind.FANG:
			return 68.0
		_:
			return 56.0


## 글자 좌우로 비워 둘 폭. 표지와 게이지가 여기 들어간다.
static func padding(kind: Kind) -> float:
	match kind:
		Kind.SLAB:
			return 74.0
		Kind.FANG:
			return 96.0
		_:
			return 78.0


## 글자 크기. **형태마다 다르다** — 같으면 판만 다르고 위계는 그대로다.
static func font_size(kind: Kind) -> int:
	match kind:
		Kind.SLAB:
			return 19
		Kind.FANG:
			return 27
		_:
			return 22


## 글자가 기운 각(라디안). 판이 기울면 글자도 같이 기울어야 한 몸으로 보인다.
static func tilt(kind: Kind) -> float:
	match kind:
		Kind.LEAN:
			return -0.075
		Kind.FANG:
			return -0.095
		_:
			return 0.0


## 판의 윤곽. 시계 방향이다.
static func outline(kind: Kind, size: Vector2) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	match kind:
		Kind.SHARD:
			return PackedVector2Array(
				[
					Vector2(26.0, 0.0),
					Vector2(w - 2.0, 0.0),
					Vector2(w, 18.0),
					Vector2(w - 28.0, h),
					Vector2(8.0, h),
					Vector2(0.0, h - 20.0),
				]
			)
		Kind.RIFT:
			return PackedVector2Array(
				[
					Vector2(10.0, 16.0),
					Vector2(w - 18.0, 16.0),
					Vector2(w - 8.0, 26.0),
					Vector2(w - 8.0, h - 8.0),
					Vector2(w - 18.0, h),
					Vector2(10.0, h),
					Vector2(0.0, h - 10.0),
					Vector2(0.0, 26.0),
				]
			)
		Kind.LEAN:
			return PackedVector2Array(
				[
					Vector2(16.0, 0.0),
					Vector2(w, 0.0),
					Vector2(w - 6.0, 9.0),
					Vector2(w - 16.0, h),
					Vector2(0.0, h),
					Vector2(6.0, h - 9.0),
				]
			)
		Kind.FANG:
			return PackedVector2Array(
				[
					Vector2(42.0, 0.0),
					Vector2(w - 4.0, 0.0),
					Vector2(w, 15.0),
					Vector2(w - 34.0, h),
					Vector2(26.0, h),
					Vector2(33.0, 45.0),
					Vector2(0.0, 36.0),
					Vector2(35.0, 25.0),
				]
			)
		_:
			return PlateShape.octagon(Rect2(Vector2.ZERO, size), 9.0)


## 본판 말고 하나 더 붙는 조각. 없으면 빈 배열이다.
##
## **판이 한 장이라는 전제를 깨는 것이 형태 축에서 가장 큰 변화다.** 어긋난 두 장은
## 색을 하나도 안 바꾸고도 화면을 다르게 만든다.
static func second(kind: Kind, size: Vector2) -> PackedVector2Array:
	var w := size.x
	match kind:
		Kind.RIFT:
			return PackedVector2Array(
				[
					Vector2(34.0, 0.0),
					Vector2(w, 0.0),
					Vector2(w - 5.0, 11.0),
					Vector2(28.0, 11.0),
				]
			)
		Kind.FANG:
			return PackedVector2Array(
				[
					Vector2(w - 78.0, -15.0),
					Vector2(w - 6.0, -15.0),
					Vector2(w - 2.0, -4.0),
					Vector2(w - 74.0, -4.0),
				]
			)
		_:
			return PackedVector2Array()


## 강세색으로 꽉 채우는 표지. 형태마다 생김새가 다르다.
static func marker(kind: Kind, size: Vector2) -> PackedVector2Array:
	var h := size.y
	match kind:
		Kind.SHARD:
			return PackedVector2Array(
				[Vector2(9.0, h - 28.0), Vector2(23.0, h - 28.0), Vector2(9.0, h - 8.0)]
			)
		Kind.RIFT:
			return PackedVector2Array(
				[
					Vector2(0.0, 30.0),
					Vector2(7.0, 30.0),
					Vector2(7.0, h - 14.0),
					Vector2(0.0, h - 14.0),
				]
			)
		Kind.LEAN:
			return PackedVector2Array(
				[
					Vector2(21.0, 12.0),
					Vector2(25.0, 12.0),
					Vector2(13.0, h - 12.0),
					Vector2(9.0, h - 12.0),
				]
			)
		Kind.FANG:
			return PackedVector2Array(
				[Vector2(0.0, 36.0), Vector2(33.0, 45.0), Vector2(35.0, 25.0)]
			)
		_:
			return PackedVector2Array(
				[
					Vector2(14.0, h * 0.5 - 9.0),
					Vector2(17.0, h * 0.5 - 9.0),
					Vector2(17.0, h * 0.5 + 9.0),
					Vector2(14.0, h * 0.5 + 9.0),
				]
			)


## 글자가 앉는 한복판. **가운데가 아니어도 된다.**
##
## `FANG` 은 일부러 오른쪽으로 밀어 **마지막 글자가 판을 넘어가게** 했다.
## 바탕도 밝고 글자도 어두워서 판을 벗어나도 대비가 유지되는 배색이라 성립한다 —
## 검은 바탕이었으면 못 할 짓이다.
static func text_at(kind: Kind, size: Vector2) -> Vector2:
	match kind:
		Kind.SHARD:
			return Vector2(size.x * 0.46, size.y * 0.47)
		Kind.RIFT:
			return Vector2(size.x * 0.52, 16.0 + (size.y - 16.0) * 0.5)
		Kind.FANG:
			return Vector2(size.x * 0.60, size.y * 0.46)
		_:
			return size * 0.5


## 게이지 칸이 시작하는 자리(오른쪽 끝).
##
## **글자와 같은 높이에 두면 안 된다.** 처음에 판 한복판 오른쪽에 놓았더니 커서에서
## 칸이 일곱으로 늘면서 글자를 덮었다 — 화려하게 만들려던 것이 **읽힘을 깼다.**
## 그래서 전부 글자 윗줄(또는 붙은 조각 위)로 올렸다. 늘어날 자리가 비어 있어야
## 늘어나도 아무것도 안 다친다.
static func gauge_at(kind: Kind, size: Vector2) -> Vector2:
	match kind:
		Kind.SHARD:
			return Vector2(size.x - 20.0, 10.0)
		Kind.RIFT:
			return Vector2(size.x - 12.0, 5.5)
		Kind.LEAN:
			return Vector2(size.x - 16.0, 10.0)
		Kind.FANG:
			return Vector2(size.x - 12.0, -9.5)
		_:
			return Vector2(size.x - 12.0, 10.0)


## 눈금 띠가 그어지는 구간. `x` 에서 `y` 까지, 높이는 `z`.
##
## 오른쪽 끝을 게이지 앞에서 끊는다. 안 끊으면 커서에서 늘어난 칸과 눈금이 겹친다.
static func ticks(kind: Kind, size: Vector2) -> Vector3:
	match kind:
		Kind.SHARD:
			return Vector3(34.0, size.x - 66.0, 6.0)
		Kind.RIFT:
			return Vector3(14.0, size.x - 30.0, 19.0)
		Kind.LEAN:
			return Vector3(30.0, size.x - 62.0, 6.0)
		Kind.FANG:
			return Vector3(50.0, size.x - 92.0, 7.0)
		_:
			return Vector3(24.0, size.x - 58.0, 6.0)


## 윤곽을 안쪽으로 민 것. 안쪽 괘선에 쓴다.
##
## 꼭짓점마다 법선을 구해 미는 대신 **테두리 상자 기준으로 축마다 줄인다.**
## 판이 길쭉해도 위아래와 좌우가 같은 거리만큼 들어오고, 비스듬한 변에서만
## 조금 어긋난다 — 1px 짜리 안쪽 줄에서는 보이지 않는 차이다.
static func shrink(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	if points.is_empty():
		return points
	var box := bounds(points)
	var factor := Vector2(
		maxf(0.1, 1.0 - distance * 2.0 / maxf(1.0, box.size.x)),
		maxf(0.1, 1.0 - distance * 2.0 / maxf(1.0, box.size.y))
	)
	var middle := box.get_center()
	var out := PackedVector2Array()
	for point in points:
		out.append(middle + (point - middle) * factor)
	return out


## 윤곽을 감싸는 가장 작은 상자.
static func bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return box
