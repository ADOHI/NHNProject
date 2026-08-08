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
## ## 판이 아예 아닌 것도 있다
##
## 첫 넷(`SHARD` `RIFT` `LEAN` `FANG`)은 전부 **한 덩어리의 변형**이었다.
## `WIRE` 는 채운 판이 아예 없고 선만 있으며, `SPLIT` 은 조각 여럿으로 흩어져 있다.
## 그래서 이 클래스는 「윤곽 하나」가 아니라 **채운 조각들 + 열린 선들**을 낸다.
##
## ## 그래도 안 넘는 선 셋
##
## 형태가 파격이어도 **읽힌다 · 누를 수 있게 보인다 · 상태 넷이 갈린다** 는 지킨다.
## 깨지면 그 형태를 버린다 — 게이지를 판 한복판에 두었다가 커서에서 글자를 덮어
## 위로 올린 것이 그 규율이다.

enum Kind {
	## 조용한 기준. 「취소」처럼 눌러도 그만인 것이 이걸 쓴다.
	SLAB,
	## 왼쪽 위가 크게 잘려 나가고 오른쪽이 뾰족하게 빠진다. 글자가 왼쪽으로 몰린다.
	SHARD,
	## 판이 **셋으로** 어긋나 있다. 위아래 조각이 크게 밀려 나가 한 장으로 안 보인다.
	RIFT,
	## 판도 글자도 기울어 있다. 각도를 두 배로 키웠다.
	LEAN,
	## 과한 것. 왼쪽으로 뿔이 튀어나오고 글자가 크고 기울고 **판을 넘어간다.**
	FANG,
	## 채운 판이 없다. **선과 글자뿐이다.** 커서가 붙어야 판이 배어 나온다.
	WIRE,
	## 조각 여섯으로 흩어져 있다. 글자가 조각과 바탕에 걸쳐 앉는다.
	SPLIT,
	## 윤곽이 **끓는다.** 테두리가 매 프레임 물결친다 — 정지 화면에는 없는 형태다.
	BOIL,
	## 아래 변이 **찢어져** 톱니가 났다. 잘린 종이의 결이다.
	RIP,
	## 판 위에 **점망**이 한쪽으로 몰려 깔린다. 셰이더가 만드는 유일한 형태다.
	MESH,
}


## 형태마다 다른 높이. 크기가 곧 위계라 이 값이 서로 달라야 한다.
static func height(kind: Kind) -> float:
	match kind:
		Kind.SHARD:
			return 58.0
		Kind.RIFT:
			return 70.0
		Kind.FANG:
			return 68.0
		Kind.WIRE:
			return 54.0
		Kind.SPLIT:
			return 62.0
		Kind.BOIL:
			return 60.0
		Kind.RIP:
			return 62.0
		_:
			return 56.0


## 글자 좌우로 비워 둘 폭. 표지와 게이지가 여기 들어간다.
static func padding(kind: Kind) -> float:
	match kind:
		Kind.SLAB:
			return 74.0
		Kind.FANG:
			return 118.0
		Kind.WIRE:
			return 92.0
		Kind.SPLIT:
			return 104.0
		Kind.MESH:
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
		Kind.WIRE:
			return 21
		Kind.SPLIT:
			return 24
		Kind.MESH:
			return 23
		_:
			return 22


## 글자가 기운 각(라디안). 판이 기울면 글자도 같이 기울어야 한 몸으로 보인다.
static func tilt(kind: Kind) -> float:
	match kind:
		Kind.LEAN:
			return -0.150
		Kind.FANG:
			return -0.095
		Kind.SPLIT:
			return -0.045
		_:
			return 0.0


## 채운 판이 있는가. `WIRE` 만 없다.
static func filled(kind: Kind) -> bool:
	return kind != Kind.WIRE


