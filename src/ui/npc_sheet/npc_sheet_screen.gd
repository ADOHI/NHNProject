class_name NpcSheetScreen
extends Control
## 인물 상세 열람기. **개발용이다 — 전부 보인다.**
##
## docs/design/24-npc-relations.md §24.17 · docs/design/20-ui-kit.md §20.23.
##
##   godot --path . res://src/ui/npc_sheet/npc_sheet_screen.tscn
##
## ## 무엇을 위한 화면인가
##
## 3000명을 만들어 놨는데 볼 방법이 계측 표의 표본 다섯 줄뿐이었다.
## **사용자가 여러 인물을 넘겨 보며 「이 인구가 그럴듯한가」를 판정하는 것**이 목적이다.
## 그래서 주 조작이 **무작위 뽑기** 다 — 인덱스 순으로 훑으면
## 앞의 스무 명만 보고 판정하게 된다 (§24.17.8).
##
## ## 손 — 클릭만으로 전부 된다
##
## [`04`](../../../docs/design/04-controls.md) §4.1 이 *「클릭(터치)만으로 전부 조작
## 가능해야 한다」* 로 못 박았는데 **이 화면은 키보드 전용이었다**(§20.22.3).
## 지금은 조작 여덟이 전부 버튼이고, 그 위에 포인터 전용 조작 셋이 더 있다.
##
## | 손짓 | 무엇 |
## | --- | --- |
## | 버튼 | 조작 여덟. **키와 같은 함수를 부른다** |
## | 휠 | 앞·뒤 인물 |
## | 관계 줄 클릭 | 그 사람으로 간다 |
## | 우클릭 · 길게 누르기 | 정보 확인 (§4.2) |
##
## **손짓은 전부 공개 함수다**(`wheel` · `tap` · `inspect` · `act`).
## 진짜 마우스도 캡처 도구도 그 하나로 들어간다 — §20.22 가 이름 붙인
## 「대역이 낀 검사」를 막는 유일한 방법이 문을 하나로 두는 것이다.
##
## ## 게임 화면이 아니다
##
## 게임 내 상세는 **단서만** 보여야 한다 (§5.4 · §24.17.2).
## 여기는 성향 6축 값이 그대로 나가므로 **그대로 게임에 붙이면 게임의 축이 무너진다.**
## 가림은 `SheetDisclosure` 층으로 얹는다.
##
## ## 생성이 한 프레임을 넘는다
##
## 3000명 생성이 20.4ms 다 (§24.16.9). 그래서 `NpcWorld.build_chunk()` 를
## **프레임마다 한 조각씩** 부른다 — §24.16.2 에서 비워 둔 자리의 첫 사용자다.
##
## **세우는 순서(인구 → 태생 관계 → 사건)를 이 화면이 다시 쓰지 않는다.**
## 그 순서는 `NpcWorld` 하나가 안다 — 화면마다 베껴 쓰면 한 단계가 빠진 화면이
## 조용히 반쪽 세계를 보여 준다.

## 목표 인구. §24.8 의 상한이다.
const POPULATION := 3000

## 첫 시드. 새 시드를 부르면 하나씩 올라간다.
const FIRST_SEED := 20260808

## 한 번에 건너뛰는 인원.
const PAGE := 100

## 조작 여덟. **버튼 글자와 키가 한 줄에서 나온다.**
##
## 갈라 적으면 하나만 고치게 되고, 그러면 **버튼으로는 되는데 키로는 안 되는** 조작이
## 생긴다. 이 화면이 고치고 있는 병이 정확히 그것이다 — 입구가 둘이면 하나가 뒤처진다.
const ACTIONS := [
	["prev", "이전", KEY_LEFT],
	["next", "다음", KEY_RIGHT],
	["back", "-100", KEY_PAGEUP],
	["forward", "+100", KEY_PAGEDOWN],
	["home", "처음", KEY_HOME],
	["random", "무작위", KEY_SPACE],
	["reseed", "새 시드", KEY_R],
	["metrics", "계측", KEY_F1],
]

## 자리를 못 찾았을 때. `Vector2.ZERO` 를 쓰면 **화면 왼쪽 위 모서리**와 구분이 안 되고,
## 대본이 아무 데나 누르고도 통과한다.
const NOWHERE := Vector2(-1.0, -1.0)

