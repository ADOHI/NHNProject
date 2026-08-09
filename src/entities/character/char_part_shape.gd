class_name CharPartShape
extends Node2D
## 파츠 하나를 도형으로 그린다. **스프라이트가 오면 버리는 파일이다.**
##
## 애니메이션 수식은 이 파일을 모른다. 여기서 하는 일은 `CharRig` 의 치수를 받아
## 그 안을 채우는 것뿐이고, 치수를 직접 적어 두지 않는다 — 리그를 고치면 도형이 따라온다.
## 그래서 모든 위치가 **반크기의 비율**로 적혀 있다.
##
## **시점은 사이드 사선이고, 그림은 자리표시자다.** 어차피 스프라이트로 갈아 끼우므로
## 옆얼굴을 새로 그리지 않았다. 시점 때문에 바꾼 것은 딱 둘이다.
##
## * **좌우 거울을 없앴다.** 옆에서 보면 두 발이 **같은 쪽**을 본다. 서로 반대로
##   벌어지는 것은 정면 문법이고, 그것 하나로 시점이 정면으로 읽혀 버린다
## * **먼 파츠를 배경 쪽으로 물들인다.** 겹침 · 크기와 함께 깊이를 만드는 셋째 수단이다
##
## 지역 좌표는 **Godot 관례대로 `+y` 가 아래**다. 코어(`+y` 위)와의 변환은
## `CharPose.canvas_transform()` 이 켤레로 처리하므로 여기서는 신경 쓸 것이 없다.
##
## 색은 앞선 레인의 파츠 시트에서 가져왔다
## (`2dAnim/outputs/minimal-char/gptparts/v2_atlas.png`). 나중에 스프라이트가
## 들어와도 화면이 안 튀게 하려는 것이다.
##
## **첫 판이 못생겼던 이유를 적어 둔다** — 도형이어도 아름다워야 하므로 값비싼 정보다.
##
## * 얼굴이 작고 가운데 있으면 **가면**으로 보인다. 크게, 아래로 내려야 얼굴이 된다
## * 원피스를 사다리꼴로 그리면 **종이봉투**가 된다. 어깨가 둥글고 허리가 잘록해야 한다
## * 벙어리장갑을 원으로만 그리면 **볼링공**이다. 엄지가 튀어나오고 손목이 있어야 손이다
## * 파츠 사이 간격이 넓으면 흩어진 조각으로 읽힌다. 레이맨은 **읽힐 만큼은 붙어 있다**

const INK := Color(0.078, 0.078, 0.098)
const HAIR := Color(0.157, 0.510, 0.549)
const HAIR_LIGHT := Color(0.400, 0.741, 0.761)
const SKIN := Color(0.988, 0.937, 0.918)
const BLUSH := Color(0.957, 0.647, 0.639)
const MOUTH := Color(0.545, 0.318, 0.322)
const DRESS := Color(0.980, 0.980, 0.992)
const DRESS_SHADE := Color(0.843, 0.859, 0.898)
const COLLAR := Color(0.157, 0.510, 0.549)
const MITTEN := Color(0.784, 0.129, 0.196)
const MITTEN_SHADE := Color(0.612, 0.078, 0.137)
const BOOT := Color(0.216, 0.208, 0.231)
const BOOT_LIGHT := Color(0.337, 0.325, 0.357)

## 먼 파츠를 배경 쪽으로 물들이는 색과 양. 공기원근을 아주 얕게 흉내 낸다.
## 세게 넣으면 뒷손이 그림자로 보이고, 없으면 앞뒤가 안 갈린다.
const FAR_TINT := Color(0.353, 0.396, 0.439)
const FAR_TINT_AMOUNT := 0.32

## **닿는 순간의 번쩍임 색.** 실루엣을 통째로 덮는다 — 격투게임의 히트 스파크와 같은 자리다.
const FLASH := Color(1.0, 0.988, 0.941)

## 번쩍임이 가장 셀 때의 불투명도. `1` 이면 자세가 통째로 사라져 무슨 일이 났는지 안 보인다.
const FLASH_ALPHA := 0.85

## 잉크 굵기. 캐릭터 키 146 에 대해 1.3 — 시트의 선 굵기와 같은 비율이다.
const STROKE := 1.3

## 원을 다각형으로 쪼갤 때의 분할 수. 배율 3 배로 봐도 각이 안 보이는 최소값이다.
const ARC_STEPS := 32

