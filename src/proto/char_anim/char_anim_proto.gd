extends Node2D
## 캐릭터 애니메이션 프로토타입의 진입점.
##
##     godot --path . res://src/proto/char_anim/char_anim_proto.tscn
##
## 하는 일은 셋이다 — 입력을 읽고, 클립에서 포즈를 뽑고, 뷰에 넘긴다.
## **애니메이션 판단은 하나도 없다.** 그것은 전부 `src/core/char_anim/` 에 있다.
##
## 조작과 설계 근거는 `README.md` 와 `docs/design/25-character-animation.md`.

## 캐릭터 키 146 을 화면에서 약 500 px 로 본다. 눌림 3 % 가 눈에 보이는 최소 배율이다.
const VIEW_SCALE := 3.4

## 발이 닿는 자리. 조절판이 오른쪽을 쓰므로 캐릭터를 왼쪽으로 밀었다.
const GROUND_POSITION := Vector2(470.0, 600.0)

const SKY_TOP := Color(0.478, 0.529, 0.573)
const SKY_BOTTOM := Color(0.353, 0.396, 0.439)
const FLOOR := Color(0.298, 0.333, 0.376)
const FLOOR_LINE := Color(0.239, 0.267, 0.302)
const GUIDE := Color(1.0, 0.294, 0.149, 0.55)
const SKY_BANDS := 28

## 조절판 자리. 캐릭터를 왼쪽으로 밀어 둔 만큼 오른쪽이 비어 있다.
const PANEL_POSITION := Vector2(944.0, 24.0)

## 정지 중에 화살표로 넘기는 한 걸음. 25 fps 캡처와 같은 간격이라 GIF 와 눈이 맞는다.
const STEP_SECONDS := 0.04

var _rig: CharRig
var _clips: Array[CharClip] = []
var _clip_index := 0
var _features := AnimFeatures.all_on()
var _time := 0.0
var _speed := 1.0
var _paused := false
var _show_guides := false

var _view: CharPartsView
var _panel: AnimTuningPanel
var _help: Label
var _status: Label


func _ready() -> void:
	_rig = CharRig.new()
	# 1 idle · 2 walk · 3 내려치기 · 4 올려치기 · 5 정면 문법 대조군.
	# 3 과 4 는 마무리 자세와 시작 자세가 맞물린다 — 이어 붙여 돌려 보라고 둘 다 둔다.
	_clips = (
		[
			CharIdleClip.new(_rig),
			CharWalkClip.new(_rig),
			CharRunClip.new(_rig),
			CharJumpClip.new(_rig),
			CharSwingClip.new(_rig, WeaponGuard.Id.HIGH, WeaponGuard.Id.LOW),
			CharSwingClip.new(_rig, WeaponGuard.Id.LOW, WeaponGuard.Id.HIGH),
			CharHitClip.new(_rig),
			CharFrontIdleClip.new(_rig),
		]
		as Array[CharClip]
	)

	_view = CharPartsView.new()
	_view.name = "PartsView"
	_view.position = GROUND_POSITION
	_view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	add_child(_view)
	_view.setup(_rig)

	_build_overlay()
	_refresh()


## 도구가 시각을 직접 넣을 때 쓴다. 실시간을 안 기다리므로 캡처가 결정적이다.
func set_time(t: float) -> void:
	_time = t
	_refresh()


func set_features(features: AnimFeatures) -> void:
	_features = features.copy()
	if _panel != null:
		_panel.sync_from(_features)
	_refresh()


func current_clip() -> CharClip:
	return _clips[_clip_index]


