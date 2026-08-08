class_name TitleStage
extends Control
## **타이틀 화면의 무대.** 겹을 배치표대로 쌓고, 겹마다 다른 박자로 움직인다.
##
## 한 장짜리 그림은 아무것도 못 움직인다. 그래서 요소를 따로 뽑아 여기서 합친다
## (docs/design/21-title.md §21.13).
##
##   배경   거의 안 움직인다
##   원경   악마. 떠 있고 흔들린다. **사람을 본다**
##   중앙   금. 화면의 주인공이자 유일한 광원. 갈라진 자리가 맥동한다
##   중경   사람. **한 번에 하나씩** 다가온다. 이 게임은 턴제다
##   전경   가장 빨리 흐른다
##
## 그림이 **아직 없어도 돌아간다.** `src/ui/title/art/<겹이름>.png` 가 있으면 쓰고,
## 없으면 그 자리에 표를 그린다. 생성 순번을 기다리는 동안 이렇게 만들었다.

## 그림을 찾는 곳. 파일 이름이 곧 겹 이름이다.
##
## 최상위 `assets/` 가 아니라 **기능 폴더 안**이다. 컨벤션이 기준을 명시한다 —
## *사용처가 둘 이상이면 `assets/`, 하나면 기능 폴더 안* (docs/conventions.md §1).
## 이 그림 열 장은 소비처가 타이틀 하나뿐이다.
const _ART_DIR := "res://src/ui/title/art/"

## 커서를 따라 판이 기우는 최대 폭(px). 크게 주면 화면이 출렁이는 장난감이 된다.
const _SWAY := 26.0

## 커서가 멈춰 있어도 판은 아주 느리게 숨 쉰다. **가만히 둬도 죽으면 안 된다.**
const _BREATH := 9.0
const _BREATH_SECONDS := 13.0

## 사람이 금 쪽으로 한 걸음 다가가는 거리(자기 폭 기준)와 그 시간.
const _CREEP := 0.055
const _CREEP_SECONDS := 0.62

## 다가갈 수 있는 최대치. 이보다 붙으면 그림이 겹쳐 뭉갠다.
const _CREEP_CAP := 0.34

var _layers: Array[StageLayer] = []
var _hunters: Array[StageLayer] = []
var _plan: ApproachPlan
var _sway := Vector2.ZERO
var _target_sway := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_lay_out()
	resized.connect(_lay_out)
	_plan = ApproachPlan.new(_hunters.size(), 8821)
	_keep_creeping()


func _process(delta: float) -> void:
	var seconds := UiMotion.clock()
	# 커서를 따라가되 곧바로 붙지 않는다. 판은 무겁다.
	_sway = _sway.lerp(_target_sway, clampf(delta * 3.2, 0.0, 1.0))
	var breath := Vector2(
		sin(seconds * TAU / _BREATH_SECONDS), cos(seconds * TAU / (_BREATH_SECONDS * 1.4)) * 0.45
	)
	var drift := _sway + breath * _BREATH
	for layer in _layers:
		layer.offset = TitleLayers.drift_of(layer.spec, drift) + _bob(layer, seconds)
		layer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var away := (event as InputEventMouseMotion).position / size - Vector2(0.5, 0.5)
		# 판이 커서를 **밀어내는** 쪽으로 기운다. 따라가면 커서가 판을 끌고 다니는 것이 된다.
		_target_sway = -away * _SWAY * 2.0


## 겹마다 제자리에서 도는 작은 움직임. 시차와 별개로 더해진다.
func _bob(layer: StageLayer, seconds: float) -> Vector2:
	match layer.spec.role:
		TitleLayers.Role.DEMON:
			# 떠 있는 것은 가라앉지 않는다. 겹마다 주기를 달리해 한 몸으로 안 보이게 한다.
			var lift := sin(seconds * 0.9 + layer.spec.depth * 21.0) * 7.0
			return Vector2(sin(seconds * 0.6 + layer.spec.depth * 11.0) * 4.0, lift)
		TitleLayers.Role.HOARD:
			# 금은 광원이라 흔들리면 화면 전체가 흔들리는 것으로 보인다. 아주 조금만.
			return Vector2(0.0, sin(seconds * 1.3) * 1.5)
		_:
			return Vector2.ZERO


func _build() -> void:
	for spec in TitleLayers.plan():
		var layer := StageLayer.new()
		layer.spec = spec
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(layer)
		layer.adopt(_art_for(spec.id))
		_layers.append(layer)
		if spec.role == TitleLayers.Role.HUNTER:
			_hunters.append(layer)


## 그림이 있으면 물린다. 없으면 null — 겹이 알아서 자리 표시를 그린다.
func _art_for(id: String) -> Texture2D:
	var path := _ART_DIR + id + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _lay_out() -> void:
	var specs := TitleLayers.plan()
	for layer in _layers:
		# 사람은 자기가 보는 것(금) 쪽으로 다가간다. 시선과 걸음이 같은 값을 쓴다.
		var toward := Vector2.ZERO
		if layer.spec.role == TitleLayers.Role.HUNTER:
			var seen := TitleLayers.find(specs, layer.spec.watching)
			if seen != null:
				toward = seen.anchor
		layer.lay_out(size, toward)


## **한 번에 하나씩 다가온다.** 순서는 ApproachPlan 이 정한다.
##
## 이 게임은 턴제다(docs/design/02-overview.md §2.2). 넷이 한꺼번에 달려들면
## 그것은 실시간 액션이고, 우리가 보여야 하는 것은 순서가 있는 판이다.
func _keep_creeping() -> void:
	get_tree().create_timer(_plan.wait()).timeout.connect(_creep_once)


func _creep_once() -> void:
	var index := _plan.next()
	if index >= 0 and index < _hunters.size():
		var hunter := _hunters[index]
		if hunter.closed < _CREEP_CAP:
			var reach: float = minf(hunter.closed + _CREEP, _CREEP_CAP)
			var tween := create_tween()
			(
				tween
				# 무게가 먼저 가고 몸이 따라온다. 선형으로 오면 미끄러지는 그림이다.
				. tween_property(hunter, "closed", reach, _CREEP_SECONDS)
				. set_ease(Tween.EASE_OUT)
				. set_trans(Tween.TRANS_BACK)
			)
	_keep_creeping()