## 길게 누르기가 정보 확인이 되는 시간(초). **터치에는 오른쪽 버튼이 없다** —
## §4.2 가 「우클릭 · 롱프레스」를 한 줄에 적은 이유다.
const LONG_PRESS := 0.5

## 누른 자리가 이만큼 넘게 움직이면 길게 누르기가 취소된다(px).
## 안 그러면 **끌기가 전부 정보 확인이 된다.**
const LONG_PRESS_SLACK := 8.0

var _seed := FIRST_SEED

## 세계 하나 — 인구 · 태생 관계 · 사건. **세우는 순서를 아는 곳은 `NpcWorld` 다.**
## 이 화면이 순서를 다시 쓰면 한 단계가 빠졌을 때 이 화면만 반쪽 세계가 된다
## (`NpcWorld` 머리말 — 화면 하나와 도구 둘과 시험 둘이 같은 여섯 줄을 베껴 쓰고 있었다).
var _world: NpcWorld
var _person := 0

## 직전에 보던 인물. **개발 화면의 「보는 쪽」이다** — 조우 화면이 서면 그 자리에
## 스쿼드 여섯이 들어간다(§20.25.7). 지금은 이것으로 면식 칸이 실제로 도는지를 본다.
var _viewer := PersonRegistry.NO_PERSON
var _pick := RandomNumberGenerator.new()
var _build_msec := 0.0
var _shows_metrics := true

var _norms: PersonNorms
var _view: PersonSheetView
var _status: Label
var _toolbar: HBoxContainer

## 왼쪽 버튼을 누른 자리와 누르고 있은 시간. 길게 누르기가 이것으로 판정된다.
var _press_at := Vector2.ZERO
var _press_held := -1.0


func _ready() -> void:
	_view = %SheetView
	_status = %StatusLine
	_toolbar = %Toolbar
	_build_toolbar()
	_restart()


func _process(delta: float) -> void:
	_tick_long_press(delta)
	if _world == null or _world.is_ready():
		return

	# **한 조각씩 세운다.** 웹은 단일 스레드라 3000명을 한 프레임에 만들면
	# 그만큼 화면이 멈춘다 (설계 24.16.2). 조각 경계는 난수 흐름에 안 들어가므로
	# 한 번에 세운 세계와 결과가 같다 (§24.24.2).
	var started := Time.get_ticks_usec()
	var done := _world.build_chunk()
	_build_msec += float(Time.get_ticks_usec() - started) / 1000.0
	if not done:
		_status.text = "%s %d / %d" % [_stage_text(), _world.built(), _world.total()]
		return

	# 눈금의 근거다. 인구가 바뀌면 같이 바뀌어야 한다 — 안 그러면 막대 눈금이
	# 옛 인구를 가리킨다 (PersonNorms 머리말).
	_norms = PersonNorms.new(_world.registry)
	_pick.seed = _seed
	show_person(0)


## 지금 어느 단계를 세우고 있나. 단계 이름을 화면이 정하지 않고 `NpcWorld` 에게 묻는다.
func _stage_text() -> String:
	match _world.stage():
		NpcWorld.Stage.KIN:
			return "가족 관계 심는 중"
		NpcWorld.Stage.EVENTS:
			return "사건 굴리는 중"
		_:
			return "인구 생성 중"


## 조작 하나를 한다. **버튼도 키도 캡처도 이 하나를 부른다.**
func act(id: String) -> void:
	if not is_ready():
		return
	match id:
		"prev":
			show_person(_person - 1)
		"next":
			show_person(_person + 1)
		"back":
			show_person(_person - PAGE)
		"forward":
			show_person(_person + PAGE)
		"home":
			show_person(0)
		"random":
			show_person(_pick.randi() % maxi(_world.registry.size(), 1))
		"reseed":
			_seed += 1
			_restart()
		"metrics":
			_shows_metrics = not _shows_metrics
			show_person(_person)


## 휠 한 칸. 앞뒤로 한 사람씩 넘어간다.
##
## **넘기는 조작이 화면에서 제일 자주 하는 일**이라 손가락이 제일 적게 움직이는
## 입력에 걸었다 (§24.17.8 — 판정하려면 여러 명을 봐야 한다).
func wheel(dir: int) -> void:
	show_person(_person - dir)


