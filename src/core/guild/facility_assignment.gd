class_name FacilityAssignment
extends RefCounted
## 어느 대원이 어느 시설에 있는가. 아지트의 내정 상태다.
##
## ## 겸직은 없다
##
## 한 대원은 시설 한 곳에만 있는다. 겸직을 허용하면 "누굴 어디에" 가 아니라
## "전부 다" 가 정답이 되고, 배치가 결정이 아니게 된다
## (docs/design/22-guild-base.md §22.10).
##
## ## 출전자는 여기서 빠지지 않는다
##
## 던전에 데려간 대원의 배치를 지우지 않는다. 돌아오면 원래 자리로 돌아가야 하고,
## 매번 배치를 다시 하게 만들면 그건 결정이 아니라 잡일이다.
## 대신 **효과를 셀 때 제외한다** (staff_count 의 absent_ids).

## member_id -> Facility.Kind
var _slots: Dictionary = {}


## 대원을 시설에 배치한다. 정원이 차 있으면 실패한다.
##
## 이미 다른 시설에 있으면 옮겨 간다 — 옮기려고 먼저 해제할 필요가 없다.
func assign(member_id: String, kind: Facility.Kind) -> bool:
	if member_id.is_empty():
		return false
	if _slots.get(member_id, -1) == int(kind):
		return true
	if members_at(kind).size() >= GuildBalance.FACILITY_CAPACITY:
		return false
	_slots[member_id] = int(kind)
	return true


## 배치를 푼다. 배치되어 있지 않았으면 아무 일도 없다.
func unassign(member_id: String) -> void:
	_slots.erase(member_id)


func is_assigned(member_id: String) -> bool:
	return _slots.has(member_id)


## 이 대원이 있는 시설. 배치되어 있지 않으면 -1 을 돌려준다.
##
## enum 밖의 값을 쓰는 이유는 "어디에도 없음" 이 시설의 한 종류가 아니기 때문이다.
## NONE 을 enum 에 넣으면 시설을 훑는 모든 자리에서 그것을 걸러야 한다.
func facility_of(member_id: String) -> int:
	return int(_slots.get(member_id, -1))


## 이 시설에 배치된 대원들. 등록 순서를 유지한다.
func members_at(kind: Facility.Kind) -> Array[String]:
	var ids: Array[String] = []
	for member_id in _slots:
		if int(_slots[member_id]) == int(kind):
			ids.append(member_id)
	return ids


## 이 시설에서 **실제로 일하고 있는** 인원 수.
##
## absent_ids 는 지금 던전에 나가 있는 대원들이다. 배치는 남아 있지만 일은 못 한다 —
## 이 한 줄이 편성과 배치를 같은 인원 풀 위에서 다투게 만든다 (Facility 참고).
func staff_count(kind: Facility.Kind, absent_ids: Array[String] = []) -> int:
	var count := 0
	for member_id in members_at(kind):
		if not absent_ids.has(member_id):
			count += 1
	return count


## 길드에서 빠진 대원의 배치를 정리한다.
func retain_only(member_ids: Array[String]) -> void:
	for member_id in _slots.keys():
		if not member_ids.has(member_id):
			_slots.erase(member_id)
