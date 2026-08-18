extends GutTest
## 코어가 잰 것과 **셰이더가 받는 것이 같은가.**
##
## `docs/design/31-soft-body.md` §31.5.3 · §31.6.3.
##
## ## 여기가 §25.13.1 의 다섯 번째가 날 자리다
##
## 앵커는 **파츠 지역 좌표**로 적혀 있고 셰이더는 **UV** 로 읽는다. 그 사이에 변환이
## 하나 있고, 그림이 왼쪽을 보므로 **좌우가 한 번 뒤집힌다** (§25.41.9).
##
## > 변환이 틀리면 **자는 얼굴을 안 건드린다고 말하는데 화면에서는 얼굴이 녹는다.**
## > 자가 코어만 보면 그것을 영원히 못 본다.
##
## 그래서 이 파일은 **셰이더가 받은 uniform 을 도로 읽어** 코어의 `weight_at()` 과
## 같은 답이 나오는지 잰다. 셰이더의 세 줄을 여기서 다시 쓰는 것은 중복이 아니라
## **그 세 줄이 무엇을 보는지 재는 유일한 방법**이다.

const EPS := 0.0001


## 알파가 꽉 찬 작은 그림. **모양은 상관없다** — 재는 것은 좌표 변환이다.
func _texture(size: Vector2i) -> Texture2D:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


## 파츠 여섯에 그림을 물린 껍데기. 실물 폴더가 없어도 그림 경로를 밟는다.
func _skin(rig: CharRig) -> CharSkin:
	var skin := CharSkin.new()
	skin.rig = rig
	for part in CharPart.COUNT:
		var half := rig.half_sizes[part]
		skin.textures[part] = _texture(Vector2i(int(half.x * 2.0), int(half.y * 2.0)))
	return skin


func _view(morph: MorphRig, merged := false) -> CharPartsView:
	var view := CharPartsView.new()
	add_child_autofree(view)
	var rig := CharRig.new()
	view.skin = _skin(rig)
	view.morph = morph
	view.merged = merged
	view.setup(rig)
	return view


func _sprite(view: CharPartsView, part: CharPart.Id) -> CharPartSprite:
	return view.part_node(part) as CharPartSprite


# --- 꺼짐이 진짜 꺼짐인가 ------------------------------------------------------


func test_no_morph_means_no_material_at_all() -> void:
	# **붙여 놓고 0 을 넣는 것과 다르다.** 안 붙어야 지금과 같은 경로로 그려진다.
	var view := _view(null)
	for part in CharPart.COUNT:
		var sprite := _sprite(view, part)
		assert_null(sprite.material, "%s 에 재질이 붙었다" % CharPart.part_name(part))
		assert_false(sprite.has_morph())


func test_strength_zero_means_no_material_either() -> void:
	var view := _view(MorphRig.default_for(CharRig.new(), 0.0))
	for part in CharPart.COUNT:
		assert_null(_sprite(view, part).material, "세기 0 인데 재질이 붙었다")


func test_no_morph_means_no_padding_on_the_rect() -> void:
	# 여백이 붙으면 그리는 화소가 달라진다 — 「픽셀 단위로 같다」가 거짓이 된다 (§31.5.3).
	var view := _view(null)
	for part in CharPart.COUNT:
		var sprite := _sprite(view, part)
		assert_eq(sprite.draw_rect_local(), sprite.base_rect_local())


func test_the_morph_rect_grows_so_the_flesh_has_somewhere_to_go() -> void:
	# 그림이 알파 경계상자로 딱 잘려 있어 안 넓히면 밀려난 살이 변에서 잘린다 (§31.6.2).
	var view := _view(MorphRig.default_for(CharRig.new()))
	var sprite := _sprite(view, CharPart.Id.TORSO)
	assert_gt(sprite.draw_rect_local().size.x, sprite.base_rect_local().size.x)
	# 넓힌 양이 진폭 상한보다 넉넉해야 한다.
	var grew := (sprite.draw_rect_local().size.x - sprite.base_rect_local().size.x) * 0.5
	assert_gt(grew, MorphRig.LIMIT_RATIO * CharRig.TORSO_HALF.x)


# --- 어디에 붙나 --------------------------------------------------------------


