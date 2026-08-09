extends GutTest
## 킷 카드가 **폭에 따라 다른 것을 보여 주지 않는가.**
##
## docs/design/20-ui-kit.md §20.25.6.
##
## ## 왜 이 검사가 생겼나
##
## `SheetPainter` 는 한 열일 때 `SINGLE_ORDER` 를, 두 열일 때
## `PersonSheet.LEFT_TITLES` + `RIGHT_TITLES` 를 쓴다. **목록이 둘이다.**
##
## 인물 상세를 다시 짜면서 칸 둘(위협 · 신원)이 생겼는데 두 열 목록에만 넣고
## 한 열 목록을 안 고쳤다. 그러면 **같은 카드가 좁을 때와 넓을 때 다른 것을 보여 준다** —
## 그리고 둘 다 멀쩡한 그림이라 아무도 모른다.
##
## > **한쪽만 고쳐진 쌍.** §20.24.1 이 시계에서 본 것과 같은 모양이 목록에서 나왔다.

const _SEED := 20260808
const _POPULATION := 60


func _sections() -> Array[SheetSection]:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	return PersonSheet.build(registry, 0, FactionIndex.new(registry))


func test_one_column_and_two_column_orders_hold_the_same_sections() -> void:
	var wide: Array[String] = []
	for title in PersonSheet.LEFT_TITLES + PersonSheet.RIGHT_TITLES:
		wide.append(str(title))
	var narrow: Array[String] = []
	for title in SheetPainter.SINGLE_ORDER:
		narrow.append(str(title))

	for title in wide:
		assert_true(narrow.has(title), "%s 가 한 열 목록에 없다 — 좁으면 사라진다" % title)
	for title in narrow:
		assert_true(wide.has(title), "%s 가 두 열 목록에 없다 — 넓으면 사라진다" % title)


func test_the_kit_lists_name_sections_that_exist() -> void:
	# 이름이 틀리면 그 칸이 조용히 안 그려진다 (`section_of` 가 null 을 내고 건너뛴다).
	var sections := _sections()
	for title in SheetPainter.SINGLE_ORDER:
		assert_not_null(PersonSheet.section_of(sections, str(title)), str(title))


func test_no_title_repeats_across_the_two_columns() -> void:
	for title in PersonSheet.LEFT_TITLES:
		assert_false(PersonSheet.RIGHT_TITLES.has(title), "%s 가 두 열에 다 있다" % str(title))
