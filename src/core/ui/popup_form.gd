class_name PopupForm
extends RefCounted
## 팝업의 **형태**. 노드에 의존하지 않는 순수 계산이다.
##
## 버튼의 `PlateForm` 과 같은 자리에 있다. 다른 점은 셋이다.
##
## | | 버튼 | 팝업 |
## | --- | --- | --- |
## | 사건 | 있던 것이 반응한다 | **없던 것이 생긴다** |
## | 안에 든 것 | 낱말 하나 | **제목 · 본문 · 단추 둘** |
## | 뒤 | 없다 | **있다.** 뒤 처리 자체가 축이다 |
##
## ## 형태가 화려한데 안이 안 읽히면 실패다
##
## 그래서 형태마다 `body()` 가 **글이 앉을 사각형**을 따로 낸다. 조각이 어떻게
## 흩어지든 그 사각형 안은 반드시 판이 채워져 있어야 한다 — 글자가 조각 틈에
## 걸치면 버튼에서와 달리 **문장이 끊긴다.** 낱말 하나는 걸쳐도 읽히지만 문장은 아니다.

enum Kind {
	## 널 다섯이 부챗살로 모여 판이 된다. 버튼의 「벌어지는 널」을 팝업 크기로 키운 것.
	SHUTTER,
	## 띠 셋(제목 · 본문 · 단추)이 서로 어긋나 있다.
	RIFT,
	## 같은 윤곽이 강세색으로 어긋나 한 번 더 찍힌다. **큰 면적에서도 되는지 보는 자리다.**
	GHOST,
	## 왼쪽 옆구리를 크게 물어냈다. 물어낸 자리에 표지가 앉는다.
	HOLE,
	## 사방이 눈금인 계측기 틀.
	TALLY,
	## 채운 판이 없다. **틀과 글자뿐이다** — 뒤가 그대로 비친다.
	WIRE,
}

## 뒤를 어떻게 하는가. **뒤 처리 자체가 축이다.**
enum Backdrop {
	## 그냥 어둡게.
	DIM,
	## 어둡게 하고 **가로줄만 남긴다.** 화면이 꺼진 것처럼 보인다.
	COMB,
	## 어둡게 하고 **옆으로 민다.** 뒤가 밀려나 자리를 비켜 준 것으로 읽힌다.
	SHOVE,
	## 강세색으로 물들인다. 되돌릴 수 없는 것을 물을 때.
	STAIN,
}


static func backdrop(kind: Kind) -> Backdrop:
	match kind:
		Kind.RIFT:
			return Backdrop.SHOVE
		Kind.GHOST:
			return Backdrop.STAIN
		Kind.TALLY:
			return Backdrop.COMB
		Kind.WIRE:
			return Backdrop.COMB
		_:
			return Backdrop.DIM


## 판을 이루는 조각들. **합치면 빈틈이 없어야 한다** — 안에 문장이 들어가기 때문이다.
static func pieces(kind: Kind, size: Vector2) -> Array[PackedVector2Array]:
	var w := size.x
	var h := size.y
	var out: Array[PackedVector2Array] = []
	match kind:
		Kind.SHUTTER:
			var slat := w / 5.0
			for i in 5:
				var left := slat * float(i)
				var lean := 6.0 if i % 2 == 0 else 0.0
				out.append(_poly([left, lean, left + slat, 0, left + slat, h, left, h - lean]))
		Kind.RIFT:
			out.append(_poly([10, 0, w, 0, w - 6, 44, 4, 44]))
			out.append(_poly([0, 46, w - 14, 46, w - 20, h - 54, -6, h - 54]))
			out.append(_poly([18, h - 52, w, h - 52, w - 8, h, 10, h]))
		Kind.GHOST:
			out.append(
				_poly([14, 0, w - 14, 0, w, 14, w, h - 14, w - 14, h, 14, h, 0, h - 14, 0, 14])
			)
		Kind.HOLE:
			out.append(_poly([0, 0, w, 0, w, h, 0, h, 0, h - 26, 52, h - 34, 52, 34, 0, 26]))
		Kind.TALLY:
			out.append(_poly([0, 0, w, 0, w, h, 0, h]))
		Kind.WIRE:
			out.append(_poly([16, 0, w, 0, w - 16, h, 0, h]))
	return out


