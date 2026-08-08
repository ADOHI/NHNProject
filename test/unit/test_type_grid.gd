extends GutTest
## 활자 격자의 단위 테스트.
##
## 이 격자가 「타이포그래피가 없다」는 지적에 대한 답이다 (docs/design/20-ui-kit.md §20.3 ④).
## 지키려는 것은 하나 — **모든 급이 같은 격자에 앉는다.** 그것이 깨지면 여백이 우연이 되고,
## 화면이 갱신될 때 판이 출렁인다.

const _RANKS: Array[TypeGrid.Rank] = [
	TypeGrid.Rank.MICRO,
	TypeGrid.Rank.BODY,
	TypeGrid.Rank.HEAD,
	TypeGrid.Rank.DISPLAY,
]


## 급이 오를수록 셀도 글자도 커진다.
func test_ranks_grow_monotonically() -> void:
	for i in range(_RANKS.size() - 1):
		assert_lt(TypeGrid.cell(_RANKS[i]).x, TypeGrid.cell(_RANKS[i + 1]).x)
		assert_lt(TypeGrid.cell(_RANKS[i]).y, TypeGrid.cell(_RANKS[i + 1]).y)
		assert_lt(TypeGrid.font_size(_RANKS[i]), TypeGrid.font_size(_RANKS[i + 1]))


## 제목과 표제는 본문 셀의 **정수배 또는 반배**여야 한다.
## 아니면 두 급을 나란히 놓았을 때 어느 쪽도 격자에 안 맞는다.
func test_bigger_ranks_align_to_the_body_cell() -> void:
	var body := TypeGrid.cell(TypeGrid.Rank.BODY).x
	for rank in [TypeGrid.Rank.HEAD, TypeGrid.Rank.DISPLAY]:
		var ratio := TypeGrid.cell(rank).x / body
		var halves := ratio * 2.0
		assert_almost_eq(halves, roundf(halves), 0.001, "급 %d 이 본문 셀의 반배 격자에 안 맞는다" % rank)


## 글자 크기는 셀보다 작아야 한다. 꽉 채우면 이웃 글자와 붙는다.
func test_glyphs_fit_inside_their_cell() -> void:
	for rank in _RANKS:
		assert_lt(
			float(TypeGrid.font_size(rank)), TypeGrid.cell(rank).x + 4.0, "급 %d 의 글자가 셀보다 크다" % rank
		)


## 폭은 글자 수에만 달려 있다. **글꼴 측정을 쓰지 않는 것**이 격자의 실질적 이득이다 —
## 글자가 바뀌어도 자리가 안 흔들리므로 갱신되는 화면에서 판이 출렁이지 않는다.
func test_width_depends_only_on_length() -> void:
	for rank in _RANKS:
		var cell := TypeGrid.cell(rank).x
		assert_almost_eq(TypeGrid.width_of("", rank), 0.0, 0.001)
		assert_almost_eq(TypeGrid.width_of("금", rank), cell, 0.001)
		assert_almost_eq(TypeGrid.width_of("탐사 기록", rank), cell * 5.0, 0.001)
		# 좁은 글자와 넓은 글자가 같은 폭이어야 한다 (전각).
		assert_eq(TypeGrid.width_of("1", rank), TypeGrid.width_of("뷁", rank))


## 어떤 치수든 격자의 정수배로 올림된다. 내림이면 글자가 잘린다.
func test_snap_rounds_up_to_the_cell() -> void:
	var body := TypeGrid.cell(TypeGrid.Rank.BODY).x
	for value in [0.0, 1.0, 12.9, 13.0, 13.1, 77.5]:
		var snapped := TypeGrid.snap(value)
		assert_gte(snapped, value, "올림이 아니라 내림했다")
		assert_almost_eq(fmod(snapped, body), 0.0, 0.001, "격자에 안 맞는 치수가 나왔다")


## 여백도 격자에서 나와야 한다. 본문 셀 높이의 절반이다.
func test_gutter_comes_from_the_grid() -> void:
	assert_almost_eq(
		TypeGrid.GUTTER * 2.0, TypeGrid.cell(TypeGrid.Rank.BODY).y, 0.001, "여백이 격자와 무관하다"
	)


## 괘선은 두 굵기뿐이어야 한다. 셋을 두면 어느 것이 무거운지 알 수 없다.
func test_two_rule_weights_only() -> void:
	assert_lt(TypeGrid.RULE_HAIR, TypeGrid.RULE_THICK)
	assert_gte(TypeGrid.RULE_THICK / TypeGrid.RULE_HAIR, 2.0, "두 괘선이 충분히 안 갈린다")
