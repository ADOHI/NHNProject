extends SceneTree
## **2D 노멀맵은 스프라이트가 돌면 같이 도나?** 이 한 가지만 잰다.
##
##     godot --path . -s res://tools/probe_normal_rotation.gd
##
## # 왜 이것부터인가
##
## 인물이 파츠로 쪼개져 있고 **파츠는 서로 돈다** (팔·다리). 판(배경)은 안 돈다.
## 그래서 §26.4 가 배경에서 얻은 결론을 인물에 그대로 못 가져온다 — 먼저 이걸
## 알아야 한다:
##
## | 돌면 노멀도 같이 돌면 | 파츠마다 텍스처 공간에서 구우면 되고, 굽는 것이 곧 답이다 |
## | 안 돌면 | 구운 노멀은 **쉬는 자세에서만 맞다.** 팔을 90° 들면 90° 틀린다 |
##
## # 어떻게 재나 — **한 방향만 보는 노멀**을 쓴다
##
## 노멀맵을 통째로 `+X`(RGB 255,128,128) 로 채운다. 빛을 오른쪽(`+X`)에 둔다.
##
##     돌기 전 (0°)    N·L 이 최대   -> 밝다
##     90° 돌린 뒤     노멀이 돌면 N 이 +Y 가 되어 빛과 직각  -> 어두워진다
##                     노멀이 안 돌면 N 이 그대로 +X          -> 그대로 밝다
##
## **밝기 하나로 갈린다.** 구(球) 같은 노멀을 쓰면 회전 대칭이라 안 갈린다 —
## 일부러 방향이 하나뿐인 노멀을 쓴다.

## 판정 문턱. 90° 돌려서 이만큼 안 어두워지면 「노멀이 안 돈다」로 본다.
const _ROTATED_DROP_FROM := 0.25

const _OUT := "res://.renders-lighting/normal_rotation"
const _SIZE := 256


func _initialize() -> void:
	_run()


func _run() -> void:
	var root := self.root
	root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color.BLACK)

	# **알베도는 완전히 평평한 회색이다.** 그림에 명암이 있으면 「빛이 갈랐나
	# 그림이 원래 그랬나」를 못 가른다.
	var albedo := Image.create(_SIZE, _SIZE, false, Image.FORMAT_RGBA8)
	albedo.fill(Color(0.5, 0.5, 0.5, 1.0))

	# 전부 `+X` 를 보는 노멀. (0.5,0.5,1.0) 이 「화면을 본다」이므로 x 를 1.0 으로.
	var normal := Image.create(_SIZE, _SIZE, false, Image.FORMAT_RGBA8)
	normal.fill(Color(1.0, 0.5, 0.5, 1.0))

	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = ImageTexture.create_from_image(albedo)
	canvas.normal_texture = ImageTexture.create_from_image(normal)

	var stage := Node2D.new()
	root.add_child(stage)

	var sprite := Sprite2D.new()
	sprite.texture = canvas
	sprite.position = Vector2(_SIZE, _SIZE) * 0.5
	stage.add_child(sprite)

	# 빛을 **오른쪽**에 둔다. `height` 는 픽셀이다 (§26.4.12 에서 이걸 틀렸었다) —
	# 0 이면 빛이 판에 누워서 노멀이 일을 안 한다.
	var light := PointLight2D.new()
	light.texture = _falloff()
	light.position = sprite.position + Vector2(_SIZE, 0.0)
	light.height = 64.0
	light.energy = 2.0
	light.texture_scale = 4.0
	stage.add_child(light)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUT))

	# **평균으로는 못 가른다.** 빛이 가까운 점광원이라 노멀이 돌면 밝아지는 쪽과
	# 어두워지는 쪽이 반반이라 평균이 거의 안 움직인다 (실제로 -12% 였다).
	# 그래서 **정답 그림과 맞춰 본다** — 네모는 90° 대칭이라 실루엣이 안 변하므로
	# 세 그림이 덮는 화소가 전부 같다.
	#
	#   A  안 돌린 스프라이트 + `+X` 노멀   <- 「노멀이 안 돈다」면 C 가 여기 맞는다
	#   B  안 돌린 스프라이트 + `+Y` 노멀   <- 「같이 돈다」면 C 가 여기 맞는다
	#   B' 안 돌린 스프라이트 + `-Y` 노멀   <- 초록 채널 방향이 반대인 경우
	#   C  **90° 돌린** 스프라이트 + `+X` 노멀
	var cases := {
		"A_rot0_plusX": [0.0, Color(1.0, 0.5, 0.5, 1.0)],
		"B_rot0_plusY": [0.0, Color(0.5, 1.0, 0.5, 1.0)],
		"B2_rot0_minusY": [0.0, Color(0.5, 0.0, 0.5, 1.0)],
		"C_rot90_plusX": [90.0, Color(1.0, 0.5, 0.5, 1.0)],
	}
	var shots := {}
	for name: String in cases:
		var entry: Array = cases[name]
		normal.fill(entry[1] as Color)
		canvas.normal_texture = ImageTexture.create_from_image(normal)
		sprite.rotation_degrees = entry[0] as float
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.save_png("%s/%s.png" % [ProjectSettings.globalize_path(_OUT), name])
		shots[name] = shot
		print("  %-16s 네모 안 평균 밝기 %.4f" % [name, _mean_luma(shot)])

	print("")
	var target: Image = shots["C_rot90_plusX"]
	var best := ""
	var best_diff := 1e9
	for name: String in ["A_rot0_plusX", "B_rot0_plusY", "B2_rot0_minusY"]:
		var mean_diff := _mean_diff(target, shots[name] as Image)
		print("  C 와 %-16s 평균 화소 차이 %.4f" % [name, mean_diff])
		if mean_diff < best_diff:
			best_diff = mean_diff
			best = name
	print("")
	if best == "A_rot0_plusX":
		print("판정: **노멀이 안 돈다 — 화면 좌표계에 붙어 있다.**")
		print("  -> 구운 노멀은 쉬는 자세에서만 맞다. 파츠가 도는 만큼 틀린다.")
	else:
		print("판정: **노멀이 스프라이트와 같이 돈다** (%s 와 맞는다)." % best)
		print("  -> 파츠를 텍스처 공간에서 구우면 되고, 팔다리가 돌아도 맞다.")
	quit()


