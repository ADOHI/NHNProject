class_name SampleBackpack
extends RefCounted
## 확인 화면이 열자마자 보여 줄 백팩 하나와 아이템들.
##
## `src/core/dungeon/sample_dungeons.gd` 와 같은 자리다 — **밸런스가 아니라 표본**이다.
## 여기 수치는 정해진 것이 아니고, 체인이 도는 모습을 보려고 골라 둔 것이다.
##
## ## 기본 배치가 전리품에서 끝나게 해 뒀다
##
## 열자마자 보이는 체인이 **단검 -> 건틀릿 -> 철퇴 -> 창 -> 원석**이고
## 마지막 원석은 출력이 없어서 거기서 끝난다.
##
## 일부러 그렇게 뒀다. `docs/design/28-combat.md` §28.10.3 —
## **루팅한 물건이 콤보 루트 위에 놓이면 체인이 끊긴다**는 것이 이 시스템의
## 요점이고, 그것이 설명이 아니라 첫 화면에 보여야 한다.
## 원석을 집어 옆으로 치우면 체인이 어떻게 되는지 바로 만져 볼 수 있다.

const GRID_WIDTH := 6
const GRID_HEIGHT := 6

## 시작 노드. **목록인 이유는 §28.10.7 에 있다** — 개수가 미정이라 하나만 꽂아 둔다.
const START_NODES: Array[Vector2i] = [Vector2i(0, 0)]


## 이 표본에 나오는 모든 아이템. 매번 새 객체를 만든다.
static func create_items() -> Array[BackpackItem]:
	return [
		BackpackItem.new(
			"dagger",
			"단검",
			BackpackItem.Kind.WEAPON,
			[Vector2i(0, 0), Vector2i(0, 1)],
			Vector2i(0, 1),
			ChainDirection.Kind.DOWN
		),
		BackpackItem.new(
			"gauntlet",
			"건틀릿",
			BackpackItem.Kind.WEAPON,
			[Vector2i(0, 0)],
			Vector2i(0, 0),
			ChainDirection.Kind.RIGHT
		),
		BackpackItem.new(
			"mace",
			"철퇴",
			BackpackItem.Kind.WEAPON,
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
			Vector2i(1, 0),
			ChainDirection.Kind.RIGHT
		),
		BackpackItem.new(
			"spear",
			"창",
			BackpackItem.Kind.WEAPON,
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			Vector2i(2, 0),
			ChainDirection.Kind.UP
		),
		BackpackItem.new(
			"longsword",
			"장검",
			BackpackItem.Kind.WEAPON,
			[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
			Vector2i(0, 2),
			ChainDirection.Kind.RIGHT
		),
		BackpackItem.new(
			"axe",
			"도끼",
			BackpackItem.Kind.WEAPON,
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
			Vector2i(1, 1),
			ChainDirection.Kind.DOWN
		),
		BackpackItem.new("gem", "원석", BackpackItem.Kind.LOOT, [Vector2i(0, 0)]),
		BackpackItem.new(
			"relic",
			"유물",
			BackpackItem.Kind.LOOT,
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		),
	]


## 아이템 id -> 놓을 자리. 여기 없는 아이템은 대기줄에서 시작한다.
static func default_layout() -> Dictionary:
	return {
		"dagger": Vector2i(0, 0),
		"gauntlet": Vector2i(0, 2),
		"mace": Vector2i(1, 2),
		"spear": Vector2i(3, 2),
		"gem": Vector2i(5, 1),
	}


static func create_grid() -> BackpackGrid:
	return BackpackGrid.new(GRID_WIDTH, GRID_HEIGHT, START_NODES)


## 격자에 기본 배치를 채우고, **들어가지 않은 아이템들을** 돌려준다 (대기줄에 갈 것들).
static func fill(grid: BackpackGrid, items: Array[BackpackItem]) -> Array[BackpackItem]:
	var layout := default_layout()
	var leftover: Array[BackpackItem] = []
	for item in items:
		if not layout.has(item.id):
			leftover.append(item)
			continue
		if grid.place(item, layout[item.id]) == null:
			push_warning("표본 배치가 격자에 들어가지 않는다: %s" % item.id)
			leftover.append(item)
	return leftover
