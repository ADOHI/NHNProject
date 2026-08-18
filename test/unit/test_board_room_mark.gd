extends GutTest
## 판이 **기사가 짚은 방**을 받아 주는가.
##
## 이것이 피드와 판 사이의 계약 전부다 (docs/design/32-rekka-feed.md §32.5.3).
## 피드는 방 id 하나를 신호로 내고, `main` 이 그것을 여기로 넘긴다.
## 둘 중 어느 쪽도 상대의 내부를 모른다.
##
## docs/design/13-information-design.md §13.7 이 이 연결을 **필수**로 못 박았다 —
## *"안 그러면 기사는 장식이 된다."*
##
## 그림은 확인하지 않는다. 화면이 무엇을 그리는가는 캡처로 본다
## (`tools/capture_rekka_feed.gd`). 여기서 보는 것은 **안 터지는가**와
## **판이 그 방으로 옮겨 가는가**뿐이다.

const BoardScene := preload("res://src/ui/dungeon_board/dungeon_board.tscn")
const SEED := 20260808

var _board: DungeonBoard
var _run: DungeonRun


func before_each() -> void:
	_board = BoardScene.instantiate()
	_board.size = Vector2(900, 600)
	add_child_autofree(_board)
	_run = SampleDungeons.create_run(SEED, 3)
	_board.setup(_run, SEED)


func _far_room() -> String:
	# 스쿼드가 선 방 말고 아무 방. 옮겨 갔는지 보려면 지금 자리가 아니어야 한다.
	for room_id in _run.graph.room_ids():
		if room_id != _run.player_room_id():
			return room_id
	return ""


# ---------------------------------------------------------------- 받는다


func test_marking_a_room_brings_it_to_the_middle() -> void:
	var target := _far_room()
	_board.highlight_room(target)

	# 화면 가운데에서 방 위젯 반쪽 안이면 가운데에 온 것이다.
	var node: Control = _board._room_nodes[target]
	var center := node.position + node.size * 0.5 * _board._zoom
	assert_lt(center.distance_to(_board.size * 0.5), 120.0, str(center))


func test_marking_does_not_change_the_zoom() -> void:
	# 지금 배율은 플레이어가 고른 것이다. 기사를 눌렀다고 되돌리면 판을 다시 훑어야 한다.
	_board._zoom = 0.7
	_board.highlight_room(_far_room())

	assert_almost_eq(_board._zoom, 0.7, 0.001)


func test_a_room_the_board_does_not_have_is_ignored() -> void:
	# 글에만 있는 이름이 새어 들어올 수 있다. 그때 터지면 안 된다.
	_board.highlight_room("이런 방은 없다")
	assert_eq(_board._marked_id, "")


func test_the_mark_fades_instead_of_piling_up() -> void:
	# 계속 남으면 판에 붉은 표가 쌓여 무엇이 지금 짚은 것인지 알 수 없게 된다.
	_board.highlight_room(_far_room())
	assert_gt(_board._mark_life, 0.0)

	_board._process(_board._MARK_TIME + 1.0)
	assert_eq(_board._mark_life, 0.0)


func test_marking_before_a_run_is_set_does_nothing() -> void:
	var fresh: DungeonBoard = BoardScene.instantiate()
	add_child_autofree(fresh)

	fresh.highlight_room("start")
	assert_eq(fresh._marked_id, "")
