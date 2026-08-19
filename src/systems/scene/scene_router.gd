class_name SceneRouter
extends Node
## 화면을 갈아 끼우는 유일한 곳. 오토로드 `Router` 로 등록되어 있다.
##
##     Router.go_to(SceneRoutes.Screen.BASE)
##     Router.go_to(SceneRoutes.Screen.DUNGEON, {"gate_seed": 1234})
##     Router.back()
##
## **화면이 서로를 직접 부르지 않는다.** 부르기 시작하면 화면이 늘어날 때마다
## 그래프가 얽히고, 어디서 어디로 갈 수 있는지 아는 곳이 없어진다
## (docs/design/34-systems.md §34.3).
##
## ## 이 노드는 얇다
##
## 되돌아갈 곳과 넘길 값은 `SceneRouteStack` 이 안다. 여기 남는 판단은
## **경로가 실제로 있는가** 하나이고, 나머지 한 줄이 `change_scene_to_file()` 이다.
## 그 한 줄은 시험이 못 덮는다 — GUT 안에서 부르면 러너가 선 씬이 사라지기 때문이다.
## 대신 `tools/capture_flow.gd` 가 실제 창에서 눌러 돌며 덮는다 (§34.6).

## 화면이 바뀌었다. 전환 연출은 나중에 여기 붙는다 (§34.3.5).
signal screen_changed(screen: int)

## 못 갔다. **조용히 실패하지 않는다** — 사유를 신호로도 내고 경고로도 남긴다.
signal route_failed(screen: int, reason: String)

var _stack := SceneRouteStack.new()


## 이 화면으로 간다. 갈 수 없으면 아무것도 바뀌지 않고 false 다.
func go_to(screen: int, payload: Dictionary = {}) -> bool:
	var path := resolve(screen)
	if path.is_empty():
		var reason := (
			"장부에 없는 화면" if not SceneRoutes.is_known(screen) else "씬 파일이 없다"
		)
		push_warning("전환 실패 (%d): %s" % [screen, reason])
		route_failed.emit(screen, reason)
		return false
	_stack.push(screen, payload)
	return _swap(screen, path)


## 한 칸 되돌아간다. 돌아갈 곳이 없으면 false 다.
func back() -> bool:
	var screen := _stack.pop()
	if screen == -1:
		return false
	return _swap(screen, SceneRoutes.path_of(screen))


## **실제로 갈아 끼우지 않고 목적지만 계산한다.** 없는 화면이면 빈 문자열이다.
##
## 시험이 화면 전부를 이걸로 훑는다 — 씬을 옮겨 놓고 장부를 안 고치면 여기서 잡힌다.
func resolve(screen: int) -> String:
	var path := SceneRoutes.path_of(screen)
	if path.is_empty() or not ResourceLoader.exists(path):
		return ""
	return path


## 넘어온 값. **한 번만 준다** (SceneRouteStack.take_payload).
func take_payload() -> Dictionary:
	return _stack.take_payload()


func current() -> int:
	return _stack.current()


func can_go_back() -> bool:
	return _stack.can_go_back()


func history() -> Array[int]:
	return _stack.history()


## 지나온 길 한 줄. 개발 패널에 그대로 나간다 (docs/conventions.md §8).
func trail() -> String:
	var names := PackedStringArray()
	for screen in _stack.history():
		names.append(SceneRoutes.label(screen))
	return " > ".join(names)


## 기록을 비운다. 새 게임을 시작하는 자리에서 쓴다. 화면은 바꾸지 않는다.
func forget() -> void:
	_stack.clear()


func _swap(screen: int, path: String) -> bool:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_warning("씬 전환 오류 %d: %s" % [error, path])
		route_failed.emit(screen, "전환 오류 %d" % error)
		return false
	screen_changed.emit(screen)
	return true
