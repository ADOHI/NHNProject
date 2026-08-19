class_name SceneRouteStack
extends RefCounted
## 지나온 화면과 **되돌아갈 곳.** 노드도 트리도 모른다.
##
## ## 왜 갈라 두었나
##
## `change_scene_to_file()` 은 **지금 떠 있는 씬을 통째로 갈아 끼운다.** GUT 안에서
## 부르면 시험 러너가 서 있는 씬이 사라진다. 그래서 **판단은 여기서 하고
## 바꾸는 한 줄만 노드(SceneRouter)에 남긴다** (docs/design/34-systems.md §34.3.2).
##
## ## 다시 들른 화면은 쌓이지 않고 **되감긴다**
##
## 던전에서 주둔지로 가는 것은 「더 깊이 들어가는 것」이 아니라 「돌아오는 것」이다.
## 쌓기만 하면 되돌아가기가 주둔지 → 던전 → 주둔지 를 거꾸로 밟는 길이 되고,
## 그것은 아무도 기대하지 않는 움직임이다.
##
## 그래서 이미 지나온 화면으로 가면 **거기까지 잘라 낸다.** 덤으로 얻는 성질이 있다 —
## 같은 화면이 두 번 들어가지 않으므로 **깊이가 화면 수를 넘지 못한다.**

## 지나온 화면들. 마지막이 지금이다.
var _visited: Array[int] = []

## 각 화면이 **들어올 때 받았던 값.** 되돌아가면 그것을 다시 준다 —
## 그러지 않으면 돌아온 화면이 자기가 어떤 맥락에 있었는지 잊는다.
var _payloads: Array[Dictionary] = []

## 아직 아무도 꺼내 가지 않은 값.
var _pending: Dictionary = {}


## 화면 하나로 간다. 모르는 화면이면 아무 일도 없이 false 다.
func push(screen: int, payload: Dictionary = {}) -> bool:
	if not SceneRoutes.is_known(screen):
		return false
	var seen := _visited.find(screen)
	if seen != -1:
		_visited.resize(seen)
		_payloads.resize(seen)
	_visited.append(screen)
	_payloads.append(payload.duplicate(true))
	_pending = payload.duplicate(true)
	return true


## 한 칸 되돌아간다. 돌아갈 곳이 없으면 -1 이고 아무것도 바뀌지 않는다.
func pop() -> int:
	if _visited.size() < 2:
		return -1
	_visited.resize(_visited.size() - 1)
	_payloads.resize(_payloads.size() - 1)
	_pending = _payloads[_payloads.size() - 1].duplicate(true)
	return _visited[_visited.size() - 1]


## 지금 화면. 아직 아무 데도 안 갔으면 -1 이다.
func current() -> int:
	return -1 if _visited.is_empty() else _visited[_visited.size() - 1]


## 되돌아가면 닿을 화면. 없으면 -1 이다.
func previous() -> int:
	return -1 if _visited.size() < 2 else _visited[_visited.size() - 2]


func can_go_back() -> bool:
	return _visited.size() >= 2


func depth() -> int:
	return _visited.size()


## 지나온 길. 개발 패널이 그대로 찍는다 (docs/conventions.md §8).
func history() -> Array[int]:
	return _visited.duplicate()


## 넘어온 값을 꺼낸다. **한 번만 준다.**
##
## 남겨 두면 나중에 그 화면에 그냥 들어왔을 때 **지난번 값이 딸려 나온다** —
## 조용히 틀린 화면이 뜨는 종류의 버그다.
func take_payload() -> Dictionary:
	var taken := _pending
	_pending = {}
	return taken


## 꺼내지 않고 들여다본다. 개발 패널용이다.
func peek_payload() -> Dictionary:
	return _pending.duplicate(true)


## 처음으로 되돌린다. 새 게임을 시작하는 자리에서 쓴다.
func clear() -> void:
	_visited.clear()
	_payloads.clear()
	_pending = {}