## 두 그림의 **화소별 평균 절대 차이**. 「어느 쪽에 더 가까운가」를 고를 때 쓴다.
func _mean_diff(a: Image, b: Image) -> float:
	var total := 0.0
	for y: int in range(_SIZE):
		for x: int in range(_SIZE):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			total += (absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)) / 3.0
	return total / float(_SIZE * _SIZE)


## 두 그림의 **화소별 최대 밝기 차이**. 「같은 그림인가」를 평균 없이 본다 —
## 평균은 밝아진 곳과 어두워진 곳이 서로를 지운다.
func _max_diff(a: Image, b: Image) -> float:
	var worst := 0.0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			worst = maxf(worst, absf(pa.r - pb.r))
			worst = maxf(worst, absf(pa.g - pb.g))
			worst = maxf(worst, absf(pa.b - pb.b))
	return worst


## 가운데가 밝고 가장자리로 떨어지는 흰 원. `PointLight2D` 는 텍스처가 있어야 켜진다.
func _falloff() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var mid := float(size) * 0.5
	for y: int in range(size):
		for x: int in range(size):
			var d := Vector2(float(x) - mid, float(y) - mid).length() / mid
			var v := clampf(1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, v))
	return ImageTexture.create_from_image(image)


## **스프라이트가 덮는 네모 안**의 평균 밝기. 자리를 좌표로 고정한다.
##
## 처음엔 「밝은 화소만」(`luma > 0.02`) 평균을 냈는데 **그게 자를 망가뜨렸다** —
## 회전으로 어두워진 화소가 문턱 아래로 내려가면 **평균에서 빠져 버려서**, 어두워질수록
## 평균이 안 떨어진다. 재려는 것(어두워졌나)을 재는 행위가 지우고 있었다.
func _mean_luma(image: Image) -> float:
	var total := 0.0
	var count := 0
	for y: int in range(_SIZE):
		for x: int in range(_SIZE):
			var c := image.get_pixel(x, y)
			total += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			count += 1
	return total / maxf(1.0, float(count))