## 글자가 앉는 본판. `WIRE` 에서는 커서에서만 배어 나오는 옅은 자리다.
static func outline(kind: Kind, size: Vector2) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	match kind:
		Kind.SHARD:
			return _poly([26, 0, w - 2, 0, w, 18, w - 28, h, 8, h, 0, h - 20])
		Kind.RIFT:
			return _poly([8, 20, w - 22, 20, w - 10, 32, w - 10, 44, w - 24, 56, 0, 56, 0, 30])
		Kind.LEAN:
			return _poly([32, 0, w, 0, w - 9, 12, w - 32, h, 0, h, 9, h - 12])
		Kind.FANG:
			return _poly([42, 0, w - 4, 0, w, 15, w - 34, h, 26, h, 33, 45, 0, 36, 35, 25])
		Kind.WIRE:
			return _poly([14, 6, w - 6, 6, w - 14, h - 6, 6, h - 6])
		Kind.BOIL:
			return _poly([10, 4, w - 10, 4, w - 4, h * 0.5, w - 12, h - 4, 12, h - 4, 4, h * 0.5])
		Kind.RIP:
			return _poly([0, 0, w, 0, w, h - 14, 0, h - 14])
		Kind.MESH:
			return _poly([18, 0, w, 0, w, h - 16, w - 18, h, 0, h, 0, 16])
		Kind.SPLIT:
			# 글자 아래 조각은 **글자보다 짧다.** 글자 양끝이 바탕에 걸린다.
			return _poly([w * 0.30, 22, w * 0.78, 18, w * 0.74, 48, w * 0.26, 52])
		_:
			return PlateShape.octagon(Rect2(Vector2.ZERO, size), 9.0)


## 본판 말고 더 붙는 채운 조각들.
##
## **판이 한 장이라는 전제를 깨는 것이 형태 축에서 가장 큰 변화다.** 색을 하나도
## 안 바꾸고도 화면이 달라진다.
static func extras(kind: Kind, size: Vector2) -> Array[PackedVector2Array]:
	var w := size.x
	var h := size.y
	var out: Array[PackedVector2Array] = []
	match kind:
		Kind.RIFT:
			# 위 조각은 오른쪽으로, 아래 조각은 왼쪽으로 크게 밀렸다.
			out.append(_poly([58, 0, w, 0, w - 8, 14, 50, 14]))
			out.append(_poly([-14, 60, w - 96, 60, w - 106, h, -24, h]))
		Kind.FANG:
			out.append(_poly([w - 78, -15, w - 6, -15, w - 2, -4, w - 74, -4]))
		Kind.SPLIT:
			out.append(_poly([w * 0.08, 4, w * 0.30, 2, w * 0.26, 18]))
			out.append(_poly([w * 0.36, 6, w * 0.62, 2, w * 0.60, 14, w * 0.34, 17]))
			out.append(_poly([w * 0.82, 26, w * 0.96, 22, w * 0.90, 44]))
			out.append(_poly([w * 0.30, 56, w * 0.66, 52, w * 0.62, h, w * 0.26, h]))
	return out


## 채우지 않고 **그어만 두는 선들.** 닫히지 않은 테두리가 여기서 나온다.
static func strokes(kind: Kind, size: Vector2) -> Array[PackedVector2Array]:
	var w := size.x
	var h := size.y
	var out: Array[PackedVector2Array] = []
	if kind != Kind.WIRE:
		return out
	# 왼쪽 위와 오른쪽 아래만 있는 **닫히지 않은 테두리.** 나머지 두 모서리는 비었다.
	out.append(_poly([52, 2, 8, 2, 2, 14, 2, 34]))
	out.append(_poly([w - 52, h - 2, w - 8, h - 2, w - 2, h - 14, w - 2, h - 34]))
	# 글자가 앉는 기준선. 판이 없어도 이 한 줄이 「여기에 무언가 놓인다」를 만든다.
	out.append(_poly([26, h - 15, w - 30, h - 15]))
	return out


## 좌표를 늘어놓은 것을 점렬로 바꾼다. 꼭짓점마다 `Vector2(...)` 를 적으면 줄이
## 길어져 자동 서식이 호출을 여러 줄로 쪼개고, 그러면 좌표가 눈에 안 들어온다.
static func _poly(numbers: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, numbers.size(), 2):
		out.append(Vector2(numbers[i], numbers[i + 1]))
	return out


