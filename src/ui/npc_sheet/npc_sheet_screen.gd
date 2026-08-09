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
## 3000명 생성이 20.4ms 다 (§24.16.9). 그래서 `PersonGenerator.append_to()` 를
## **프레임마다 조각씩** 부른다 — §24.16.2 에서 비워 둔 자리의 첫 사용자다.

## 목표 인구. §24.8 의 상한이다.
const POPULATION := 3000

## 첫 시드. 새 시드를 부르면 하나씩 올라간다.
const FIRST_SEED := 20260808

## 한 프레임에 만드는 인원. 20.4ms / 3000명 기준으로 한 조각이 2ms 남짓이다.
const CHUNK := 250

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

## 길게 누르기가 정보 확인이 되는 시간(초). **터치에는 오른쪽 버튼이 없다** —
## §4.2 가 「우클릭 · 롱프레스」를 한 줄에 적은 이유다.
const LONG_PRESS := 0.5

## 누른 자리가 이만큼 넘게 움직이면 길게 누르기가 취소된다(px).
## 안 그러면 **끌기가 전부 정보 확인이 된다.**
const LONG_PRESS_SLACK := 8.0

var _seed := FIRST_SEED
var _registry: PersonRegistry
var _factions: FactionIndex
var _generator: PersonGenerator
var _graph: RelationGraph
var _kin: KinSeeder
var _person := 0
var _pick := RandomNumberGenerator.new()
var _build_msec := 0.0
var _shows_metrics := true

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
	if _generator == null and _kin == null:
		return
	if _generator != null:
		var started := Time.get_ticks_usec()
		var done := _generator.append_to(_registry, CHUNK)
		_build_msec += float(Time.get_ticks_usec() - started) / 1000.0
		if not done:
			_status.text = "인구 생성 중 %d / %d" % [_registry.size(), POPULATION]
			return

	if _generator != null:
		_generator = null
		# 태생 관계도 조각으로 심는다 — 인구 생성과 같은 규율이다 (설계 24.22).
		_graph = RelationGraph.new(_registry.size())
		_kin = KinSeeder.new(_seed, _registry, _graph)
		_status.text = "가족 관계 심는 중"
		return

	var kin_started := Time.get_ticks_usec()
	var kin_done := _kin.seed_chunk(CHUNK)
	_build_msec += float(Time.get_ticks_usec() - kin_started) / 1000.0
	if not kin_done:
		_status.text = "가족 관계 심는 중 %d / %d" % [_kin.seeded(), _registry.size()]
		return

	_kin = null
	_factions = FactionIndex.new(_registry)
	_pick.seed = _seed
	show_person(0)


## 조작 하나를 한다. **버튼도 키도 캡처도 이 하나를 부른다.**
func act(id: String) -> void:
	if _factions == null:
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
			show_person(_pick.randi() % maxi(_registry.size(), 1))
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


## 누른다. 갈 곳이 있는 줄이면 그 사람으로 간다.
func tap(where: Vector2) -> void:
	_view.show_note(Vector2.ZERO, "")
	var field := _field_at(where)
	if field != null and field.has_link():
		show_person(field.link)


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
	if _registry == null or _registry.size() == 0 or _factions == null:
		return
	_person = wrapi(person, 0, _registry.size())
	_view.show_sections(
		PersonSheet.build(_registry, _person, _factions, SheetDisclosure.Level.DEV, _graph)
	)
	_status.text = _status_text()


## 지금 보고 있는 인물.
func person() -> int:
	return _person


## 볼 준비가 됐는가.
##
## **도구가 사적 변수를 들여다보지 않게 낸다.** `_factions` 가 마지막에 서므로
## 그것 하나가 준비 신호다 — 인구만 보면 뒤에 오는 가족 심기(설계 24.22)를 놓쳐
## 빈 화면을 찍는다.
func is_ready() -> bool:
	return _factions != null and _registry != null and _registry.size() > 0


## 지금 인구. 도구가 찍을 인물을 고를 때 쓴다.
func registry() -> PersonRegistry:
	return _registry


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
	if key == null or not key.pressed or key.echo or _factions == null:
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
	_registry = PersonRegistry.new()
	_generator = PersonGenerator.new(_seed, POPULATION)
	_graph = null
	_kin = null
	_factions = null
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
	var hands := "휠 인물 넘김  관계 줄 클릭  우클릭/길게 누르기 정보"
	if not _shows_metrics:
		return hands
	return (
		"%d / %d  시드 %d  소속 %d개  생성 %.1fms  |  %s"
		% [_person + 1, _registry.size(), _seed, _factions.populated_count(), _build_msec, hands]
	)
