extends SceneTree
## 아지트 화면을 창에 띄워 몇 장 찍는다. **헤드리스로는 렌더링 결과를 볼 수 없다.**
##
##     godot --path . -s res://tools/capture_hideout.gd
##
## | 파일 | 무엇을 보려고 |
## | --- | --- |
## | `.captures/hideout_board.png` | 판 전체가 한눈에 들어오고 칸이 읽히는가 (§30.9 ★2) |
## | `.captures/hideout_close.png` | **칸과 건물의 각도가 캐릭터와 맞는가** (§30.2.1) |
## | `.captures/hideout_hover.png` | 가리킨 칸이 마우스 밑에 정확히 붙는가 |
## | `.captures/hideout_ghost_ok.png` | ③ 놓을 수 있는 자리의 미리보기 |
## | `.captures/hideout_ghost_blocked.png` | ③ 겹치는 자리의 미리보기와 그 이유 |
##
## ## 창을 한 번만 띄운다
##
## 캡처마다 창을 새로 띄우면 GL 컨텍스트를 그때마다 새로 만들게 되고, 그것이 드라이버를
## 흔들어 세션이 끊긴 적이 있다 (CLAUDE.md — GPU 를 나눠 쓴다).
## **끝나면 바로 놓는다.** 그림 생성이 GPU 를 기다리고 있다 (LANE-RULES §3).
##
## ## 바꾸고 나서 바로 찍으면 안 된다
##
## `get_texture().get_image()` 는 **이미 그려진 마지막 프레임**을 준다. 상태를 바꾼 그 틱에
## 찍으면 바꾸기 **전** 화면이 나온다. 처음에 그렇게 짰다가 확대 장면이 확대 전 화면으로
## 찍혔고, 세 장이 전부 한 칸씩 밀렸다. 그래서 **바꾸고 - 몇 프레임 두고 - 찍는다.**
##
## ## 마우스는 진짜로 옮긴다
##
## 화면은 매 프레임 실제 마우스 자리를 읽는다(`_track_mouse`). 코드로 가리키기만 하면
## 다음 프레임에 실제 마우스 자리로 덮인다. 그래서 OS 커서를 그 칸 위로 **실제로 옮긴다** —
## 덤으로 사람이 쓰는 길과 같은 길을 시험하게 된다.

const _SCENE := "res://src/ui/hideout/hideout_screen.tscn"
const _OUT_DIR := "res://.captures"

## 창이 자리를 잡을 준비 프레임. 첫 프레임은 아직 아무것도 안 그려져 있다.
const _WARMUP_FRAMES := 20

## 상태를 바꾼 뒤 그것이 화면에 나올 때까지 두는 프레임.
const _SETTLE_FRAMES := 8

var _screen: Node
var _frames := 0
var _step := 0
var _due := -1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUT_DIR))
	var packed: PackedScene = load(_SCENE)
	_screen = packed.instantiate()
	root.add_child(_screen)
	_due = _WARMUP_FRAMES


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _due:
		return false
	match _step:
		0:
			_save("hideout_board")
		1:
			_zoom_in()
		2:
			_save("hideout_close")
		3:
			_point_at_a_building()
		4:
			_save("hideout_hover")
		5:
			_aim_build_at_free_ground()
		6:
			_save("hideout_ghost_ok")
		7:
			_aim_build_at_a_building()
		8:
			_save("hideout_ghost_blocked")
		_:
			return true
	_step += 1
	_due = _frames + _SETTLE_FRAMES
	return false


func _camera() -> Camera2D:
	return _screen.find_children("*", "Camera2D", true, false)[0] as Camera2D


func _zoom_in() -> void:
	var grid = _screen.call("grid")
	var iso = _screen.call("projection")
	var camera := _camera()
	camera.zoom = Vector2(1.5, 1.5)
	camera.position = iso.cell_to_world(Vector2i(grid.cols / 2, grid.rows / 2))
	print("[capture] 확대: 판 %d x %d · 건물 %d" % [grid.cols, grid.rows, grid.buildings().size()])


## 건물 앞 칸으로 **실제 커서를 옮긴다.** 커서가 그 칸에 붙는지가 투영 왕복의 눈에 보이는 증거다.
func _point_at_a_building() -> void:
	var grid = _screen.call("grid")
	var iso = _screen.call("projection")
	var building = grid.buildings()[0]
	var target: Vector2i = building.entrance_cell()
	var world: Vector2 = iso.cell_to_world(target)
	Input.warp_mouse(_screen.get_viewport().get_canvas_transform() * world)
	print("[capture] 커서를 %s 칸으로 옮겼다" % [target])


## 빈 땅에 정보실(2x3)을 겨눈다. 발자국이 정사각형이 아닌 것을 일부러 고른다.
func _aim_build_at_free_ground() -> void:
	_screen.call("begin_build", Facility.Kind.INTEL_ROOM)
	_warp_to(Vector2i(6, 6))


## 이미 선 건물 위에 겹쳐 겨눈다. 빨갛게 뜨고 이유가 나와야 한다.
func _aim_build_at_a_building() -> void:
	var grid = _screen.call("grid")
	_screen.call("begin_build", Facility.Kind.INTEL_ROOM)
	_warp_to(grid.buildings()[0].origin)


func _warp_to(cell: Vector2i) -> void:
	var iso = _screen.call("projection")
	Input.warp_mouse(_screen.get_viewport().get_canvas_transform() * iso.cell_to_world(cell))


func _save(shot_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_OUT_DIR, shot_name]
	image.save_png(path)
	print("[capture] %s  ->  %s" % [path, _screen.call("status_text").split("\n")[1]])