## 원피스 실루엣은 **`CharRig.TORSO_PROFILE` 에 있다.** 여기에 두지 않는 이유가 있다 —
## 손이 몸에 겹치는지를 재려면 리그가 그 높이의 몸 너비를 알아야 하는데, 표가 이 파일에
## 있으면 코어가 못 본다. 그러면 검증이 최대 반너비(밑단)로 재게 되어 거짓말한다.
##
## **밑단(1.00)이 어깨(0.68)보다 1.5 배 넓다.** 첫 판은 이 비가 1.3 이었는데
## 그 정도로는 A 라인이 안 읽히고 그냥 민소매 상의로 보였다.
## 점을 촘촘히 둔 이유도 있다 — 적으면 윤곽선에 각이 생겨 종이봉투가 된다.

## 부츠 실루엣은 **`CharRig.FOOT_PROFILE` 에 있다.** 밑창의 앞뒤 끝이 접지 계산에
## 쓰이므로 코어가 봐야 한다 — 여기 두면 리그가 반너비로 어림잡다 발을 띄운다.
##
## **좁은 목(위쪽 폭 0.96)과 넓은 발(아래쪽 폭 1.42) 그리고 바깥으로 나온 발끝.**

var part := CharPart.Id.HEAD
var rig: CharRig

## **닿는 순간의 번쩍임** (`0` … `1`).
##
## **켜져 있는 동안 일정하다.** 시간에 따라 줄게 두면 하나뿐인 표본이 꺼지기 직전에
## 걸려 아무것도 안 보인다 (§25.28.3).
##
## **값이 안 바뀌면 다시 안 그린다.** 파츠는 트랜스폼만 바뀌므로 평소에는 한 번 그리고
## 마는데, 매 프레임 `queue_redraw()` 를 부르면 그 절약이 사라진다 (§25.8).
var flash := 0.0:
	set(value):
		if is_equal_approx(value, flash):
			return
		flash = value
		queue_redraw()


func setup(p_part: CharPart.Id, p_rig: CharRig) -> void:
	part = p_part
	rig = p_rig
	queue_redraw()


## 파츠의 **바깥 실루엣.** 그리기와 번쩍임이 **같은 폴리곤**을 쓴다.
##
## 두 곳에 따로 적으면 번쩍임이 그림과 어긋난 자리에서 난다 — 이 저장소에서
## 열 번 넘게 밟은 모양이다 (§25.13.1).
func silhouette() -> Array[PackedVector2Array]:
	var half := _half()
	match part:
		CharPart.Id.HEAD:
			return [_ellipse(_center(), half.x, half.x)]
		CharPart.Id.TORSO:
			return [_mirrored_profile(CharRig.TORSO_PROFILE, half)]
		CharPart.Id.HAND_FAR, CharPart.Id.HAND_NEAR:
			var r := half.x
			return [
				_face(_ellipse(Vector2(-r * 0.52, -r * 0.46), r * 0.36, r * 0.42)),
				_face(_ellipse(Vector2(0.0, r * 0.06), r * 0.82, r)),
			]
		_:
			return [_loop_profile(CharRig.FOOT_PROFILE, half, 1.0)]


func _draw() -> void:
	if rig == null:
		return
	var outline := silhouette()
	match part:
		CharPart.Id.HEAD:
			_draw_head(outline[0])
		CharPart.Id.TORSO:
			_draw_torso(outline[0])
		CharPart.Id.HAND_FAR, CharPart.Id.HAND_NEAR:
			_draw_hand(outline)
		_:
			_draw_foot(outline[0])
	if flash <= 0.001:
		return
	# **실루엣이 통째로 하얘진다.** 먼 파츠는 잉크선과 같은 비율로 흐려야 한다 —
	# 번쩍임만 새하야면 뒷손이 앞으로 튀어나온다.
	for polygon in outline:
		_fill(polygon, Color(_ink(FLASH), flash * FLASH_ALPHA))


## 지역 공간에서 그려지는 덩어리의 중심. 코어는 `+y` 가 위이므로 `y` 를 뒤집는다.
func _center() -> Vector2:
	var core := rig.local_centers[part]
	return Vector2(core.x, -core.y)


func _half() -> Vector2:
	return rig.half_sizes[part]


