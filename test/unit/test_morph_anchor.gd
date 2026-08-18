extends GutTest
## 앵커의 감쇠와 **영역 마스크.**
##
## `docs/design/31-soft-body.md` §31.2.3.
##
## ## ★ 여기서 막는 것은 하나다 — **얼굴이 녹는 것**
##
## 머리 앵커의 감쇠 반경이 얼굴까지 닿으면 이목구비가 뭉개진다. 그리고 그것은
## **화면에서만 보인다** — 자가 못 보면 §25.13.1 의 다섯 번째가 여기서 난다.
##
## 그래서 마스크를 **자료**로 뒀고, 이 파일이 그 자료를 읽어 **얼굴 자리의 가중치가
## 0 인지**를 단언한다. 그림이 바뀌어도 이 자는 안 바뀐다.

const EPS := 0.0001


func _rig() -> CharRig:
	return CharRig.new()


func _hair() -> MorphAnchor:
	var morph := MorphRig.default_for(_rig())
	return morph.anchors[morph.index_of(MorphRig.HAIR)]


func _chest() -> MorphAnchor:
	var morph := MorphRig.default_for(_rig())
	return morph.anchors[morph.index_of(MorphRig.CHEST)]


# --- 감쇠 -------------------------------------------------------------------


func test_the_centre_moves_the_most() -> void:
	var anchor := _chest()
	assert_almost_eq(anchor.falloff_at(anchor.centre), 1.0, EPS)


func test_outside_the_radius_nothing_moves() -> void:
	var anchor := _chest()
	assert_eq(anchor.falloff_at(anchor.centre + anchor.radius * 1.01), 0.0)
	assert_eq(anchor.falloff_at(anchor.centre - anchor.radius * 2.0), 0.0)


func test_the_falloff_never_leaves_zero_to_one() -> void:
	var anchor := _hair()
	for x in range(-60, 61, 5):
		for y in range(-20, 100, 5):
			var w := anchor.weight_at(Vector2(float(x), float(y)))
			assert_between(w, 0.0, 1.0, "(%d, %d) 의 가중치가 범위 밖이다" % [x, y])


func test_the_radius_is_elliptical_not_circular() -> void:
	# 반경을 스칼라로 두면 머리카락이 **동그랗게** 부푼다. 축마다 달라야 한다.
	var anchor := _hair()
	assert_ne(anchor.radius.x, anchor.radius.y)


# --- ★ 얼굴 -----------------------------------------------------------------


## 머리 지역 좌표에서 **얼굴이 있는 자리들.** 머리는 `y 0 … 60` 이고 앞이 `+x` 다.
func _face_points(rig: CharRig) -> Array:
	var half := rig.half_sizes[CharPart.Id.HEAD]
	return [
		Vector2(0.30 * half.x, 0.80 * half.y),  # 눈
		Vector2(0.42 * half.x, 0.80 * half.y),  # 바깥 눈
		Vector2(0.35 * half.x, 0.62 * half.y),  # 코
		Vector2(0.30 * half.x, 0.45 * half.y),  # 입
		Vector2(0.10 * half.x, 0.90 * half.y),  # 미간
		Vector2(0.55 * half.x, 1.00 * half.y),  # 뺨 위
	]


func test_the_hair_anchor_never_touches_the_face() -> void:
	var rig := _rig()
	var anchor := _hair()
	for point: Vector2 in _face_points(rig):
		assert_eq(
			anchor.weight_at(point), 0.0, "얼굴 자리 %s 가 휜다 — 이목구비가 녹는다" % point
		)


func test_the_hair_anchor_does_reach_the_crown_and_the_back() -> void:
	# **안 닿는 것만 확인하면 마스크를 다 닫아 두고도 통과한다.** 닿는 것도 재야 한다.
	var rig := _rig()
	var half := rig.half_sizes[CharPart.Id.HEAD]
	var anchor := _hair()
	assert_gt(anchor.weight_at(Vector2(0.0, 1.70 * half.y)), 0.4, "정수리가 안 움직인다")
	assert_gt(anchor.weight_at(Vector2(-0.60 * half.x, 1.20 * half.y)), 0.3, "뒤통수가 안 움직인다")


func test_the_chest_anchor_leaves_the_hem_alone() -> void:
	# 치마 밑단이 같이 출렁이면 A 라인이 무너진다 (§25.2.2).
	var rig := _rig()
	var half := rig.half_sizes[CharPart.Id.TORSO]
	var anchor := _chest()
	for at in [0.0, 0.2, 0.45]:
		var point := Vector2(0.0, at * half.y * 2.0)
		assert_eq(anchor.weight_at(point), 0.0, "밑단 %s 가 휜다" % point)


func test_the_chest_anchor_does_reach_the_chest() -> void:
	var rig := _rig()
	var half := rig.half_sizes[CharPart.Id.TORSO]
	var anchor := _chest()
	assert_gt(anchor.weight_at(Vector2(0.3 * half.x, 1.44 * half.y)), 0.5, "가슴이 안 움직인다")


# --- 마스크가 없을 때 ---------------------------------------------------------


func test_no_normal_means_no_gate() -> void:
	var anchor := MorphAnchor.new("맨것", CharPart.Id.TORSO)
	assert_eq(anchor.mask_at(Vector2(999.0, -999.0)), 1.0)


func test_the_gate_is_smooth_not_a_cliff() -> void:
	# 계단이면 그 경계에 **줄이 보인다.** 무디게 넘어가야 한다.
	var anchor := _chest()
	var along := anchor.mask_normal.normalized()
	var edge := along * anchor.mask_offset
	assert_almost_eq(anchor.mask_at(edge), 0.5, 0.02)
	assert_between(anchor.mask_at(edge + along * anchor.mask_feather * 0.5), 0.5, 1.0)


func test_copy_does_not_share() -> void:
	var anchor := _chest()
	var clone := anchor.copy()
	clone.centre += Vector2(50.0, 50.0)
	clone.limit = 99.0
	assert_ne(clone.centre, anchor.centre)
	assert_ne(clone.limit, anchor.limit)
