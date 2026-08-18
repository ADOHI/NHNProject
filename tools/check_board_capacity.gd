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

## **크기 사다리를 따라간다.** 예전에는 `[12, 22, 32, 50, 64]` 를 여기 적어 뒀는데,
## 그러면 이 도구가 **게임이 만들지 않는 판**을 재고(64) 게임이 만드는 최악(53)은 안 잰다.
## 등급 경계가 사다리를 안 따라와 크기 3·4·5 가 붙어 버린 것과 **같은 병**이다
## (docs/design/17-dungeon-generation.md §17.30).
const _SEEDS := 8

## project.godot 의 기준 해상도. 웹 빌드도 이 비율로 늘어난다.
const _VIEW := Vector2(1280.0, 720.0)

## **화면 쪽 상수는 베끼지 않고 읽어 온다.**
##
## 처음에는 간격 · 확대 하한 · 위젯 크기를 이 파일에 적어 뒀는데, 그러면 화면이 바뀔 때
## 이 도구가 옛 수치로 조용히 거짓말을 한다. 실제로 간격을 240 으로 내리면서
## 두 곳을 고쳐야 했다. GDScript 의 밑줄은 관례일 뿐이라 상수는 그대로 읽힌다.
const _SPACING := DungeonBoard._SPACING
const _ZOOM_MIN := DungeonBoard._ZOOM_MIN
const _DETAIL_NAME_ZOOM := DungeonBoard._DETAIL_NAME_ZOOM

## room_node.tscn 의 위젯 크기. 씬을 한 번 세워 읽는다.
static var _node_size := Vector2.ZERO


func _initialize() -> void:
	_node_size = _measure_node()
	print("== 화면이 담는가 — 크기 사다리를 따라 ==")
	print(
		(
			"기준 화면 %dx%d · 간격 %d · 방 위젯 %dx%d · 확대 하한 %.2f"
			% [
				int(_VIEW.x),
				int(_VIEW.y),
				int(_SPACING),
				int(_node_size.x),
				int(_node_size.y),
				_ZOOM_MIN
			]
		)
	)
	print("판마다 성격 %d x 시드 %d" % [DungeonCatalog.count(), _SEEDS])
	print("")
	print(
		(
			"%-5s %5s %9s %8s %8s %9s %8s %7s"
			% ["크기", "표기", "실제", "fit최악", "fit중앙", "하한미달", "minGap", "이름?"]
		)
	)
	for size in range(SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX + 1):
		_check(size)
	print("")
	print("== 가장 큰 크기(%d)에서 간격을 줄이면 ==" % SampleDungeons.SIZE_MAX)
	print(
		"%-8s %11s %11s %8s %8s %8s" % ["spacing", "map_w", "map_h", "fitZoom", "seen%", "minGap"]
	)
	for spacing in [280.0, 240.0, 220.0, 200.0, 180.0]:
		_check_spacing(spacing)
	print("")
	print("fit최악  : 판 전체가 화면에 들어오려면 필요한 배율 — **가장 큰 판** 기준")
	print("하한미달 : 확대 하한에서 판이 안 들어오는 판의 수. **0 이 아니면 결함이다**")
	print("minGap   : 배율 1 에서 가장 가까운 두 방의 위젯 사이 간격 (픽셀, 음수면 겹친다)")
	print("이름?    : 가장 큰 판을 통째로 보는 배율에서 방 이름이 보이는가")
	quit()


## 방 위젯의 크기. 씬을 세워 읽고 바로 버린다.
func _measure_node() -> Vector2:
	var node: Control = load("res://src/ui/dungeon_board/room_node.tscn").instantiate()
	var found := node.custom_minimum_size
	node.free()
	return found


