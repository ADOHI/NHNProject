extends SceneTree
## 화면이 방 N 개짜리 판을 감당하는가를 **숫자로** 확인한다.
##
## 창을 띄우지 않고 답할 수 있는 것이 대부분이다 — 지도의 크기, 화면에 담기는 배율,
## 방 위젯끼리의 간격은 전부 배치 계산의 결과이지 그림이 아니다.
## `gl_compatibility` 라 창을 띄울 때마다 GL 컨텍스트가 새로 생기므로 아낀다
## (docs/design/17-dungeon-generation.md §17.15).
##
##   godot --headless --path . -s res://tools/check_board_capacity.gd

const BoardScene := preload("res://src/ui/dungeon_board/dungeon_board.tscn")

const _COUNTS: Array[int] = [12, 22, 32, 50, 64]
const _SEEDS: Array[int] = [11, 23, 47, 91, 137]

## project.godot 의 기준 해상도. 웹 빌드도 이 비율로 늘어난다.
const _VIEW := Vector2(1280.0, 720.0)

## dungeon_board.gd 의 상수들. 여기서 다시 적는 이유는 private 이라 읽을 수 없어서다.
## **바뀌면 이 도구도 같이 고쳐야 한다.**
const _SPACING := 280.0
const _ZOOM_MIN := 0.4
const _DETAIL_NAME_ZOOM := 0.62
const _DETAIL_FULL_ZOOM := 0.92

## room_node.tscn 의 custom_minimum_size.
const _NODE_SIZE := Vector2(146.0, 76.0)


func _initialize() -> void:
	print("== 화면이 담는가 (판마다 시드 %d개) ==" % _SEEDS.size())
	print(
		(
			"기준 화면 %dx%d · 간격 %d · 방 위젯 %dx%d · 확대 하한 %.2f"
			% [
				int(_VIEW.x),
				int(_VIEW.y),
				int(_SPACING),
				int(_NODE_SIZE.x),
				int(_NODE_SIZE.y),
				_ZOOM_MIN
			]
		)
	)
	print("")
	print(
		(
			"%-6s %6s %11s %11s %8s %8s %8s %7s"
			% ["want", "rooms", "map_w", "map_h", "fitZoom", "seen%", "minGap", "name?"]
		)
	)
	for wanted in _COUNTS:
		_check(wanted)
	print("")
	print("map_w/h  : 지도 전체 크기 (배율 1 의 픽셀)")
	print("fitZoom  : 판 전체가 화면에 들어오려면 필요한 배율")
	print("seen%%    : 확대 하한에서 보이는 판의 넓이 비율 (100 이면 다 보인다)")
	print("minGap   : 배율 1 에서 가장 가까운 두 방의 위젯 사이 간격 (픽셀, 음수면 겹친다)")
	print("name?    : 판 전체를 보는 배율에서 방 이름이 보이는가")
	quit()


func _check(wanted: int) -> void:
	var map := Vector2.ZERO
	var rooms := 0.0
	var gap := INF
	var fit := 0.0

	for seed_value in _SEEDS:
		var positions := _layout(seed_value, wanted)
		if positions.is_empty():
			continue
		rooms += float(positions.size())
		var span := _span(positions)
		map += span
		gap = minf(gap, _closest_gap(positions))
		fit += minf(_VIEW.x / maxf(span.x, 1.0), _VIEW.y / maxf(span.y, 1.0))

	var runs := float(_SEEDS.size())
	map /= runs
	fit /= runs
	var shown := clampf(_ZOOM_MIN / fit, 0.0, 1.0)
	print(
		(
			"%-6d %6.1f %11.0f %11.0f %8.3f %8.1f %8.0f %7s"
			% [
				wanted,
				rooms / runs,
				map.x,
				map.y,
				fit,
				100.0 * shown * shown,
				gap,
				"보인다" if maxf(fit, _ZOOM_MIN) >= _DETAIL_NAME_ZOOM else "안 보인다",
			]
		)
	)


## 그 방 개수로 판 하나를 만들어 화면 좌표를 얻는다.
func _layout(seed_value: int, wanted: int) -> Dictionary:
	var params := DungeonGenerator.Params.new()
	params.room_count = wanted
	var blueprint := DungeonGenerator.new(seed_value, params).generate()
	return blueprint.layout(seed_value, _SPACING)


func _span(positions: Dictionary) -> Vector2:
	var lowest := Vector2.INF
	var highest := -Vector2.INF
	for position in positions.values():
		lowest = lowest.min(position as Vector2)
		highest = highest.max(position as Vector2)
	# 방 위젯은 좌표를 중심으로 그려지므로 양쪽으로 절반씩 더 뻗는다.
	return highest - lowest + _NODE_SIZE


## 가장 가까운 두 방의 **위젯 사이** 간격. 음수면 이름이 겹쳐 보인다.
##
## 푸아송 디스크가 최소 간격을 보장하므로 이 값은 방 개수와 무관해야 한다.
## 무관한지 확인하는 것이 이 항목의 목적이다.
func _closest_gap(positions: Dictionary) -> float:
	var values: Array = positions.values()
	var closest := INF
	for i in values.size():
		for j in range(i + 1, values.size()):
			var delta: Vector2 = (values[i] as Vector2) - (values[j] as Vector2)
			closest = minf(
				closest, maxf(absf(delta.x) - _NODE_SIZE.x, absf(delta.y) - _NODE_SIZE.y)
			)
	return closest
