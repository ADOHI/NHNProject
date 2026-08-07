class_name ProtoControlGroups
extends RefCounted
## 숫자키에 묶어 둔 부대. 저장 · 불러오기 · 같은 숫자 연타로 화면 이동까지를 판정한다.
##
## 연타 판정을 화면 코드에 두지 않는 이유는, 그것이 **시간에 의존하는 규칙**이기 때문이다.
## 시간이 걸린 규칙은 눈으로 확인하기 어렵고 회귀도 조용히 일어난다. 시각을 인자로 받아
## 순수 함수로 만들면 테스트가 그 규칙을 대신 지켜 준다.

## 부대 칸 수. 스타크래프트와 같이 1..9 와 0 을 쓴다.
const SLOT_COUNT := 10

## 같은 숫자를 이 안에 다시 누르면 연타로 본다(밀리초).
##
## 400 은 더블클릭 판정과 같은 대역이다. 이보다 짧으면 의도한 연타가 자주 새고,
## 길면 부대를 연달아 부르는 평범한 조작이 화면 이동으로 오인된다.
const DOUBLE_TAP_MSEC := 400

var _groups: Dictionary = {}
var _last_press_slot := -1
var _last_press_msec := -100000


## 지금 선택을 이 칸에 저장한다. 기존 내용은 버린다.
func assign(slot: int, ids: PackedInt32Array) -> void:
	if not _is_valid_slot(slot):
		return
	_groups[slot] = _unique(ids)


## 기존 부대에 더한다. Shift+숫자.
func append(slot: int, ids: PackedInt32Array) -> void:
	if not _is_valid_slot(slot):
		return
	var merged := _stored(slot)
	merged.append_array(ids)
	_groups[slot] = _unique(merged)


## 이 칸에 저장된 id 목록.
func members(slot: int) -> PackedInt32Array:
	return _stored(slot)


func size(slot: int) -> int:
	return _stored(slot).size()


func has_members(slot: int) -> bool:
	return not _stored(slot).is_empty()


## 사라진 유닛을 모든 칸에서 떨군다.
func retain(alive: PackedInt32Array) -> void:
	var alive_set: Dictionary = {}
	for id in alive:
		alive_set[id] = true
	for slot: int in _groups.keys():
		var kept := PackedInt32Array()
		for id in _stored(slot):
			if alive_set.has(id):
				kept.append(id)
		_groups[slot] = kept


## 숫자키를 눌렀다. 같은 칸을 연달아 눌렀으면 true 를 돌려주고, 화면은 그때 시점을 옮긴다.
##
## 시각을 밖에서 받는 이유는 테스트가 시간을 직접 정할 수 있어야 하기 때문이다.
func note_press(slot: int, now_msec: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	var repeated := slot == _last_press_slot and now_msec - _last_press_msec <= DOUBLE_TAP_MSEC
	_last_press_slot = slot
	_last_press_msec = now_msec
	# 세 번째 누름이 또 연타로 잡히지 않게 판정 뒤에는 시각을 밀어 둔다.
	if repeated:
		_last_press_msec = now_msec - DOUBLE_TAP_MSEC - 1
	return repeated


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


func _stored(slot: int) -> PackedInt32Array:
	if not _is_valid_slot(slot) or not _groups.has(slot):
		return PackedInt32Array()
	return (_groups[slot] as PackedInt32Array).duplicate()


func _unique(ids: PackedInt32Array) -> PackedInt32Array:
	var seen: Dictionary = {}
	var result := PackedInt32Array()
	for id in ids:
		if seen.has(id):
			continue
		seen[id] = true
		result.append(id)
	return result