## 조각 `index` 가 **어디에서 날아오는가.** 열림에서 이 자리부터 제자리로 온다.
##
## 형태마다 방향이 달라야 여섯이 서로 다른 열림으로 보인다.
static func entry(kind: Kind, index: int, count: int, size: Vector2) -> Vector2:
	var middle := float(count - 1) * 0.5
	var side := signf(float(index) - middle + 0.001)
	match kind:
		Kind.SHUTTER:
			# 널은 **위아래로 갈라져** 있다가 맞물린다.
			return Vector2(side * 26.0, side * size.y * 0.55)
		Kind.RIFT:
			# 띠는 좌우로 어긋나 있다가 붙는다.
			return Vector2(side * size.x * 0.5, 0.0)
		Kind.GHOST:
			return Vector2(0.0, -size.y * 0.22)
		Kind.HOLE:
			return Vector2(-size.x * 0.30, 0.0)
		Kind.TALLY:
			return Vector2(0.0, size.y * 0.30)
		_:
			return Vector2(size.x * 0.16, -size.y * 0.10)


## 열림에서 조각이 커졌다 작아지는지. 1 이면 크기는 안 변하고 자리만 온다.
static func entry_scale(kind: Kind) -> float:
	match kind:
		Kind.GHOST:
			return 1.14
		Kind.TALLY:
			return 0.86
		Kind.WIRE:
			return 1.20
		_:
			return 1.0


## 닫힘에서 판이 **어느 축으로 접히는가.** 열림에 쓴 축과 달라야 역재생으로 안 보인다.
static func fold_axis(kind: Kind) -> Vector2:
	match kind:
		Kind.SHUTTER:
			# 열림은 위아래로 갈라졌다 모이는 것이라 닫힘은 **좌우로** 접는다.
			return Vector2(1.0, 0.12)
		Kind.RIFT:
			# 열림이 좌우였으니 닫힘은 세로로 접는다.
			return Vector2(0.10, 1.0)
		Kind.HOLE:
			return Vector2(0.15, 1.0)
		_:
			return Vector2(0.06, 1.0)


## 제목이 앉는 자리. 팝업 크기와 무관하게 왼쪽 위에 고정된다 — 제목이 가운데로
## 가면 문서처럼 보이고, 팝업은 문서가 아니라 **묻는 것**이다.
static func title_at(kind: Kind) -> Vector2:
	match kind:
		Kind.HOLE:
			return Vector2(70.0, 34.0)
		Kind.WIRE:
			return Vector2(34.0, 32.0)
		_:
			return Vector2(28.0, 32.0)


## 본문이 앉는 사각형. **여기는 조각 틈이 지나가면 안 된다.**
static func body(kind: Kind, size: Vector2) -> Rect2:
	match kind:
		Kind.HOLE:
			return Rect2(70.0, 52.0, size.x - 96.0, 46.0)
		Kind.RIFT:
			return Rect2(24.0, 56.0, size.x - 60.0, 44.0)
		Kind.WIRE:
			return Rect2(34.0, 50.0, size.x - 72.0, 46.0)
		_:
			return Rect2(28.0, 52.0, size.x - 56.0, 46.0)


## 단추 둘이 앉는 왼쪽 위 모서리. 오른쪽 아래로 몰아 둔다 — 읽고 나서 누른다.
static func buttons_at(kind: Kind, size: Vector2) -> Vector2:
	match kind:
		Kind.RIFT:
			return Vector2(size.x - 250.0, size.y - 44.0)
		Kind.TALLY:
			return Vector2(size.x - 244.0, size.y - 42.0)
		_:
			return Vector2(size.x - 246.0, size.y - 46.0)


## 틀에 눈금을 두르는가. 계측기 틀만 두른다.
static func ruled(kind: Kind) -> bool:
	return kind == Kind.TALLY


## 채운 판이 있는가. `WIRE` 만 없다.
static func filled(kind: Kind) -> bool:
	return kind != Kind.WIRE


## 같은 윤곽을 강세색으로 한 번 더 어긋나게 찍는가.
##
## **큰 면적에서 이 수법이 어떻게 되는지 보는 자리다.** 버튼(184x56)에서는 4px
## 어긋남이 또렷했는데, 팝업(380x210)에서 같은 비율로 키우면 어긋남이 20px 가 넘어
## **테두리가 두 개인 것**이 되지 흐릿함이 아니다. 그래서 **비율이 아니라 절대값**으로
## 잡고 버튼보다 조금만 키웠다 — 면적이 커져도 어긋남은 커지지 않는다.
static func misprint(kind: Kind) -> Vector3:
	match kind:
		Kind.GHOST:
			return Vector3(6.0, -5.0, 0.006)
		_:
			return Vector3.ZERO


static func _poly(numbers: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, numbers.size(), 2):
		out.append(Vector2(numbers[i], numbers[i + 1]))
	return out
