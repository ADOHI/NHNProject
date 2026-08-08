extends SceneTree
## 판을 SVG 로 그린다. **창을 띄우지 않는다.**
##
## 사용자는 숫자가 아니라 판을 보고 판단한다. 그런데 판을 보려면 지금까지는 게임을
## 띄워야 했고, gl_compatibility 라 캡처마다 GL 컨텍스트가 새로 생긴다.
## SVG 는 텍스트라 헤드리스에서 만들 수 있고 브라우저로 바로 본다.
##
## **한 그림에서 셋이 동시에 읽혀야 한다** — 고도 · 방의 가치 · 통로의 험함.
## 그래서 축을 셋으로 나눴다.
##
## | 보이는 것 | 뜻 |
## | --- | --- |
## | 원의 **밝기** | 고도 (어두울수록 낮다) |
## | 원의 **크기** | 방의 가치 (보스가 가장 크다) |
## | 테두리 **색** | 방 종류 |
## | 선의 **색·굵기** | 상승폭 (회색 0 · 주황 1~2 · 빨강 3+) |
##
## 지금 생성기와 설계안 프로토타입을 **같은 시드 · 같은 방 개수로** 나란히 그린다
## (docs/design/17-dungeon-generation.md §17.13).
##
##   godot --headless --path . -s res://tools/draw_dungeon_svg.gd -- .shots

const Metrics := preload("res://tools/dungeon_metrics.gd")
const Proto := preload("res://tools/proto_organic_dungeon.gd")

const _CELL := Vector2(660.0, 500.0)
const _MARGIN := 40.0
const _SEEDS: Array[int] = [11, 23, 47, 91]

## 사용자 요구 방 개수. 지금 슬라이더 최대(32 안팎) 밖이다.
const _ROOMS := 50

## 방 종류별 테두리 색과 반지름. 반지름이 곧 "이 방이 얼마나 값진가"다.
const _KIND_EDGE := {
	Room.Kind.ENTRANCE: "#5fe08a",
	Room.Kind.EXIT: "#5fb8ff",
	Room.Kind.BOSS: "#ff5a5a",
	Room.Kind.TREASURE: "#ffc83d",
	Room.Kind.HAZARD: "#c06bff",
	Room.Kind.EMPTY: "#6a6a78",
}
const _KIND_RADIUS := {
	Room.Kind.ENTRANCE: 11.0,
	Room.Kind.EXIT: 11.0,
	Room.Kind.BOSS: 16.0,
	Room.Kind.TREASURE: 13.0,
	Room.Kind.HAZARD: 9.0,
	Room.Kind.EMPTY: 7.0,
}


func _initialize() -> void:
	var target := "res://.shots"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		target = "res://%s" % arguments[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))

	var now := _sheet("지금 생성기", _current_boards())
	var proto := _sheet("설계안 프로토타입", _proto_boards())
	_write("%s/dungeon_now.svg" % target, now, "현재")
	_write("%s/dungeon_proto.svg" % target, proto, "설계안")
	_write(
		"%s/dungeon_compare.html" % target,
		(
			(
				'<!doctype html><meta charset="utf-8"><title>던전 생성 비교 (방 %d개)</title>'
				+ '<body style="margin:0;background:#0e0e12;color:#e8e8ee;font-family:sans-serif">'
				+ "%s%s</body>"
			)
			% [_ROOMS, now, proto]
		),
		"비교"
	)
	quit()


