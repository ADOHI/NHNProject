class_name GlyphShape
extends RefCounted
## **글자를 진짜 도형으로.** 글꼴의 윤곽선을 받아 다각형으로 편다.
##
## docs/design/20-ui-kit.md §20.37.
##
## ## 왜 필요했나
##
## §20.28 이 「글자가 도형이다」라고 적었지만 실제로는 **도형처럼 다뤘을 뿐**이다 —
## 기울이고 판에 걸치고 두 번 찍었지 글자 자체는 끝까지 `draw_string` 이었다.
##
## 그래서 §20.33 의 벤 자국이 글자를 못 벴다. 판만 갈라지고 **글자는 벌어진 틈 위에
## 그대로 떠 있었다** — 그 한 곳이 「어긋난 게 아니라 안 맞은 것」으로 보였다.
##
## ## 구멍을 따로 낸다
##
## `draw_colored_polygon` 은 **구멍 뚫린 다각형을 못 그린다.** ㅇ · ㅁ · 0 의 속이
## 메워지면 한글은 그 순간 못 읽는다.
##
## 그래서 **바깥 윤곽과 안쪽 구멍을 갈라서 낸다.** 부르는 쪽이 바깥을 글자색으로
## 칠하고 **구멍을 판 색으로 덮으면** 구멍이 뚫린다 — 판이 단색이라 정확히 맞는다.
## 구멍도 같은 자국에 같이 걸려야 하므로 **바깥과 구멍이 같은 판정을 받아야 한다.**

## 곡선 한 도막을 몇 개의 직선으로 펴나. **글자는 크게 쓰니 적으면 각이 보인다.**
const SMOOTH := 6

## 곡선 **위**에 있는 점의 표시. 나머지는 전부 조절점이다.
##
## 오픈타입의 3차 조절점(2.0)도 여기서는 2차로 근사한다 — 여기 글꼴은
## 트루타입이라 안 나오고, 나오더라도 크게 쓴 글자에서만 아주 조금 통통해진다.
const ON_CURVE := 1.0


## `text` 를 `at` 에 앉힌 도형. `{"solid": [...], "hole": [...]}`.
##
## `at` 은 **글자의 왼쪽 밑동**(기준선)이다 — `draw_string` 과 같은 자리라
## 있던 호출을 그대로 옮길 수 있다.
static func of(text: String, font: Font, tall: int, at: Vector2) -> Dictionary:
	var solid: Array[PackedVector2Array] = []
	var hole: Array[PackedVector2Array] = []
	var rids := font.get_rids()
	if rids.is_empty():
		return {"solid": solid, "hole": hole}
	var rid: RID = rids[0]
	var server := TextServerManager.get_primary_interface()
	var pen := at
	for i in text.length():
		var index := server.font_get_glyph_index(rid, tall, text.unicode_at(i), 0)
		_one(server, rid, tall, index, pen, solid, hole)
		pen.x += server.font_get_glyph_advance(rid, tall, index).x
	return {"solid": solid, "hole": hole}


## 글자 하나의 윤곽을 편다.
static func _one(
	server: TextServer,
	rid: RID,
	tall: int,
	index: int,
	pen: Vector2,
	solid: Array[PackedVector2Array],
	hole: Array[PackedVector2Array]
) -> void:
	var got := server.font_get_glyph_contours(rid, tall, index)
	if not got.has("points"):
		return
	var points: PackedVector3Array = got["points"]
	var ends: PackedInt32Array = got["contours"]
	var rings: Array[PackedVector2Array] = []
	var from := 0
	for upto in ends:
		var ring := _ring(points, from, upto, pen)
		from = upto + 1
		if ring.size() >= 3:
			rings.append(ring)
	for i in rings.size():
		if _wrapped(rings, i) % 2 == 1:
			hole.append(rings[i])
		else:
			solid.append(rings[i])


## 이 윤곽이 같은 글자의 다른 윤곽 **몇 개 안에** 들어 있나. 홀수면 구멍이다.
##
## 감는 방향으로 가르면 안 된다. 트루타입은 바깥을 시계 방향으로 감지만 **y 가 어느 쪽으로
## 자라느냐에 따라 그 판정이 통째로 뒤집힌다.** 실제로 뒤집혔다 — 「참격」이 통째로 구멍이
## 되어 판 위에서 미색으로 칠해졌고, 그래서 **제목이 화면에서 사라졌다.**
## 담긴 관계는 좌표계가 뒤집혀도 안 변한다.
static func _wrapped(rings: Array[PackedVector2Array], which: int) -> int:
	var seat := rings[which][0]
	var deep := 0
	for i in rings.size():
		if i != which and Geometry2D.is_point_in_polygon(seat, rings[i]):
			deep += 1
	return deep


## 윤곽 하나를 다각형으로. 트루타입 윤곽선 읽는 방법 그대로다.
##
## **조절점이 둘 이어지면 사이에 점이 하나 생략된 것**이다 — 그 자리에 두 점의 가운데를
## 넣어야 한다. 이걸 빼면 획이 뭉개지는 게 아니라 **엉뚱한 데로 이어진다.**
static func _ring(
	points: PackedVector3Array, from: int, upto: int, pen: Vector2
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := upto - from + 1
	if count < 2:
		return out
	var spot: Array[Vector2] = []
	var on: Array[bool] = []
	for i in count:
		var raw := points[from + i]
		spot.append(Vector2(raw.x, raw.y) + pen)
		on.append(is_equal_approx(raw.z, ON_CURVE))

	# 곡선 위의 점부터 시작해야 한다. 하나도 없으면 첫 두 점의 가운데에서 연다.
	var begin := -1
	for i in count:
		if on[i]:
			begin = i
			break
	var here := spot[0].lerp(spot[1], 0.5)
	if begin >= 0:
		here = spot[begin]
	else:
		begin = 0
	out.append(here)

	var step := 1
	while step <= count:
		var i := (begin + step) % count
		if on[i]:
			out.append(spot[i])
			here = spot[i]
			step += 1
			continue
		var j := (begin + step + 1) % count
		var stop := spot[j]
		var eaten := 2
		if not on[j]:
			stop = spot[i].lerp(spot[j], 0.5)
			eaten = 1
		for s in range(1, SMOOTH + 1):
			var t := float(s) / float(SMOOTH)
			out.append(here.lerp(spot[i], t).lerp(spot[i].lerp(stop, t), t))
		here = stop
		step += eaten
	return out
