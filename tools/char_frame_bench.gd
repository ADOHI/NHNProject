extends Node2D
## **잔상 장수별로 몇 명까지 되나.** 네이티브와 웹에서 **같은 장면**을 돌린다.
##
##     godot --path . res://tools/char_frame_bench.tscn
##
## 웹 빌드는 `run/main_scene` 하나만 띄우고 `-s` 로 스크립트를 못 돌린다. 그래서
## `web_frame_bench.gd` 와 같은 방식으로 **장면**으로 만들었다. 같은 코드로 두 곳을
## 재야 렌더 경로와 스레드 차이만 남는다.
##
## **왜 재는가.** [`28-combat.md`](../docs/design/28-combat.md) §28.6 의 물량전 상한
## 실측(56 / 72 / 100)은 **네모**를 셌을 때다. 캐릭터는 **파츠 여섯 + 무기**라
## 노드가 일곱 배이고, 거기에 **잔상이 장수만큼 더 그린다.**
##
## **잔상이 축인 이유.** 잔상은 노드를 안 만든다 — 과거 자세를 `sample(t - Δ)` 로
## 뽑아 **폴리곤만 더 찍는다**(§25.23). 그래서 값이 노드 수가 아니라 **채움률**로
## 나오고, 웹(`gl_compatibility` · 단일 스레드)에서 가장 나쁜 쪽이 바로 그것이다.
##
## **95 백분위로 읽는다.** 최악값은 외부 간섭(다른 프로세스 · 브라우저 탭)에 가장 약해서
## 우리 탓과 남 탓을 못 가른다.

## 한 칸을 몇 프레임 모으나. **웹은 프레임이 느리게 흘러** 240 장을 20 칸 모으면
## 결과를 못 볼 만큼 오래 걸린다. 150 이면 95 분위가 흔들릴 만큼 적지는 않다.
const FRAMES := 150
const WARMUP := 30
const BUDGET_MS := 16.7

## 잔상 장수. `CharFlourish` 의 세 눈금(3 · 6 · 12)에 **「없음」**을 더한 것이다.
##
## **몸을 안 남기고 무기만 남긴다** — 장수만 축으로 두려는 것이다. 몸까지 남기면
## 한 장이 일곱 배가 되어 「장수」와 「무엇을 남기나」가 한 축에 뭉친다.
## `x` 는 잔상 장수, `y` 가 1 이면 **파츠를 한 노드로 합쳐** 그린다 (§25.32).
##
## **합침은 잔상 없음에서만 잰다.** 묻는 것이 「노드 일곱이 값을 하나」 하나뿐이라,
## 잔상까지 곱하면 칸이 배로 늘고 답은 안 는다.
const MODES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0), Vector2i(12, 0), Vector2i(0, 1)
]

## 재는 인원. **§28.6 의 물량전 상한(56 · 72 · 100)을 그대로 밟는다** —
## 저쪽이 네모로 잰 자리를 캐릭터로 다시 재야 배수가 뜻을 갖는다.
const COUNTS: Array[int] = [8, 24, 56, 72, 100]

## 예산을 이 배수 넘게 넘기면 **더 큰 인원은 안 잰다.** 더 넣어서 나아질 리가 없고,
## 그 칸이 가장 오래 걸린다 — 웹에서 결과를 못 보게 만드는 것이 정확히 그 칸이다.
const HOPELESS := 2.5

## 표를 남기는 자리. 웹에서는 못 쓰지만 그때는 콘솔이 확실하다.
const REPORT := "res://.renders-char-anim/char_frame_bench.md"

## 화면에 늘어놓을 때의 배율과 간격. 겹쳐도 상관없다 — 그리는 양이 줄면 안 되므로
## 오히려 **다 보이게** 늘어놓는다.
const ACTOR_SCALE := 0.42
const COLUMNS := 10

var _actors: Array[CharActor] = []
var _label: Label
var _trail := 0
var _count := -1
var _warmup := 0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _lines := PackedStringArray()