## 크기 한 칸을 잰다.
##
## **평균이 아니라 최악을 본다.** 확대 하한은 "평균적인 판이 들어오는가"가 아니라
## "**어떤 판도** 잘리지 않는가"의 문제다. 평균만 재면 큰 판 몇 개가 잘려도 표가 통과한다
## — §17.25.2 가 크기 5 를 0.421 로 적었는데 그것은 20 판의 평균이었다.
func _check(size: int) -> void:
	var fits: Array[float] = []
	var rooms: Array[int] = []
	var gap := INF
	var worst_fit := INF
	var short := 0

	for character in DungeonCatalog.count():
		for seed_value in _SEEDS:
			var positions := _layout(seed_value * 977 + character, size, character)
			if positions.is_empty():
				continue
			rooms.append(positions.size())
			var span := _span(positions)
			gap = minf(gap, _closest_gap(positions))
			var fit := minf(_VIEW.x / maxf(span.x, 1.0), _VIEW.y / maxf(span.y, 1.0))
			fits.append(fit)
			worst_fit = minf(worst_fit, fit)
			if fit < _ZOOM_MIN:
				short += 1

	fits.sort()
	rooms.sort()
	var median := fits[fits.size() / 2]
	print(
		(
			"%-5d %5d %4d~%-4d %8.3f %8.3f %5d/%-3d %8.0f %7s"
			% [
				size,
				SampleDungeons.room_estimate(size),
				rooms[0],
				rooms[rooms.size() - 1],
				worst_fit,
				median,
				short,
				fits.size(),
				gap,
				"보인다" if maxf(worst_fit, _ZOOM_MIN) >= _DETAIL_NAME_ZOOM else "안 보인다",
			]
		)
	)


## 간격을 바꿨을 때 **사다리의 가장 큰 판**이 어떻게 되는가.
##
## 간격을 줄이면 판이 화면에 들어오지만 방 위젯끼리 가까워진다.
## minGap 이 0 에 가까워지면 이름이 겹친다 — 그 경계를 찾는 것이 목적이다.
## 여기서도 **최악**을 본다.
func _check_spacing(spacing: float) -> void:
	var map := Vector2.ZERO
	var gap := INF
	var fit := INF
	var runs := 0.0
	for character in DungeonCatalog.count():
		for seed_value in _SEEDS:
			var params := SampleDungeons.params_for_size(SampleDungeons.SIZE_MAX, character)
			var layout_seed := seed_value * 977 + character
			var blueprint := DungeonGenerator.new(layout_seed, params).generate()
			var positions := blueprint.layout(layout_seed, spacing)
			if positions.is_empty():
				continue
			runs += 1.0
			var span := _span(positions)
			map += span
			gap = minf(gap, _closest_gap(positions))
			fit = minf(fit, minf(_VIEW.x / maxf(span.x, 1.0), _VIEW.y / maxf(span.y, 1.0)))

	map /= maxf(runs, 1.0)
	var shown := clampf(fit / _ZOOM_MIN, 0.0, 1.0)
	print(
		(
			"%-8.0f %11.0f %11.0f %8.3f %8.1f %8.0f"
			% [spacing, map.x, map.y, fit, 100.0 * shown * shown, gap]
		)
	)


## 그 크기로 판 하나를 만들어 화면 좌표를 얻는다. **사다리를 통해서만 만든다.**
func _layout(layout_seed: int, size: int, character: int) -> Dictionary:
	var params := SampleDungeons.params_for_size(size, character)
	var blueprint := DungeonGenerator.new(layout_seed, params).generate()
	return blueprint.layout(layout_seed, _SPACING)


func _span(positions: Dictionary) -> Vector2:
	var lowest := Vector2.INF
	var highest := -Vector2.INF
	for position in positions.values():
		lowest = lowest.min(position as Vector2)
		highest = highest.max(position as Vector2)
	# 방 위젯은 좌표를 중심으로 그려지므로 양쪽으로 절반씩 더 뻗는다.
	return highest - lowest + _node_size


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
				closest, maxf(absf(delta.x) - _node_size.x, absf(delta.y) - _node_size.y)
			)
	return closest
