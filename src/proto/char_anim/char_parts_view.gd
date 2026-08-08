class_name CharPartsView
extends Node2D
## 파츠 여섯을 `Node2D` 로 만들고 포즈를 **트랜스폼에 그대로 넣는다.**
##
## 이 클래스가 하는 일은 그것뿐이다 — 애니메이션 판단이 하나도 없다.
## 파츠가 진짜 노드인 이유는 나중에 각각을 `Sprite2D` 로 바꿀 자리이기 때문이다.
##
## 그림자는 여기서 그린다. 포즈에서 파생되는 값이라 코어에 둘 것이 아니고,
## **떠 있는 파츠에 접지감을 주는 가장 값싼 수단**이라 뺄 것도 아니다.
##
## 무기도 여기서 붙인다 — **든 손의 자식**이라 손의 트랜스폼을 그대로 물려받는다.

const SHADOW := Color(0.145, 0.161, 0.196, 0.28)

## 몸이 1 px 오를 때 그림자가 줄어드는 비율. 이 값이 크면 그림자가 따로 노는 것으로 보인다.
const SHADOW_LIFT_RESPONSE := 0.030

var rig: CharRig

var _shapes: Array[CharPartShape] = []
var _weapon: CharWeaponShape
var _shadow_scale := 1.0
var _shadow_offset := 0.0


func setup(p_rig: CharRig) -> void:
	rig = p_rig
	for shape in _shapes:
		shape.queue_free()
	_shapes.clear()
	_shapes.resize(CharPart.COUNT)
	# 뒤에서 앞으로 붙인다 — 자식 순서가 곧 그리는 순서다.
	for part in CharPart.DRAW_ORDER:
		var shape := CharPartShape.new()
		shape.name = "Part%d" % part
		add_child(shape)
		shape.setup(part, rig)
		_shapes[part] = shape
	_mount_weapon()
	apply_pose(CharPose.from_rig(rig))


## 무기를 **든 손의 자식으로** 붙인다.
##
## 자식이면 손의 트랜스폼을 그대로 물려받으므로 여기서 해 줄 일이 없다 —
## 손이 돌면 무기가 손을 축으로 같이 돈다. `sample()` 은 무기를 모르고,
## 파츠는 여섯 그대로다 (`CharWeapon`).
func _mount_weapon() -> void:
	_weapon = CharWeaponShape.new()
	_weapon.name = "Weapon"
	# 손 지역 좌표는 `+y` 가 아래다. 코어(`+y` 위)에서 잡은 자리를 뒤집어 넣는다.
	var grip := CharWeapon.grip_offset(rig)
	_weapon.position = Vector2(grip.x, -grip.y)
	_weapon.rotation = -CharWeapon.REST_ANGLE
	_shapes[CharWeapon.HOLDER].add_child(_weapon)


func apply_pose(pose: CharPose) -> void:
	for part in CharPart.COUNT:
		_shapes[part].transform = pose.canvas_transform(part)
	var torso := CharPart.Id.TORSO
	var lift := pose.positions[torso].y - rig.rest_positions[torso].y
	_shadow_scale = 1.0 - lift * SHADOW_LIFT_RESPONSE
	_shadow_offset = pose.positions[torso].x * 0.5
	queue_redraw()


## 파츠 노드. 나중에 `Sprite2D` 로 갈아 끼울 때의 접점이다.
func part_node(part: CharPart.Id) -> CharPartShape:
	return _shapes[part]


func _draw() -> void:
	if rig == null:
		return
	var rx := rig.total_width() * 0.30 * _shadow_scale
	var ry := rx * 0.22
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(Vector2(_shadow_offset + cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, SHADOW)
