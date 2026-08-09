extends SceneTree
## 인물 상세 화면을 몇 장 뽑는다. **레이아웃이 실제로 읽히는지 눈으로 보려는 것이다.**
##
##   godot --path . --resolution 1280x720 \
##     -s res://tools/capture_npc_sheet.gd -- .captures/npc_sheet
##   godot --path . --resolution 1280x720 \
##     -s res://tools/capture_npc_sheet.gd -- .captures/npc_sheet hand
##
## **헤드리스로는 그림이 나오지 않는다** — 창이 있어야 한다 (다른 캡처 도구와 같다).
##
## ## 두 벌을 뽑는다
##
## | 벌 | 무엇을 보이나 |
## | --- | --- |
## | 기본 | **인물 넷** — 성향이 뚜렷한 사람과 무색한 사람, 유명한 사람, 무소속 |
## | `hand` | **손 다섯** — 커서 · 눌러서 가족으로 이동 · 정보 확인 · 휠 (설계 20.23) |
##
## `hand` 벌이 §4.1 「클릭만으로 전부 조작 가능」이 실제로 도는지 보이는 판정 매체다.
##
## ## 자리를 좌표로 안 박는다
##
## 손짓의 자리는 `screen.point_of()` · `screen.linked_point()` 가 **그때 그려진 배치에서**
## 낸다. 좌표를 박아 두면 배치가 한 번 바뀔 때 대본이 엉뚱한 데를 누르고 —
## **그림은 여전히 나오므로 아무도 모른다**(설계 20.24.1 의 그 병이 좌표로 온 꼴).
##
## 대본이 진짜 줄을 겨누는지는 `test_npc_sheet_hand.gd` 가 **창 없이** 잰다.
##
## ## 함정 둘 — 둘 다 「A 를 찍었는데 B 가 나온다」 로 끝난다
##
## 1. **`_initialize()` 안에서 `add_child()` 해도 `_ready()` 가 그 자리에서 안 돈다.**
##    게다가 인구 생성은 그 뒤로 여러 프레임에 걸쳐 조각으로 진행된다
##    (docs/design/24-npc-relations.md §24.16.2). **생성이 끝날 때까지 기다린 뒤에 찍는다.**
## 2. **`queue_redraw()` 한 프레임에 `force_draw()` 하면 직전 화면이 찍힌다.**
##    실제로 이걸로 한 칸씩 밀린 그림 넷을 뽑았다 — 첫 장이 화면의 초기 인물이었다.
##    **화면을 바꾼 다음 프레임에 찍는다.**

const _SCREEN := "res://src/ui/npc_sheet/npc_sheet_screen.tscn"

## 인구 생성이 끝나기를 기다리는 최대 프레임. 3000명 / 조각 250명이면 12 프레임이다.
const _WAIT_FRAMES := 200

## 찍을 인물. 골라 놓은 이유는 §24.17.8 의 무작위 뽑기를 재현할 수 없어서다 —
## 대신 **성향이 뚜렷한 인물과 무색한 인물을 골라** 딱지 규칙이 둘 다 보이게 한다.
const _SHOTS := ["vivid", "colorless", "famous", "unaffiliated"]

## `_HAND` 의 줄 자리에 쓰면 「갈 곳이 있는 첫 줄」이라는 뜻.
const LINKED := -1

## 손이 하는 일 다섯. `[찍을 이름, 손짓, 칸, 줄]`.
##
## 줄이 `LINKED` 면 **갈 곳이 있는 첫 줄**이다 — 가족이 몇 명인지는 사람마다 다르므로
## 몇 번째 줄인지를 박을 수 없다.
const _HAND := [
	["hand_1_plain", "", "", 0],
	["hand_2_hover", "hover", "관계", LINKED],
	["hand_3_tapped", "tap", "관계", LINKED],
	["hand_4_inspect", "inspect", "성향", 1],
	["hand_5_wheel", "wheel", "", 0],
]

## 가족이 있는 사람을 찾을 때 훑는 최대 인원. 55%가 가족을 가지므로(§24.22.5)
## 몇 명 안 가서 걸린다.
const _SEEK := 400

var _out := "res://.captures/npc_sheet"
var _hand_mode := false
var _screen: NpcSheetScreen
var _frames := 0
var _shot := 0

## 화면을 바꿔 두었고 다음 프레임에 찍으면 되는가.
var _armed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = "res://%s" % args[0]
	_hand_mode = args.size() > 1 and args[1] == "hand"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_screen = load(_SCREEN).instantiate() as NpcSheetScreen
	root.add_child(_screen)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false

	# 준비가 **끝났는지**를 화면에게 묻는다. 사적 변수를 들여다보던 것을 고쳤다
	# (설계 20.23) — 도구가 뒷문으로 들어가면 그 문이 막혀도 아무도 모른다.
	if not _screen.is_ready():
		if _frames > _WAIT_FRAMES:
			push_error("인구 생성이 %d 프레임 안에 끝나지 않았다" % _WAIT_FRAMES)
			return true
		return false

	var steps: int = _HAND.size() if _hand_mode else _SHOTS.size()
	if _shot >= steps:
		return true
	# 한 프레임에 바꾸고, 그다음 프레임에 찍는다 (위 함정 2).
	if _armed:
		_capture(str(_HAND[_shot][0]) if _hand_mode else _SHOTS[_shot])
		_shot += 1
		_armed = false
		return false
	if _hand_mode:
		_do_hand(_shot)
	else:
		_screen.show_person(_pick(_screen.registry(), _SHOTS[_shot]))
	_armed = true
	return false


## 손짓 한 단계. 첫 단계에서 **가족이 있는 사람**을 찾아 세운다 —
## 없는 사람 앞에서는 「눌러서 간다」를 보일 수가 없다.
func _do_hand(step: int) -> void:
	if step == 0:
		_seek_kin()
		return
	var what := str(_HAND[step][1])
	if what == "wheel":
		_screen.wheel(-1)
		return
	var where := _aim(str(_HAND[step][2]), int(_HAND[step][3]))
	if where == NpcSheetScreen.NOWHERE:
		push_error("대본 %d 단계가 겨눌 줄을 못 찾았다" % step)
		return
	match what:
		"hover":
			_screen.hover(where)
		"tap":
			_screen.tap(where)
		"inspect":
			_screen.inspect(where)


## 대본이 겨누는 자리. **그때 그려진 배치에서 낸다.**
func _aim(section_title: String, field: int) -> Vector2:
	if field == LINKED:
		return _screen.linked_point()
	return _screen.point_of(section_title, field)


## 가족이 있는 첫 사람 앞에 선다.
func _seek_kin() -> void:
	for person in _SEEK:
		_screen.show_person(person)
		if _screen.linked_point() != NpcSheetScreen.NOWHERE:
			return
	push_error("%d 명 안에 가족이 있는 사람이 없다" % _SEEK)


## 찍고 싶은 성질의 인물을 찾는다. 없으면 0 번을 쓴다.
func _pick(registry: PersonRegistry, kind: String) -> int:
	var best := 0
	var best_score := -1
	for person in registry.size():
		var score := _score(registry, person, kind)
		if score > best_score:
			best_score = score
			best = person
	return best


func _score(registry: PersonRegistry, person: int, kind: String) -> int:
	match kind:
		"vivid":
			return registry.pole_count_of(person)
		"colorless":
			return NpcAxis.count() - registry.pole_count_of(person)
		"famous":
			return registry.fame_of(person)
		_:
			return 1 if registry.faction_of(person) == PersonRegistry.NO_FACTION else 0


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	if image.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("캡처 실패: %s" % path)
	else:
		print("saved %s" % path)