func _write(path: String, body: String, label: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("파일을 열 수 없습니다: %s" % path)
		return
	file.store_string(body)
	file.close()
	print("%s -> %s" % [label, ProjectSettings.globalize_path(path)])


# ---------------------------------------------------------------- 판 모으기


func _current_boards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seed_value in _SEEDS:
		var params := DungeonGenerator.Params.new()
		params.room_count = _ROOMS
		var board := Metrics.from_blueprint(DungeonGenerator.new(seed_value, params).generate())
		board["seed"] = seed_value
		result.append(board)
	return result


func _proto_boards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seed_value in _SEEDS:
		var board := Proto.build(seed_value, _ROOMS)
		if board.is_empty():
			continue
		board["seed"] = seed_value
		result.append(board)
	return result


# ---------------------------------------------------------------- 그리기


func _sheet(title: String, boards: Array[Dictionary]) -> String:
	var width := _CELL.x * float(boards.size())
	var height := _CELL.y + 96.0
	var parts: Array[String] = []
	parts.append(
		(
			(
				'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
				+ 'viewBox="0 0 %d %d" font-family="sans-serif">'
			)
			% [int(width), int(height), int(width), int(height)]
		)
	)
	parts.append('<rect width="100%" height="100%" fill="#14141a"/>')
	parts.append(
		(
			'<text x="18" y="34" fill="#e8e8ee" font-size="24">%s — 방 %d개 목표, 시드 %s</text>'
			% [title, _ROOMS, str(_SEEDS)]
		)
	)
	parts.append(_legend(18.0, 66.0))
	for slot in boards.size():
		parts.append(_board(boards[slot], Vector2(_CELL.x * float(slot), 96.0)))
	parts.append("</svg>")
	return "\n".join(parts)


func _legend(x: float, y: float) -> String:
	var parts: Array[String] = []
	var labels := {
		Room.Kind.ENTRANCE: "입구",
		Room.Kind.EXIT: "탈출",
		Room.Kind.BOSS: "보스",
		Room.Kind.TREASURE: "귀중품",
		Room.Kind.HAZARD: "위험",
		Room.Kind.EMPTY: "빈방",
	}
	var offset := x
	for kind in labels:
		parts.append(
			(
				'<circle cx="%.0f" cy="%.0f" r="%.0f" fill="#3a3a46" stroke="%s" stroke-width="3"/>'
				% [offset + 8.0, y, _KIND_RADIUS[kind], _KIND_EDGE[kind]]
			)
		)
		parts.append(
			(
				'<text x="%.0f" y="%.0f" fill="#b8b8c4" font-size="14">%s</text>'
				% [offset + 26.0, y + 5.0, labels[kind]]
			)
		)
		offset += 96.0
	parts.append(
		(
			(
				'<text x="%.0f" y="%.0f" fill="#b8b8c4" font-size="14">'
				+ "원 크기=가치 · 원 밝기=고도(어두울수록 낮다) · "
				+ "선 색=상승폭(회색 0 · 주황 1~2 · 빨강 3+)</text>"
			)
			% [offset + 10.0, y + 5.0]
		)
	)
	return "\n".join(parts)


func _board(board: Dictionary, origin: Vector2) -> String:
	var points: PackedVector2Array = board["points"]
	if points.is_empty():
		return ""
	var placed := _fit(points, origin)
	var elevations: PackedInt32Array = board["elevations"]
	var kinds: Dictionary = board["kinds"]
	var edges: Array[Vector2i] = board["edges"]
	var highest := 1
	for value in elevations:
		highest = maxi(highest, value)

	var parts: Array[String] = []
	parts.append(
		(
			'<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" stroke="#2a2a34"/>'
			% [origin.x + 6.0, origin.y + 6.0, _CELL.x - 12.0, _CELL.y - 12.0]
		)
	)
	(
		parts
		. append(
			(
				(
					'<text x="%.0f" y="%.0f" fill="#8a8a98" font-size="14">'
					+ "seed %d · 방 %d · 간선 %d · 고리 %d · 최고 고도 %d</text>"
				)
				% [
					origin.x + 16.0,
					origin.y + 28.0,
					int(board["seed"]),
					points.size(),
					edges.size(),
					edges.size() - points.size() + 1,
					highest,
				]
			)
		)
	)

	parts.append(_route(placed, board.get("slow", PackedInt32Array()), "#2fbf8f", 11.0))
	parts.append(_route(placed, board.get("fast", PackedInt32Array()), "#ff8a3d", 11.0))
	for edge in edges:
		parts.append(_edge(placed, elevations, edge))
	for index in points.size():
		parts.append(_node(placed, elevations, kinds, index, highest))
	return "\n".join(parts)


## 강조 경로. 프로토타입에서만 값이 들어온다 (빠른 길 · 돌아가는 길).
func _route(
	placed: PackedVector2Array, route: PackedInt32Array, color: String, width: float
) -> String:
	if route.size() < 2:
		return ""
	var steps: Array[String] = []
	for index in route.size():
		steps.append("%.1f,%.1f" % [placed[route[index]].x, placed[route[index]].y])
	return (
		(
			'<polyline points="%s" fill="none" stroke="%s" stroke-width="%.0f" stroke-opacity="0.35" '
			% ["  ".join(steps), color, width]
		)
		+ 'stroke-linecap="round" stroke-linejoin="round"/>'
	)


func _edge(placed: PackedVector2Array, elevations: PackedInt32Array, edge: Vector2i) -> String:
	var climb := absi(elevations[edge.x] - elevations[edge.y])
	var color := "#4e4e5a"
	var width := 1.4
	if climb >= 3:
		color = "#d84a4a"
		width = 3.2
	elif climb >= 1:
		color = "#cf9130"
		width = 2.0
	return (
		'<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f"/>'
		% [placed[edge.x].x, placed[edge.x].y, placed[edge.y].x, placed[edge.y].y, color, width]
	)


func _node(
	placed: PackedVector2Array,
	elevations: PackedInt32Array,
	kinds: Dictionary,
	index: int,
	highest: int
) -> String:
	var kind: Room.Kind = kinds.get(index, Room.Kind.EMPTY)
	var radius: float = _KIND_RADIUS[kind]
	var body := (
		'<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="3"/>'
		% [
			placed[index].x,
			placed[index].y,
			radius,
			_height_color(elevations[index], highest),
			_KIND_EDGE[kind],
		]
	)
	if radius < 10.0:
		return body
	return (
		body
		+ (
			(
				'<text x="%.1f" y="%.1f" fill="#0e0e12" font-size="11" font-weight="bold" '
				% [placed[index].x, placed[index].y + 4.0]
			)
			+ 'text-anchor="middle">%d</text>' % elevations[index]
		)
	)


## 고도를 밝기로. 낮으면 어둡고 높으면 밝다. 판을 축소해도 지형이 읽힌다.
func _height_color(elevation: int, highest: int) -> String:
	var ratio := clampf(float(elevation) / maxf(float(highest), 1.0), 0.0, 1.0)
	var tone := Color(0.13, 0.15, 0.22).lerp(Color(0.98, 0.94, 0.72), ratio)
	return "#%s" % tone.to_html(false)


func _fit(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var lowest := points[0]
	var highest := points[0]
	for point in points:
		lowest = lowest.min(point)
		highest = highest.max(point)
	var span := highest - lowest
	var usable := _CELL - Vector2(_MARGIN, _MARGIN) * 2.0
	var scale := minf(usable.x / maxf(span.x, 0.001), usable.y / maxf(span.y, 0.001))

	var result := PackedVector2Array()
	for point in points:
		result.append(origin + Vector2(_MARGIN, _MARGIN + 22.0) + (point - lowest) * scale)
	return result