func test_only_the_torso_and_the_head_carry_anchors() -> void:
	# 파츠를 안 늘리는 대신 **둘만 휜다.** 손발에 붙으면 벙어리장갑이 물러진다.
	var view := _view(MorphRig.default_for(CharRig.new()))
	assert_true(_sprite(view, CharPart.Id.TORSO).has_morph())
	assert_true(_sprite(view, CharPart.Id.HEAD).has_morph())
	for part in [
		CharPart.Id.HAND_NEAR, CharPart.Id.HAND_FAR, CharPart.Id.FOOT_NEAR, CharPart.Id.FOOT_FAR
	]:
		assert_false(_sprite(view, part).has_morph(), "%s 가 휜다" % CharPart.part_name(part))


func test_merged_drawing_never_gets_a_morph() -> void:
	# 합쳐 그리면 **남의 캔버스에 찍어서 파츠의 재질이 안 쓰인다.** 넓힌 사각형만 남으면
	# 그림이 커진다 — 벤치가 다른 그림을 재게 된다 (§31.6.1).
	var view := _view(MorphRig.default_for(CharRig.new()), true)
	for part in CharPart.COUNT:
		var sprite := _sprite(view, part)
		assert_false(sprite.has_morph())
		assert_eq(sprite.draw_rect_local(), sprite.base_rect_local())


func test_placeholder_shapes_do_not_explode() -> void:
	# 도형판에는 UV 가 없다. **갈래를 새로 만들지 않는다** — 그냥 아무 일도 안 일어난다.
	var view := CharPartsView.new()
	add_child_autofree(view)
	view.morph = MorphRig.default_for(CharRig.new())
	view.setup(CharRig.new())
	var clip := CharIdleClip.new(view.rig)
	var f := AnimFeatures.all_on()
	view.morph_at(clip, 0.7, f, clip.sample(0.7, f))
	assert_true(view.part_node(CharPart.Id.TORSO) is CharPartShape)


# --- 좌표 변환 ----------------------------------------------------------------


func test_the_part_box_maps_to_the_whole_uv_square() -> void:
	var view := _view(MorphRig.default_for(CharRig.new()))
	var sprite := _sprite(view, CharPart.Id.HEAD)
	var half := view.rig.half_sizes[CharPart.Id.HEAD]
	var centre := view.rig.local_centers[CharPart.Id.HEAD]
	# 파츠 지역의 네 귀퉁이가 UV 의 네 귀퉁이여야 한다.
	for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
		var uv := sprite.uv_of(centre + corner * half)
		assert_almost_eq(minf(uv.x, uv.y), 0.0 if uv.x < 0.5 or uv.y < 0.5 else 1.0, 0.01)
		assert_between(uv.x, -EPS, 1.0 + EPS)
		assert_between(uv.y, -EPS, 1.0 + EPS)
	assert_almost_eq(sprite.uv_of(centre).x, 0.5, EPS)
	assert_almost_eq(sprite.uv_of(centre).y, 0.5, EPS)


func test_height_flips_because_local_y_points_down() -> void:
	var view := _view(MorphRig.default_for(CharRig.new()))
	var sprite := _sprite(view, CharPart.Id.HEAD)
	var centre := view.rig.local_centers[CharPart.Id.HEAD]
	var high := sprite.uv_of(centre + Vector2(0.0, 10.0))
	var low := sprite.uv_of(centre - Vector2(0.0, 10.0))
	assert_lt(high.y, low.y, "위가 UV 에서 아래로 가면 머리카락이 턱에 달린다")


func test_a_borrowed_sprite_flips_sideways_and_only_sideways() -> void:
	# 그림이 왼쪽을 보므로 파츠 지역 `+x` 가 텍스처의 `-u` 다 (§31.6.3).
	var rig := CharRig.new()
	var plain := CharPartSprite.new()
	autofree(plain)
	plain.setup(CharPart.Id.HEAD, rig, _texture(Vector2i(60, 60)), false)
	var flipped := CharPartSprite.new()
	autofree(flipped)
	flipped.setup(CharPart.Id.HEAD, rig, _texture(Vector2i(60, 60)), true)
	var at := rig.local_centers[CharPart.Id.HEAD] + Vector2(12.0, 7.0)
	assert_almost_eq(flipped.uv_of(at).x, 1.0 - plain.uv_of(at).x, EPS)
	assert_almost_eq(flipped.uv_of(at).y, plain.uv_of(at).y, EPS, "좌우만 뒤집혀야 한다")
	var step := Vector2(3.0, 0.0)
	assert_almost_eq(flipped.uv_delta_of(step).x, -plain.uv_delta_of(step).x, EPS)


