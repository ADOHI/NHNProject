class_name TerminalGuide
extends Control
## 컨셉 견본 — **「활판 단말」.** 정지 화면 한 장으로 판정받는 그림이다.
##
## > **화면은 활자로 짜여 있고, 화면처럼 갱신된다.**
##
## 층을 이렇게 갈랐다. 장식을 섞은 것이 아니라 **층마다 어느 쪽인지 정한 것**이다.
##
## | 층 | 어느 쪽 | 왜 |
## | --- | --- | --- |
## | **조판 • 배치** | **클래식** | 아름다움이 500년 검증됐다. 없다고 지적받은 타이포가 여기 온다 |
## | **재료** | **디지털** | 전자종이 화면이다. 종이를 쓰면 스팀펑크가 된다 |
## | **갱신 • 거동** | **디지털** | 한 번 뒤집히고 잔상이 남는다 |
## | **색** | **클래식** | 종이색 + 잉크 + 금 한 점. 원색 대비쌍이 사라진다 |
##
## ## 부조화가 무기다
##
## 격식은 **인간 쪽**의 것이다 — 길드가 남기는 계측 기록의 양식.
## 저질 말투는 **그놈들 쪽**의 것이다 — 재미로 게이트를 열고 중계하는 존재들
## ([`02`](../../../docs/design/02-overview.md) §2.6.1). 렉카는 그중 하나다.
##
## **그래서 그놈들의 중계는 격자를 지키지 않는다.** 기울고, 반전되고, 괘선을 넘어간다.
## 격식 있는 그릇에 저질 내용이 끼어드는 것이 이 세계가 사람의 죽음을 다루는 방식이고,
## 그 어긋남을 숨기지 않고 화면의 사건으로 쓴다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const PAPER := Color(0.788, 0.769, 0.714)
const INK := Color(0.102, 0.094, 0.082)
const MID := Color(0.431, 0.416, 0.373)
const GOLD := Color(0.663, 0.541, 0.294)
const BEZEL := Color(0.137, 0.129, 0.114)

## 화면 여백. 격자의 정수배다.
const MARGIN := Vector2(78.0, 58.0)

var _sheet: Texture2D
var _crack: Texture2D
var _smudge: Texture2D
var _brass: Texture2D
var _bezel_tex: Texture2D
var _font: FontVariation

## 눌린 판을 보여 줄지. 반전이 이 컨셉의 눌림이다.
var _screen: Rect2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = FontVariation.new()
	_font.base_font = FONT
	_sheet = _try_load("eink_sheet")
	_crack = _try_load("glass_crack")
	_smudge = _try_load("glass_smudge")
	_brass = _try_load("brass")
	_bezel_tex = _try_load("bezel")


func _try_load(name: String) -> Texture2D:
	var path := "res://assets/ui/kit/%s.webp" % name
	if not ResourceLoader.exists(path):
		push_warning("에셋이 없다: " + path)
		return null
	return load(path) as Texture2D


func _draw() -> void:
	_screen = Rect2(Vector2(34.0, 30.0), size - Vector2(68.0, 60.0))
	_draw_device()
	_draw_screen_surface()
	_draw_masthead()
	_draw_record_block()
	_draw_buttons()
	_draw_popup()
	_draw_map()
	_draw_feed()
	_draw_glass()


## 기기 — 화면 밖의 몸체. 베젤이 있어야 화면이 **물건 안에** 있다.
func _draw_device() -> void:
	if _bezel_tex != null:
		draw_texture_rect(_bezel_tex, Rect2(Vector2.ZERO, size), true, BEZEL * 2.4)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), BEZEL)
	# 금박 압인. 화면에서 **금은 이것 하나뿐**이다 — 흔해지면 귀하지 않다.
	var mark := Rect2(size.x - 58.0, size.y - 21.0, 20.0, 11.0)
	if _brass != null:
		draw_texture_rect(_brass, mark, false, Color(1.0, 1.0, 1.0, 0.95))
	_text(
		"협회 인증",
		Vector2(mark.position.x - 54.0, mark.position.y + 9.0),
		TypeGrid.Rank.MICRO,
		Color(PAPER.r, PAPER.g, PAPER.b, 0.42)
	)


