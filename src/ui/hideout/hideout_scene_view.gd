class_name HideoutSceneView
extends Node2D
## 건물과 배회하는 대원을 **한 자로 정렬해** 그린다. 매 프레임 다시 그려진다.
##
## ## 그림은 없다. 도형으로 세운다
##
## 인물 그림은 캐릭터 레인이 뽑고 있고, 오면 이 파일이 스프라이트로 갈린다.
## 지금 재려는 것은 **크기**다 — 대원이 화면에서 얼마만 해야 읽히고 집히는가
## (docs/design/30-hideout.md §30.12).
##
## ## 그리는 차례가 건물과 섞여야 한다
##
## 건물 뒤로 걸어 들어가면 가려야 하고 앞으로 나오면 보여야 한다.
## 그래서 사람과 건물을 **한 노드에서 같은 자로 정렬해 그린다** — 노드를 나누면
## 사람이 항상 건물 위이거나 항상 아래가 된다. 이 파일이 그 합침을 맡는다.

## 대원 키(px). **잠정이다** — 이 값을 재려고 세운 것이다.
##
## 유도: 칸 한 변을 2 m 로 보면 사람 1.7 m 는 0.85 칸이고,
## 칸 한 변 높이가 64 px(`IsoProjection.CELL_HEIGHT_PX`)이므로 **54 px** 이 된다.
## 그림에서 나온 값이 아니라 격자에서 나온 값이다.
const PERSON_HEIGHT := 54.0

## 몸 굵기(px). 키의 3할이면 사람으로 읽히고 그보다 굵으면 통으로 보인다.
const PERSON_WIDTH := 17.0

## 발밑 그림자의 가로 반지름(px). 접지가 없으면 사람이 떠 보인다.
const SHADOW_RADIUS := 11.0

var _iso: IsoProjection
var _grid: HideoutGrid
var _crowd: HideoutCrowd

## 지금 집어 든 대원. ⑤ 가 쓸 자리이고 지금은 강조만 한다.
var _highlight := -1


func bind(iso: IsoProjection, grid: HideoutGrid, crowd: HideoutCrowd) -> void:
	_iso = iso
	_grid = grid
	_crowd = crowd
	queue_redraw()


func highlight(index: int) -> void:
	if _highlight == index:
		return
	_highlight = index
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


## 건물과 사람을 한 줄로 세워 뒤에서 앞으로 그린다.
func _draw() -> void:
	if _iso == null or _grid == null or _crowd == null:
		return
	var drawables: Array[Dictionary] = []
	for building in _grid.buildings():
		drawables.append({"depth": float(building.depth()), "building": building})
	for index in _crowd.count():
		var person := _crowd.person(index)
		var at: Vector2 = person["at"]
		drawables.append({"depth": at.x + at.y, "person": index})
	drawables.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] < b["depth"]
	)

	for item in drawables:
		if item.has("building"):
			HideoutBuildingPainter.paint(self, _iso, item["building"])
		else:
			_draw_person(item["person"])


func _draw_person(index: int) -> void:
	var person := _crowd.person(index)
	var foot := _iso.plane_to_world(person["at"])
	var lit := index == _highlight

	# 접지 그림자. 인물 그림의 그림자가 납작한 칼날이었다(§30.2.1) — 여기서도 납작하게.
	draw_set_transform(foot, 0.0, Vector2(1.0, 1.0 / 3.0))
	draw_circle(Vector2.ZERO, SHADOW_RADIUS, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var body := HideoutPalette.PERSON_LIT if lit else HideoutPalette.PERSON
	var half := PERSON_WIDTH * 0.5
	var head := PERSON_HEIGHT * 0.30
	draw_rect(
		Rect2(foot.x - half, foot.y - PERSON_HEIGHT + head, PERSON_WIDTH, PERSON_HEIGHT - head),
		body
	)
	draw_circle(Vector2(foot.x, foot.y - PERSON_HEIGHT + head * 0.5), head * 0.62, body)
	if lit:
		draw_arc(foot, SHADOW_RADIUS + 4.0, 0.0, TAU, 20, HideoutPalette.HOVER_LINE, 2.0)
