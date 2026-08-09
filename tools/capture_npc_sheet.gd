extends SceneTree
## 인물 상세 화면을 몇 장 뽑는다. **레이아웃이 실제로 읽히는지 눈으로 보려는 것이다.**
##
##   godot --path . --resolution 1280x720 -s res://tools/capture_npc_sheet.gd -- .captures/npc_sheet
##
## **헤드리스로는 그림이 나오지 않는다** — 창이 있어야 한다 (다른 캡처 도구와 같다).
##
## ## 함정 둘 — 둘 다 「A 를 찍었는데 B 가 나온다」 로 끝난다
##
## 1. **`_initialize()` 안에서 `add_child()` 해도 `_ready()` 가 그 자리에서 안 돈다.**
##    게다가 인구 생성은 그 뒤로 여러 프레임에 걸쳐 조각으로 진행된다
##    (docs/design/24-npc-relations.md §24.16.2). **생성이 끝날 때까지 기다린 뒤에 찍는다.**
## 2. **`queue_redraw()` 한 프레임에 `force_draw()` 하면 직전 화면이 찍힌다.**
##    실제로 이걸로 한 칸씩 밀린 그림 넷을 뽑았다 — 첫 장이 화면의 초기 인물이었다.
##    **인물을 갈아 끼운 다음 프레임에 찍는다.**

const _SCREEN := "res://src/ui/npc_sheet/npc_sheet_screen.tscn"

## 인구 생성이 끝나기를 기다리는 최대 프레임. 3000명 / 조각 250명이면 12 프레임이다.
const _WAIT_FRAMES := 200

## 찍을 인물. 골라 놓은 이유는 §24.17.8 의 무작위 뽑기를 재현할 수 없어서다 —
## 대신 **성향이 뚜렷한 인물과 무색한 인물을 골라** 딱지 규칙이 둘 다 보이게 한다.
const _SHOTS := ["vivid", "colorless", "famous", "unaffiliated"]

var _out := "res://.captures/npc_sheet"
var _screen: NpcSheetScreen
var _frames := 0
var _shot := 0

## 인물을 갈아 끼워 두었고 다음 프레임에 찍으면 되는가.
var _armed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = "res://%s" % args[0]
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

	if _shot >= _SHOTS.size():
		return true
	# 한 프레임에 갈아 끼우고, 그다음 프레임에 찍는다 (위 함정 2).
	if _armed:
		_capture(_SHOTS[_shot])
		_shot += 1
		_armed = false
		return false
	_screen.show_person(_pick(_screen.registry(), _SHOTS[_shot]))
	_armed = true
	return false


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
