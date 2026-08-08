class_name NpcSheetScreen
extends Control
## 인물 상세 열람기. **개발용이다 — 전부 보인다.**
##
## docs/design/24-npc-relations.md §24.17.
##
##   godot --path . res://src/ui/npc_sheet/npc_sheet_screen.tscn
##
## ## 무엇을 위한 화면인가
##
## 3000명을 만들어 놨는데 볼 방법이 계측 표의 표본 다섯 줄뿐이었다.
## **사용자가 여러 인물을 넘겨 보며 「이 인구가 그럴듯한가」를 판정하는 것**이 목적이다.
## 그래서 주 조작이 **무작위 뽑기(Space)** 다 — 인덱스 순으로 훑으면
## 앞의 스무 명만 보고 판정하게 된다 (§24.17.8).
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

## 첫 시드. R 을 누르면 하나씩 올라간다.
const FIRST_SEED := 20260808

## 한 프레임에 만드는 인원. 20.4ms / 3000명 기준으로 한 조각이 2ms 남짓이다.
const CHUNK := 250

## PageUp · PageDown 이 건너뛰는 인원.
const PAGE := 100

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


func _ready() -> void:
	_view = %SheetView
	_status = %StatusLine
	_restart()


func _process(_delta: float) -> void:
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
	_show(0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _factions == null:
		return

	match key.keycode:
		KEY_RIGHT:
			_show(_person + 1)
		KEY_LEFT:
			_show(_person - 1)
		KEY_PAGEDOWN:
			_show(_person + PAGE)
		KEY_PAGEUP:
			_show(_person - PAGE)
		KEY_HOME:
			_show(0)
		KEY_SPACE:
			_show(_pick.randi() % maxi(_registry.size(), 1))
		KEY_R:
			_seed += 1
			_restart()
		KEY_F1:
			_shows_metrics = not _shows_metrics
			_show(_person)
		_:
			return
	get_viewport().set_input_as_handled()


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


func _show(person: int) -> void:
	# 생성이 끝나기 전에는 아무것도 안 보인다. 소속 색인이 아직 없어서다 —
	# 입력은 이미 막혀 있지만 도구가 직접 부를 수 있으므로 여기서도 막는다.
	if _registry == null or _registry.size() == 0 or _factions == null:
		return
	_person = wrapi(person, 0, _registry.size())
	_view.show_sections(
		PersonSheet.build(_registry, _person, _factions, SheetDisclosure.Level.DEV, _graph)
	)
	_status.text = _status_text()


func _status_text() -> String:
	var keys := "좌우 인물  PgUp/PgDn %d명  Space 무작위  Home 처음  R 새 시드  F1 계측" % PAGE
	if not _shows_metrics:
		return keys
	return (
		"%d / %d  시드 %d  소속 %d개  생성 %.1fms  |  %s"
		% [_person + 1, _registry.size(), _seed, _factions.populated_count(), _build_msec, keys]
	)
