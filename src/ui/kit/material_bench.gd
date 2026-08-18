class_name MaterialBench
extends Control
## **창이 무엇으로 되어 있나 — 재료 다섯 × 세기 셋.**
##
##     godot --path . res://src/ui/kit/material_bench.tscn
##
## 지금까지 창은 **평평한 도형에 선**이었다. 그게 심플하게 읽히는 이유다.
## 재료를 갈아 끼워 보고 고른다. **하나로 좁히지 않는다.**
##
## | 재료 | 무엇 | 이 킷과의 거리 |
## | --- | --- | --- |
## | 유리 | 가장자리에서 빛이 모인다 | 가깝다 |
## | 빛 | 안에서 나오고 가장자리로 스민다 | 멀다 |
## | 금속 | 결과 비스듬한 반사 띠 | 중간 |
## | 장 | 무늬가 흐르고 경계가 떨린다 | 가장 멀다 |
## | 판화 | 결과 잉크 번짐 | **계보 그대로** |
##
## **뒤에 인물을 세워 둔다.** 재료가 뒤를 얼마나 먹는지는 뒤에 뭐가 있어야 보인다.

const FONT := preload("res://assets/fonts/song_myung/SongMyung-Regular.ttf")

const DESK := Color("#aab5c2")
const SHEET := Color("#dee2e8")
const RULE := Color("#6f8098")
const INK := Color("#212a37")
const DIM := Color("#6d7681")
const ACCENT := Color("#c0705f")
const COOL := Color("#5c86a8")

const PANE := Vector2(300.0, 200.0)
const GAP := Vector2(34.0, 62.0)
const LEFT: float = 132.0
const TOP: float = 176.0

const SEED: int = 20260809
const POPULATION: int = 240
const LOOP: float = 4.80

## 모따기. **깎인 모서리는 도형이 만든다** — 셰이더는 가장자리를 모른다.
const CUT: float = 20.0

var _panes: Array[HoloPane] = []
var _ink := SheetPainter.new()
var _figure: Texture2D = null
var _clock := 0.0
var _driven := false


func _ready() -> void:
	_build()
	if not _driven:
		set_process(true)


func drive_externally() -> void:
	_driven = true
	set_process(false)


func _build() -> void:
	var path := "res://assets/ui/kit/cast/figure_3.webp"
	if ResourceLoader.exists(path):
		_figure = load(path)
	var registry := PersonGenerator.new(SEED, POPULATION).generate()
	_ink.sections = PersonSheet.build(registry, 3, FactionIndex.new(registry))
	_ink.paged = true
	_ink.columns = 1

	for row in HoloPane.count():
		for step in HoloPane.STEPS.size():
			var pane := HoloPane.new()
			pane.shape = _silhouette()
			add_child(pane)
			pane.position = _spot(row, step)
			pane.size = PANE
			pane.set_stuff(row as HoloPane.Stuff, HoloPane.STEPS[step])
			_panes.append(pane)


func _spot(row: int, step: int) -> Vector2:
	return Vector2(LEFT + float(step) * (PANE.x + GAP.x), TOP + float(row) * (PANE.y + GAP.y))


## 창의 실루엣. 왼쪽 위와 오른쪽 아래를 깎는다 — 선이 들어오는 자리를 비켜 준다.
func _silhouette() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(CUT, 0.0),
			Vector2(PANE.x, 0.0),
			Vector2(PANE.x, PANE.y - CUT),
			Vector2(PANE.x - CUT, PANE.y),
			Vector2(0.0, PANE.y),
			Vector2(0.0, CUT),
		]
	)


func _process(delta: float) -> void:
	if _driven:
		return
	set_clock(fposmod(_clock + delta, LOOP))


func set_clock(t: float) -> void:
	_clock = t
	for pane in _panes:
		pane.set_clock(t)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHEET)
	draw_rect(Rect2(LEFT - 60.0, TOP - 34.0, size.x - LEFT, size.y - TOP), Color(DESK, 0.9))
	_label("창이 무엇으로 되어 있나 — 재료 다섯, 세기 셋", Vector2(40.0, 52.0), 24, INK)
	_label("실루엣은 꼭짓점이 만들고 안쪽만 셰이더가 칠한다. 프래그먼트는 가장자리까지의 거리를 모른다.", Vector2(40.0, 82.0), 15, DIM)
	_label("뒤에 인물을 세워 둔다 — 재료가 뒤를 얼마나 먹는지는 뒤에 뭐가 있어야 보인다.", Vector2(40.0, 106.0), 14, DIM)

	for step in HoloPane.STEPS.size():
		_label(
			"%s (%.2f)" % [HoloPane.STEP_NAMES[step], HoloPane.STEPS[step]],
			Vector2(LEFT + float(step) * (PANE.x + GAP.x), TOP - 14.0),
			17,
			INK
		)

	# 창 뒤에 인물. 자식 노드가 나중에 그려지므로 여기서 그리면 저절로 뒤가 된다.
	for row in HoloPane.count():
		var at := _spot(row, 0)
		if _figure != null:
			draw_texture_rect(
				_figure,
				Rect2(at + Vector2(PANE.x * 0.62, -18.0), Vector2(148.0, 216.0)),
				false,
				Color(1, 1, 1, 0.85)
			)
		_label(HoloPane.label(row as HoloPane.Stuff), at - Vector2(96.0, -28.0), 20, INK)
		draw_rect(Rect2(at.x - 96.0, at.y + 36.0, 26.0, 2.0), ACCENT)


func _label(what: String, at: Vector2, size_px: int, color: Color) -> void:
	draw_string(FONT, at, what, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