## 강세색으로 꽉 채우는 표지. 형태마다 생김새가 다르다.
static func marker(kind: Kind, size: Vector2) -> PackedVector2Array:
	var w := size.x
	var h := size.y
	match kind:
		Kind.SHARD:
			return _poly([9, h - 28, 23, h - 28, 9, h - 8])
		Kind.RIFT:
			return _poly([0, 32, 8, 32, 8, 50, 0, 50])
		Kind.LEAN:
			return _poly([34, 13, 39, 13, 19, h - 13, 14, h - 13])
		Kind.FANG:
			return _poly([0, 36, 33, 45, 35, 25])
		Kind.WIRE:
			return _poly([18, h * 0.5 - 8, 30, h * 0.5, 18, h * 0.5 + 8])
		Kind.SPLIT:
			return _poly([w * 0.13, 26, w * 0.23, 24, w * 0.16, 44])
		Kind.BOIL:
			return _poly([16, h * 0.5 - 8, 27, h * 0.5, 16, h * 0.5 + 8])
		Kind.RIP:
			return _poly([12, 12, 16, 12, 16, h - 26, 12, h - 26])
		Kind.MESH:
			return _poly([14, 14, 20, 12, 20, h - 12, 14, h - 14])
		_:
			return _poly([14, h * 0.5 - 9, 17, h * 0.5 - 9, 17, h * 0.5 + 9, 14, h * 0.5 + 9])


## 글자가 앉는 한복판. **가운데가 아니어도 된다.**
##
## `FANG` 은 글자 한복판을 오른쪽 끝에서 재서 **마지막 글자가 판을 넘어가게** 했다.
## 비율로 잡으면 낱말이 짧을 때 안 넘어가서, 끝에서부터 재는 방식으로 바꿨다.
## 바탕도 밝고 글자도 어두워서 판을 벗어나도 대비가 유지되는 배색이라 성립한다 —
## 검은 바탕이었으면 못 할 짓이다.
static func text_at(kind: Kind, size: Vector2) -> Vector2:
	match kind:
		Kind.SHARD:
			return Vector2(size.x * 0.46, size.y * 0.47)
		Kind.RIFT:
			return Vector2(size.x * 0.48, 37.0)
		Kind.FANG:
			return Vector2(size.x - 34.0, size.y * 0.44)
		Kind.WIRE:
			return Vector2(size.x * 0.52, size.y * 0.44)
		Kind.SPLIT:
			return Vector2(size.x * 0.52, 35.0)
		Kind.RIP:
			return Vector2(size.x * 0.5, (size.y - 14.0) * 0.55)
		Kind.MESH:
			return Vector2(size.x * 0.44, size.y * 0.5)
		_:
			return size * 0.5


## 게이지 칸이 시작하는 자리(오른쪽 끝).
##
## **글자와 같은 높이에 두면 안 된다.** 처음에 판 한복판 오른쪽에 놓았더니 커서에서
## 칸이 일곱으로 늘면서 글자를 덮었다 — 화려하게 만들려던 것이 **읽힘을 깼다.**
## 그래서 전부 글자 윗줄(또는 붙은 조각 위)로 올렸다.
static func gauge_at(kind: Kind, size: Vector2) -> Vector2:
	match kind:
		Kind.SHARD:
			return Vector2(size.x - 20.0, 10.0)
		Kind.RIFT:
			return Vector2(size.x - 14.0, 7.0)
		Kind.LEAN:
			return Vector2(size.x - 16.0, 10.0)
		Kind.FANG:
			return Vector2(size.x - 12.0, -9.5)
		Kind.WIRE:
			return Vector2(size.x - 10.0, size.y - 4.0)
		Kind.SPLIT:
			return Vector2(size.x * 0.62, 9.0)
		Kind.BOIL:
			return Vector2(size.x - 18.0, 12.0)
		Kind.RIP:
			return Vector2(size.x - 12.0, 9.0)
		Kind.MESH:
			return Vector2(size.x - 10.0, 10.0)
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
			return Vector3(14.0, size.x - 62.0, 24.0)
		Kind.LEAN:
			return Vector3(38.0, size.x - 62.0, 6.0)
		Kind.FANG:
			return Vector3(50.0, size.x - 92.0, 7.0)
		Kind.WIRE:
			return Vector3(30.0, size.x - 40.0, 4.0)
		Kind.SPLIT:
			return Vector3(size.x * 0.30, size.x * 0.58, 22.0)
		Kind.BOIL:
			return Vector3(26.0, size.x - 64.0, 8.0)
		Kind.RIP:
			return Vector3(20.0, size.x - 58.0, 5.0)
		Kind.MESH:
			return Vector3(28.0, size.x - 56.0, 6.0)
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