## 머리 — 실루엣은 머리카락 덩어리 하나다. 얼굴은 그 안에 **크고 아래로** 앉힌다.
##
## 얼굴 윤곽에 잉크를 두르지 않는다. 머리카락과 살의 **색 경계가 곧 헤어라인**이고,
## 거기에 선을 한 번 더 그으면 얼굴이 머리에 붙인 가면으로 보인다.
func _draw_head(outline: PackedVector2Array) -> void:
	var r := _half().x

	_blob(outline, _ink(HAIR))
	_fill(_ellipse(Vector2(0.0, -r * 0.77), r * 0.77, r * 0.77), _ink(SKIN))
	# 앞머리 — 이마를 덮어 남은 아래쪽만 얼굴로 만든다. 이것이 단발머리로 읽히게 하는 부분이다.
	_fill(_ellipse(Vector2(0.0, -r * 1.33), r * 0.83, r * 0.50), _ink(HAIR))
	# 광택은 **가운데를 벗어나고 기울어야** 광택이다.
	# 정중앙에 수평으로 두면 머리띠나 베레모로 보인다 (첫 판이 그랬다).
	_fill(_ellipse(Vector2(-r * 0.22, -r * 1.58), r * 0.42, r * 0.10, -0.26), _ink(HAIR_LIGHT))

	var eye := Vector2(r * 0.32, -r * 0.53)
	for side: float in [-1.0, 1.0]:
		var at := Vector2(side * eye.x, eye.y)
		# 위쪽 속눈썹을 눈보다 넓고 납작하게 겹쳐 얹는다. 이 무게가 눈을 크게 보이게 한다.
		_fill(_ellipse(at + Vector2(0.0, -r * 0.16), r * 0.20, r * 0.10), _ink(INK))
		_fill(_ellipse(at, r * 0.17, r * 0.23), _ink(INK))
		# 하이라이트는 두 눈 모두 **같은 쪽**에 둔다. 좌우로 뒤집으면 빛이 두 군데서 오고,
		# 눈 안에서 눈동자처럼 읽혀 물음표 모양이 된다.
		_fill(_ellipse(at + Vector2(-r * 0.055, -r * 0.10), r * 0.065, r * 0.065), _ink(SKIN))
		# 볼은 **얼굴 안에** 있어야 한다. 처음엔 0.57 이라 머리카락을 넘어 밖으로 삐져나왔다.
		_fill(_ellipse(Vector2(side * r * 0.44, -r * 0.40), r * 0.15, r * 0.075), _ink(BLUSH))
	_fill(_ellipse(Vector2(0.0, -r * 0.23), r * 0.072, r * 0.052), _ink(MOUTH))


## 몸 — 둥근 어깨에서 잘록한 허리로, 다시 벌어지는 밑단으로.
func _draw_torso(points: PackedVector2Array) -> void:
	var half := _half()
	_blob(points, _ink(DRESS_SHADE))
	# 손과 같은 두 판 방식. 직선으로 자르면 음영이 아니라 접힌 자국으로 보였다 —
	# 밝은 판을 **실루엣 자체를 줄여** 얹으면 그늘이 치맛단의 곡선을 따라 흐른다.
	_fill(_shrunk(points, 0.80, half.x * 0.11, 0.94), _ink(DRESS))
	_blob(_ellipse(Vector2(0.0, -half.y * 1.92), half.x * 0.42, half.y * 0.12), _ink(COLLAR))


## 손 — 엄지를 먼저 찍고 손등으로 덮어 이음매를 감춘다. 그 순서가 벙어리장갑을 만든다.
##
## 손등은 **원이 아니라 달걀**이다. 정원으로 그리면 볼링공이 되고, 엄지를 옆으로 멀리
## 빼면 주전자 주둥이가 된다 (첫 판이 둘 다였다). 엄지는 안쪽 **위**에 얹은 혹이어야 한다.
##
## 음영은 **어두운 판을 먼저 깔고 밝은 쪽을 위에 얹어** 만든다. 반대로 하면 그늘이
## 실루엣 밖으로 새어 나간다 — `draw_colored_polygon` 은 잘라 주지 않기 때문이다.
## 이 순서가 곧 자체 클리핑이고, 그늘이 실루엣의 바깥 테두리에 닿아 셀 음영으로 읽힌다.
## **뒷손은 좌우로 뒤집어 그린다.** 왼손과 오른손은 서로 거울이라, 같은 그림을 두 손에
## 쓰면 **오른손이 둘**이 된다 — 엄지가 같은 쪽에 붙어 있어 그렇게 보인다.
##
## **발은 안 뒤집는다.** 발은 좌우 거울이 아니라 **둘 다 앞(`+x`)을 본다** — 옆에서 본
## 두 발은 발끝이 같은 방향이다. 뒤집으면 뒷발의 발끝이 뒤를 향해 정면 자세가 된다
## (§25.0.1 이 정한 것이고, 지금도 유효하다).
func _draw_hand(outline: Array[PackedVector2Array]) -> void:
	var r := _half().x
	# 두 손이 **같은 쪽**을 본다. 옆에서 보면 앞손과 뒷손이 같은 각도로 보이기 때문이다.
	_blob(outline[0], _ink(MITTEN_SHADE))
	_blob(outline[1], _ink(MITTEN_SHADE))
	_fill(_face(_ellipse(Vector2(-r * 0.12, -r * 0.18), r * 0.62, r * 0.72)), _ink(MITTEN))
	_blob(_face(_ellipse(Vector2(0.0, -r * 0.86), r * 0.50, r * 0.20)), _ink(BOOT))


