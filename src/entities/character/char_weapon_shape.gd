class_name CharWeaponShape
extends Node2D
## 무기를 도형으로 그린다. **자리표시자다 — 스프라이트가 오면 버리는 파일이다.**
##
## §28.7 이 「손에 따로 붙는 스프라이트」로 확정했으므로 나중에 실제 무기로 갈아 끼운다.
## 지금 필요한 것은 **무기가 손을 축으로 도는 것이 보이는가** 하나뿐이라 막대에 가깝다.
##
## 지역 좌표는 Godot 관례대로 `+y` 가 아래다. 원점이 **자루를 잡은 자리**이고
## `+x` 가 날 끝 방향이다 — 그래서 회전이 곧 「휘두르는 각도」가 된다.
##
## 색은 캐릭터와 같은 잉크선 · 셀 음영 규칙을 따른다. 무기만 다른 화법이면 따로 논다.
##
## **모양은 여기 없다.** 자루 · 코등이 · 날의 윤곽은 `CharWeapon.OUTLINE` 에 있다 —
## 실루엣 자와 잔상이 같은 표를 봐야 「그림은 검인데 자는 네모를 잰다」가 안 난다
## (§25.13.1). 이 파일이 하는 일은 그 윤곽을 **구간마다 다른 색으로 칠하는 것**뿐이다.

const INK := Color(0.078, 0.078, 0.098)
const BLADE := Color(0.788, 0.827, 0.867)
const BLADE_SHADE := Color(0.573, 0.616, 0.675)
const GUARD := Color(0.839, 0.678, 0.310)
const GRIP := Color(0.290, 0.216, 0.204)

## 닿는 순간 무기까지 같이 하얘진다. 캐릭터만 번쩍이면 검이 따로 논다.
const FLASH := Color(1.0, 0.988, 0.941)
const FLASH_ALPHA := 0.85

const STROKE := 1.3

## 날 안쪽의 밝은 판이 실루엣의 몇 할인가. 얇게 얹어야 날의 능선으로 읽힌다.
const HIGHLIGHT := 0.5

## 그릴 무기. **길이도 두께도 여기서 나온다** — 칸 수만 다르면 그림이 따라 바뀐다.
var weapon: CharWeapon

## **닿는 순간의 번쩍임** (`0` … `1`). 켜져 있는 동안 일정하다 (§25.28.3).
var flash := 0.0:
	set(value):
		if is_equal_approx(value, flash):
			return
		flash = value
		queue_redraw()

## **남의 캔버스에 그린다.** 파츠와 같은 이유다 (§25.32).
var _canvas: CanvasItem = null


func setup(p_weapon: CharWeapon) -> void:
	weapon = p_weapon
	queue_redraw()


func paint_into(target: CanvasItem, at: Transform2D) -> void:
	_canvas = target
	target.draw_set_transform_matrix(at)
	_draw()
	target.draw_set_transform_matrix(Transform2D.IDENTITY)
	_canvas = null


func _target() -> CanvasItem:
	return self if _canvas == null else _canvas


func _draw() -> void:
	if weapon == null:
		return
	var outline := weapon.outline_span(0.0, 1.0)
	# 날. **어두운 판을 먼저 깔고 밝은 판을 안쪽에 얹는다** — 캐릭터와 같은 규칙이라
	# `draw_colored_polygon` 이 안 잘라 줘도 그늘이 밖으로 안 샌다.
	_blob(outline, BLADE_SHADE)
	_fill(_thinned(weapon.outline_span(CharWeapon.GUARD_TO, 1.0), HIGHLIGHT), BLADE)
	# 자루와 코등이. 경계를 만들어 「검」으로 읽히게 하는 최소한의 표시다.
	_blob(weapon.outline_span(0.0, CharWeapon.GUARD_FROM), GRIP)
	_blob(weapon.outline_span(CharWeapon.GUARD_FROM, CharWeapon.GUARD_TO), GUARD)
	if flash > 0.001:
		_fill(outline, Color(FLASH, flash * FLASH_ALPHA))


## 날 방향은 그대로 두고 두께만 줄인다. 능선이 날의 가운데를 따라 흐른다.
func _thinned(points: PackedVector2Array, ratio: float) -> PackedVector2Array:
	var thin := PackedVector2Array()
	for p in points:
		thin.append(Vector2(p.x, p.y * ratio))
	return thin


func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		_target().draw_colored_polygon(points, color)


func _blob(points: PackedVector2Array, color: Color) -> void:
	_fill(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	_target().draw_polyline(closed, INK, STROKE, true)
