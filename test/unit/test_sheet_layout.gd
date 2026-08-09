extends GutTest
## 인물 상세의 **자리**를 덮는다. docs/design/20-ui-kit.md §20.23.3.
##
## ## 이 파일이 존재하는 이유
##
## 이 화면의 배치는 지금까지 **눈으로만** 확인됐다 — `_draw()` 가 그리면서 자리를
## 계산했으므로 창을 띄우지 않고는 아무것도 물을 수 없었다.
##
## 자리를 순수 계산으로 떼어내자 **헤드리스로 물을 수 있게 됐고**, 물어보자마자
## 지금까지 아무도 몰랐던 것이 나왔다 (`test_left_column_overflows_720p`).
##
## ## 여기서 지켜야 할 것
##
## 1. **그린 곳이 곧 눌리는 곳이다.** 줄은 자기 칸 안에 있어야 한다
## 2. **줄이 겹치지 않는다.** 겹치면 클릭이 어느 줄로 갈지 아무도 모른다
## 3. **열 선언이 자리로 나타난다** — 왼쪽은 남과의 관계, 오른쪽은 이 사람 자체

const _SEED := 20260808
const _POPULATION := 200

## 실제로 이 화면이 도는 크기. 1280x720 에서 버튼 줄과 상태 줄을 뺀 나머지다
## (`npc_sheet_screen.tscn` 의 `SheetView` offset_bottom = -50).
const _VIEW := Vector2(1280.0, 670.0)

const _FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

## 검사가 서는 탭. 조우 탭이 3초 안에 읽히는 자리라 여기가 제일 빡빡하다 (§20.25.2).
const _TAB := SheetTab.Kind.ENCOUNTER


func _sections(person: int = 0) -> Array[SheetSection]:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	return PersonSheet.build(
		registry, person, FactionIndex.new(registry), SheetDisclosure.Level.DEV, graph
	)


func _layout(person: int = 0) -> SheetLayout:
	return SheetLayout.build(
		_sections(person),
		_VIEW,
		_FONT,
		PersonSheet.left_titles(_TAB),
		PersonSheet.right_titles(_TAB),
		PersonSheet.wheel_titles(_TAB),
		SheetTab.count()
	)


# ------------------------------------------------------------ 자리가 나오긴 하나


func test_every_section_gets_a_panel() -> void:
	var sections := _sections()
	var placed := SheetLayout.build(
		sections,
		_VIEW,
		_FONT,
		PersonSheet.left_titles(_TAB),
		PersonSheet.right_titles(_TAB),
		PersonSheet.wheel_titles(_TAB),
		SheetTab.count()
	)
	var wanted: int = PersonSheet.left_titles(_TAB).size() + PersonSheet.right_titles(_TAB).size()
	assert_eq(placed.panels.size(), wanted, "이 탭이 세우기로 한 칸이 다 안 섰다")


func test_no_font_yields_no_places() -> void:
	# 폰트가 없으면 글 높이를 못 재므로 자리를 지어내지 않는다.
	var placed := SheetLayout.build(
		_sections(),
		_VIEW,
		null,
		PersonSheet.left_titles(_TAB),
		PersonSheet.right_titles(_TAB),
		PersonSheet.wheel_titles(_TAB),
		SheetTab.count()
	)
	assert_eq(placed.panels.size(), 0)
	assert_eq(placed.rows.size(), 0)


func test_frame_section_has_no_rows() -> void:
	# 액자는 통째로 그림이다. 눌러야 할 낱줄이 없다.
	var sections := _sections()
	var placed := SheetLayout.build(
		sections,
		_VIEW,
		_FONT,
		PersonSheet.left_titles(_TAB),
		PersonSheet.right_titles(_TAB),
		PersonSheet.wheel_titles(_TAB),
		SheetTab.count()
	)
	for i in placed.rows.size():
		assert_ne(sections[placed.row_section[i]].shape, SheetSection.Shape.FRAME, "액자 칸이 줄을 냈다")


# ---------------------------------------------------- 그린 곳이 곧 눌리는 곳이다


func test_every_row_sits_inside_its_panel() -> void:
	var placed := _layout()
	for i in placed.rows.size():
		var row := placed.rows[i]
		var panel := placed.panel_rect(placed.row_section[i])
		assert_almost_eq(row.position.x, panel.position.x, 0.01, "줄이 칸 밖에 있다")
		assert_almost_eq(row.size.x, panel.size.x, 0.01, "줄 폭이 칸과 다르다")
		assert_true(row.position.y >= panel.position.y, "줄이 칸 위로 튀어나갔다")
		assert_true(row.end.y <= panel.end.y + 0.01, "줄이 칸 아래로 넘쳤다")


func test_rows_of_a_section_do_not_overlap() -> void:
	var placed := _layout()
	for i in placed.rows.size():
		for j in range(i + 1, placed.rows.size()):
			if placed.row_section[i] != placed.row_section[j]:
				continue
			assert_false(placed.rows[i].intersects(placed.rows[j]), "줄 둘이 겹치면 클릭이 어디로 갈지 아무도 모른다")


func test_panels_do_not_overlap() -> void:
	var placed := _layout()
	for i in placed.panels.size():
		for j in range(i + 1, placed.panels.size()):
			assert_false(placed.panels[i].intersects(placed.panels[j]), "칸 둘이 겹쳤다")


func test_hit_finds_the_row_it_drew() -> void:
	var placed := _layout()
	for i in placed.rows.size():
		var middle := placed.rows[i].get_center()
		var found := placed.field_at(middle)
		assert_eq(found, Vector2i(placed.row_section[i], placed.row_field[i]), "줄 %d" % i)