## 누른다. **탭 띠가 먼저다** — 그다음이 갈 곳이 있는 줄이다.
func tap(where: Vector2) -> void:
	_view.show_note(Vector2.ZERO, "")
	var tab := _view.layout().tab_at(where - _view.position)
	if tab >= 0:
		show_tab(tab as SheetTab.Kind)
		return
	var field := _field_at(where)
	if field != null and field.has_link():
		show_person(field.link)


## 탭을 고른다. **버튼도 클릭도 캡처도 이 하나를 부른다.**
func show_tab(tab: SheetTab.Kind) -> void:
	_view.show_tab(tab)
	_status.text = _status_text()


## 지금 고른 탭.
func tab() -> SheetTab.Kind:
	return _view.tab()


## 정보 확인 (§4.2). **우클릭도 길게 누르기도 이 하나로 들어온다** (§20.23.5).
func inspect(where: Vector2) -> void:
	_view.show_note(where, _note_for(where))


## 커서를 옮긴다. 갈 곳이 있는 줄에 표시가 뜬다.
func hover(where: Vector2) -> void:
	_view.set_hover(_view.layout().field_at(where - _view.position))


## 인물을 갈아 끼운다. **도구도 이 문으로 들어온다** — 예전에는 `_show` 라
## 캡처가 사적 함수를 불러야 했다.
func show_person(person: int) -> void:
	# 생성이 끝나기 전에는 아무것도 안 보인다. 소속 색인이 아직 없어서다 —
	# 입력은 이미 막혀 있지만 도구가 직접 부를 수 있으므로 여기서도 막는다.
	if not is_ready():
		return
	var was := _person
	_person = wrapi(person, 0, _world.registry.size())
	if _person != was:
		_viewer = was
	# **`_viewer` 를 실제로 넘긴다.** ui-kit-2 레인에서는 이 인자가 빠져 있어
	# 면식 칸이 언제나 비어 있었다 — `_viewer` 를 재 놓고 안 쓰고 있었다.
	# 그 칸의 주석이 "이것으로 면식 칸이 실제로 도는지를 본다" 라고 적혀 있으므로
	# 빠뜨린 쪽이 사고다 (통합 2026-08-18).
	_view.show_sections(
		PersonSheet.build(
			_world.registry,
			_person,
			_world.factions,
			SheetDisclosure.Level.DEV,
			_world.graph,
			_norms,
			_viewer,
			_world.ledger
		)
	)
	_status.text = _status_text()


## 지금 보고 있는 인물.
func person() -> int:
	return _person


## 볼 준비가 됐는가.
##
## **도구가 사적 변수를 들여다보지 않게 낸다.** 인구만 보면 뒤에 오는
## 가족 심기(설계 24.22)와 사건을 놓쳐 빈 화면을 찍는다 —
## **`NpcWorld.is_ready()` 하나가 그 신호다.**
func is_ready() -> bool:
	return _world != null and _world.is_ready() and _norms != null


## 지금 인구. 도구가 찍을 인물을 고를 때 쓴다.
func registry() -> PersonRegistry:
	return null if _world == null else _world.registry


## 어느 칸 어느 줄의 한복판. 없으면 `NOWHERE`.
##
## **캡처 대본이 자리를 좌표로 박지 않게 한다.** 박아 두면 배치가 한 번 바뀔 때
## 대본이 엉뚱한 데를 누르고, 그림은 여전히 나오므로 아무도 모른다 —
## §20.22 의 병이 좌표로 돌아온 꼴이다.
func point_of(section_title: String, field: int) -> Vector2:
	var placed := _view.layout()
	for i in placed.rows.size():
		if _view.sections()[placed.row_section[i]].title != section_title:
			continue
		if placed.row_field[i] != field:
			continue
		return placed.rows[i].get_center() + _view.position
	return NOWHERE


