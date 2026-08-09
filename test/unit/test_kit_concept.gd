extends GutTest
## 안 여섯이 **정말 서로 다른 방향인가.** docs/design/20-ui-kit.md §20.26.2.
##
## ## 이 검사가 막는 것
##
## 안을 여섯 만들라고 하면 **한 아이디어의 여섯 변주**가 나오기 쉽다. 그러면 사용자가
## 고를 것이 없는데 **여섯 장이 나왔으므로 일은 된 것처럼 보인다.**
##
## 눈으로는 *"이 둘이 사실 같은 안 아닌가"* 를 답하기 어렵다. 매개변수를 떼어 놨으므로
## (`KitConcept`) **창 없이 묻는다** — 면을 채우는 방식이 겹치나, 모서리가 다 같나,
## 바탕 밝기가 붙어 있나.

const _BOX := Rect2(10.0, 20.0, 120.0, 60.0)


func test_there_are_six_concepts() -> void:
	assert_eq(KitConcept.count(), 6)


func test_no_two_concepts_fill_a_surface_the_same_way() -> void:
	# **면을 채우는 방식이 이 여섯을 가르는 첫 축이다.** 겹치면 두 안이 같은 안이다.
	var seen: Array[int] = []
	for kind in KitConcept.count():
		var fill := int(KitConcept.fill(kind as KitConcept.Kind))
		assert_false(
			seen.has(fill),
			"%s 가 앞의 안과 같은 방식으로 면을 채운다" % KitConcept.name_of(kind as KitConcept.Kind)
		)
		seen.append(fill)


func test_the_concepts_do_not_all_share_one_corner_rule() -> void:
	# 각짐 · 모따기 · 둥금이 다 나와야 「모서리」가 고를 수 있는 축이 된다.
	var angular := false
	var chamfered := false
	var rounded := false
	for kind in KitConcept.count():
		var corner := KitConcept.corner(kind as KitConcept.Kind)
		angular = angular or is_equal_approx(corner, 0.0)
		chamfered = chamfered or corner < 0.0
		rounded = rounded or corner > 0.0
	assert_true(angular and chamfered and rounded, "모서리 규칙이 한두 가지뿐이다")


func test_some_concepts_have_no_border_at_all() -> void:
	# 테두리 0 은 「빼먹었다」가 아니라 **경계를 다른 방법으로 만든다**는 선언이다.
	var borderless := 0
	for kind in KitConcept.count():
		if is_equal_approx(KitConcept.edge(kind as KitConcept.Kind), 0.0):
			borderless += 1
	assert_true(borderless >= 1, "여섯이 다 테두리로 경계를 만든다 — 축이 하나 죽었다")


func test_light_and_dark_grounds_both_appear() -> void:
	# 밝은 바탕에서만 죽는 안이 있고 어두운 바탕에서만 사는 안이 있다.
	# 여섯이 다 같은 바탕이면 그 축을 고를 수 없다.
	var light := 0
	for kind in KitConcept.count():
		if KitConcept.is_light(kind as KitConcept.Kind):
			light += 1
	assert_true(light > 0 and light < KitConcept.count(), "여섯이 다 같은 밝기 바탕에 산다")


func test_every_concept_reads_against_its_own_ground() -> void:
	# 글자가 바탕에 묻히면 그 안은 볼 것도 없이 탈락인데, **그림은 여전히 나온다.**
	for kind in KitConcept.count():
		var here := kind as KitConcept.Kind
		var gap := absf(
			KitConcept.ink(here).get_luminance() - KitConcept.backdrop(here).get_luminance()
		)
		assert_true(gap > 0.25, "%s 는 글자가 바탕에 묻힌다 (차이 %.2f)" % [KitConcept.name_of(here), gap])


func test_every_concept_says_something_and_admits_a_weakness() -> void:
	# **약점이 없는 안은 안 골라 본 안이다.**
	for kind in KitConcept.count():
		var here := kind as KitConcept.Kind
		assert_false(KitConcept.says(here).is_empty(), KitConcept.name_of(here))
		assert_false(KitConcept.weakness(here).is_empty(), KitConcept.name_of(here))


func test_slugs_are_unique_and_ascii() -> void:
	# 한글 파일명은 도구 사이를 지나며 깨진 전례가 있다.
	var seen: Array[String] = []
	for kind in KitConcept.count():
		var slug := KitConcept.slug(kind as KitConcept.Kind)
		assert_false(seen.has(slug), slug)
		assert_true(slug.is_valid_ascii_identifier(), "%s 가 ascii 가 아니다" % slug)
		seen.append(slug)


# ------------------------------------------------------------------ 외곽선


func test_every_outline_is_a_closed_area() -> void:
	for kind in KitConcept.count():
		var shape := KitConcept.outline(kind as KitConcept.Kind, _BOX)
		assert_true(
			shape.size() >= 4, "%s 의 외곽이 면이 아니다" % KitConcept.name_of(kind as KitConcept.Kind)
		)


func test_no_outline_leaves_its_box() -> void:
	# 외곽이 상자를 넘으면 부품끼리 겹쳐 그려지고, 그건 안의 성질이 아니라 버그다.
	var room := _BOX.grow(0.01)
	for kind in KitConcept.count():
		for point in KitConcept.outline(kind as KitConcept.Kind, _BOX):
			assert_true(
				room.has_point(point),
				"%s 의 외곽이 상자를 넘었다" % KitConcept.name_of(kind as KitConcept.Kind)
			)


func test_a_tiny_box_does_not_fold_the_corners_inside_out() -> void:
	# 모서리가 상자 절반보다 크면 도형이 뒤집힌다. 작은 부품(체크 22px)이 그 자리다.
	var tiny := Rect2(0.0, 0.0, 10.0, 10.0)
	for kind in KitConcept.count():
		for point in KitConcept.outline(kind as KitConcept.Kind, tiny):
			assert_true(
				tiny.grow(0.01).has_point(point), KitConcept.name_of(kind as KitConcept.Kind)
			)
