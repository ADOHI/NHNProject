class_name LedgerLayout
extends RefCounted
## **이음매를 놓아도 되는 자리를 찾는다.** 노드에 의존하지 않는 순수 계산이다.
##
## `LedgerForm` 이 「어디를 자를지」를 스스로 정하지 않고 이 계산에게 물어본다.
## 입력은 **글을 실제로 앉혀 보고 잰 줄 상자들**이고 출력은 그 사이 빈틈이다.
##
## ## 열이 둘이면 가로 이음매도 안전하지 않다
##
## §20.13.2 는 *"가로 이음매는 줄 사이에 숨는다"* 로 끝났는데, 그건 **한 열짜리**
## 이야기다. 인물 상세는 두 열이고 두 열의 줄 높이가 서로 다르다. 왼쪽 열의 빈틈이
## 오른쪽 열에서는 글줄 한복판일 수 있다.
##
## > **이음매가 설 수 있는 자리는 모든 열의 빈틈이 동시에 겹치는 구간뿐이다.**
##
## 그래서 `common()` 이 있다. 이것을 안 하면 「가로로 갈랐으니 안전하다」고 믿는
## 형태가 오른쪽 열의 낱말을 자른다 — **없는 합격**이 또 한 번 나온다(§20.13.1).
##
## ## 자를 자리가 없으면 안 자른다
##
## 겹치는 빈틈이 하나도 없으면 `cuts()` 가 빈 배열을 낸다. 형태는 층이 하나가 되고
## 그건 실패가 아니라 **자료가 그런 것**이다. 형태를 지키려고 아무 데나 자르면
## 그 순간 낱말이 잘린다.

## 이음매가 설 수 있는 최소 빈틈(px). **절대값이다** — 이음매의 두께와 그림자는
## 재료의 성질이지 판의 성질이 아니다(§20.12).
const MIN_GAP: float = 7.0


## 줄 상자들 사이의 빈틈. `Vector2(위, 아래)` 목록이고 y 오름차순이다.
##
## `lines` 는 `Rect2(왼쪽, 윗변, 글이 닿은 폭, 줄 높이)` 목록이다. 순서는 상관없다 —
## 여기서 정렬한다. 두 열을 한꺼번에 넘겨도 되게 하려고 그렇게 했다.
static func gaps(lines: Array[Rect2], top: float, bottom: float) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for line in lines:
		spans.append(Vector2(line.position.y, line.end.y))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var out: Array[Vector2] = []
	var edge := top
	for span in spans:
		if span.x - edge >= MIN_GAP:
			out.append(Vector2(edge, span.x))
		edge = maxf(edge, span.y)
	if bottom - edge >= MIN_GAP:
		out.append(Vector2(edge, bottom))
	return out


## 두 열의 빈틈이 **동시에** 비어 있는 구간. 이음매는 여기에만 설 수 있다.
static func common(a: Array[Vector2], b: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for one in a:
		for other in b:
			var top := maxf(one.x, other.x)
			var bottom := minf(one.y, other.y)
			if bottom - top >= MIN_GAP:
				out.append(Vector2(top, bottom))
	out.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	return out


## 두 열의 빈틈을 **합친다.** 겹치는 자리만 고르는 `common()` 의 반대다.
##
## 이음매가 **눈에 안 보이는 형태**만 이걸 쓴다(`LedgerForm.seam_shows()`).
## 「층계」와 「끝에 붙은 판」은 층끼리 딱 붙어 있어서 판 안에 경계가 없고 오른쪽
## 변의 위치만 층마다 다르다. 그 변은 글보다 오른쪽에 있으므로 **경계 y 가 글줄
## 한복판이어도 잘리는 것이 없다.**
##
## > **이음매가 글 위를 지나가도 판이 이어져 있으면 자른 것이 아니다.**
static func merge(a: Array[Vector2], b: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.append_array(a)
	out.append_array(b)
	out.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	return out


## **넓은 빈틈부터** 최대 `most` 개 골라 그 한복판을 이음매로 낸다.
##
## 넓은 쪽부터 고르는 이유는 그것이 칸과 칸 사이일 확률이 높기 때문이다. 좁은 빈틈은
## 같은 칸 안의 줄 사이라 거기를 자르면 **한 칸이 두 층에 걸친다.**
static func cuts(bands: Array[Vector2], most: int) -> PackedFloat32Array:
	if most <= 0:
		return PackedFloat32Array()
	var wide := bands.duplicate()
	wide.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y - p.x > q.y - q.x)
	var picked: Array[float] = []
	for band in wide:
		if picked.size() >= most:
			break
		picked.append((band.x + band.y) * 0.5)
	picked.sort()
	var out := PackedFloat32Array()
	for y in picked:
		out.append(y)
	return out


## 이음매가 줄 상자를 가로지른 횟수. **이 값이 0 이 아니면 형태가 글을 자른 것이다.**
##
## 「어느 형태가 무너지나」를 재는 자가 여기 하나뿐이라 눈으로 세지 않는다 —
## §20.13.1 이 재는 축이 모자라서 없는 합격을 냈던 자리다.
static func crossings(lines: Array[Rect2], at: PackedFloat32Array) -> int:
	var hit := 0
	for y in at:
		for line in lines:
			if y > line.position.y + 0.5 and y < line.end.y - 0.5:
				hit += 1
	return hit


## 층마다 글이 닿은 가장 오른쪽 x. 「층계」의 디딤 깊이가 이 값에서 나온다.
##
## `edges` 는 층 경계 y 목록(`LedgerForm._edges` 가 낸 것과 같은 모양)이고
## 결과는 층 수만큼이다.
static func reaches(lines: Array[Rect2], edges: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in maxi(edges.size() - 1, 0):
		var far := 0.0
		for line in lines:
			var middle := (line.position.y + line.end.y) * 0.5
			if middle >= edges[i] and middle < edges[i + 1]:
				far = maxf(far, line.end.x)
		out.append(far)
	return out