## 눌러서 갈 곳이 있는 첫 줄의 한복판. 없으면 `NOWHERE`.
func linked_point() -> Vector2:
	var placed := _view.layout()
	for i in placed.rows.size():
		var field := _view.sections()[placed.row_section[i]].fields[placed.row_field[i]]
		if field.has_link():
			return placed.rows[i].get_center() + _view.position
	return NOWHERE


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _press_held >= 0.0 and motion.position.distance_to(_press_at) > LONG_PRESS_SLACK:
			_press_held = -1.0
		hover(motion.position)
		return

	var click := event as InputEventMouseButton
	if click == null:
		return
	match click.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if click.pressed:
				wheel(1)
		MOUSE_BUTTON_WHEEL_DOWN:
			if click.pressed:
				wheel(-1)
		MOUSE_BUTTON_RIGHT:
			if click.pressed:
				inspect(click.position)
		MOUSE_BUTTON_LEFT:
			_left_button(click)


func _left_button(click: InputEventMouseButton) -> void:
	if click.pressed:
		_press_at = click.position
		_press_held = 0.0
		return
	# 이미 길게 눌러 정보가 떴으면 떼는 것으로 다른 일을 하지 않는다.
	if _press_held < 0.0:
		return
	_press_held = -1.0
	tap(click.position)


func _tick_long_press(delta: float) -> void:
	if _press_held < 0.0:
		return
	_press_held += delta
	if _press_held < LONG_PRESS:
		return
	_press_held = -1.0
	inspect(_press_at)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_ready():
		return
	for action in ACTIONS:
		if int(action[2]) != key.keycode:
			continue
		act(str(action[0]))
		get_viewport().set_input_as_handled()
		return


## 버튼 여덟을 `ACTIONS` 에서 만든다. **표가 하나라 버튼과 키가 못 어긋난다.**
func _build_toolbar() -> void:
	for action in ACTIONS:
		var button := Button.new()
		button.text = str(action[1])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(act.bind(str(action[0])))
		_toolbar.add_child(button)


## 인구를 처음부터 다시 만든다. 시드 하나만 보고는 분포를 판정할 수 없다 (§24.17.8).
func _restart() -> void:
	_world = NpcWorld.new(_seed, POPULATION)
	_norms = null
	_viewer = PersonRegistry.NO_PERSON
	_build_msec = 0.0
	_view.show_sections([] as Array[SheetSection])
	_status.text = "인구 생성 중 0 / %d" % POPULATION


## 눌린 자리의 줄. 없으면 null.
func _field_at(where: Vector2) -> SheetField:
	var at := _view.layout().field_at(where - _view.position)
	if at.x < 0:
		return null
	return _view.sections()[at.x].fields[at.y]


## 정보 확인이 내놓는 글.
##
## **자료가 없는 자리에서도 할 말이 있어야 한다** — §24.17.4 가 세운 규율이다.
## 빈칸을 눌렀는데 아무 말도 안 나오면 그것이 고장으로 읽힌다.
func _note_for(where: Vector2) -> String:
	var local := where - _view.position
	var at := _view.layout().field_at(local)
	if at.x < 0:
		var section := _view.layout().section_at(local)
		if section < 0:
			return ""
		var empty := _view.sections()[section]
		return "%s\n칸이 여기까지다. 채워지면 아래로 자란다 (예상 %d줄)" % [empty.title, empty.expected_lines]

	var owner := _view.sections()[at.x]
	var field := owner.fields[at.y]
	var lines := "%s — %s" % [owner.title, field.label if not field.label.is_empty() else "값"]
	match field.state:
		SheetField.State.MISSING:
			lines += "\n아직 없다: %s" % field.reason
		SheetField.State.HIDDEN:
			lines += "\n이 문맥에서는 안 보인다: %s" % field.reason
		_:
			lines += "\n%s" % field.value
	if field.has_bar():
		lines += "\n막대 %.2f (%s)" % [field.bar, "부호 있음" if field.is_signed_bar else "0부터"]
	if field.has_link():
		lines += "\n누르면 이 사람으로 간다"
	return lines


func _status_text() -> String:
	var hands := "탭 클릭  휠 인물 넘김  관계 줄 클릭  우클릭/길게 누르기 정보"
	if not _shows_metrics:
		return hands
	return (
		"%d / %d  시드 %d  소속 %d개  생성 %.1fms  |  %s"
		% [_person + 1, _world.registry.size(), _seed, _world.factions.populated_count(), _build_msec, hands]
	)
