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

const INK := Color(0.078, 0.078, 0.098)
const BLADE := Color(0.788, 0.827, 0.867)
const BLADE_SHADE := Color(0.573, 0.616, 0.675)
const GUARD := Color(0.839, 0.678, 0.310)
const GRIP := Color(0.290, 0.216, 0.204)

const STROKE := 1.3


func _draw() -> void:
	var tip := CharWeapon.tip_offset().x
	var butt := CharWeapon.butt_offset().x
	var half := CharWeapon.BLADE_HALF_WIDTH

	# 자루. 잡은 자리에서 뒤로 나간다.
	_blob(_rect(butt, 0.0, half * 0.55), GRIP)
	# 날. **어두운 판을 먼저 깔고 밝은 판을 안쪽에 얹는다** — 캐릭터와 같은 규칙이라
	# `draw_colored_polygon` 이 안 잘라 줘도 그늘이 밖으로 안 샌다.
	_blob(_blade(tip, half), BLADE_SHADE)
	_fill(_blade(tip * 0.96, half * 0.52), BLADE)
	# 코등이. 자루와 날의 경계를 만들어 「검」으로 읽히게 하는 최소한의 표시다.
	_blob(_rect(-half * 0.5, half * 0.9, half * 1.5), GUARD)


## 날. 끝이 뾰족해야 막대가 아니라 검으로 읽힌다.
func _blade(tip: float, half: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(0.0, -half),
			Vector2(tip * 0.82, -half * 0.86),
			Vector2(tip, 0.0),
			Vector2(tip * 0.82, half * 0.86),
			Vector2(0.0, half),
		]
	)


func _rect(from_x: float, to_x: float, half: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(from_x, -half),
			Vector2(to_x, -half),
			Vector2(to_x, half),
			Vector2(from_x, half),
		]
	)


func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		draw_colored_polygon(points, color)


func _blob(points: PackedVector2Array, color: Color) -> void:
	_fill(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, INK, STROKE, true)