## 전자종이 표면. 발광하지 않고 반사한다 — 그것이 네온과 갈리는 지점이다.
func _draw_screen_surface() -> void:
	draw_rect(_screen, PAPER)
	if _sheet != null:
		draw_texture_rect(_sheet, _screen, true, Color(1.0, 1.0, 1.0, 0.30))
	# 화면 안쪽으로 유리가 드리우는 그늘. 화면이 유리 **아래**에 있다는 표시다.
	var shade := _screen
	shade.size.y = 26.0
	draw_rect(shade, Color(INK.r, INK.g, INK.b, 0.055))


## 제호 — 표제 급이 격자에서 어떻게 서는지 보이는 자리.
func _draw_masthead() -> void:
	var at := _screen.position + MARGIN
	_text("금", at, TypeGrid.Rank.DISPLAY, INK)
	var after := at.x + TypeGrid.width_of("금", TypeGrid.Rank.DISPLAY) + TypeGrid.GUTTER
	_text("탐사 기록", Vector2(after, at.y - 20.0), TypeGrid.Rank.HEAD, INK)
	_text("게이트 제 4 구역 • 삼층 • 스물두 방", Vector2(after, at.y + 4.0), TypeGrid.Rank.MICRO, MID)
	# 굵은 괘선 하나. 사방을 두르지 않는다 — 액자는 어느 UI 에나 있다.
	var rule_y := at.y + 34.0
	draw_line(
		Vector2(at.x, rule_y), Vector2(_screen.end.x - MARGIN.x, rule_y), INK, TypeGrid.RULE_THICK
	)


## 계측 기록 — 격식 있는 인간 쪽의 양식. 숫자가 격자에 맞아 자릿수가 정렬된다.
func _draw_record_block() -> void:
	var at := _screen.position + MARGIN + Vector2(0.0, 56.0)
	var rows := [
		["인접 위험도 합", "14"],
		["직전 턴 대비", "+2"],
		["도달 가능 방", "3"],
	]
	for i in range(rows.size()):
		var y := at.y + float(i) * TypeGrid.cell(TypeGrid.Rank.BODY).y
		_text(rows[i][0], Vector2(at.x, y), TypeGrid.Rank.BODY, MID)
		# 값은 오른쪽 정렬. 셀 격자라 자릿수가 저절로 맞는다.
		var value: String = rows[i][1]
		var value_x := at.x + 268.0 - TypeGrid.width_of(value, TypeGrid.Rank.BODY)
		_text(value, Vector2(value_x, y), TypeGrid.Rank.BODY, INK)
		draw_line(Vector2(at.x, y + 5.0), Vector2(at.x + 268.0, y + 5.0), MID, TypeGrid.RULE_HAIR)


## 버튼 — 활자 상자다. **눌리면 통째로 잉크가 먹는다**(반전).
##
## 반전이 두 기술에서 동시에 성립한다. 활판에서는 판에 잉크가 묻은 것이고,
## 전자종이에서는 갱신할 때 그 구역이 한 번 뒤집히는 것이다. 억지가 아니다.
func _draw_buttons() -> void:
	var at := _screen.position + MARGIN + Vector2(0.0, 154.0)
	_button("들어간다", at, false)
	var second := Vector2(at.x + 176.0, at.y)
	_button("물러난다", second, true)
	_text("눌림은 반전이다", Vector2(at.x, at.y + 62.0), TypeGrid.Rank.MICRO, MID)


