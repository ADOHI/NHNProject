class_name ProtoUnitSelection
extends RefCounted
## 지금 무엇이 선택되어 있는가. 화면도 유닛도 모르는 순수 상태다.
##
## 선택은 조작감의 절반이다. 클릭 한 번이 무엇을 뜻하는지(교체인지 추가인지 토글인지)가
## 화면 코드에 흩어져 있으면 규칙이 조용히 어긋난다. 여기 한 곳에만 둔다.

## 선택이 바뀔 때마다 알린다. 화면은 이 신호만 보고 다시 그린다.
signal changed

## 삽입 순서를 보존해야 하는 이유는 부대 지정에 그대로 넘어가기 때문이다.
## Dictionary 를 집합으로 쓰면 순서가 유지되고 포함 검사가 상수 시간이다.
var _ids: Dictionary = {}


## 선택된 id 목록. 선택한 순서를 유지한다.
func ids() -> PackedInt32Array:
	var result := PackedInt32Array()
	for id: int in _ids:
		result.append(id)
	return result


func size() -> int:
	return _ids.size()


func is_empty() -> bool:
	return _ids.is_empty()


func has(id: int) -> bool:
	return _ids.has(id)


## 통째로 갈아 끼운다. 수식키 없는 클릭과 드래그가 이것을 쓴다.
func replace(new_ids: PackedInt32Array) -> void:
	var next: Dictionary = {}
	for id in new_ids:
		next[id] = true
	if next.size() == _ids.size() and _same_keys(next):
		return
	_ids = next
	changed.emit()


func add(new_ids: PackedInt32Array) -> void:
	var touched := false
	for id in new_ids:
		if not _ids.has(id):
			_ids[id] = true
			touched = true
	if touched:
		changed.emit()


func remove(old_ids: PackedInt32Array) -> void:
	var touched := false
	for id in old_ids:
		if _ids.erase(id):
			touched = true
	if touched:
		changed.emit()


## Shift 클릭. 이미 있으면 빼고 없으면 넣는다.
##
## 스타크래프트가 이 규칙을 쓰는 이유는 잘못 넣은 하나를 빼는 데 별도 키가 필요 없기 때문이다.
func toggle(id: int) -> void:
	if _ids.has(id):
		_ids.erase(id)
	else:
		_ids[id] = true
	changed.emit()


## Shift 드래그. 박스에 걸린 것을 **더하기만** 한다.
##
## 드래그에 토글을 적용하면 박스가 기존 선택을 스칠 때마다 절반이 빠져 결과를 예측할 수 없다.
func add_from_box(boxed: PackedInt32Array) -> void:
	add(boxed)


func clear() -> void:
	if _ids.is_empty():
		return
	_ids.clear()
	changed.emit()


## 사라진 유닛을 선택에서 떨군다. 이번 프로토타입에는 죽음이 없지만
## 유닛 수를 줄이는 조절이 있어 필요하다.
func retain(alive: PackedInt32Array) -> void:
	var alive_set: Dictionary = {}
	for id in alive:
		alive_set[id] = true
	var dropped := PackedInt32Array()
	for id: int in _ids:
		if not alive_set.has(id):
			dropped.append(id)
	remove(dropped)


func _same_keys(other: Dictionary) -> bool:
	for id: int in other:
		if not _ids.has(id):
			return false
	return true
