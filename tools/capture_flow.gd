extends SceneTree
## 화면 흐름을 **실제로 부팅해서 눌러 돌고** 단계마다 한 장씩 남긴다.
##
##     godot --path . -s res://tools/capture_flow.gd
##
## 헤드리스 시험을 통과하고도 화면에서 파싱 에러로 터진 전례가 있다(CLAUDE.md).
## 그리고 `SceneRouter` 의 마지막 한 줄(`change_scene_to_file`)은 GUT 이 못 덮는다 —
## 부르는 순간 러너가 선 씬이 사라지기 때문이다. **그 한 줄을 덮는 것이 이 도구다**
## (docs/design/34-systems.md §34.6).
##
## **창을 한 번만 띄운다.** 캡처마다 새로 띄우면 GL 컨텍스트를 그때마다 새로 만들게 되고,
## 그것이 드라이버를 흔들어 세션이 끊긴 적이 있다 (CLAUDE.md — GPU 를 나눠 쓴다).
##
## 상태를 직접 건드리지 않고 **실제 버튼을 누른다.** 그래야 배선까지 검증된다.
##
## 주둔지 화면은 진짜 세이브(`user://save/guild.json`)를 읽는다.
## 저장된 진행이 있으면 「이어서 한다」로, 없으면 새 길드로 뜬다 — **둘 다 정상이다.**
##
## ## ⚠ 이 도구는 **진짜 세이브에 쓴다**
##
## 정산 단계를 지나면 자동 저장이 걸린다 (docs/design/36-settlement.md §36.6).
## 그것이 이 도구가 덮는 것의 절반이다 — 저장이 흐름 위에서 실제로 도는지는
## 진짜 경로로 돌지 않으면 확인되지 않는다. 대신 **돌릴 때마다 원정 한 번이 쌓인다.**

const _OUT_DIR := "res://.captures"

## 한 단계가 자리를 잡을 때까지 두는 시간(초).
##
## 프레임이 아니라 **시간**으로 재는 이유가 있다. 타이틀은 박이 종이에 닿기까지
## 0.42초를 두고(TitleScreen), 창의 주사율은 기계마다 다르다.
## 프레임으로 기다리면 어떤 기계에서는 연출 도중에 찍힌다.
const _SETTLE_SECONDS := 1.4

## 한 단계 — **무엇이 뜨기를 기다려서 · 찍고 · 무엇을 누르는가.**
##
## `shot` 이 비면 안 찍는다. 편성처럼 **누르기만 하는 단계**가 있고,
## 그것까지 찍으면 같은 화면이 넉 장 나온다.
##
## `optional` 은 **없어도 넘어가는 단계**다. 편성은 정원과 아지트 레벨에 따라
## 몇 명까지 되는지가 달라지므로(GuildBalance.squad_capacity), 세 번째 대원은
## 있을 수도 없을 수도 있다. **없는 것과 고장난 것을 가르려고 표시한다** —
## 표시가 없는 단계에서 단추를 못 찾으면 그것은 흐름이 끊긴 것이다.
const _STEPS: Array[Dictionary] = [
	{"want": "TitleScreen", "shot": "01_title", "press": "들어간다"},
	{"want": "BaseScreen", "shot": "02_base", "press": "데려간다"},
	{"want": "BaseScreen", "shot": "", "press": "데려간다", "optional": true},
	{"want": "BaseScreen", "shot": "", "press": "데려간다", "optional": true},
	{"want": "BaseScreen", "shot": "03_deployed", "press": "원정을 나간다"},
	{"want": "DungeonScreen", "shot": "04_dungeon", "press": "원정을 접는다"},
	{"want": "SettlementScreen", "shot": "05_settlement", "press": "주둔지로"},
	{"want": "BaseScreen", "shot": "06_returned", "press": ""},
]

var _step := 0
var _waited := 0.0
var _found: Node = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUT_DIR))
	# 진짜 부팅 경로로 시작한다. 화면을 직접 띄우면 main 이 하는 일이 안 돈다.
	var boot: Node = (
		load(String(ProjectSettings.get_setting("application/run/main_scene"))).instantiate()
	)
	root.add_child(boot)
	# `change_scene_to_file` 은 현재 씬을 지우고 새것을 앉힌다. 손으로 붙인 것은
	# 현재 씬이 아니므로, 알려 주지 않으면 부팅 화면이 안 치워진다.
	current_scene = boot


func _process(delta: float) -> bool:
	if _step >= _STEPS.size():
		return true
	var step := _STEPS[_step]
	if _found == null:
		_found = _find_class(String(step["want"]))
		if _found == null:
			return false
		_waited = 0.0
		print("flow: %s 가 떴다" % step["want"])
	_waited += delta
	if _waited < _SETTLE_SECONDS:
		return false
	var shot := String(step["shot"])
	if not shot.is_empty():
		_save(shot)
	var press := String(step["press"])
	if not press.is_empty() and not _press(press):
		if not bool(step.get("optional", false)):
			push_warning("누를 버튼을 못 찾았다: %s" % press)
			return true
		print("flow: 건너뛴다 — %s (없어도 되는 단계)" % press)
	_step += 1
	_found = null
	if _step >= _STEPS.size():
		print("flow: 지나온 길 = %s" % _router_trail())
		return true
	return false


## 라우터가 기억하는 길. **되돌아가기가 정말 되감았는지**가 여기서 보인다.
func _router_trail() -> String:
	var router := root.get_node_or_null("Router")
	return "" if router == null else String(router.call("trail"))


func _save(name: String) -> void:
	var path := "%s/flow_%s.png" % [_OUT_DIR, name]
	var error := root.get_texture().get_image().save_png(path)
	print("capture: %s (err=%d)" % [path, error])


func _press(text: String) -> bool:
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == text and not button.disabled and button.is_visible_in_tree():
			button.pressed.emit()
			print("flow: 눌렀다 — %s" % text)
			return true
	return false


func _find_class(class_text: String) -> Node:
	var found := root.find_children("*", class_text, true, false)
	return null if found.is_empty() else found[0]
