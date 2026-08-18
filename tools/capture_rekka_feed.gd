extends SceneTree
## 렉카 피드를 실제 화면에 올려 **한 번의 실행으로** 필요한 장면을 몰아 찍는다.
##
##   godot --path . -s res://tools/capture_rekka_feed.gd -- .capture_feed
##
## `gl_compatibility` 라 창을 띄울 때마다 GL 컨텍스트가 새로 생긴다.
## 띄우고 닫기를 반복하지 말고 한 번 띄운 김에 다 찍는다 (CLAUDE.md GPU 절 규칙 3).
##
## 찍는 것 넷.
##
## | 이름 | 무엇을 보는가 |
## | --- | --- |
## | `first` | 판이 시작하자마자 한 편이 걸려 있는가 (피드는 비지 않는다) |
## | `stack` | 편이 쌓였을 때 최신이 위인가, 조각이 겹치지 않는가 |
## | `mark` | 기사 속 방 이름을 짚었을 때 판에 표시가 뜨는가 (13 13.7) |
## | `tall` | 세로 화면에서 판 위에 피드가 쌓이는가 (08 8.2) |

## 화면이 자리를 잡을 때까지 기다릴 프레임.
##
## **인쇄가 끝나기를 기다려야 한다.** 이 화면은 켜지는 것 자체가 한 판을 찍는 것이라
## (`main.gd` `_print_edition`) 그동안 지면이 굵은 점 덩어리로 덮여 있다.
## 여덟 프레임만 기다렸더니 화면 전체가 망점으로 찍혀 나왔다.
## `UiTokens.TIME_PRESS` 가 2.2초이므로 그보다 넉넉히 둔다.
const _SETTLE := 150

## 세로 화면 크기. 모바일 비율을 흉내 낸다.
const _PORTRAIT := Vector2i(760, 1280)

var _prefix := ".capture_feed"
var _main: Node
var _step := 0
var _wait := _SETTLE


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	_main = load("res://src/main/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			_save("first")
		1:
			_walk(3)
		2:
			_save("stack")
		3:
			# 표시는 2.6초에 걸쳐 사그라든다. 여느 걸음처럼 기다렸다가 찍으면
			# 다 사라진 뒤라 아무것도 안 나온다. 짚고 바로 찍는다.
			_mark_room()
			_wait = 4
			_step += 1
			return false
		4:
			_save("mark")
		5:
			DisplayServer.window_set_size(_PORTRAIT)
		6:
			_save("tall")
		_:
			return true
	_step += 1
	_wait = _SETTLE
	return false


## 스쿼드를 몇 걸음 움직인다. 걸음마다 그 턴이 기사가 된다.
func _walk(steps: int) -> void:
	var board: DungeonBoard = _main.get("_board")
	var run: DungeonRun = _main.get("_run")
	for i in steps:
		var open := run.reachable_room_ids()
		if open.is_empty():
			return
		run.move_player(open[i % open.size()])
		board.redraw()
		board.player_acted.emit()


## 최신 편이 가리키는 방 하나를 짚는다. 피드가 내는 신호와 같은 것을 흉내 낸다.
func _mark_room() -> void:
	var feed: RekkaFeed = _main.get("_feed")
	var board: DungeonBoard = _main.get("_board")
	var entry := feed.latest()
	if entry == null:
		return
	var ids := entry.room_ids()
	if not ids.is_empty():
		board.highlight_room(ids[0])


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "res://%s_%s.png" % [_prefix, name]
	image.save_png(path)
	print("%s  %dx%d" % [path, image.get_width(), image.get_height()])
