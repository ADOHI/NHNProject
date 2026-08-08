extends SceneTree
## 판을 SVG 로 그린다. **창을 띄우지 않는다.**
##
## 사용자는 숫자가 아니라 판을 보고 판단한다. 그런데 판을 보려면 게임을 띄워야 했고,
## `gl_compatibility` 라 캡처마다 GL 컨텍스트가 새로 생긴다.
## SVG 는 텍스트라 헤드리스에서 만들 수 있고 브라우저로 바로 본다.
##
## ## 밝기와 색으로는 검산이 안 된다
##
## 처음에는 고도를 원의 밝기로, 상승폭을 선의 색으로만 칠했다. 그러면 "대충 저쪽이 높다"
## 까지만 읽히고 **두 경로를 따라가며 더해 보는 것이 불가능하다.**
## 「급경사 지름길 / 완경사 우회」가 이 설계안의 핵심 약속인데, 그림이 그것을 증명하지
## 못하면 보는 사람은 측정값을 믿는 수밖에 없다. 그래서 숫자를 얹었다.
##
## | 보이는 것 | 뜻 |
## | --- | --- |
## | 원 **안의 숫자** | 그 방의 고도 |
## | 원의 **크기** | 방의 가치 (보스가 가장 크다) |
## | 원의 **밝기** | 고도 (숫자를 읽지 않고 지형을 훑을 때) |
## | 테두리 **색** | 방 종류 |
## | 간선의 **화살표와 숫자** | 올라가는 방향과 상승폭. **평지는 화살표를 그리지 않는다** |
## | 굵은 주황 / 초록 띠 | 빠른 길 / 돌아가는 길 |
##
## 평지에 화살표를 그리면 무엇이 오르막인지 흐려진다. 대신 판마다 머리글에
## **평지가 몇 %인지 적는다.**
##
##   godot --headless --path . -s res://tools/draw_dungeon_svg.gd -- .shots

const Metrics := preload("res://tools/dungeon_metrics.gd")
const Proto := preload("res://tools/proto_organic_dungeon.gd")

## 한 칸의 크기와 한 줄에 놓을 칸 수.
##
## 방 50개면 이웃한 방이 화면에서 80px 쯤 떨어진다. 간선 위에 숫자를 얹으려면
## 그 정도는 있어야 한다. 4개를 한 줄로 놓으면 칸이 좁아져 숫자가 뭉친다.
const _CELL := Vector2(880.0, 660.0)
const _COLUMNS := 2
const _MARGIN := 44.0

const _SEEDS: Array[int] = [11, 23, 47, 91]

## 던전 성격 후보. [이름, 방 개수, 흔드는 축]
##
## **한 던전에서 흔드는 축은 둘까지다.** 셋 이상 흔들면 어느 것이 그 던전의 성격인지
## 읽히지 않는다 — 봉우리를 판에 하나만 두는 것과 같은 이유다
## (docs/design/07-level-design.md §7.3, docs/design/17-dungeon-generation.md §17.16).
const _CHARACTERS := [
	["얕은 갱도", 14, {"extra_edge_ratio": 0.10, "elevation_gain": 0.35}],
	["벌집", 34, {"extra_edge_ratio": 0.46}],
	["수직 회랑", 24, {"elevation_gain": 1.60}],
	["먼 출구", 40, {"exit_distance_ratio": 0.95}],
	["금고층", 28, {"treasure_ratio": 0.05, "hazard_ratio": 0.36}],
]

## 사용자 요구 방 개수. 지금 슬라이더 최대(32 안팎) 밖이다.
const _ROOMS := 50

const _KIND_EDGE := {
	Room.Kind.ENTRANCE: "#5fe08a",
	Room.Kind.EXIT: "#5fb8ff",
	Room.Kind.BOSS: "#ff5a5a",
	Room.Kind.TREASURE: "#ffc83d",
	Room.Kind.HAZARD: "#c06bff",
	Room.Kind.EMPTY: "#6a6a78",
}

## 방의 가치. 크기로 읽힌다. 가장 작은 것도 두 자리 숫자가 들어갈 만큼은 된다.
const _KIND_RADIUS := {
	Room.Kind.ENTRANCE: 13.0,
	Room.Kind.EXIT: 13.0,
	Room.Kind.BOSS: 19.0,
	Room.Kind.TREASURE: 15.0,
	Room.Kind.HAZARD: 11.0,
	Room.Kind.EMPTY: 10.0,
}


