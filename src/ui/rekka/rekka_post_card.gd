class_name RekkaPostCard
extends PressPanel
## 게시글 한 편의 화면. **지면에서 오려 낸 조각이다.**
##
## ## 조형을 발명하지 않는다
##
## 이 저장소의 화면은 인쇄물이고 (docs/design/18-visual-identity.md),
## 렉카가 쓴 말이 어느 판으로 찍히는지는 `press_panel.gd` 가 이미 정해 뒀다 —
## **별색판은 오려 낸 조각이라 찢겨 있고 기울어 있다.** 그 자리가 이 부품의 자리다.
##
## | 부분 | 쓰는 것 | 왜 |
## | --- | --- | --- |
## | 조각 | `PressPanel.Plate.STORY` | 못 믿는 말이라고 형태가 먼저 말한다 |
## | 제목 | `PlateLabel` 별색판 + 가장 큰 어긋남 | **어긋난 크기가 곧 부풀린 크기다** |
## | 본문 | `RichTextLabel` | 방 이름만 누를 수 있어야 한다 |
## | 댓글 | `MICRO` + 흐린 먹 | 억측이다. 본문과 같은 무게로 읽히면 안 된다 |
##
## ## 방 이름만 누를 수 있다
##
## docs/design/13-information-design.md 13.7 이 **필수**로 못 박았다 —
## *"기사에 나온 방 이름을 클릭하면 판 위에서 강조되는 정도의 연결은 필수다.
## 안 그러면 기사는 장식이 된다."*
##
## 어디까지가 방 이름인가는 `RekkaFeedEntry.spans()` 가 판정한다. 화면은 그 판정을
## 받아 칠하기만 한다 — **판에 없는 이름은 판정에서 이미 빠져 있다.**
##
## ## 댓글에는 링크를 걸지 않는다
##
## 댓글은 억측이고 틀려도 되는 자리다 (13-information-design.md 13.3.0).
## 거기 나온 방 이름을 누를 수 있게 하면 **억측이 판 조작으로 이어진다.**
## 게시글 본문은 사실이므로 거기서만 판으로 이어진다.

## 기사 속 방 이름을 눌렀다. 판이 그 방을 강조한다.
signal room_selected(room_id: String)

## 본문에서 방 이름을 감싸는 표시. `RichTextLabel` 의 링크 문법이다.
const _LINK_OPEN := "[url=%s][color=#%s]"
const _LINK_CLOSE := "[/color][/url]"

var _entry: RekkaFeedEntry = null
var _title: PlateLabel
var _body: RichTextLabel
var _comments: VBoxContainer


func _ready() -> void:
	plate = PressPanel.Plate.STORY
	_build()
	# 종이면과 찢긴 가장자리는 내용이 들어온 뒤에 깔린다. 순서를 뒤집으면
	# 여백을 넣을 MarginContainer 가 아직 없어서 글자가 조각 끝에 붙는다.
	super()


## 이 조각에 실을 글.
func show_entry(entry: RekkaFeedEntry) -> void:
	_entry = entry
	if _title == null:
		return
	_title.set_text(entry.title)
	_body.text = _markup(entry)
	for child in _comments.get_children():
		child.queue_free()
	for line in entry.comments:
		_comments.add_child(_comment_label(line))


## 본문을 링크가 박힌 글로 옮긴다.
##
## **대괄호를 먼저 막는다.** 본문에 대괄호가 남아 있으면 (후처리가 허용하는 글자다)
## 그것이 서식으로 읽혀 글자가 통째로 사라진다.
func _markup(entry: RekkaFeedEntry) -> String:
	var color := UiTokens.SPOT_DEEP.to_html(false)
	var lines: Array[String] = []
	for line in entry.body:
		var built := ""
		for span in RekkaFeedEntry.spans(line, entry.rooms):
			var text := _escape(str(span["text"]))
			var room_id := str(span["room_id"])
			if room_id.is_empty():
				built += text
			else:
				built += (_LINK_OPEN % [room_id, color]) + text + _LINK_CLOSE
		lines.append(built)
	return "\n".join(lines)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _build() -> void:
	var margin := MarginContainer.new()
	margin.name = "Content"
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.SPACE_SNUG)
	margin.add_child(column)

	_title = PlateLabel.new()
	_title.plate = PlateLabel.Plate.SPOT
	_title.variation = UiTheme.SUB
	# 제목이 본문보다 크게 어긋난다. 이 화면에서 제일 부풀린 자리이기 때문이다.
	#
	# **`SLIP_SHOUT` 은 안 쓴다.** 그 값은 1면 톱처럼 큰 활자를 위한 것이고,
	# 좁은 단의 22px 제목에 걸면 두 판이 열 픽셀 어긋나 글자가 겹쳐 읽을 수가 없다.
	# 실제로 찍어 보고 내렸다. **읽히지 않는 서명은 서명이 아니다.**
	_title.slip_amount = UiTokens.SLIP_STORY
	_title.wrap = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("default_color", UiTokens.INK)
	_body.add_theme_font_size_override("normal_font_size", UiTokens.TYPE_LABEL)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.meta_clicked.connect(_on_meta_clicked)
	column.add_child(_body)

	_comments = VBoxContainer.new()
	_comments.add_theme_constant_override("separation", UiTokens.SPACE_TIGHT)
	_comments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_comments)


## 댓글 한 줄. 본문보다 작고 흐리다 — 읽기 전에 무게가 다르다는 것을 알아야 한다.
func _comment_label(line: String) -> Label:
	var label := Label.new()
	label.text = line
	label.theme_type_variation = UiTheme.MICRO
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", UiTokens.INK_FAINT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _on_meta_clicked(meta: Variant) -> void:
	var room_id := str(meta)
	if not room_id.is_empty():
		room_selected.emit(room_id)