# --- 셰이더가 받은 것이 코어가 잰 것과 같은가 -----------------------------------


## 셰이더의 반평면 세 줄을 그대로 다시 쓴다. **이것이 그 줄이 보는 것을 재는 방법이다.**
func _mask_from_uniform(mask: Vector4, uv: Vector2) -> float:
	if Vector2(mask.x, mask.y).is_zero_approx():
		return 1.0
	return smoothstep(mask.z - mask.w, mask.z + mask.w, Vector2(mask.x, mask.y).dot(uv))


func _check_mask_agrees(part: CharPart.Id, mirror: bool) -> void:
	var rig := CharRig.new()
	var morph := MorphRig.default_for(rig)
	var index := morph.indices_of(part)[0]
	var anchor := morph.anchors[index]
	var sprite := CharPartSprite.new()
	autofree(sprite)
	var half := rig.half_sizes[part]
	sprite.setup(part, rig, _texture(Vector2i(int(half.x * 2.0), int(half.y * 2.0))), mirror)
	var list: Array[MorphAnchor] = [anchor]
	sprite.setup_morph(list)
	var masks: PackedVector4Array = sprite.material.get_shader_parameter("anchor_mask")
	var centre := rig.local_centers[part]
	for ix in range(-10, 11):
		for iy in range(-10, 11):
			var point := centre + Vector2(half.x * ix * 0.1, half.y * iy * 0.1)
			var want := anchor.mask_at(point)
			var got := _mask_from_uniform(masks[0], sprite.uv_of(point))
			assert_almost_eq(got, want, 0.002, "%s 에서 마스크가 갈렸다 (뒤집기 %s)" % [point, mirror])


func test_the_shader_mask_sees_what_the_core_ruler_sees() -> void:
	_check_mask_agrees(CharPart.Id.HEAD, false)
	_check_mask_agrees(CharPart.Id.TORSO, false)


func test_the_shader_mask_survives_the_left_facing_flip() -> void:
	# **뒤집기를 빠뜨리면 마스크가 반대쪽을 지킨다** — 얼굴 대신 뒤통수를 지키게 된다.
	_check_mask_agrees(CharPart.Id.HEAD, true)
	_check_mask_agrees(CharPart.Id.TORSO, true)


func test_the_face_stays_out_of_the_warp_in_uv_too() -> void:
	# 코어가 아니라 **셰이더가 받은 값**으로 다시 묻는다. 이 물음이 §25.13.1 을 막는다.
	var rig := CharRig.new()
	var morph := MorphRig.default_for(rig)
	var anchor := morph.anchors[morph.index_of(MorphRig.HAIR)]
	var half := rig.half_sizes[CharPart.Id.HEAD]
	for mirror in [false, true]:
		var sprite := CharPartSprite.new()
		autofree(sprite)
		sprite.setup(
			CharPart.Id.HEAD, rig, _texture(Vector2i(int(half.x * 2.0), int(half.y * 2.0))), mirror
		)
		var list: Array[MorphAnchor] = [anchor]
		sprite.setup_morph(list)
		var masks: PackedVector4Array = sprite.material.get_shader_parameter("anchor_mask")
		for point: Vector2 in [
			Vector2(0.30 * half.x, 0.80 * half.y),
			Vector2(0.35 * half.x, 0.62 * half.y),
			Vector2(0.30 * half.x, 0.45 * half.y)
		]:
			assert_almost_eq(
				_mask_from_uniform(masks[0], sprite.uv_of(point)),
				0.0,
				EPS,
				"셰이더가 얼굴 %s 를 휜다 (뒤집기 %s)" % [point, mirror]
			)


func test_the_uniforms_actually_move_when_the_body_wobbles() -> void:
	# **넣는 자리가 있는데 아무 값도 안 가면 조용히 꺼진 것이다** (§25.13.6).
	var view := _view(MorphRig.default_for(CharRig.new()))
	var clip := CharRunClip.new(view.rig)
	var f := AnimFeatures.all_on()
	var sprite := _sprite(view, CharPart.Id.TORSO)
	var seen := 0.0
	for i in 40:
		var at := clip.loop_seconds() * float(i) / 40.0
		view.morph_at(clip, at, f, clip.sample(at, f))
		var shifts: PackedVector2Array = sprite.material.get_shader_parameter("anchor_shift")
		seen = maxf(seen, shifts[0].length())
	assert_gt(seen, 0.005, "달리는데 UV 가 하나도 안 움직인다")