func _process(delta: float) -> void:
	if _paused:
		return
	_time = current_clip().wrap_time(_time + delta * _speed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_LEFT:
			_step(-STEP_SECONDS)
		KEY_RIGHT:
			_step(STEP_SECONDS)
		KEY_Q:
			_toggle("delay")
		KEY_W:
			_toggle("arc")
		KEY_E:
			_toggle("squash")
		KEY_A:
			_toggle("asymmetry")
		KEY_D:
			_toggle("depth")
		KEY_P:
			_toggle("plant")
		KEY_1:
			_select_clip(0)
		KEY_2:
			_select_clip(1)
		KEY_3:
			_select_clip(2)
		KEY_4:
			_select_clip(3)
		KEY_5:
			_select_clip(4)
		KEY_6:
			_select_clip(5)
		KEY_7:
			_select_clip(6)
		KEY_8:
			_select_clip(7)
		KEY_Z:
			_toggle_all()
		KEY_G:
			_show_guides = not _show_guides
			queue_redraw()
		KEY_TAB:
			_panel.visible = not _panel.visible
		KEY_H:
			_help.visible = not _help.visible
		KEY_BRACKETLEFT:
			_set_speed(_speed - 0.1)
		KEY_BRACKETRIGHT:
			_set_speed(_speed + 0.1)
		KEY_R:
			_time = 0.0
		KEY_ESCAPE:
			get_tree().quit()
	_refresh()


func _draw() -> void:
	var view_size := get_viewport_rect().size
	var floor_y := GROUND_POSITION.y
	for i in SKY_BANDS:
		var u := float(i) / float(SKY_BANDS)
		var band := Rect2(0.0, floor_y * u, view_size.x, floor_y / float(SKY_BANDS) + 1.0)
		draw_rect(band, SKY_TOP.lerp(SKY_BOTTOM, u))
	draw_rect(Rect2(0.0, floor_y, view_size.x, view_size.y - floor_y), FLOOR)
	draw_line(Vector2(0.0, floor_y), Vector2(view_size.x, floor_y), FLOOR_LINE, 2.0)
	if _show_guides:
		_draw_guides()


## 쉬는 자세의 피벗 자리. 파츠가 얼마나 벗어나는지를 눈으로 재는 기준선이다.
func _draw_guides() -> void:
	for part in CharPart.COUNT:
		var rest := _rig.rest_positions[part]
		var at := GROUND_POSITION + Vector2(rest.x, -rest.y) * VIEW_SCALE
		draw_line(at - Vector2(7.0, 0.0), at + Vector2(7.0, 0.0), GUIDE, 1.0)
		draw_line(at - Vector2(0.0, 7.0), at + Vector2(0.0, 7.0), GUIDE, 1.0)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	add_child(layer)

	_panel = AnimTuningPanel.new()
	_panel.name = "TuningPanel"
	# 앵커 프리셋을 쓰지 않는다. `PRESET_TOP_RIGHT` 를 걸면 `position` 이 오른쪽 변
	# 기준의 오프셋으로 해석되어 조절판이 화면 밖으로 나간다 — 실제로 안 보였다.
	_panel.position = PANEL_POSITION
	_panel.features_changed.connect(_on_panel_features)
	_panel.speed_changed.connect(_set_speed)
	layer.add_child(_panel)

	_status = Label.new()
	_status.name = "Status"
	_status.position = Vector2(24.0, 20.0)
	layer.add_child(_status)

	_help = Label.new()
	_help.name = "Help"
	_help.position = Vector2(24.0, 52.0)
	_help.text = (
		"\n"
		. join(
			[
				"1 idle • 2 walk • 3 run • 4 jump • 5 내려치기 • 6 올려치기 • 7 맞기 • 8 정면",
				"Space  멈춤 • 왼쪽 오른쪽 화살표  한 걸음씩",
				"Q 지연 • W 호 • E 배율 • A 비대칭 • D 앞뒤 • P 디딤 • Z 다",
				"G 기준선 • Tab 조절판 • H 도움말 • R 처음으로",
				"대괄호 여닫기  느리게 빠르게 • Esc 나가기",
			]
		)
	)
	layer.add_child(_help)


func _refresh() -> void:
	if _view == null:
		return
	var clip := current_clip()
	_view.apply_pose(clip.sample(_time, _features))
	_status.text = (
		"%s   %.2f / %.2f 초   %s"
		% [clip.clip_name(), _time, clip.loop_seconds(), "멈춤" if _paused else "재생"]
	)


func _step(amount: float) -> void:
	_paused = true
	_time = current_clip().wrap_time(_time + amount)


func _toggle(field: String) -> void:
	_features.set(field, 0.0 if _features.get(field) > 0.0 else 1.0)
	_panel.sync_from(_features)


func _toggle_all() -> void:
	var any_on := (
		_features.delay > 0.0
		or _features.arc > 0.0
		or _features.squash > 0.0
		or _features.asymmetry > 0.0
		or _features.depth > 0.0
		or _features.plant > 0.0
	)
	_features = AnimFeatures.all_off() if any_on else AnimFeatures.all_on()
	_panel.sync_from(_features)


## 클립을 바꿔도 시각을 안 되돌린다. 같은 `t` 의 두 문법을 바로 견줄 수 있어야 한다.
func _select_clip(index: int) -> void:
	_clip_index = clampi(index, 0, _clips.size() - 1)
	_time = current_clip().wrap_time(_time)


func _set_speed(speed: float) -> void:
	_speed = clampf(speed, AnimTuningPanel.SPEED_MIN, AnimTuningPanel.SPEED_MAX)
	_panel.set_speed_display(_speed)


func _on_panel_features(features: AnimFeatures) -> void:
	_features = features
	_refresh()