func test_hit_outside_finds_nothing() -> void:
	var placed := _layout()
	assert_eq(placed.field_at(Vector2(-10.0, -10.0)), Vector2i(-1, -1))
	assert_eq(placed.section_at(Vector2(-10.0, -10.0)), -1)


func test_the_gap_between_columns_belongs_to_nobody() -> void:
	# 열 사이 틈을 누르면 아무 칸도 안 잡혀야 한다. 잡히면 잘못된 칸이 열린다.
	var placed := _layout()
	var seam := SheetLayout.MARGIN + SheetLayout.LEFT_WIDTH + SheetLayout.COLUMN_GAP * 0.5
	assert_eq(placed.section_at(Vector2(seam, SheetLayout.MARGIN + 40.0)), -1)


# ------------------------------------------------------------ 열 선언이 자리다


func test_left_titles_are_left_of_right_titles() -> void:
	var sections := _sections()
	var placed := SheetLayout.build(
		sections,
		_VIEW,
		_FONT,
		PersonSheet.left_titles(_TAB),
		PersonSheet.right_titles(_TAB),
		PersonSheet.wheel_titles(_TAB),
		SheetTab.count()
	)
	var left_edge := 0.0
	var right_edge := _VIEW.x
	for i in placed.panels.size():
		var title := sections[placed.panel_of[i]].title
		if PersonSheet.left_titles(_TAB).has(title):
			left_edge = maxf(left_edge, placed.panels[i].end.x)
		else:
			right_edge = minf(right_edge, placed.panels[i].position.x)
	assert_true(left_edge <= right_edge, "왼쪽 열이 오른쪽 열을 침범했다")


func test_relations_sit_below_identity_in_the_history_tab() -> void:
	# §24.17.3 — 자라는 칸을 아래에 둔다. 위로 올라가면 채워질 때 위를 밀어낸다.
	# 관계는 이제 「내력」 탭이다 (§20.25.4) — 조우 중에 읽을 것이 아니다.
	var history := SheetTab.Kind.HISTORY
	var sections := _sections()
	var placed := SheetLayout.build(
		sections,
		_VIEW,
		_FONT,
		PersonSheet.left_titles(history),
		PersonSheet.right_titles(history),
		PersonSheet.wheel_titles(history),
		SheetTab.count()
	)
	var identity := -1
	var relations := -1
	for i in sections.size():
		if sections[i].title == "신원":
			identity = i
		elif sections[i].title == "관계":
			relations = i
	assert_true(identity >= 0 and relations >= 0, "칸 이름이 바뀌었다")
	assert_true(
		placed.panel_rect(relations).position.y > placed.panel_rect(identity).position.y,
		"관계가 신원 위로 올라갔다"
	)


# --------------------------------------- 물어보자마자 나온 것 — 아래 여백이 0 이었다


func test_the_sheet_fits_the_screen_it_runs_at() -> void:
	# **이 검사는 손을 붙이다가 생겼다.**
	#
	# §4.1 이 요구한 버튼 줄을 아래에 놓자 화면이 그만큼 줄었고, 실측해 보니
	# 왼쪽 열이 **정확히 654px** 로 끝나 새 화면 높이와 한 픽셀도 안 남기고 맞닿았다.
	# 초상 액자가 왼쪽 열 폭의 정사각이라 그 칸 하나가 356px 다 (설계 24.20.4).
	#
	# **자리를 계산으로 떼어내기 전에는 이걸 물어볼 방법이 없었다** — 넘쳤어도
	# 창을 띄워 눈으로 보기 전에는 몰랐다. 그래서 아래 여백을 검사가 지킨다.
	var placed := _layout()
	var lowest := 0.0
	for panel in placed.panels:
		lowest = maxf(lowest, panel.end.y)
	assert_true(
		lowest <= _VIEW.y - SheetLayout.MARGIN,
		"아래 여백이 없다 — 가장 아래 %d, 화면 %d" % [int(lowest), int(_VIEW.y)]
	)


func test_no_one_in_the_population_overflows() -> void:
	# 관계 줄 수가 사람마다 다르다. 0번만 재면 **가족이 많은 사람에서 넘치는 것**을 못 본다.
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	var factions := FactionIndex.new(registry)
	var worst := 0.0
	var who := 0
	for person in registry.size():
		var sheet := PersonSheet.build(registry, person, factions, SheetDisclosure.Level.DEV, graph)
		var one := SheetLayout.build(
			sheet,
			_VIEW,
			_FONT,
			PersonSheet.left_titles(_TAB),
			PersonSheet.right_titles(_TAB),
			PersonSheet.wheel_titles(_TAB),
			SheetTab.count()
		)
		for panel in one.panels:
			if panel.end.y > worst:
				worst = panel.end.y
				who = person
	assert_true(worst <= _VIEW.y, "인물 %d 에서 %d px 로 넘쳤다" % [who, int(worst)])


# ------------------------------------------------------------ 줄이 사람을 가리킨다


func test_kin_rows_carry_the_person_they_point_at() -> void:
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	var factions := FactionIndex.new(registry)
	var linked := 0
	for person in registry.size():
		var sections := PersonSheet.build(
			registry, person, factions, SheetDisclosure.Level.DEV, graph
		)
		var section := PersonSheet.section_of(sections, "관계")
		for field in section.fields:
			if not field.has_link():
				continue
			linked += 1
			assert_true(field.link >= 0 and field.link < registry.size(), "가리키는 데가 없다")
			assert_ne(field.link, person, "자기 자신을 가리킨다")
	assert_true(linked > 0, "가족이 있는 인구인데 눌러 갈 줄이 하나도 없다")
