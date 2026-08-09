class_name CharActor
extends Node2D
## 캐릭터 하나. **다른 레인이 쓰는 얼굴이다.**
##
## 붙이고, `play()` 를 부르고, 무기 칸 수를 주면 끝난다. 리그도 클립도 포즈도 안 보인다.
##
## ```gdscript
## var actor := CharActor.new()
## add_child(actor)
## actor.weapon_cells = 4     # 무게 (총 칸 수)
## actor.weapon_span = 2      # 길이 (긴 쪽 칸 수) -> 2x2 철퇴
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

## **무너졌다.** 눈금이 문턱을 넘어 상태가 바뀌었다 — 이때 비로소 경직·띄우기·쓰러짐이다.
signal broke_down

enum Action { IDLE, WALK, RUN, JUMP, SWING, SWING_UP, HIT, DIE }

## 화면에서 캐릭터 키(141)를 몇 배로 볼 것인가. 쓰는 쪽이 정한다.
const DEFAULT_SCALE := 1.0

## 무기의 **총 칸 수 = 무게.** 휘두르는 시간 · 멈춤 · 몸 끌림이 여기서 나온다.
@export_range(1, 4) var weapon_cells := 1:
	set(value):
		var next := clampi(value, CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS)
		if next == weapon_cells:
			return
		weapon_cells = next
		_rebuild_weapon()

## 무기의 **긴 쪽 칸 수 = 길이.** 궤적 반경과 가장 가파른 각도가 여기서 나온다.
##
## **총 칸 수와 따로 준다.** 같은 4 칸이라도 `4×1` 은 길고 `2×2` 는 짧다 (§25.20).
@export_range(1, 4) var weapon_span := 1:
	set(value):
		var next := clampi(value, CharWeapon.MIN_CELLS, CharWeapon.MAX_CELLS)
		if next == weapon_span:
			return
		weapon_span = next
		_rebuild_weapon()

## `+1` 이면 오른쪽, `-1` 이면 왼쪽을 본다.
@export var facing := 1:
	set(value):
		facing = 1 if value >= 0 else -1
		scale.x = absf(scale.x) * float(facing)

## 재생 속도. 0 이면 멈춘다.
@export var speed := 1.0

## **무너짐 문턱.** 쌓인 눈금이 이걸 넘으면 상태가 바뀐다 (§28.5).
##
## 넘기 전까지는 **때리던 동작이 계속 돈다** — 맞아도 안 멈춘다.
## **전투 레인이 확정한 값이다** — 경직 30 · 띄우기 60 · 쓰러짐 100.
@export var breakdown_at := CharHitClip.STUN_AT

## 눈금이 잦아드는 빠르기(초당). 안 맞으면 서서히 회복된다.
##
## **전투 레인이 20 에서 10 으로 옮겼다.** 20 이면 1 칸은 한 방의 29 %, 4 칸은 7 % 만
## 남아서 **아홉 타가 다섯 타와 같은 데서 만난다** — *"문턱은 그 폭을 나눌 뿐
## 폭을 만들지 못한다."* 문턱이 아니라 감쇠가 폭을 만든다.
@export var stagger_recovery := 10.0

## 얹는 연출 장치들 (§25.23). 바꾸면 바로 반영된다.
var flourish := CharFlourish.none():
	set(value):
		flourish = value
		if _view != null:
			_view.flourish = value
		_refresh()

var _rig: CharRig
var _view: CharPartsView
var _clips: Dictionary[Action, CharClip] = {}
var _action := Action.IDLE
var _time := 0.0
var _done := false
var _struck := false

## **반응 층.** 맞은 것을 클립이 아니라 힘으로 들고 있다 (§25.27).
var _reaction := CharReaction.new()
var _stagger := 0.0

## 밀리기 전 제자리. 뿌리 이동을 여기서 잰다.
var _home := Vector2.ZERO


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


