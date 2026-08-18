extends GutTest
## 렉카 피드 화면의 **배선** 테스트.
##
## 화면은 규칙을 갖지 않는다. 글을 만드는 규칙은 전부 `src/core/rekka/` 에 있고
## 그쪽에 테스트가 따로 있다. 여기서 볼 것은 둘이다.
##
##   1. **편이 걸리는가.** 최신이 위인가 (08-ui-ux.md §8.2)
##   2. **방 이름을 누르면 신호가 나가는가** (13-information-design.md §13.7)
##
## 헤드리스 테스트를 통과하고도 화면에서 파싱 에러로 터진 전례가 있어(CLAUDE.md)
## 실제로 노드를 세운다.

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const GraphScript := preload("res://src/core/dungeon/dungeon_graph.gd")
const RunScript := preload("res://src/core/dungeon/dungeon_run.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const FeedScript := preload("res://src/core/rekka/rekka_feed.gd")
const ViewScript := preload("res://src/ui/rekka/rekka_feed_view.gd")
const CardScript := preload("res://src/ui/rekka/rekka_post_card.gd")
const EntryScript := preload("res://src/core/rekka/rekka_feed_entry.gd")

var _run: DungeonRun
var _graph: DungeonGraph
var _feed: RekkaFeed
var _view: RekkaFeedView


func before_each() -> void:
	_graph = GraphScript.new()
	_graph.add_room(RoomScript.new("start", "입구 광장", 0, Room.Kind.ENTRANCE))
	_graph.add_room(RoomScript.new("vault", "수장고", 0, Room.Kind.TREASURE))
	_graph.connect_rooms("start", "vault")
	var squad: Actor = ActorScript.new("player_squad", "우리 스쿼드", Actor.Kind.PLAYER_SQUAD, 8, 2)
	_graph.place_actor(squad, "start")
	_run = RunScript.new(null, _graph, squad)
	_feed = FeedScript.new(771)
	_view = ViewScript.new()
	_view.size = Vector2(380, 600)
	add_child_autofree(_view)
	_view.bind(_feed)


func _record(turn: int) -> RekkaFeedEntry:
	var johan: Actor = ActorScript.new("johan", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 2)
	var event: GameEvent = EventScript.new(
		turn, GameEvent.Kind.SEARCHED, johan, _graph.get_room("vault"), 5
	)
	return _feed.record_turn(_run, [event] as Array[GameEvent])


# ---------------------------------------------------------------- 편이 걸린다


func test_a_new_post_shows_up_on_its_own() -> void:
	_record(1)
	assert_eq(_view.card_count(), 1)


func test_the_newest_post_sits_on_top() -> void:
	_record(1)
	_record(2)

	var top: RekkaPostCard = _view._column.get_child(0)
	assert_eq(top._entry.turn, 2)


func test_binding_a_feed_that_already_has_posts_shows_them_all() -> void:
	_record(1)
	_record(2)
	var fresh: RekkaFeedView = ViewScript.new()
	add_child_autofree(fresh)
	fresh.bind(_feed)

	assert_eq(fresh.card_count(), 2)


func test_rebinding_drops_the_old_feed() -> void:
	# 안 끊으면 지난 판의 피드가 계속 편을 붙여 목록이 섞인다.
	_record(1)
	var other: RekkaFeed = FeedScript.new(9042)
	_view.bind(other)

	_record(2)
	assert_eq(_view.card_count(), 0, "지난 판의 편이 새 목록에 붙었다")


func test_binding_nothing_empties_the_list() -> void:
	_record(1)
	_view.bind(null)

	assert_eq(_view.card_count(), 0)


# ---------------------------------------------------------------- 판으로 잇기


func test_clicking_a_room_name_reaches_the_board() -> void:
	_record(1)
	watch_signals(_view)
	var card: RekkaPostCard = _view._column.get_child(0)

	card._on_meta_clicked("vault")

	assert_signal_emitted_with_parameters(_view, "room_selected", ["vault"])


func test_an_empty_meta_is_ignored() -> void:
	_record(1)
	watch_signals(_view)
	var card: RekkaPostCard = _view._column.get_child(0)

	card._on_meta_clicked("")

	assert_signal_not_emitted(_view, "room_selected")


# ---------------------------------------------------------------- 조각 하나


func test_the_card_shows_the_title_and_every_comment() -> void:
	var entry: RekkaFeedEntry = EntryScript.new(
		1, "요한 근황\n\n요한이 수장고를 수색했다\n\n[낄낄이] ㅋㅋ\n\n[고인물] ㅇㅇ", {"수장고": "vault"}
	)
	var card: RekkaPostCard = CardScript.new()
	add_child_autofree(card)
	card.show_entry(entry)

	assert_eq(card._title.text, "요한 근황")
	assert_eq(card._comments.get_child_count(), 2)


func test_room_names_in_the_body_become_links() -> void:
	var entry: RekkaFeedEntry = EntryScript.new(
		1, "제목\n\n요한이 수장고를 수색했다", {"수장고": "vault"}
	)
	var card: RekkaPostCard = CardScript.new()
	add_child_autofree(card)
	card.show_entry(entry)

	assert_string_contains(card._body.text, "[url=vault]")


func test_brackets_in_the_body_never_become_markup() -> void:
	# 후처리는 대괄호를 허용한다. 그대로 넘기면 서식으로 읽혀 글자가 사라진다.
	var entry: RekkaFeedEntry = EntryScript.new(1, "제목\n\n요한이 [공백] 어쩌고", {})
	var card: RekkaPostCard = CardScript.new()
	add_child_autofree(card)
	card.show_entry(entry)

	assert_string_contains(card._body.text, "[lb]공백")
	assert_string_contains(card._body.get_parsed_text(), "[공백]")
