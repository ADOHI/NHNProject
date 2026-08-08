class_name ChainDirection
extends RefCounted
## 출력 블럭이 가리키는 네 방향. 체인이 다음 아이템을 찾아가는 유일한 통로다.
##
## `docs/design/28-combat.md` §28.2 의 *"각 무기는 한 블럭과 방향을 가진다"* 에서 온 것이다.
##
## **왜 Vector2i 를 그냥 쓰지 않았나.** 날 벡터를 들고 다니면 대각선이나 (0, 0) 이
## 조용히 섞여 들어온다. 네 방향뿐이라는 것이 이 시스템의 성질이므로 타입으로 못 박는다.
##
## **방향 표는 여기 한 곳에만 있다.** 벡터 · 이름 · 회전이 전부 이 파일에서 나온다.

enum Kind { NONE, UP, RIGHT, DOWN, LEFT }

## 화면 좌표계다 — y 가 아래로 늘어난다. 그래서 UP 이 (0, -1) 이다.
const _VECTORS := {
	Kind.NONE: Vector2i.ZERO,
	Kind.UP: Vector2i(0, -1),
	Kind.RIGHT: Vector2i(1, 0),
	Kind.DOWN: Vector2i(0, 1),
	Kind.LEFT: Vector2i(-1, 0),
}

## 화면에 나가는 이름. **한글만 쓴다** — 본문 폰트에 화살표 글리프가 하나도 없다
## (`docs/design/28-combat.md` §28.10.9).
const _LABELS := {
	Kind.NONE: "없음",
	Kind.UP: "위",
	Kind.RIGHT: "오른쪽",
	Kind.DOWN: "아래",
	Kind.LEFT: "왼쪽",
}

## 시계 방향 한 칸. 화면 좌표계라 위 다음이 오른쪽이다.
const _NEXT_CLOCKWISE := {
	Kind.NONE: Kind.NONE,
	Kind.UP: Kind.RIGHT,
	Kind.RIGHT: Kind.DOWN,
	Kind.DOWN: Kind.LEFT,
	Kind.LEFT: Kind.UP,
}


static func to_vector(kind: Kind) -> Vector2i:
	return _VECTORS[kind]


static func label(kind: Kind) -> String:
	return _LABELS[kind]


## 시계 방향으로 90도. `Kind.NONE` 은 돌려도 `NONE` 이다 — 출력이 없는 아이템은
## 회전해도 여전히 출력이 없다.
static func rotated_cw(kind: Kind) -> Kind:
	return _NEXT_CLOCKWISE[kind]


## 격자 칸 하나를 시계 방향으로 90도 돌린다.
##
## 화면 좌표계(y 아래)에서 시계 방향은 (x, y) -> (-y, x) 다.
## 방향 회전과 **같은 규칙**이어야 아이템 모양과 출력 방향이 함께 돈다 —
## 두 곳에 다른 식을 적으면 회전한 무기가 엉뚱한 데를 가리킨다.
static func rotate_cell_cw(cell: Vector2i) -> Vector2i:
	return Vector2i(-cell.y, cell.x)