func _button(label: String, at: Vector2, inverted: bool) -> void:
	var pad := Vector2(TypeGrid.GUTTER * 1.5, 9.0)
	var box := Rect2(
		at,
		Vector2(
			TypeGrid.snap(TypeGrid.width_of(label, TypeGrid.Rank.BODY) + pad.x * 2.0),
			TypeGrid.cell(TypeGrid.Rank.BODY).y + pad.y * 2.0
		)
	)
	var ink := INK
	if inverted:
		draw_rect(box, INK)
		ink = PAPER
	# 아래 굵은 괘선과 위 가는 괘선. 사방을 두르지 않는 것이 이 컨셉의 형태다.
	draw_line(
		Vector2(box.position.x, box.end.y),
		Vector2(box.end.x, box.end.y),
		ink if inverted else INK,
		TypeGrid.RULE_THICK
	)
	if not inverted:
		draw_line(box.position, Vector2(box.end.x, box.position.y), MID, TypeGrid.RULE_HAIR)
	_text(
		label,
		Vector2(box.position.x + pad.x, box.position.y + pad.y + 15.0),
		TypeGrid.Rank.BODY,
		ink
	)


## 팝업 — 덮지 않는다. **더 두꺼운 괘선으로 둘러싸인 다른 단**이다.
##
## 반투명 판으로 뒤를 어둡게 덮는 것은 어느 웹앱에나 있다. 조판에서 「끼어든 단」은
## 굵은 괘선과 여백으로 표시하고, 그 규율을 그대로 쓴다.
func _draw_popup() -> void:
	var box := Rect2(
		_screen.position + Vector2(_screen.size.x * 0.50, 118.0), Vector2(430.0, 268.0)
	)
	draw_rect(box, PAPER)
	if _sheet != null:
		draw_texture_rect(_sheet, box, true, Color(1.0, 1.0, 1.0, 0.22))
	# 왼쪽만 굵은 괘선. 끼어든 단이라는 표시다.
	draw_line(box.position, Vector2(box.position.x, box.end.y), INK, TypeGrid.RULE_THICK)
	draw_line(
		Vector2(box.position.x, box.position.y),
		Vector2(box.end.x, box.position.y),
		INK,
		TypeGrid.RULE_HAIR
	)
	draw_line(
		Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.end.y), INK, TypeGrid.RULE_HAIR
	)

	var inner := box.position + Vector2(TypeGrid.GUTTER * 2.0, TypeGrid.GUTTER * 2.0)
	# 제목 띠는 반전이다 — 활판의 먹판이고 전자종이의 갱신이다.
	var bar := Rect2(inner, Vector2(box.size.x - TypeGrid.GUTTER * 3.0, 30.0))
	draw_rect(bar, INK)
	_text("귀환 여부", inner + Vector2(TypeGrid.GUTTER, 21.0), TypeGrid.Rank.HEAD, PAPER)

	var body := inner + Vector2(0.0, 52.0)
	var lines := [
		"이 방을 지나면 되돌아올 길이",
		"닫힌다. 스쿼드 넷 중 둘이",
		"부상 상태로 기록되어 있다.",
	]
	for i in range(lines.size()):
		_text(
			lines[i],
			Vector2(body.x, body.y + float(i) * TypeGrid.cell(TypeGrid.Rank.BODY).y),
			TypeGrid.Rank.BODY,
			INK
		)
	_button("들어간다", Vector2(body.x, body.y + 96.0), true)
	_button("물러난다", Vector2(body.x + 158.0, body.y + 96.0), false)