## **맞았다.** 동작을 안 바꾼다 — 지금 하던 것 위에 충격을 얹을 뿐이다.
##
## 눈금이 문턱을 넘어야 비로소 상태가 바뀐다. 그래서 **때리다 맞으면 스윙이 계속 돌고
## 그 위에 흔들림이 얹힌다** — 전환이 없다.
##
## `power` 는 **§28.5 의 무너짐 눈금**이다 (쓰러짐이 100). 그 단위는 전투가 정한다.
##
## **밀림의 세기는 같은 축의 다른 단위다.** 한 방에 눕히는 값(100)을 `1` 로 두고 나눈다 —
## 눈금을 그대로 넣으면 어떤 타격이든 누적 상한에 붙어서 **1 칸과 4 칸이 같아 보인다.**
func take_hit(power: float, direction := -1.0) -> void:
	_reaction.strike(_time, power / CharHitClip.FALL_AT, direction)
	_stagger += power
	_refresh()


## 지금 쌓인 무너짐. `0` … `breakdown_at` 을 넘으면 무너진다.
func stagger() -> float:
	return _stagger


## **어디까지 무너졌나.** `broke_down` 을 받고 읽으면 된다 (경직 · 띄우기 · 쓰러짐).
func breakdown_depth() -> CharHitClip.Depth:
	return (_clips[Action.HIT] as CharHitClip).depth


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
	return swing.anticipate + swing.still + swing.strike


## **히트스톱 길이(초).** 전투가 이 시간 동안 **때린 쪽과 맞은 쪽을 같이** 멈추면 된다.
##
## 휘두르는 쪽 혼자 멈추는 것은 절반이다 — 타격감은 둘이 동시에 설 때 난다.
## 눈금도 같이 멈춰야 화면과 규칙이 안 갈린다 (§25.19.2).
func hitstop_seconds() -> float:
	return CharWeapon.new(weapon_cells, weapon_span).hitstop_seconds()


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
	_settle_stagger(delta)


## 눈금은 안 맞으면 잦아든다. 넘으면 **그때 비로소** 상태가 바뀐다.
##
## 상태가 바뀔 때 **진동을 지운다** — `hit` 클립이 이미 큰 반응을 갖고 있어서
## 진동까지 남기면 같은 사건을 두 번 세는 것이 된다 (§25.27.3).
func _settle_stagger(delta: float) -> void:
	_reaction.forget_spent(_time)
	if _stagger >= breakdown_at and _action != Action.HIT and _action != Action.DIE:
		# **깊이를 지우기 전에 읽는다.** 눈금이 어디까지 갔는지가 곧 어디까지 무너지는지다.
		(_clips[Action.HIT] as CharHitClip).depth = CharHitClip.depth_for(_stagger)
		_stagger = 0.0
		_reaction.clear()
		play(Action.HIT)
		broke_down.emit()
		return
	_stagger = maxf(0.0, _stagger - stagger_recovery * delta)


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
	_home = _view.position
	_rebuild_weapon()


## 무기가 바뀌면 **휘두르기와 그림이 같이 바뀐다.** 휘두르기의 길이가 무기에서 나오므로
## 클립을 다시 만들어야 하고, 그림도 길이 · 두께가 달라진다.
func _rebuild_weapon() -> void:
	if _rig == null:
		return
	var weapon := CharWeapon.new(weapon_cells, weapon_span)
	_clips[Action.SWING] = CharSwingClip.new(_rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW, weapon)
	_clips[Action.SWING_UP] = CharSwingClip.new(
		_rig, WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH, weapon
	)
	(_clips[Action.HIT] as CharHitClip).weapon = weapon
	(_clips[Action.DIE] as CharDieClip).weapon = weapon
	_view.weapon = weapon
	_view.flourish = flourish
	_view.setup(_rig)
	_refresh()


func _clip() -> CharClip:
	return _clips[_action]


func _refresh() -> void:
	if _view == null:
		return
	# **뷰가 자기 장식을 스스로 만든다.** 클립과 시각만 주면 되므로 캡처 도구도 같은 길을 쓴다.
	# **히트스톱** — 맞는 순간 동작이 멈춘다. 충격은 실제 시각으로 계속 잦아든다.
	var play_t := _time - _reaction.stalled(_time)
	_view.show_at(_clip(), play_t, impact_seconds(), _reaction, _time)
	# **뿌리가 통째로 밀린다.**
	_view.position = _home + _reaction.root_offset(_time)


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
