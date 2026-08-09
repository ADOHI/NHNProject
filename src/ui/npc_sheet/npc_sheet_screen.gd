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
##
## ## 세계를 세우는 순서는 NpcWorld 가 안다
##
## 인구 -> 태생 관계 -> 사건. **이 화면은 그 순서를 모르고 조각만 돌린다** —
## 순서를 화면이 들고 있으면 다른 화면이 반쪽 세계를 세운다 (NpcWorld).

## 첫 시드. R 을 누르면 하나씩 올라간다.
const FIRST_SEED := 20260808

## PageUp · PageDown 이 건너뛰는 인원.
const PAGE := 100

var _seed := FIRST_SEED
var _world: NpcWorld
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
	if _world == null or _world.is_ready():
		return
	var started := Time.get_ticks_usec()
	var done := _world.build_chunk()
	_build_msec += float(Time.get_ticks_usec() - started) / 1000.0
	if done:
		_pick.seed = _seed
		_show(0)
		return
	_status.text = "%s %d / %d" % [_stage_text(), _world.built(), _world.total()]


func _stage_text() -> String:
	match _world.stage():
		NpcWorld.Stage.KIN:
			return "가족 관계 심는 중"
		NpcWorld.Stage.EVENTS:
			return "사건 굴리는 중"
		_:
			return "인구 생성 중"


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _world == null or not _world.is_ready():
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
			_show(_pick.randi() % maxi(_world.registry.size(), 1))
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
	_world = NpcWorld.new(_seed)
	_build_msec = 0.0
	_view.show_sections([] as Array[SheetSection])
	_status.text = "인구 생성 중 0 / %d" % _world.population()


func _show(person: int) -> void:
	# 세계가 다 서기 전에는 아무것도 안 보인다. 입력은 이미 막혀 있지만
	# 도구가 직접 부를 수 있으므로 여기서도 막는다.
	if _world == null or not _world.is_ready():
		return
	_person = wrapi(person, 0, _world.registry.size())
	_view.show_sections(
		PersonSheet.build(
			_world.registry,
			_person,
			_world.factions,
			SheetDisclosure.Level.DEV,
			_world.graph,
			_world.ledger
		)
	)
	_status.text = _status_text()


func _status_text() -> String:
	var keys := "좌우 인물  PgUp/PgDn %d명  Space 무작위  Home 처음  R 새 시드  F1 계측" % PAGE
	if not _shows_metrics:
		return keys
	return (
		"%d / %d  시드 %d  소속 %d개  사건 %d건  관계 %d개  생성 %.1fms  |  %s"
		% [
			_person + 1,
			_world.registry.size(),
			_seed,
			_world.factions.populated_count(),
			_world.ledger.size(),
			_world.graph.size(),
			_build_msec,
			keys,
		]
	)