## 던전 지도 — **조판된 도표.**
##
## 지도를 그림으로 그리지 않는다. 방은 **활자 상자**이고 통로는 **괘선**이다.
## 옛 인쇄물의 도표가 그렇게 만들어졌고(활자와 괘선밖에 없었으니까), 문자 셀만 가진
## 화면도 그렇게 만든다. **여기서 클래식과 디지털이 같은 답을 낸다** — 억지가 아니다.
##
## 방 종류 표시는 §20.7 의 원자를 그대로 쓴다. 쐐기 = 보상, 빗금 = 위협.
func _draw_map() -> void:
	var at := _screen.position + MARGIN + Vector2(0.0, 250.0)
	_text("판", at, TypeGrid.Rank.HEAD, INK)
	_text("방 스물둘 • 도달 가능 셋", Vector2(at.x + 46.0, at.y - 2.0), TypeGrid.Rank.MICRO, MID)
	draw_line(
		Vector2(at.x, at.y + 12.0), Vector2(at.x + 396.0, at.y + 12.0), INK, TypeGrid.RULE_HAIR
	)

	# 방 여덟을 격자 위에 앉힌다. 자리도 셀의 정수배다.
	var cell := TypeGrid.cell(TypeGrid.Rank.BODY)
	var rooms := [
		[0, 0, "0", 0],  # 열, 행, 숫자, 종류 (0 빈방 1 귀중품 2 위험 3 보스 4 입구 5 탈출)
		[3, 0, "4", 1],
		[6, 0, "7", 2],
		[1, 2, "2", 4],
		[4, 2, "9", 0],
		[7, 2, "14", 3],
		[2, 4, "3", 0],
		[6, 4, "1", 5],
	]
	var origin := Vector2(at.x, at.y + 30.0)
	var step := Vector2(cell.x * 4.0, cell.y * 1.6)
	# 통로를 먼저 깐다. 괘선이 방 밑으로 지나가야 이어진 것으로 보인다.
	var links := [[0, 3], [0, 1], [1, 4], [1, 2], [2, 5], [3, 6], [4, 6], [5, 7], [4, 7]]
	for link in links:
		var a: Array = rooms[link[0]]
		var b: Array = rooms[link[1]]
		var from := origin + Vector2(float(a[0]) * step.x + 16.0, float(a[1]) * step.y + 9.0)
		var to := origin + Vector2(float(b[0]) * step.x + 16.0, float(b[1]) * step.y + 9.0)
		# 꺾인 괘선. 사선은 활자 조판에 없다 — 가로와 세로만 있다.
		draw_line(from, Vector2(from.x, to.y), MID, TypeGrid.RULE_HAIR)
		draw_line(Vector2(from.x, to.y), to, MID, TypeGrid.RULE_HAIR)

	for room in rooms:
		var box := Rect2(
			origin + Vector2(float(room[0]) * step.x, float(room[1]) * step.y),
			Vector2(cell.x * 2.6, 18.0)
		)
		_room(box, room[2] as String, room[3] as int)


## 방 한 칸. 종류는 §20.7 의 원자(쐐기 • 빗금 • 결손)로 말한다.
func _room(box: Rect2, number: String, kind: int) -> void:
	var here := kind == 4
	draw_rect(box, PAPER if not here else INK)
	# 입구와 탈출은 옆구리가 파여 실루엣이 바뀐다.
	if kind == 4 or kind == 5:
		var bite := Rect2(
			Vector2(box.position.x if kind == 4 else box.end.x - 4.0, box.position.y + 5.0),
			Vector2(4.0, 8.0)
		)
		draw_rect(bite, PAPER)
	draw_rect(box, INK, false, TypeGrid.RULE_HAIR)
	if kind == 1 or kind == 3:
		# 쐐기 — 보상이 있다.
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(box.end.x - 7.0, box.position.y),
					Vector2(box.end.x, box.position.y),
					Vector2(box.end.x, box.position.y + 7.0),
				]
			),
			INK
		)
	if kind == 2 or kind == 3:
		# 빗금 띠 — 위협이 있다.
		var y := box.end.y - 3.0
		var x := box.position.x + 1.0
		while x < box.end.x - 3.0:
			draw_line(Vector2(x, box.end.y - 1.0), Vector2(x + 3.0, y - 2.0), INK, 1.0)
			x += 4.0
	_text(
		number,
		Vector2(box.position.x + 4.0, box.position.y + 13.0),
		TypeGrid.Rank.MICRO,
		PAPER if here else INK
	)