func _initialize() -> void:
	var target := "res://.shots"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		target = "res://%s" % arguments[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))

	var characters := _sheet("던전 성격 후보 — 같은 시드 %d, 파라미터만 다르다" % _SEEDS[0], _character_boards())
	_write("%s/dungeon_characters.svg" % target, characters, "성격")
	_write(
		"%s/dungeon_characters.html" % target,
		(
			(
				'<!doctype html><meta charset="utf-8"><title>던전 성격 후보</title>'
				+ '<body style="margin:0;background:#0e0e12;color:#e8e8ee;font-family:sans-serif">'
				+ "%s</body>"
			)
			% characters
		),
		"성격 묶음"
	)

	var now := _sheet("지금 생성기 — 구역·관문까지 적용 (덩어리 2/5)", _current_boards())
	var proto := _sheet("설계안 프로토타입 — 고도·경로 시공까지 (덩어리 3~4 가 남았다)", _proto_boards())
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


## 지금 생성기의 판. **두 경로를 같은 정의로 계산해 함께 넘긴다.**
##
## 프로토타입에만 경로를 그리면 비교가 되지 않는다. 지금 생성기에도 같은 방법으로
## 빠른 길과 돌아가는 길을 찾아 그린다 — 대개 **돌아가는 길이 나오지 않는데,
## 그 사실 자체가 이 그림이 보여 줄 것이다.**
func _current_boards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seed_value in _SEEDS:
		var params := DungeonGenerator.Params.new()
		params.room_count = _ROOMS
		var board := Metrics.from_blueprint(DungeonGenerator.new(seed_value, params).generate())
		board["seed"] = seed_value
		_attach_routes(board)
		result.append(board)
	return result


## 던전마다 파라미터를 달리 준 판들. **시드는 전부 같다.**
##
## 시드를 같이 두는 것이 요점이다. 판이 달라 보이는 이유가 운이 아니라
## **파라미터**라는 것을 한눈에 보이게 한다.
func _character_boards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _CHARACTERS:
		var params := DungeonGenerator.Params.new()
		params.room_count = int(entry[1])
		for field in entry[2] as Dictionary:
			params.set(String(field), float((entry[2] as Dictionary)[field]))
		var board := Metrics.from_blueprint(DungeonGenerator.new(_SEEDS[0], params).generate())
		board["seed"] = _SEEDS[0]
		board["label"] = String(entry[0])
		_attach_routes(board)
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


## 보스 방까지의 최단 경로와, 그 간선을 뺀 뒤의 두 번째 경로.
func _attach_routes(board: Dictionary) -> void:
	var count: int = (board["points"] as PackedVector2Array).size()
	var edges: Array[Vector2i] = board["edges"]
	var kinds: Dictionary = board["kinds"]
	var target := -1
	for index in count:
		if kinds.get(index, Room.Kind.EMPTY) == Room.Kind.BOSS:
			target = index
			break
	if target < 0:
		return

	var fast := Metrics.path(count, edges, int(board["entrance"]), target)
	var reduced: Array[Vector2i] = []
	for edge in edges:
		if not Metrics.on_path(fast, edge):
			reduced.append(edge)
	board["fast"] = fast
	board["slow"] = Metrics.path(count, reduced, int(board["entrance"]), target)


# ---------------------------------------------------------------- 그리기


