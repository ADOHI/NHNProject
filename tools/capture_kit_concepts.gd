extends SceneTree
## 공통 시각 언어 후보 여섯을 **한 장씩, 그리고 여섯을 붙여 한 장** 뽑는다.
##
##     godot --path . -s res://tools/capture_kit_concepts.gd -- .renders/41-kit
##
## docs/design/20-ui-kit.md §20.26.
##
## ## 왜 붙인 장이 따로 필요한가
##
## **안은 나란히 놓여야 골라진다.** 한 장씩만 있으면 사용자가 창을 여섯 번 열어
## 기억으로 비교하게 되고, 그러면 **마지막에 본 것이 이긴다.**
##
## ## 창을 한 번만 띄운다
##
## `gl_compatibility` 라 캡처마다 GL 컨텍스트를 새로 만들고 그 반복이 드라이버를
## 흔든 전례가 있다 (CLAUDE.md — GPU 를 나눠 쓴다). 그래서 한 번 띄워 일곱 장을 다 뽑는다.

## 붙인 장의 칸 배치.
const COLUMNS := 3
const ROWS := 2

## 안 사이의 틈. 0 이면 어디까지가 한 안인지 안 보인다.
const SEAM := 8.0

var _out := "res://.renders/41-kit"
var _stage: SubViewport
var _sheet: KitConceptSheet
var _board: SubViewport
var _waited := 0
var _shot := 0
var _armed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = "res://%s" % args[0]

	_stage = SubViewport.new()
	_stage.size = Vector2i(KitConceptSheet.CARD)
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_stage)
	_sheet = KitConceptSheet.new()
	_stage.add_child(_sheet)
	_sheet.size = KitConceptSheet.CARD

	_board = SubViewport.new()
	_board.size = Vector2i(
		int(KitConceptSheet.CARD.x * float(COLUMNS) + SEAM * float(COLUMNS + 1)),
		int(KitConceptSheet.CARD.y * float(ROWS) + SEAM * float(ROWS + 1))
	)
	_board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_board)
	var mat := ColorRect.new()
	mat.color = Color("#101014")
	mat.size = Vector2(_board.size)
	_board.add_child(mat)
	for kind in KitConcept.count():
		var one := KitConceptSheet.new()
		one.kind = kind as KitConcept.Kind
		_board.add_child(one)
		one.size = KitConceptSheet.CARD
		one.position = Vector2(
			SEAM + float(kind % COLUMNS) * (KitConceptSheet.CARD.x + SEAM),
			SEAM + float(kind / COLUMNS) * (KitConceptSheet.CARD.y + SEAM)
		)


func _process(_delta: float) -> bool:
	_waited += 1
	if _waited < 6:
		return false

	if _shot >= KitConcept.count():
		_board.get_texture().get_image().save_png("%s-all.png" % _out)
		print("붙인 장: %s-all.png" % _out)
		return true

	# 한 프레임에 갈아 끼우고 그다음 프레임에 찍는다 — `queue_redraw()` 한 프레임에
	# 찍으면 직전 안이 나온다 (capture_npc_sheet 의 함정 2 와 같다).
	if _armed:
		var kind := _shot as KitConcept.Kind
		var path := "%s-%s.png" % [_out, KitConcept.slug(kind)]
		_stage.get_texture().get_image().save_png(path)
		print("saved %s  (%s)" % [path, KitConcept.name_of(kind)])
		_shot += 1
		_armed = false
		return false
	_sheet.kind = _shot as KitConcept.Kind
	_sheet.queue_redraw()
	_armed = true
	return false