## 중계 — **한 기기에 두 내용이 담긴다.**
##
## 렉카 피드와 던전 지도를 **같은 기기**로 정했다. 근거: 목숨 걸린 계측과 그것을
## 화젯거리로 삼는 중계가 **같은 화면에 나란히 있는 것**이 이 게임의 논지다
## ([`02`](../../../docs/design/02-overview.md) §2.6.1 — "비극이 아니라 구경거리").
## 기기를 둘로 나누면 그 아이러니가 사라지고 조형 언어도 둘 세워야 한다.
##
## 대신 **같은 조판 규율에 다른 내용이 담긴다.** 그리고 중계 한 줄만 격자를 깨뜨린다.
func _draw_feed() -> void:
	var at := _screen.position + Vector2(_screen.size.x * 0.50 + 22.0, 418.0)
	_text("중계", at, TypeGrid.Rank.HEAD, INK)
	_text("그놈들이 틀어 준다", Vector2(at.x + 46.0, at.y - 2.0), TypeGrid.Rank.MICRO, MID)
	draw_line(
		Vector2(at.x, at.y + 12.0), Vector2(at.x + 386.0, at.y + 12.0), INK, TypeGrid.RULE_HAIR
	)
	var rows := [["삼층 스물두 방", "교전"], ["사층 열한 방", "붕괴"]]
	for i in range(rows.size()):
		var y := at.y + 34.0 + float(i) * TypeGrid.cell(TypeGrid.Rank.BODY).y
		_text(rows[i][0], Vector2(at.x, y), TypeGrid.Rank.BODY, INK)
		_text(rows[i][1], Vector2(at.x + 258.0, y), TypeGrid.Rank.BODY, MID)
		draw_line(Vector2(at.x, y + 5.0), Vector2(at.x + 386.0, y + 5.0), MID, TypeGrid.RULE_HAIR)
	_draw_intrusion(Vector2(at.x - 8.0, at.y + 100.0))


## 그놈들의 중계 한 줄 — **격자를 지키지 않는 유일한 것.**
##
## 기울고 반전되고 괘선을 넘어간다. 격식 있는 그릇에 저질 내용이 끼어드는 것이
## 이 세계가 사람의 죽음을 다루는 방식이고, 그 어긋남이 화면의 사건이다.
func _draw_intrusion(at: Vector2) -> void:
	draw_set_transform(at, -0.028, Vector2.ONE)
	var line := "ㅋㅋㅋ 두 명 남았단다 여기서 접으면 개꿀잼인데"
	var box := Rect2(
		Vector2(-TypeGrid.GUTTER, -20.0),
		Vector2(TypeGrid.width_of(line, TypeGrid.Rank.BODY) + TypeGrid.GUTTER * 2.0, 30.0)
	)
	draw_rect(box, INK)
	draw_string(_font, Vector2(0.0, 2.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text("중계는 격자를 지키지 않는다", Vector2(at.x + 18.0, at.y + 34.0), TypeGrid.Rank.MICRO, MID)


## 유리 — 화면 위에 실제로 한 겹 있다. 지문과 금이 그 증거다.
func _draw_glass() -> void:
	# 지문은 **잘게 타일링**한다. 한 장을 화면 전체로 늘리면 거대한 지문 도장이 된다.
	if _smudge != null:
		draw_texture_rect(_smudge, _screen, true, Color(INK.r, INK.g, INK.b, 0.045))
	if _crack != null:
		# 금은 한 구석에서 시작해 화면을 가로지른다. 알파 텍스처라 검은 바탕이 안 찍힌다.
		var corner := Rect2(
			Vector2(_screen.end.x - 296.0, _screen.position.y - 44.0), Vector2(330.0, 286.0)
		)
		draw_texture_rect(_crack, corner, false, Color(INK.r, INK.g, INK.b, 0.40))
		# 금이 지나간 자리에 잉크가 조금 새어 든다 — 유리 아래 화면이 눌린 것이다.
		draw_texture_rect(_crack, corner.grow(-1.5), false, Color(1.0, 1.0, 1.0, 0.20))


## 활자를 셀에 하나씩 앉힌다. **글꼴 측정을 쓰지 않는다** — 폭이 미리 정해져 있다.
func _text(text: String, at: Vector2, rank: TypeGrid.Rank, color: Color) -> void:
	var cell := TypeGrid.cell(rank)
	var font_size := TypeGrid.font_size(rank)
	for i in range(text.length()):
		var glyph := text.substr(i, 1)
		var advance := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		# 셀 안에서 가운데 맞춤. 좁은 글자도 넓은 글자도 같은 칸을 차지한다.
		var offset := (cell.x - advance) * 0.5
		draw_string(
			_font,
			Vector2(at.x + float(i) * cell.x + offset, at.y),
			glyph,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			color
		)