## 잔상 장수마다 **통과한 가장 큰 인원.** 이 표가 이 벤치의 답이다.
var _ceiling: Dictionary[int, int] = {}


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 13)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(_label)
	add_child(layer)
	_lines.append("| 그리기 | 인원 | 노드 | 중앙 | 95 | 99 | 최악 | 넘침 |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for i in MODES.size():
		_ceiling[i] = 0
	_next()


func _process(delta: float) -> void:
	if _trail >= MODES.size():
		return
	if _warmup > 0:
		_warmup -= 1
		return
	_frame_ms.append(delta * 1000.0)
	if _frame_ms.size() >= FRAMES:
		_record()
		_next()


## 다음 칸으로. 인원을 다 밟으면 잔상 장수를 올린다.
func _next() -> void:
	_count += 1
	if _count >= COUNTS.size():
		_count = 0
		_trail += 1
	if _trail >= MODES.size():
		_finish()
		return
	_spawn(COUNTS[_count], MODES[_trail])
	_frame_ms = PackedFloat32Array()
	_warmup = WARMUP
	_label.text = "재는 중… %s · %d 명" % [_mode_name(_trail), COUNTS[_count]]


## 사람이 읽는 이름. 표와 화면이 같은 말을 쓰게 하려는 것이다.
func _mode_name(index: int) -> String:
	var mode: Vector2i = MODES[index]
	if mode.y == 1:
		return "합침 (잔상 %d)" % mode.x
	return "잔상 %d 장" % mode.x


## 이 잔상 장수에서 더 큰 인원은 볼 것도 없다. **가장 오래 걸리는 칸을 건너뛴다.**
func _give_up_on_this_trail() -> void:
	_count = COUNTS.size() - 1


func _flourish(trail: int) -> CharFlourish:
	var it := CharFlourish.none()
	if trail <= 0:
		return it
	it.trail_count = trail
	it.trail_alpha = 0.3
	return it


func _spawn(count: int, mode: Vector2i) -> void:
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	var view := get_viewport_rect().size
	var rows := int(ceil(float(count) / float(COLUMNS)))
	for i in count:
		var actor := CharActor.new()
		# 무기 칸 수를 섞는다. 한 종류만 쓰면 클립 하나만 도는 셈이라 실제보다 낫게 나온다.
		actor.weapon_cells = 1 + (i % CharWeapon.MAX_CELLS)
		actor.merged = mode.y == 1
		actor.flourish = _flourish(mode.x)
		actor.scale = Vector2(ACTOR_SCALE, ACTOR_SCALE)
		actor.position = Vector2(
			view.x * (float(i % COLUMNS) + 0.5) / float(COLUMNS),
			view.y * (float(i / COLUMNS) + 0.85) / float(maxi(rows, 1))
		)
		add_child(actor)
		# **휘두르게 둔다.** 잔상은 특수기에만 붙는 장치라(§25.26.5) 걷기로 재면
		# 정작 켜지는 자리를 안 재는 것이 된다.
		actor.finished.connect(_replay.bind(actor))
		actor.play(CharActor.Action.SWING)
		# **위상을 어긋나게 둔다.** 다 같은 `t` 면 캐시가 이상하게 잘 맞아 실제보다 낫게 나온다.
		actor.seek(float(i) * 0.037)
		_actors.append(actor)


## 한 방이 끝나면 다시 건다. 루프가 아닌 동작이라 안 걸면 그 자리에 굳는다.
func _replay(_action: CharActor.Action, actor: CharActor) -> void:
	actor.play(CharActor.Action.SWING)


func _record() -> void:
	var sorted := Array(_frame_ms)
	sorted.sort()
	var over := 0
	for ms: float in sorted:
		if ms > BUDGET_MS:
			over += 1
	var p95 := _at(sorted, 0.95)
	var count: int = COUNTS[_count]
	if p95 <= BUDGET_MS:
		_ceiling[_trail] = maxi(_ceiling[_trail], count)
	_emit(
		(
			"| %s | %d | %d | %.2f | %.2f | %.2f | %.2f | %d/%d |"
			% [
				_mode_name(_trail),
				count,
				get_tree().get_node_count(),
				_at(sorted, 0.50),
				p95,
				_at(sorted, 0.99),
				sorted[sorted.size() - 1],
				over,
				sorted.size(),
			]
		)
	)
	if p95 > BUDGET_MS * HOPELESS:
		_give_up_on_this_trail()


## **행이 끝나는 대로 바로 낸다.** 마지막에 몰아서 내면 마지막 칸이 안 끝날 때
## 앞의 결과도 못 본다 — 웹에서 실제로 그렇게 막혔다.
##
## 화면 · 콘솔 · 파일 셋에 같이 남긴다. 브라우저에서는 콘솔이 확실하고, 네이티브에서는
## **콘솔이 파이프로 넘어가면 끝날 때까지 안 흘러나온다** — 실제로 그것 때문에
## 20 분 동안 아무것도 못 봤다. 파일은 그 자리에서 읽힌다.
func _emit(line: String) -> void:
	_lines.append(line)
	print(line)
	_label.text = "\n".join(_lines)
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()


func _at(sorted: Array, ratio: float) -> float:
	var index := clampi(int(float(sorted.size() - 1) * ratio), 0, sorted.size() - 1)
	return sorted[index]


func _finish() -> void:
	for actor in _actors:
		actor.queue_free()
	_actors.clear()
	_lines.append("")
	_lines.append("| 그리기 | 예산 안에 드는 인원 |")
	_lines.append("| --- | --- |")
	for i in MODES.size():
		_lines.append("| %s | %d 명 |" % [_mode_name(i), _ceiling[i]])
	_emit("예산 %.1f ms · 프레임 %d · 준비 %d" % [BUDGET_MS, FRAMES, WARMUP])
	var text := "\n".join(_lines)
	_label.text = text
	print("\n== 캐릭터 프레임 실측 ==")
	print(text)
	print("예산 %.1f ms · 프레임 %d · 준비 %d" % [BUDGET_MS, FRAMES, WARMUP])
