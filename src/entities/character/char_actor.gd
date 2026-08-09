class_name CharActor
extends Node2D
## 캐릭터 하나. **다른 레인이 쓰는 얼굴이다.**
##
## 붙이고, `play()` 를 부르고, 무기 칸 수를 주면 끝난다. 리그도 클립도 포즈도 안 보인다.
##
## ```gdscript
## var actor := CharActor.new()
## add_child(actor)
## actor.weapon_cells = 3
## actor.play(CharActor.Action.WALK)
## actor.struck.connect(_on_struck)   # 검이 닿는 순간
## ```
##
## **`docs/design/25-character-animation.md` §25.18 이 이 노드의 명세다.**
## 거기 적은 입출력이 그대로 여기 얼굴이 된다 — 그래서 두 문서가 안 갈린다.
##
## ## 안 받는 것
##
## **위치 · 충돌 · 판정은 전투 쪽 것이다.** 이쪽은 「그 자리에서 무엇을 보여 줄지」만 안다.
## 바라보는 방향도 안 받는다 — `facing` 이 `scale.x` 를 뒤집을 뿐이고, 트랜스폼만 쓰므로
## **앞뒤 관계가 그대로 유지된다**(§25.2).

## 동작 하나가 끝났다. **루프가 아닌 것들만** 낸다 (`JUMP` · `SWING` · `HIT` · `DIE`).
##
## 이것을 받아서 다음 동작을 걸면 된다 — 쓰러진 채로 두고 싶으면 안 걸면 그만이다.
signal finished(action: Action)

## **검이 닿는 순간.** 휘두르기에서만 난다.
##
## **전투가 이 시각을 상수로 박으면 안 된다** — 무기 무게에 따라 1 칸 0.23 초,
## 4 칸 0.71 초로 **3.1 배** 차이 난다. 상수로 박으면 4 칸에서 **검이 아직 머리 위에
## 있을 때 적이 날아간다** (§25.18.1).
signal struck

enum Action { IDLE, WALK, RUN, JUMP, SWING, SWING_UP, HIT, DIE }

## 화면에서 캐릭터 키(141)를 몇 배로 볼 것인가. 쓰는 쪽이 정한다.
const DEFAULT_SCALE := 1.0

## 든 무기의 칸 수. **부피가 곧 동작의 무게다** (§25.16).
@export_range(1, 4) var weapon_cells := 1:
	set(value):
		var next := clampi(value, CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS)
		if next == weapon_cells:
			return
		weapon_cells = next
		_rebuild_weapon()

## `+1` 이면 오른쪽, `-1` 이면 왼쪽을 본다.
@export var facing := 1:
	set(value):
		facing = 1 if value >= 0 else -1
		scale.x = absf(scale.x) * float(facing)

## 재생 속도. 0 이면 멈춘다.
@export var speed := 1.0

var _rig: CharRig
var _view: CharPartsView
var _clips: Dictionary[Action, CharClip] = {}
var _action := Action.IDLE
var _time := 0.0
var _done := false
var _struck := false


func _ready() -> void:
	if _rig == null:
		_build()


## 동작을 건다. 같은 동작을 다시 걸면 **처음부터 다시** 시작한다 —
## 연타를 같은 동작으로 받을 때 그 편이 맞다.
func play(action: Action) -> void:
	if _rig == null:
		_build()
	_action = action
	_time = 0.0
	_done = false
	_struck = false
	_refresh()


func current_action() -> Action:
	return _action


## 지금 동작이 루프인가. 루프가 아니면 끝에서 멈추고 `finished` 를 낸다.
func is_looping() -> bool:
	return _clip().is_looping()


## 지금 동작의 전체 길이(초).
func action_seconds() -> float:
	return _clip().loop_seconds()


## **검이 닿는 시각(초).** 휘두르기가 아니면 `-1`.
##
## 전투가 판정을 여기에 넣어야 화면과 규칙이 맞는다. `struck` 시그널로도 나가지만,
## 미리 알아야 하는 쪽(예약·예측)을 위해 값으로도 준다.
func impact_seconds() -> float:
	var swing := _clip() as CharSwingClip
	if swing == null:
		return -1.0
	return swing.anticipate + swing.strike


## **맞는 순간 멈춰 있는 시간.** 전투가 히트스톱을 이 길이로 걸면 화면과 맞는다.
func hold_seconds() -> float:
	return CharWeapon.new(weapon_cells).hold_seconds()


## 지금 자세. 체인 조건이 확정되면 `앞.to_guard == 뒤.from_guard` 로 쓴다 (§25.11.4).
func closing_guard() -> WeaponGuard.Id:
	var swing := _clip() as CharSwingClip
	return WeaponGuard.Id.NEUTRAL if swing == null else swing.to_guard


## 시각을 직접 넣는다. 캡처·벤치처럼 실시간을 안 기다리는 쪽이 쓴다.
func seek(seconds: float) -> void:
	_time = seconds
	_refresh()


func _process(delta: float) -> void:
	if _done or is_zero_approx(speed):
		return
	var clip := _clip()
	var was := _time
	_time += delta * speed
	if not clip.is_looping() and _time >= clip.loop_seconds():
		_time = clip.loop_seconds()
		_done = true
	else:
		_time = clip.wrap_time(_time)
	_refresh()
	_report_strike(was)


func _build() -> void:
	_rig = CharRig.new()
	_clips = {
		Action.IDLE: CharIdleClip.new(_rig),
		Action.WALK: CharWalkClip.new(_rig),
		Action.RUN: CharRunClip.new(_rig),
		Action.JUMP: CharJumpClip.new(_rig),
		Action.HIT: CharHitClip.new(_rig),
		Action.DIE: CharDieClip.new(_rig),
	}
	_view = CharPartsView.new()
	_view.name = "Parts"
	add_child(_view)
	_rebuild_weapon()


## 무기가 바뀌면 **휘두르기와 그림이 같이 바뀐다.** 휘두르기의 길이가 무기에서 나오므로
## 클립을 다시 만들어야 하고, 그림도 길이 · 두께가 달라진다.
func _rebuild_weapon() -> void:
	if _rig == null:
		return
	var weapon := CharWeapon.new(weapon_cells)
	_clips[Action.SWING] = CharSwingClip.new(_rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, weapon)
	_clips[Action.SWING_UP] = CharSwingClip.new(
		_rig, WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH, weapon
	)
	(_clips[Action.HIT] as CharHitClip).weapon = weapon
	(_clips[Action.DIE] as CharDieClip).weapon = weapon
	_view.weapon = weapon
	_view.setup(_rig)
	_refresh()


func _clip() -> CharClip:
	return _clips[_action]


func _refresh() -> void:
	if _view != null:
		_view.apply_pose(_clip().sample(_time, AnimFeatures.all_on()))


## 검이 닿는 시각을 **지나쳤는지**로 낸다. 정확히 그 프레임을 밟기를 기다리면
## 프레임률에 따라 아예 안 난다 — 웹은 프레임이 튀므로 특히 그렇다.
func _report_strike(was: float) -> void:
	var at := impact_seconds()
	if not _struck and at >= 0.0 and was < at and _time >= at:
		_struck = true
		struck.emit()
	# `_done` 이 선 프레임에만 여기 닿는다 — `_process` 가 그다음부터 바로 돌아 나간다.
	if _done:
		finished.emit(_action)
