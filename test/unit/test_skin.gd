extends GutTest
## **파츠 PNG 에서 리그를 세우는 길** — §25.41 의 규약이 실제로 도는지.
##
## **실물이 오기 전에 길이 도는지 확인하는 것이 이 파일의 전부다.** 그림이 오는 날
## 「읽어서 물리기만」 하려면 그 전에 길이 뚫려 있어야 한다 (§25.39.0).
##
## 자리표시자는 시트에서 **실제로 잰 조각 크기**로 만들었다 —
## 머리 391x344 · 몸 233x259 · 손 67x94 · 발 136x181. 그래서 이 시험이 통과하면
## **그 비례가 리그에 물린다**는 뜻이지, 아무 숫자나 물린다는 뜻이 아니다.
##
## 그리고 **일부러 여백을 37 px 넣어 뒀다.** 규약이 「자르기는 아무렇게나 둬도 된다」고
## 적었으므로(§25.41.2), 그 문장이 참인지 여기서 확인된다.

const DIR := "res://test/fixtures/skin"

## 배치 규칙 (§25.41.5). **검사와 배치가 같은 표를 쓴다** — 갈리면 조용히 틀린다.
const NECK := 0.035
const FEET_APART := 0.149
const FOOT_FAR_RISE := 0.035
const HAND_CLEAR := 0.024
const HAND_TUCK := 0.031
const EPS := 0.5


func _skin() -> CharSkin:
	var skin := CharSkin.load_dir(DIR)
	assert_true(skin.is_whole(), "여섯 장을 다 못 읽었다: %s" % str(skin.problems))
	return skin


func test_the_padding_is_ignored() -> void:
	# **규약이 「여백은 무의미하다」고 적었다.** 자리표시자에 37 px 을 넣어 뒀으므로,
	# 그 말이 참이면 머리 반크기가 여백과 무관하게 나온다.
	var skin := _skin()
	var head := skin.rig.half_sizes[CharPart.Id.HEAD]
	assert_almost_eq(head.y * 2.0, CharSkin.HEAD_UNITS, 0.001, "머리 세로가 기준값이 아니다")
	# 391 : 344 가 그대로 유지돼야 한다. 여백이 섞이면 이 비가 깨진다.
	assert_almost_eq(head.x / head.y, 391.0 / 344.0, 0.01, "머리의 가로세로비가 여백에 오염됐다")


func test_the_scale_comes_from_the_head_alone() -> void:
	# **배율을 안 받는다.** 머리 하나로 여섯이 정해진다 (§25.41.4).
	var skin := _skin()
	var per_pixel := CharSkin.HEAD_UNITS / 344.0
	for pair: Array in [
		[CharPart.Id.TORSO, 233.0, 259.0],
		[CharPart.Id.HAND_NEAR, 67.0, 94.0],
		[CharPart.Id.FOOT_NEAR, 136.0, 181.0],
	]:
		var half: Vector2 = skin.rig.half_sizes[pair[0]]
		assert_almost_eq(half.x * 2.0, float(pair[1]) * per_pixel, 0.01, "가로가 같은 배율이 아니다")
		assert_almost_eq(half.y * 2.0, float(pair[2]) * per_pixel, 0.01, "세로가 같은 배율이 아니다")


func test_the_layout_is_solved_not_copied() -> void:
	# **자리는 리그가 푼다** (§25.41.5). 시트 안에서 파츠가 어디 놓였는지는 아무 뜻이 없다.
	var rig := _skin().rig
	var height := rig.total_height()
	assert_gt(height, 100.0, "키가 안 나온다")

	var near_foot := CharPart.Id.FOOT_NEAR
	var far_foot := CharPart.Id.FOOT_FAR
	assert_almost_eq(rig.rest_positions[near_foot].y, 0.0, 0.001, "앞발이 지면에 안 붙었다")
	assert_almost_eq(rig.rest_positions[far_foot].y, height * FOOT_FAR_RISE, EPS, "뒷발 접지가 더 높지 않다")
	var apart := rig.rest_positions[near_foot].x - rig.rest_positions[far_foot].x
	assert_almost_eq(apart, height * FEET_APART, EPS, "두 발이 나란히 서면 정면 자세가 된다")

	var torso := CharPart.Id.TORSO
	var torso_top := rig.rest_positions[torso].y + rig.half_sizes[torso].y * 2.0
	var neck := rig.rest_positions[CharPart.Id.HEAD].y - torso_top
	assert_almost_eq(neck, height * NECK, EPS, "목 간격이 없으면 지연과 갸웃이 안 보인다")


