extends Node2D
## **N 명이 동시에 움직일 때 프레임을 잰다.** 네이티브와 웹에서 **같은 장면**을 돌린다.
##
##     godot --path . res://tools/char_frame_bench.tscn
##
## 웹 빌드는 `run/main_scene` 하나만 띄우고 `-s` 로 스크립트를 못 돌린다. 그래서
## `web_frame_bench.gd` 와 같은 방식으로 **장면**으로 만들었다. 같은 코드로 두 곳을
## 재야 렌더 경로와 스레드 차이만 남는다.
##
## **왜 재는가.** [`28-combat.md`](../docs/design/28-combat.md) §28.6 의 물량전 상한
## 실측(56 / 72 / 100)은 **네모**를 셌을 때다. 캐릭터는 **파츠 여섯 + 무기**라
## 노드가 일곱 배다. 그 배수가 어디서 걸리는지 모르면 스쿼드 인원을 못 정한다.
##
## **95 백분위로 읽는다.** 최악값은 외부 간섭(다른 프로세스 · 브라우저 탭)에 가장 약해서
## 우리 탓과 남 탓을 못 가른다.

const FRAMES := 240
const WARMUP := 45
const BUDGET_MS := 16.7

## 재는 인원. **64 까지 본다** — 안 되면 그것이 발견이다.
const COUNTS: Array[int] = [4, 8, 16, 32, 64]

## 화면에 늘어놓을 때의 배율과 간격. 겹쳐도 상관없다 — 그리는 양이 줄면 안 되므로
## 오히려 **다 보이게** 늘어놓는다.
const ACTOR_SCALE := 0.42
const COLUMNS := 8

var _actors: Array[CharActor] = []
var _label: Label
var _index := -1
var _warmup := 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _lines := PackedStringArray()


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 14)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(_label)
	add_child(layer)
	_lines.append("| 인원 | 노드 | 중앙 | 95 | 99 | 최악 | 넘침 |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	_next()


func _process(delta: float) -> void:
	if _index >= COUNTS.size():
		return
	if _warmup > 0:
		_warmup -= 1
		return
	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() >= FRAMES:
		_record()
		_next()


func _next() -> void:
	_index += 1
	if _index >= COUNTS.size():
		_finish()
		return
	_spawn(COUNTS[_index])
	_frame_ms = PackedFloat32Array()
	_warmup = WARMUP
	_label.text = "재는 중… %d 명" % COUNTS[_index]


func _spawn(count: int) -> void:
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	var view := get_viewport_rect().size
	var rows := int(ceil(float(count) / float(COLUMNS)))
	for i in count:
		var actor := CharActor.new()
		# 무기 칸 수를 섞는다. 한 종류만 쓰면 클립 하나만 도는 셈이라 실제보다 낫게 나온다.
		actor.weapon_cells = 1 + (i % CharWeapon.MAX_CELLS)
		actor.scale = Vector2(ACTOR_SCALE, ACTOR_SCALE)
		actor.position = Vector2(
			view.x * (float(i % COLUMNS) + 0.5) / float(COLUMNS),
			view.y * (float(i / COLUMNS) + 0.85) / float(maxi(rows, 1))
		)
		add_child(actor)
		actor.play(CharActor.Action.WALK)
		# **위상을 어긋나게 둔다.** 다 같은 `t` 면 캐시가 이상하게 잘 맞아 실제보다 낫게 나온다.
		actor.seek(float(i) * 0.037)
		_actors.append(actor)


func _record() -> void:
	var sorted := Array(_frame_ms)
	sorted.sort()
	var over := 0
	for ms: float in sorted:
		if ms > BUDGET_MS:
			over += 1
	(
		_lines
		. append(
			(
				"| %d | %d | %.2f | %.2f | %.2f | %.2f | %d/%d |"
				% [
					COUNTS[_index],
					get_tree().get_node_count(),
					_at(sorted, 0.50),
					_at(sorted, 0.95),
					_at(sorted, 0.99),
					sorted[sorted.size() - 1],
					over,
					sorted.size(),
				]
			)
		)
	)
	print(_lines[_lines.size() - 1])


func _at(sorted: Array, ratio: float) -> float:
	var index := clampi(int(float(sorted.size() - 1) * ratio), 0, sorted.size() - 1)
	return sorted[index]


func _finish() -> void:
	var text := "\n".join(_lines)
	_label.text = text
	print("\n== 캐릭터 프레임 실측 ==")
	print(text)
	print("예산 %.1f ms · 프레임 %d · 준비 %d" % [BUDGET_MS, FRAMES, WARMUP])