func _sheet(title: String, boards: Array[Dictionary]) -> String:
	var rows := int(ceil(float(boards.size()) / float(_COLUMNS)))
	var width := _CELL.x * float(_COLUMNS)
	var height := _CELL.y * float(rows) + 108.0
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
			'<text x="20" y="36" fill="#e8e8ee" font-size="25">%s — 방 %d개 목표, 시드 %s</text>'
			% [title, _ROOMS, str(_SEEDS)]
		)
	)
	parts.append(_legend(20.0, 70.0))
	for slot in boards.size():
		var origin := Vector2(
			_CELL.x * float(slot % _COLUMNS), 108.0 + _CELL.y * float(slot / _COLUMNS)
		)
		parts.append(_board(boards[slot], origin))
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
				% [offset + 10.0, y, _KIND_RADIUS[kind], _KIND_EDGE[kind]]
			)
		)
		parts.append(
			(
				'<text x="%.0f" y="%.0f" fill="#b8b8c4" font-size="14">%s</text>'
				% [offset + 30.0, y + 5.0, labels[kind]]
			)
		)
		offset += 96.0
	parts.append(
		(
			(
				'<text x="%.0f" y="%.0f" fill="#b8b8c4" font-size="14">'
				+ "원 안 숫자=고도 · 원 크기=가치 · "
				+ "간선 화살표=올라가는 방향, 숫자=상승폭 (평지는 표시 없음)</text>"
			)
			% [offset + 10.0, y - 4.0]
		)
	)
	parts.append(
		(
			(
				'<text x="%.0f" y="%.0f" fill="#b8b8c4" font-size="14">'
				+ "굵은 주황 띠=빠른 길 · 굵은 초록 띠=돌아가는 길 (보스 방까지)</text>"
			)
			% [offset + 10.0, y + 15.0]
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

	var parts: Array[String] = []
	parts.append(
		(
			'<rect x="%.0f" y="%.0f" width="%.0f" height="%.0f" fill="none" stroke="#2a2a34"/>'
			% [origin.x + 6.0, origin.y + 6.0, _CELL.x - 12.0, _CELL.y - 12.0]
		)
	)
	if board.has("label"):
		parts.append(
			(
				'<text x="%.0f" y="%.0f" fill="#e8e8ee" font-size="20" font-weight="bold">%s</text>'
				% [origin.x + 18.0, origin.y + 26.0, board["label"]]
			)
		)
		parts.append(_caption(board, origin + Vector2(0.0, 18.0)))
	else:
		parts.append(_caption(board, origin))

	parts.append(_route(placed, board.get("slow", PackedInt32Array()), "#2fbf8f", 13.0))
	parts.append(_route(placed, board.get("fast", PackedInt32Array()), "#ff8a3d", 13.0))
	for edge in edges:
		parts.append(_edge(placed, elevations, edge))
	for edge in edges:
		parts.append(_climb_mark(placed, elevations, edge))
	for index in points.size():
		parts.append(_node(placed, elevations, kinds, index, _highest(elevations)))
	return "\n".join(parts)


## 판마다의 머리글. **평지 비율과 두 경로의 최대 상승폭을 여기에 적는다.**
##
## 평지 간선에는 화살표를 그리지 않으므로, 그리지 않은 것이 몇 개인지는 글로 알려 줘야 한다.
func _caption(board: Dictionary, origin: Vector2) -> String:
	var points: PackedVector2Array = board["points"]
	var edges: Array[Vector2i] = board["edges"]
	var elevations: PackedInt32Array = board["elevations"]
	var flat := 0
	for edge in edges:
		if elevations[edge.x] == elevations[edge.y]:
			flat += 1

	var fast: PackedInt32Array = board.get("fast", PackedInt32Array())
	var slow: PackedInt32Array = board.get("slow", PackedInt32Array())
	var fast_text := "없음"
	if fast.size() >= 2:
		fast_text = "%d칸, 최대 상승 %d" % [fast.size() - 1, _peak_climb(fast, elevations)]
	var slow_text := "**없음**"
	if slow.size() >= 2:
		slow_text = "%d칸, 최대 상승 %d" % [slow.size() - 1, _peak_climb(slow, elevations)]

	return (
		(
			'<text x="%.0f" y="%.0f" fill="#8a8a98" font-size="14">'
			% [origin.x + 18.0, origin.y + 30.0]
		)
		+ (
			"%sseed %d · 방 %d · 간선 %d · 고리 %d · 평지 %d%% · 최고 고도 %d</text>"
			% [
				("%s — " % board["label"]) if board.has("label") else "",
				int(board["seed"]),
				points.size(),
				edges.size(),
				edges.size() - points.size() + 1,
				int(round(100.0 * float(flat) / maxf(float(edges.size()), 1.0))),
				_highest(elevations),
			]
		)
		+ (
			(
				'<text x="%.0f" y="%.0f" fill="#c8c8d4" font-size="14">'
				% [origin.x + 18.0, origin.y + 50.0]
			)
			+ '<tspan fill="#ff8a3d">빠른 길</tspan> %s   ' % fast_text.replace("**", "")
			+ '<tspan fill="#2fbf8f">돌아가는 길</tspan> %s</text>' % slow_text.replace("**", "")
		)
	)


func _peak_climb(route: PackedInt32Array, elevations: PackedInt32Array) -> int:
	var climb := 0
	for index in range(1, route.size()):
		climb = maxi(climb, maxi(0, elevations[route[index]] - elevations[route[index - 1]]))
	return climb


func _highest(elevations: PackedInt32Array) -> int:
	var highest := 0
	for value in elevations:
		highest = maxi(highest, value)
	return highest


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
			'<polyline points="%s" fill="none" stroke="%s" stroke-width="%.0f" stroke-opacity="0.30" '
			% ["  ".join(steps), color, width]
		)
		+ 'stroke-linecap="round" stroke-linejoin="round"/>'
	)


