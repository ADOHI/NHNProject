extends SceneTree
## 방 50개짜리 판을 실제 화면에 올려 **한 번의 실행으로** 필요한 배율을 몰아 찍는다.
##
## `gl_compatibility` 라 창을 띄울 때마다 GL 컨텍스트가 새로 생긴다. 그래서 배율마다
## 따로 띄우지 않고 한 번에 세 장을 찍는다 (docs/design/17-dungeon-generation.md §17.15).
##
## 슬라이더 최대가 32 안팎이라 50개는 UI 로 만들 수 없다. 그래서 판을 직접 만들어
## 화면에 붙인다. **`src/` 는 건드리지 않는다.**
##
##   godot --path . -s res://tools/capture_board_50.gd -- .capture_board

## 찍을 배율과 그 이유.
const _SHOTS := [
	[1.0, "play", "플레이 배율. 스쿼드 중심"],
	[0.62, "names", "이름이 보이는 최저 배율"],
	[0.4, "limit", "확대 하한. 판 전체를 보려는 배율"],
]

const _ROOMS := 50
const _SEED := 11

## 화면이 자리를 잡을 때까지 기다릴 프레임. 중앙 정렬이 다음 프레임으로 미뤄져 있다.
const _SETTLE_FRAMES := 10

var _prefix := ".capture_board"
var _main: Node
var _step := 0
var _wait := _SETTLE_FRAMES


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	_main = load("res://src/main/main.tscn").instantiate()
	root.add_child(_main)


## 설치 -> (배율 맞추기 -> 찍기) x 3.
##
## 배율을 바꾼 프레임에 바로 찍으면 위젯이 아직 옛 자리에 있다. 한 박자 기다린다.
func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _step == 0:
		_install()
	elif _step % 2 == 1:
		var slot := (_step - 1) / 2
		if slot >= _SHOTS.size():
			return true
		_frame(float(_SHOTS[slot][0]))
	else:
		var slot := (_step - 2) / 2
		_save(String(_SHOTS[slot][1]))
	_step += 1
	_wait = _SETTLE_FRAMES
	return false


## 방 50개짜리 판을 만들어 화면에 붙인다. SampleDungeons.create_run 과 같은 순서다.
func _install() -> void:
	var params := DungeonGenerator.Params.new()
	params.room_count = _ROOMS
	var blueprint := DungeonGenerator.new(_SEED, params).generate()
	var graph := blueprint.build()

	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var entrances := blueprint.rooms_of_kind(Room.Kind.ENTRANCE)
	var entrance: String = entrances[0] if not entrances.is_empty() else blueprint.room_ids()[0]
	SampleDungeons._populate(graph, blueprint, entrance, rng)

	var squad := Actor.new(
		"player_squad",
		"우리 스쿼드",
		Actor.Kind.PLAYER_SQUAD,
		SampleDungeons.SQUAD_THREAT,
		SampleDungeons.SQUAD_AGILITY
	)
	graph.place_actor(squad, entrance)

	var board := _board()
	if board == null:
		push_error("DungeonBoard 를 찾지 못했습니다")
		return
	board.setup(DungeonRun.new(blueprint, graph, squad), _SEED)
	print("방 %d개 · 간선 %d" % [blueprint.room_ids().size(), blueprint.connections().size()])


## 배율을 맞추고 지도 전체가 화면 가운데 오도록 옮긴다.
##
## 플레이 배율에서는 스쿼드를 가운데 두는 것이 맞지만, 판이 담기는지 보려면
## 지도의 한가운데를 봐야 한다.
func _frame(zoom: float) -> void:
	var board := _board()
	if board == null:
		return
	board.set("_zoom", zoom)
	var positions: Dictionary = board.get("_positions")
	if not positions.is_empty() and zoom < 1.0:
		var lowest := Vector2.INF
		var highest := -Vector2.INF
		for position in positions.values():
			lowest = lowest.min(position as Vector2)
			highest = highest.max(position as Vector2)
		board.set("_pan", (board as Control).size * 0.5 - (lowest + highest) * 0.5 * zoom)
	board.call("_clamp_pan")
	board.call("_reposition")
	board.call("_refresh")


## 화면 위의 판. **이름으로 먼저 찾는다.**
##
## 타입("DungeonBoard")으로 찾으면 인스턴스된 씬에서 빗나가는 경우가 있었다.
## 이름은 main.tscn 에 박혀 있으므로 확실하다.
func _board() -> Node:
	var named := _main.find_child("DungeonBoard", true, false)
	if named != null:
		return named
	var found := root.find_children("*", "DungeonBoard", true, false)
	if not found.is_empty():
		return found[0]
	for child in _main.get_children():
		print("  자식: %s (%s)" % [child.name, child.get_class()])
	return null


func _save(label: String) -> void:
	var path := "res://%s_%s.png" % [_prefix, label]
	var error := root.get_texture().get_image().save_png(path)
	print("capture: %s (err=%d)" % [ProjectSettings.globalize_path(path), error])
