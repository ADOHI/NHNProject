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
##
## **26 에서 올렸다.** 26 에서는 커서를 화면 끝에서 끝까지 끌어도 금과 사람이
## 서로 10~20px 밖에 안 어긋나서, 심사자 둘이 최대 입력에서도 시차를 못 알아봤다
## (docs/design/21-title.md §21.14.3). **최대 입력에서 안 보이면 진폭 문제다.**
##
## 진폭과 분배를 같이 고쳤다 — 분배는 `TitleLayers.depth_share` 가 진다.
## 이 값만 키우면 안 보이는 두 겹(배경 · 전경)이 늘어난 예산을 다 먹는다.
const _SWAY := 58.0

## 커서가 멈춰 있어도 판은 느리게 흐른다. **가만히 둬도 죽으면 안 된다.**
##
## **9px / 13초에서 올렸다.** 그것은 없는 것과 같았다 — 타이틀 화면은 대부분의
## 시간이 idle 인데 **깊이를 만드는 장치가 입력에만 걸려 있었다.**
## 마우스를 안 만지는 사람에게 이 화면은 완전히 정지한 그림이었다.
##
## 진폭을 커서의 절반쯤 주고 주기를 늘렸다. 커서보다 작아야 하는 이유는,
## 자동 표류가 커서를 이기면 **내가 만지는 것이 화면에 안 나타나기** 때문이다.
const _BREATH := 24.0
const _BREATH_SECONDS := 17.0

## 자동 표류의 가로세로 비. 세로가 작아야 **떠다니는 것이 아니라 둘러보는 것**이 된다.
const _BREATH_RISE := 0.38

## 자동 표류의 둘째 박자. 하나만 쓰면 왕복이 시계추로 읽힌다.
##
## 주기를 정수배가 아닌 값으로 어긋내야 두 박자가 겹쳐 **같은 자리로 안 돌아온다.**
const _BREATH_SECONDS_SLOW := 41.0
const _BREATH_SLOW_SHARE := 0.42

## 사람이 금 쪽으로 한 걸음 다가가는 거리(자기 폭 기준)와 그 시간.
const _CREEP := 0.055
const _CREEP_SECONDS := 0.62

## 다가갈 수 있는 최대치. 이보다 붙으면 그림이 겹쳐 뭉갠다.
const _CREEP_CAP := 0.34

## 켜진 장치. **사용자가 직접 껐다 켜며 무엇이 무엇을 만드는지 가른다.**
var toggles := TitleToggles.new()

var _layers: Array[StageLayer] = []
var _hunters: Array[StageLayer] = []
var _plan: ApproachPlan
var _sway := Vector2.ZERO
var _target_sway := Vector2.ZERO
var _hint: Label = null


## 판이 밀릴 수 있는 최대치(px). 커서 최대 + 자동 표류 최대다.
##
## 밖으로 내놓는 이유는 **여백 검사가 이 값을 알아야 하기 때문**이다. 진폭을
## 키우면서 여백을 안 재면 배경 가장자리가 드러나고, 그 순간 판이 종이 한 장이 된다.
## 상수를 테스트에 베껴 두면 다음에 진폭을 바꿀 때 조용히 어긋난다.
static func max_sway() -> float:
	return _SWAY + _BREATH


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_build_hint()
	_lay_out()
	resized.connect(_lay_out)
	_plan = ApproachPlan.new(_hunters.size(), 8821)
	_keep_creeping()


func _process(delta: float) -> void:
	var seconds := UiMotion.clock()
	# 커서를 따라가되 곧바로 붙지 않는다. 판은 무겁다.
	_sway = _sway.lerp(_target_sway, clampf(delta * 3.2, 0.0, 1.0))
	var drift := Vector2.ZERO
	if toggles.is_on(TitleToggles.Device.PARALLAX):
		drift = _sway + _breath(seconds)
	for layer in _layers:
		var bob := Vector2.ZERO
		if toggles.is_on(TitleToggles.Device.VFX):
			bob = _bob(layer, seconds)
		layer.tinted = toggles.is_on(TitleToggles.Device.SHADER)
		layer.offset = TitleLayers.drift_of(layer.spec, drift) + bob
		layer.queue_redraw()


## 마우스가 없어도 도는 표류. **박자를 둘 겹쳐서 같은 자리로 안 돌아오게 한다.**
##
## 하나만 쓰면 왕복이 시계추가 되고, 시계추는 몇 초 만에 다 읽혀서 그다음부터
## 아무것도 아니다. 주기가 어긋난 둘을 더하면 마루가 매번 다른 자리에 온다.
func _breath(seconds: float) -> Vector2:
	var fast := Vector2(
		sin(seconds * TAU / _BREATH_SECONDS),
		cos(seconds * TAU / (_BREATH_SECONDS * 1.4)) * _BREATH_RISE
	)
	var slow := Vector2(
		sin(seconds * TAU / _BREATH_SECONDS_SLOW),
		cos(seconds * TAU / (_BREATH_SECONDS_SLOW * 1.3)) * _BREATH_RISE
	)
	return (fast * (1.0 - _BREATH_SLOW_SHARE) + slow * _BREATH_SLOW_SHARE) * _BREATH


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var away := (event as InputEventMouseMotion).position / size - Vector2(0.5, 0.5)
		# 판이 커서를 **밀어내는** 쪽으로 기운다. 따라가면 커서가 판을 끌고 다니는 것이 된다.
		_target_sway = -away * _SWAY * 2.0


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == TitleToggles.KEY_HINT:
		show_toggle_hint(_hint != null and not _hint.visible)
		return
	if toggles.toggle_by_key(key.keycode) >= 0:
		_refresh_hint()


## 안내 줄을 보이거나 감춘다. **필름을 뽑을 때는 도구가 이걸 끈다** —
## 판정용 화면에 우리 계기판이 찍혀 있으면 심사자가 그것부터 짚는다.
func show_toggle_hint(value: bool) -> void:
	if _hint != null:
		_hint.visible = value


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


## 토글 안내. 화면 아래 왼쪽에 한 줄로 깔린다.
##
## 켜 둔 상태로 시작하는 이유는 **사용자가 누를 것이 있다는 사실을 알아야** 하기
## 때문이다. 0 으로 접을 수 있고, 필름을 뽑는 도구는 직접 끈다.
func _build_hint() -> void:
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = UiTokens.SPACE_GAP
	_hint.offset_top = -float(UiTokens.SPACE_GAP + UiTokens.TYPE_LABEL * 2)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", UiTokens.TYPE_LABEL)
	# 이 화면은 어둡다. 종이색 글자에 먹색 외곽선을 둘러야 겹 위에서도 읽힌다.
	_hint.add_theme_color_override("font_color", UiTokens.PAPER)
	_hint.add_theme_color_override("font_outline_color", UiTokens.MARK_DEEP)
	_hint.add_theme_constant_override("outline_size", 6)
	add_child(_hint)
	_refresh_hint()


func _refresh_hint() -> void:
	if _hint != null:
		_hint.text = toggles.hint()


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