func _edge(placed: PackedVector2Array, elevations: PackedInt32Array, edge: Vector2i) -> String:
	var climb := absi(elevations[edge.x] - elevations[edge.y])
	var color := "#4e4e5a"
	var width := 1.3
	if climb >= 3:
		color = "#d84a4a"
		width = 2.6
	elif climb >= 1:
		color = "#cf9130"
		width = 1.9
	return (
		'<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f"/>'
		% [placed[edge.x].x, placed[edge.x].y, placed[edge.y].x, placed[edge.y].y, color, width]
	)


## 오르막 표시 — **낮은 쪽에서 높은 쪽을 가리키는 화살촉과 상승폭 숫자.**
##
## 평지는 그리지 않는다. 전부 그리면 무엇이 오르막인지가 오히려 흐려진다.
func _climb_mark(
	placed: PackedVector2Array, elevations: PackedInt32Array, edge: Vector2i
) -> String:
	var climb := absi(elevations[edge.x] - elevations[edge.y])
	if climb == 0:
		return ""
	var low := edge.x if elevations[edge.x] < elevations[edge.y] else edge.y
	var high := edge.y if low == edge.x else edge.x
	var from_point := placed[low]
	var to_point := placed[high]
	var direction := (to_point - from_point).normalized()
	# 방 위젯을 피해 간선의 가운데쯤에 놓는다.
	var tip := from_point.lerp(to_point, 0.62)
	var side := direction.orthogonal()
	var color := "#e86a6a" if climb >= 3 else "#d8a24a"

	var wing_a := tip - direction * 9.0 + side * 4.5
	var wing_b := tip - direction * 9.0 - side * 4.5
	var label := tip + side * 10.0 - direction * 2.0
	return (
		(
			'<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="%s"/>'
			% [tip.x, tip.y, wing_a.x, wing_a.y, wing_b.x, wing_b.y, color]
		)
		+ (
			'<text x="%.1f" y="%.1f" fill="%s" font-size="12" font-weight="bold" '
			% [label.x, label.y + 4.0, color]
		)
		+ (
			'text-anchor="middle" stroke="#14141a" stroke-width="2.5" paint-order="stroke">%d</text>'
			% climb
		)
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
	var ratio := clampf(float(elevations[index]) / maxf(float(highest), 1.0), 0.0, 1.0)
	# 밝은 바탕에는 검은 글자, 어두운 바탕에는 흰 글자. 숫자가 늘 읽혀야 한다.
	var text_color := "#0e0e12" if ratio > 0.45 else "#f0f0f4"
	return (
		(
			'<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="3"/>'
			% [
				placed[index].x,
				placed[index].y,
				radius,
				_height_color(ratio),
				_KIND_EDGE[kind],
			]
		)
		+ (
			'<text x="%.1f" y="%.1f" fill="%s" font-size="13" font-weight="bold" '
			% [placed[index].x, placed[index].y + 4.5, text_color]
		)
		+ 'text-anchor="middle">%d</text>' % elevations[index]
	)


## 고도를 밝기로. 숫자를 읽지 않고 지형만 훑을 때 쓴다.
func _height_color(ratio: float) -> String:
	var tone := Color(0.13, 0.15, 0.22).lerp(Color(0.98, 0.94, 0.72), ratio)
	return "#%s" % tone.to_html(false)


func _fit(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var lowest := points[0]
	var highest := points[0]
	for point in points:
		lowest = lowest.min(point)
		highest = highest.max(point)
	var span := highest - lowest
	var usable := _CELL - Vector2(_MARGIN, _MARGIN) * 2.0 - Vector2(0.0, 44.0)
	var scale := minf(usable.x / maxf(span.x, 0.001), usable.y / maxf(span.y, 0.001))

	var result := PackedVector2Array()
	for point in points:
		result.append(origin + Vector2(_MARGIN, _MARGIN + 46.0) + (point - lowest) * scale)
	return result