func test_the_hands_keep_the_gap_and_the_overlap() -> void:
	# **앞손은 떠 있고 뒷손은 겹친다.** 둘 다 띄우면 깊이 단서가 사라진다 (§25.38.1).
	var rig := _skin().rig
	var height := rig.total_height()
	var near := CharPart.Id.HAND_NEAR
	var far := CharPart.Id.HAND_FAR
	var near_inner := rig.rest_positions[near].x - rig.half_sizes[near].x
	var gap := near_inner - rig.torso_front_at(rig.rest_positions[near].y)
	assert_gte(gap, height * HAND_CLEAR - EPS, "앞손이 몸에 붙었다 — 레이맨의 표시가 사라진다")

	var far_inner := rig.rest_positions[far].x + rig.half_sizes[far].x
	var tuck := far_inner - rig.torso_back_at(rig.rest_positions[far].y)
	assert_gte(tuck, height * HAND_TUCK - EPS, "뒷손이 몸에 안 겹친다 — 깊이가 사라진다")


func test_the_far_pieces_may_be_missing() -> void:
	# **뒷것 둘은 안 줘도 된다** (§25.41.1). 없으면 앞것을 쓴다.
	var skin := CharSkin.load_dir(DIR)
	assert_true(skin.textures.has(CharPart.Id.HAND_FAR), "뒷손 자리가 비어 있으면 안 된다")
	# 폴더에 없는 것을 흉내 내는 대신, 대체 표가 실제로 그 짝을 가리키는지 본다.
	assert_eq(CharSkin.FALLBACK[CharPart.Id.HAND_FAR], CharPart.Id.HAND_NEAR, "뒷손이 없으면 앞손을 뒤집어 쓴다")
	assert_eq(
		CharSkin.FALLBACK[CharPart.Id.FOOT_FAR],
		CharPart.Id.FOOT_NEAR,
		"뒷발이 없으면 앞발을 그대로 쓴다 — 두 발은 둘 다 앞을 본다"
	)


func test_a_missing_folder_says_so_instead_of_half_working() -> void:
	# **조용히 반쯤 성공하는 것이 가장 비싼 실패다** (§25.13.7).
	var skin := CharSkin.load_dir("res://test/fixtures/does_not_exist")
	assert_false(skin.is_whole(), "없는 폴더인데 성공했다고 한다")
	assert_gt(skin.problems.size(), 0, "무엇이 없는지를 안 알려 준다")
	assert_null(skin.rig, "머리가 없으면 배율을 못 정하므로 리그가 없어야 한다")


func test_the_clips_do_not_know_about_the_skin() -> void:
	# **이것이 이 구조의 값이다.** 그림에서 세운 리그로도 클립이 그대로 돈다 —
	# `sample()` 이 순수 함수라 그림을 모른다 (§25.3).
	var rig := _skin().rig
	var f := AnimFeatures.all_on()
	for clip: CharClip in [CharIdleClip.new(rig), CharWalkClip.new(rig), CharRunClip.new(rig)]:
		var t := 0.0
		while t <= clip.loop_seconds():
			var pose := clip.sample(t, f)
			assert_lte(
				pose.deepest_sink(rig), 0.001, "%s 의 t = %.2f 에서 파고든다" % [clip.clip_name(), t]
			)
			t += 0.02