## 조각과 선을 **전부** 감싸는 상자. 모서리 표와 충격파가 이걸 쓴다 —
## 본판만 보면 흩어진 조각이 표 밖으로 삐져나온다.
static func hull(kind: Kind, size: Vector2) -> Rect2:
	var box := bounds(outline(kind, size))
	for piece in extras(kind, size):
		box = box.merge(bounds(piece))
	for line in strokes(kind, size):
		box = box.merge(bounds(line))
	return box


## 셰이더가 붙는 형태인가. `MESH` 만 붙는다.
static func shaded(kind: Kind) -> bool:
	return kind == Kind.MESH


## 윤곽을 **시각에 따라 흔든다.** 정지 화면에는 없는 형태가 여기서 나온다.
##
## 셰이더로 하지 않고 여기서 하는 이유: 프래그먼트 셰이더는 자기가 테두리에서
## 얼마나 떨어져 있는지 모른다. 판 모양이 형태마다 다르므로 거리장을 넘겨 줄 방법도
## 마땅치 않다. **꼭짓점을 직접 흔드는 쪽이 정확하고, 어느 형태에나 붙는다.**
##
## `randf()` 를 쓰지 않는다 — 캡처마다 화면이 달라지면 비교가 안 된다.
static func animate(kind: Kind, points: PackedVector2Array, clock: float) -> PackedVector2Array:
	match kind:
		Kind.BOIL:
			return _boil(points, clock)
		Kind.RIP:
			return _rip(points, clock)
		_:
			return points


## 테두리를 잘게 나눈 뒤 바깥 방향으로 물결치게 민다.
##
## 파장 둘을 섞는다. 하나만 쓰면 **주기가 눈에 보여서** 끓는 것이 아니라
## 톱니바퀴가 도는 것으로 읽힌다.
static func _boil(points: PackedVector2Array, clock: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := points.size()
	var walked := 0.0
	for i in count:
		var from := points[i]
		var to := points[(i + 1) % count]
		var length := from.distance_to(to)
		if length <= 0.0:
			continue
		var way := (to - from) / length
		var normal := Vector2(way.y, -way.x)
		var steps := maxi(2, int(length / 4.0))
		for step in steps:
			var along := float(step) / float(steps)
			var s := walked + along * length
			var push := 1.5 * sin(s * 0.28 + clock * 5.1) + 0.9 * sin(s * 0.63 - clock * 3.3)
			out.append(from + way * (along * length) + normal * push)
		walked += length
	return out


## 아래 변을 톱니로 찢는다. 이가 고르면 톱이고 **들쭉날쭉해야 찢어진 것**이다.
static func _rip(points: PackedVector2Array, clock: float) -> PackedVector2Array:
	if points.size() < 4:
		return points
	var out := PackedVector2Array([points[0], points[1], points[2]])
	var from := points[2]
	var to := points[3]
	var span := from.x - to.x
	var teeth := maxi(4, int(span / 11.0))
	for i in range(teeth + 1):
		var t := float(i) / float(teeth)
		var x := from.x - span * t
		var deep := 3.0 + 9.0 * KitEase.hash01(i * 2654435761 + 11)
		if i % 2 == 1:
			deep += 1.2 * sin(clock * 2.0 + float(i))
		else:
			deep *= 0.25
		out.append(Vector2(x, from.y + deep))
	out.append(points[3])
	return out
