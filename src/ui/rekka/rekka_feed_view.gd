class_name RekkaFeedView
extends Control
## 렉카 피드 화면. **최신이 위, 아래로 스크롤.**
##
## ## 판과 서로의 내부를 들여다보지 않는다
##
## 이 화면은 `DungeonBoard` 를 모르고 `DungeonBoard` 도 이 화면을 모른다.
## 판은 `main` 이 만들어 화면들에 나눠 주고, 화면끼리는 신호로만 말한다
## (`src/main/main.gd` — *"판은 여기서 만들어 화면 둘에 나눠 준다"*).
##
##     RekkaFeedView --room_selected--> main --> DungeonBoard
##
## 둘을 직접 이으면 주둔지 뉴스 피드(08-ui-ux.md 8.3.4.1)가 판 없이는 못 뜬다.
## 같은 부품을 두 화면에서 쓰는 것이 이 장치의 전제다.
##
## ## 피드는 절대 비지 않는다
##
## 사건이 없는 턴에도 편은 나온다 (docs/design/32-rekka-feed.md 32.1).
## 그래서 이 화면에는 "표시할 것이 없습니다" 상태가 없다 — 판이 시작하기 전에만
## 비어 있고, 첫 턴부터는 언제나 한 편 이상이 있다.

## 기사 속 방 이름을 눌렀다. 판이 그 방을 강조한다 (13-information-design.md 13.7).
signal room_selected(room_id: String)

## 조각 사이의 틈.
##
## 조각이 서로 기울어 있어서(별색판) 좁게 두면 모서리가 겹쳐 보인다.
const _CARD_GAP := UiTokens.SPACE_GAP

var _feed: RekkaFeed = null
var _scroll: ScrollContainer
var _column: VBoxContainer
var _title: Label


func _ready() -> void:
	_build()


## 피드를 갈아 끼운다. 판이 새로 시작하면 부른다.
##
## **듣던 신호를 먼저 끊는다.** 안 끊으면 이전 판의 피드가 계속 이 화면에 편을 붙이고,
## 새 판의 목록에 지난 판의 글이 섞인다.
func bind(feed: RekkaFeed) -> void:
	if _feed != null and _feed.post_added.is_connected(_on_post_added):
		_feed.post_added.disconnect(_on_post_added)
	_feed = feed
	if _feed != null:
		_feed.post_added.connect(_on_post_added)
	rebuild()


## 목록을 통째로 다시 그린다.
func rebuild() -> void:
	if _column == null:
		return
	for child in _column.get_children():
		# **떼어 내고 나서 버린다.** `queue_free()` 만 부르면 이번 프레임 동안 자식으로
		# 남아 있어서, 판을 갈아 끼운 직후에 지난 판의 편이 목록에 그대로 세어진다.
		_column.remove_child(child)
		child.queue_free()
	if _feed == null:
		return
	for entry in _feed.newest_first():
		_column.add_child(_card_for(entry))


## 지금 몇 편이 걸려 있는가. 화면 밖에서 세어 보려고 쓴다.
func card_count() -> int:
	return 0 if _column == null else _column.get_child_count()


## 새 편은 **맨 위**에 꽂는다. 최신이 위라는 것이 이 목록의 규칙이다 (8.2).
func _on_post_added(entry: RekkaFeedEntry) -> void:
	var card := _card_for(entry)
	_column.add_child(card)
	_column.move_child(card, 0)
	# 새 편이 붙으면 맨 위로 되돌린다. 읽던 자리에 그대로 두면 방금 나온 소식을
	# 놓치고, 계획 페이즈에 읽으라고 만든 장치가 헛돈다.
	_scroll.set_deferred("scroll_vertical", 0)


func _card_for(entry: RekkaFeedEntry) -> RekkaPostCard:
	var card := RekkaPostCard.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.room_selected.connect(_on_room_selected)
	# 자식으로 들어가기 전에는 _ready 가 안 돌아서 안쪽 위젯이 없다.
	card.ready.connect(card.show_entry.bind(entry))
	return card


func _on_room_selected(room_id: String) -> void:
	room_selected.emit(room_id)


func _build() -> void:
	var frame := VBoxContainer.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", UiTokens.SPACE_SNUG)
	add_child(frame)

	# 제호. 이 단이 무엇인지 한 번은 말해야 한다 — 판 옆에 글이 쌓여 있는 것만으로는
	# 그것이 남이 쓴 기사라는 것이 전달되지 않는다.
	_title = Label.new()
	_title.text = "렉카 피드"
	_title.theme_type_variation = UiTheme.CAPTION
	frame.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(_scroll)

	_column = VBoxContainer.new()
	_column.name = "Posts"
	_column.add_theme_constant_override("separation", _CARD_GAP)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_column)
