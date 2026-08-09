extends RefCounted
## 대련 테스트가 함께 쓰는 표본. **테스트 전용이다.**
##
## `docs/design/28-combat.md` §28.4 · §28.20.34.
##
## 대련 테스트는 네 파일로 갈라져 있다 (한 파일에 스무 개가 넘으면 린트가 막는다).
## 갈라 놓고 나니 **같은 표본 만드는 코드가 네 벌**이 됐다 — 한쪽만 고치면
## 그때부터 파일마다 다른 무기를 쓰면서 같은 이름으로 부르게 된다.
##
## 파일 이름이 test_ 로 시작하지 않으므로 GUT 은 이 파일을 테스트로 실행하지 않는다.


## 칸 수만 있는 무기. **모양이 아니라 부피가 성질을 정한다** (§28.20.18).
static func sized(cells: int) -> BackpackItem:
	var shape: Array[Vector2i] = []
	for index in cells:
		shape.append(Vector2i(index, 0))
	return BackpackItem.new(
		"s%d" % cells,
		"무기%d" % cells,
		BackpackItem.Kind.WEAPON,
		shape,
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


## 1칸 무기 하나. 격자에 놓고 체인을 풀 때 쓴다.
static func pip(id: String) -> BackpackItem:
	return BackpackItem.new(
		id,
		id,
		BackpackItem.Kind.WEAPON,
		[Vector2i(0, 0)],
		Vector2i(0, 0),
		ChainDirection.Kind.RIGHT
	)


## 1칸 무기 여러 개짜리 체인.
static func items(count: int, cells: int = 1) -> Array[BackpackItem]:
	var made: Array[BackpackItem] = []
	for _index in count:
		made.append(sized(cells))
	return made


## 그 무기 한 번 휘두르는 데 걸리는 시간. **테스트가 상수를 따로 안 적는다.**
static func strike(tuning: BreakTuning, cells: int = 1) -> float:
	return tuning.strike_seconds_for(sized(cells))


## 적 하나가 그 간격에 선 대련장.
static func field_at(gap: float) -> SparringField:
	return SparringField.new(0.0, gap)


## 적 여럿이 줄지어 선 대련장. 첫째가 `gap`, 그 뒤로 `spacing` 씩 물러선다.
static func crowd(gap: float, spacing: float, count: int) -> SparringField:
	var xs := PackedFloat32Array()
	for index in count:
		xs.append(gap + float(index) * spacing)
	var field := SparringField.new()
	field.reset_with(0.0, xs)
	return field


## 판이 끝날 때까지 잘게 돌린다.
static func run_to_end(bout: SparringBout, step: float = 1.0 / 120.0) -> void:
	for _frame in 20000:
		if not bout.is_running():
			return
		bout.tick(step)