func _draw_foot(points: PackedVector2Array) -> void:
	var half := _half()
	# 발끝이 **둘 다 앞(`+x`)** 을 본다. 거울로 뒤집으면 그 순간 정면 자세가 된다.
	_blob(points, _ink(BOOT))
	# 목 안쪽. 좁은 목이 있어야 이것이 통 뚜껑이 아니라 부츠 입구로 읽힌다.
	_fill(_ellipse(Vector2(0.0, -half.y * 1.86), half.x * 0.40, half.y * 0.11), _ink(BOOT_LIGHT))


## 한쪽 윤곽만 적은 비율표를 **좌우 대칭으로 닫아** 폴리곤을 만든다.
##
## 한쪽만 펼치면 점이 한 줄로 늘어선 실이 되어 삼각분할이 실패한다
## (실제로 `Invalid polygon data, triangulation failed` 로 걸렸다).
## 중심선 위의 점(`x = 0`)은 되돌아올 때 건너뛴다 — 겹친 점은 윤곽선을 끊는다.
func _mirrored_profile(profile: Array[Vector2], half: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in profile:
		points.append(Vector2(p.x * half.x, -p.y * half.y * 2.0))
	for i in range(profile.size() - 1, -1, -1):
		var p := profile[i]
		if is_zero_approx(p.x):
			continue
		points.append(Vector2(-p.x * half.x, -p.y * half.y * 2.0))
	return points


## 이미 한 바퀴를 다 적은 비율표를 펼친다. `outward` 가 좌우를 뒤집는다.
func _loop_profile(profile: Array[Vector2], half: Vector2, outward: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in profile:
		points.append(Vector2(p.x * half.x * outward, -p.y * half.y * 2.0))
	return points


## 뒷손은 좌우가 뒤집힌다 — 왼손과 오른손은 서로 거울이라 같은 그림을 두 손에 쓰면
## **오른손이 둘**이 된다.
##
## **`draw_set_transform` 이 아니라 점을 뒤집는다.** 번쩍임은 그리기 밖에서 같은
## 폴리곤을 받아 쓰므로, 뒤집기가 그리기 안에만 있으면 **번쩍임만 반대쪽에서 난다.**
##
## **발은 안 뒤집는다.** 옆에서 본 두 발은 발끝이 같은 방향이다 (§25.0.1).
func _face(points: PackedVector2Array) -> PackedVector2Array:
	if part != CharPart.Id.HAND_FAR:
		return points
	var flipped := PackedVector2Array()
	for p in points:
		flipped.append(Vector2(-p.x, p.y))
	return flipped


func _ellipse(center: Vector2, rx: float, ry: float, tilt := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ARC_STEPS:
		var a := TAU * float(i) / float(ARC_STEPS)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	return points


## 실루엣을 좁히고 오른쪽으로 밀어 **안쪽에 들어가는 밝은 판**을 만든다.
##
## 밑면(`y = 0`)을 기준으로 세로를 줄이므로 밑단이 제자리에 남는다.
## 밀어내는 양을 폭 축소분보다 작게 두어야 오른쪽 테두리를 넘지 않는다.
func _shrunk(
	points: PackedVector2Array, width_scale: float, shift_x: float, height_scale: float
) -> PackedVector2Array:
	var inner := PackedVector2Array()
	for p in points:
		inner.append(Vector2(p.x * width_scale + shift_x, p.y * height_scale))
	return inner


## 먼 파츠면 배경 쪽으로 물들인 색을, 아니면 원래 색을 준다.
##
## 잉크선까지 같이 흐려야 한다 — 선만 새까맣게 남으면 뒷손이 앞으로 튀어나와 보인다.
func _ink(color: Color) -> Color:
	if not CharPart.is_far(part):
		return color
	return color.lerp(FAR_TINT, FAR_TINT_AMOUNT)


func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		draw_colored_polygon(points, color)


## 채우고 잉크로 두른다. **모든 덩어리는 두 번 찍힌다** — 셀 그림체의 본체다.
func _blob(points: PackedVector2Array, color: Color) -> void:
	_fill(points, color)
	if points.size() < 2:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, _ink(INK), STROKE, true)
