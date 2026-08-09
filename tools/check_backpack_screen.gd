extends SceneTree
## **확인 화면이 실제로 도는가.** 창을 안 띄우고 본다.
##
##     godot --headless --path . -s res://tools/check_backpack_screen.gd
##
## `docs/design/28-combat.md` §28.20.24 · §28.20.51.
##
## ## 왜 필요한가
##
## §28.20.24 가 이미 겪었다: **`--import` 는 파싱 에러를 하나도 못 잡는다.**
## 그리고 `--quit-after` 는 `main.tscn` 만 띄우므로 **이 화면은 아예 안 돈다.**
## GUT 은 코어를 붙들지만 **화면 스크립트를 `load` 하지 않는다.**
##
## 그래서 **대련장 API 를 갈아엎는 동안 화면이 도는지 확인하는 것이 캡처뿐이었다** —
## 그런데 캡처는 창을 띄워 GPU 를 쓴다. 그림 생성이 GPU 를 쓰는 동안에는 못 돌린다.
##
## **이것이 그 자리를 메운다.** 창도 GPU 도 안 쓰고 씬을 붙여 몇 초를 굴린다.
##
## ## 무엇을 잡고 무엇을 못 잡나
##
## | 잡는다 | 못 잡는다 |
## | --- | --- |
## | 파싱 에러 · 없는 함수 · 시그널 연결 실패 | **그림이 읽히는가** — 그건 캡처의 몫이다 |
## | 발사 뒤 실제로 타가 나가는가 | 겹침 · 잘림 · 색 |
##
## **캡처를 대신하지 않는다.** 캡처가 못 도는 동안 **깨진 채로 쌓이는 것**을 막을 뿐이다.

## 씬이 자리를 잡을 시간. `_ready` 가 붙인 그 자리에서 돌지 않는다.
const _WARMUP := 4

## 발사 뒤 굴릴 시간(초). 표본 체인이 다 나가고 마무리 관찰까지 든다.
const _RUN_SECONDS := 8.0

var _screen: Control
var _frames := 0
var _elapsed := 0.0
var _fired := false
var _hits := 0
var _failures := PackedStringArray()


func _initialize() -> void:
	var packed := load("res://src/ui/backpack/backpack_screen.tscn")
	if packed == null:
		_fail("씬을 못 불러왔다")
		_finish()
		return
	_screen = packed.instantiate()
	root.add_child(_screen)


func _process(delta: float) -> bool:
	if _screen == null:
		return true
	_frames += 1
	if _frames < _WARMUP:
		return false

	if not _fired:
		_check_before_fire()
		_fire()
		_fired = true
		return false

	# **엔진이 이미 자식 노드를 돌린다.** 여기서 또 부르면 두 배로 흐른다 —
	# `tools/capture_backpack.gd` 가 같은 방식으로 붙여 놓고 그냥 기다린다.
	_elapsed += delta
	if _elapsed < _RUN_SECONDS:
		return false

	_check_after_fire()
	_finish()
	return true


# ---------------------------------------------------------------- 검사


func _check_before_fire() -> void:
	var grid: BackpackGrid = _screen._grid
	if grid == null:
		_fail("격자가 안 세워졌다")
		return
	var chains := ChainResolver.resolve_all(grid)
	if chains.is_empty() or chains[0].length() == 0:
		_fail("표본 배치에서 체인이 안 나온다")
	else:
		print("  표본 체인 %d 타 (%s)" % [chains[0].length(), chains[0].stop_label()])

	var field: SparringField = _screen._field
	if field == null:
		_fail("대련장 자리가 없다")
		return
	print("  적 %d 명, 간격 %.0f" % [field.enemy_count(), field.gap()])


## **발사가 실제로 타를 내는가.** 이것이 이 검사의 알맹이다 —
## API 를 갈아엎으면 여기서 조용히 0 타가 된다.
func _fire() -> void:
	_screen._fire()
	var bout: SparringBout = _screen._bout
	if bout == null:
		_fail("발사했는데 판이 안 만들어졌다")
		return
	bout.hit_landed.connect(func(_index: int, _item: BackpackItem) -> void: _hits += 1)


func _check_after_fire() -> void:
	var bout: SparringBout = _screen._bout
	if bout == null:
		_fail("판이 사라졌다")
		return
	if _hits == 0:
		_fail("%.0f 초를 굴렸는데 한 타도 안 나갔다" % _RUN_SECONDS)
	print("  나간 타 %d, 적이 때린 타 %d" % [_hits, bout.enemy_landed()])
	print(
		(
			"  적 눈금 최고 %.0f (%s), 우리 눈금 최고 %.0f (%s)"
			% [
				bout.enemy_gauge(0).peak(),
				BreakState.label(bout.enemy_gauge(0).peak_state()),
				bout.ally_gauge().peak(),
				BreakState.label(bout.ally_gauge().peak_state()),
			]
		)
	)
	if bout.enemy_gauge(0).peak() <= 0.0:
		_fail("적 눈금이 한 번도 안 올랐다")


# ---------------------------------------------------------------- 마무리


func _fail(why: String) -> void:
	_failures.append(why)


func _finish() -> void:
	print("")
	if _failures.is_empty():
		print("확인 화면이 돈다. 깨진 곳 없음.")
	else:
		print("**깨진 곳 %d 군데**" % _failures.size())
		for why in _failures:
			print("  - %s" % why)
	quit(0 if _failures.is_empty() else 1)
