class_name ProtoNormalFromLuminance
extends RefCounted
## **휘도 기울기로 노멀맵을 근사한다.** 노드에 의존하지 않는 순수 변환이다.
##
## 사용자가 요구한 것은 「AI 로 노멀 만들기」이고, 이것은 **그 앞에 세워 두는 대조군**이다.
## AI 추정이 값을 하는지는 이것보다 나은지로만 말할 수 있다. 먼저 싼 쪽을 만들어
## 재고, 비싼 쪽이 눈에 보이게 나을 때만 비싼 쪽을 쓴다 (90 시간 잼이다).
##
## 원리: 화면의 밝기를 높이로 읽고(밝은 곳이 튀어나왔다고 가정), Sobel 로 x·y 기울기를
## 구해 그 기울기에 수직인 벡터를 법선으로 삼는다. **이 가정은 틀릴 수 있다** —
## 흰 대리석 무늬는 튀어나온 것이 아니라 색이 흰 것이고, 이 방법은 그것을 구분하지
## 못한다. 그 한계가 곧 AI 추정을 쓸 이유가 되는 지점이고, `docs/design/26-2d-lighting.md`
## 에서 실제 그림으로 가른다.
##
## 출력은 Godot 이 기대하는 **접선 공간 노멀맵**이다 —
## `r = x*0.5+0.5`, `g = (-y)*0.5+0.5`, `b = z*0.5+0.5`.
## `g` 의 부호를 뒤집는 이유는 엔진 셰이더가 `texture(normal_texture, uv).xy *
## vec2(2.0, -2.0) - vec2(1.0, -1.0)` 로 읽기 때문이다 (`drivers/gles3/shaders/canvas.glsl`).
## **부호를 틀리면 빛이 반대쪽에서 오는 것처럼 보이는데, 증상이 「노멀이 약하다」와
## 똑같이 생긴다.** 방 시각화 레인이 알파 램프를 좌우로 뒤집어 붙였던 사고와 같은 종류다
## (`room-studio/docs/OPEN-ISSUES.md` §2-b).


## `source` 의 휘도에서 노멀맵을 만든다.
## `strength` 가 크면 기울기를 세게 읽어 요철이 강해진다.
static func build(source: Image, strength: float = 4.0) -> Image:
	var w := source.get_width()
	var h := source.get_height()
	var height_map := PackedFloat32Array()
	height_map.resize(w * h)
	for y in h:
		for x in w:
			height_map[y * w + x] = _luma(source.get_pixel(x, y))

	var out := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			# Sobel. 가장자리는 좌표를 물려 읽는다(clamp) — 감싸 읽으면(wrap)
			# 이음선에서 없는 요철이 생긴다.
			var dx := (
				(
					_at(height_map, w, h, x + 1, y - 1)
					+ 2.0 * _at(height_map, w, h, x + 1, y)
					+ _at(height_map, w, h, x + 1, y + 1)
				)
				- (
					_at(height_map, w, h, x - 1, y - 1)
					+ 2.0 * _at(height_map, w, h, x - 1, y)
					+ _at(height_map, w, h, x - 1, y + 1)
				)
			)
			var dy := (
				(
					_at(height_map, w, h, x - 1, y + 1)
					+ 2.0 * _at(height_map, w, h, x, y + 1)
					+ _at(height_map, w, h, x + 1, y + 1)
				)
				- (
					_at(height_map, w, h, x - 1, y - 1)
					+ 2.0 * _at(height_map, w, h, x, y - 1)
					+ _at(height_map, w, h, x + 1, y - 1)
				)
			)
			var n := Vector3(-dx * strength, -dy * strength, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, -n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return out


## **기울어진 평면의 법선 하나로 채운다. 추정이 아니라 계산이다.**
##
## 방 시각화의 바닥은 **정사영 바닥밭을 워프한 것**이라 바닥의 법선이 기하에서
## 곧바로 나온다 — 평면이니까 어디서나 같은 벡터다. 여기에 AI 추정을 돌리는 것은
## **아는 답을 모르는 척하고 알아맞히는 것**이고, 맞히지도 못한다(그림에는 얼룩과
## 줄눈이 있고 추정기는 그것을 요철로 읽는다).
##
## `pitch_degrees` 는 바닥면이 화면에서 얼마나 누워 보이는가다.
## 0 이면 화면을 정면으로 마주 본 벽(=평평한 노멀), 90 이면 완전히 누운 바닥이다.
static func build_plane(width: int, height: int, pitch_degrees: float) -> Image:
	var pitch := deg_to_rad(clampf(pitch_degrees, 0.0, 89.0))
	# 화면 위쪽(−y)으로 기울어 눕는 면. z 는 화면 밖을 본다.
	var n := Vector3(0.0, -sin(pitch), cos(pitch)).normalized()
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(n.x * 0.5 + 0.5, -n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return image


## 평면 법선 위에 휘도 결을 얹는다. 바닥이 「누워 있으면서 줄눈도 있는」 경우다.
static func build_plane_with_detail(
	source: Image, pitch_degrees: float, strength: float = 1.5
) -> Image:
	var detail := build(source, strength)
	var pitch := deg_to_rad(clampf(pitch_degrees, 0.0, 89.0))
	var base := Vector3(0.0, -sin(pitch), cos(pitch)).normalized()
	var out := Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGB8)
	for y in source.get_height():
		for x in source.get_width():
			var c := detail.get_pixel(x, y)
			# 결의 기울기만 뽑아 평면 법선에 더한다. 두 법선을 섞는 것이 아니라
			# **평면을 기준면으로 삼고 그 위의 요철**로 다룬다.
			var tilt := Vector3(c.r * 2.0 - 1.0, -(c.g * 2.0 - 1.0), 0.0)
			var n := (base + tilt).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, -n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	return out


## 노멀맵이 실제로 방향을 담고 있는지 재는 자. **아무것도 확인하지 않는 검사가
## 통과하는 것**을 막기 위한 것이다 (`CLAUDE.md` 의 일곱 유형 중 여섯째).
##
## 평평한 노멀맵은 전부 (0.5, 0.5, 1.0) 이고 이 값이 0 이다. 클수록 요철이 세다.
static func tilt_rms(normal_map: Image) -> float:
	var total := 0.0
	var w := normal_map.get_width()
	var h := normal_map.get_height()
	for y in h:
		for x in w:
			var c := normal_map.get_pixel(x, y)
			var nx := c.r * 2.0 - 1.0
			var ny := c.g * 2.0 - 1.0
			total += nx * nx + ny * ny
	return sqrt(total / float(maxi(1, w * h)))


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _at(map: PackedFloat32Array, w: int, h: int, x: int, y: int) -> float:
	return map[clampi(y, 0, h - 1) * w + clampi(x, 0, w - 1)]
